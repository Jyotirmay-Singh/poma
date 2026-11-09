#include "focus_audio_runtime.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <mutex>
#include <random>
#include <string>
#include <thread>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#include <time.h>
#endif

namespace {
int64_t Now() {
#ifdef _WIN32
  ULONGLONG ticks = 0;
  QueryInterruptTimePrecise(&ticks);
  return static_cast<int64_t>(ticks / 10);
#elif defined(__APPLE__)
  return static_cast<int64_t>(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1000);
#else
  timespec value{};
  if (clock_gettime(CLOCK_BOOTTIME, &value) != 0) return -1;
  return static_cast<int64_t>(value.tv_sec) * 1000000 + value.tv_nsec / 1000;
#endif
}
#ifndef POMA_MOBILE_AUDIO_TESTS
struct PomaMobileRenderer {
  void (*prepare_init)();
  void (*attributes)(unsigned);
  int (*init)(int, unsigned, unsigned, unsigned, unsigned);
  int (*load)(char*, unsigned char*, int, int, unsigned*);
  int (*play)(unsigned, unsigned, float, float, bool, bool, double, unsigned*);
  int (*pause)(unsigned, bool);
  int (*stop)(unsigned);
  int (*volume)(unsigned, float);
  int (*fade)(unsigned, float, float);
  int (*schedule_stop)(unsigned, float);
  double (*engine_time)();
  void (*fade_scheduled)(unsigned, double, float, double, bool);
  void (*dispose)();
  void (*callbacks)(PomaVoiceCallback, PomaFileCallback, PomaDeviceCallback);
  void (*native_free)(void*);
};
#endif
void DeviceFeedback(unsigned* state);
struct Runtime {
  std::mutex mutex;
  std::condition_variable changed;
  // In-memory capability: a prior process's notification must never match a
  // cold process that happens to reach the same operation generation.
  static int64_t Residency() {
    std::random_device entropy;
    const auto random = (static_cast<uint64_t>(entropy()) << 32) ^ entropy();
    return static_cast<int64_t>((random ^ static_cast<uint64_t>(Now())) & 0x3fffffffffffffffULL) | 1;
  }
  std::atomic<int64_t> owner{Residency()}, floor{0}, epoch{0};
  std::atomic<unsigned> voice{0};
  std::atomic<bool> busy{false};
  std::atomic<PomaMobileEvent> event{nullptr};
  std::atomic<int> device_event{-1};
  std::atomic<int64_t> device_generation{0};
  bool ending = false, initialized = false, retiring = false;
  int64_t serial = 0, source = 0, generation = 0, platform_epoch = 0;
  int64_t deadline = 0;
  unsigned hash = 0;
  std::vector<unsigned char> encoded;
  PomaMobileRenderer api{};
  std::thread worker;
  Runtime() : worker([this] { Run(); }) {}
  ~Runtime() {
    { std::lock_guard<std::mutex> lock(mutex); ending = true; Clear(); }
    changed.notify_all();
    worker.join();
  }
  void Emit(int kind, int64_t generation_value) {
    const auto callback = event.load();
    if (callback) callback(kind, owner.load(), generation_value, epoch.load());
  }
  bool Resolve() {
    if (api.init) return true;
#ifndef POMA_MOBILE_AUDIO_TESTS
#ifdef __ANDROID__
    // dlopen reuses the packaged library; it never constructs a second engine.
    void* library = dlopen("libflutter_soloud_plugin.so", RTLD_NOW | RTLD_LOCAL);
#elif defined(__APPLE__)
    void* library = RTLD_DEFAULT;
#else
    return false;
#endif
#if defined(__ANDROID__) || defined(__APPLE__)
#define LOAD(field, name) api.field = reinterpret_cast<decltype(api.field)>(dlsym(library, name))
    LOAD(prepare_init, "prepareEngineInit"); LOAD(attributes, "setAndroidAAudioAttributes");
    LOAD(init, "initEngine"); LOAD(load, "loadMem"); LOAD(play, "play");
    LOAD(pause, "setPause"); LOAD(stop, "stop"); LOAD(volume, "setVolume");
    LOAD(fade, "fadeVolume"); LOAD(schedule_stop, "scheduleStop");
    LOAD(engine_time, "getEngineTime"); LOAD(fade_scheduled, "fadeScheduled"); LOAD(dispose, "dispose");
    LOAD(callbacks, "setDartEventCallback"); LOAD(native_free, "nativeFree");
#undef LOAD
#endif
#endif
    if (!api.prepare_init || !api.attributes || !api.init || !api.load ||
        !api.play || !api.pause || !api.stop || !api.volume || !api.fade ||
        !api.schedule_stop || !api.engine_time || !api.fade_scheduled || !api.dispose ||
        !api.callbacks || !api.native_free) { api = {}; return false; }
    return true;
  }
  bool Valid(int64_t who, int64_t gen, int64_t ep, int64_t until) const {
    const auto now = Now();
    return who == owner && gen == floor && ep == epoch && now >= 0 && until > now;
  }
  void Clear() {
    const auto handle = voice.exchange(0);
    if (handle && initialized) { api.volume(handle, 0); api.stop(handle); }
    busy = false;
    retiring = false;
    source = 0; hash = 0; deadline = 0;
    // Device teardown may block in a platform driver. The worker owns it;
    // mute, route loss and expiry must retire the voice before that wait.
    changed.notify_all();
  }
  void Dispose() {
    if (initialized) { api.dispose(); initialized = false; }
    encoded.clear();
  }
  void Run() {
    std::unique_lock<std::mutex> lock(mutex);
    while (!ending) {
      const int device_kind = device_event.exchange(-1);
      if (device_kind >= 0) {
        const auto gen = device_generation.load();
        if (busy && platform_epoch != epoch) Clear();
        Emit(device_kind, gen);
      }
      if (!busy && initialized) Dispose();
      if (!busy) { changed.wait(lock); continue; }
      const auto now = Now();
      const bool expired = now < 0 || now >= deadline;
      const bool cancelled = platform_epoch != epoch || (!retiring && generation != floor);
      if (expired || cancelled) {
        const auto gen = generation;
        const bool natural = expired && !retiring && !cancelled;
        Clear();
        Emit(natural ? 0 : 7, gen); // 7: native cleanup only, not a Dart error.
        continue;
      }
      changed.wait_for(lock, std::chrono::microseconds(deadline - now));
    }
    Dispose();
  }
};
Runtime& State() { static Runtime runtime; return runtime; }
void DeviceFeedback(unsigned* state) {
  if (!state) return;
  auto& s = State();
  const unsigned kind = *state;
  s.api.native_free(state);
  // Never call back into a device from its notification/audio thread. Epoch
  // invalidation is immediate; the guard worker retires output independently
  // of Java/Swift/Dart, including reroutes with an unchanged device inventory.
  if ((kind == 2 || kind == 3) && s.busy) {
    s.device_generation = s.floor.load();
    ++s.epoch;
    s.device_event = kind == 2 ? 3 : 1;
    s.changed.notify_all();
  }
}
}

extern "C" {
void pomaMobileSetEvent(PomaMobileEvent callback) { State().event = callback; }
int64_t pomaMobileNow() { return Now(); }
int64_t pomaMobileOwner() { return State().owner; }
int64_t pomaMobileGeneration() { return State().floor; }
int64_t pomaMobileEpoch() { return State().epoch; }
int pomaMobileBusy() { return State().busy ? 1 : 0; }
int pomaMobilePlaying() { return State().voice != 0 ? 1 : 0; }
int64_t pomaMobileOpen() {
  auto& s = State(); std::lock_guard<std::mutex> lock(s.mutex);
  s.Clear(); ++s.owner; ++s.epoch; s.floor = 0;
  s.changed.notify_all(); return s.owner;
}
int64_t pomaMobilePrepare(int64_t owner, int64_t generation, int64_t epoch,
    int64_t startup_deadline, int sound, const unsigned char* bytes, int length) {
  auto& s = State(); std::lock_guard<std::mutex> lock(s.mutex);
  if (!bytes || length < 1 || length > 4 * 1024 * 1024 || sound < 1 || sound > 4 ||
      !s.Valid(owner, generation, epoch, startup_deadline)) return 0;
  s.Clear();
  s.Dispose();
  if (!s.Resolve()) return 0;
  s.generation = generation; s.platform_epoch = epoch;
  s.deadline = startup_deadline; s.busy = true;
  s.api.prepare_init(); s.api.attributes(1);
  s.api.callbacks(nullptr, nullptr, DeviceFeedback);
  // Media playback uses a conservative, media/music-tagged Android stream.
  const int initialized = s.api.init(-1, 48000, 512, 2, 0);
  s.initialized = true; // Partial initialization also requires disposal.
  if (initialized != 0) { s.Clear(); return 0; }
  s.encoded.assign(bytes, bytes + length);
  std::string name = "poma-focus-" + std::to_string(owner) + "-" + std::to_string(++s.serial);
  // The pinned stream-mode loadMem takes ownership of its caller's allocation.
  // Decode mode copies instead; never transfer a std::vector/JVM/Swift buffer.
  // Only one bundled recording is decoded (largest draft: ~34 MiB PCM).
  if (s.api.load(&name[0], s.encoded.data(), length, 1, &s.hash) != 0 ||
      !s.Valid(owner, generation, epoch, startup_deadline)) { s.Clear(); return 0; }
  s.source = s.serial;
  s.changed.notify_all(); return s.source;
}
int pomaMobileStart(int64_t owner, int64_t source, int64_t generation,
    int64_t epoch, int64_t deadline, float gain) {
  auto& s = State(); std::unique_lock<std::mutex> lock(s.mutex, std::try_to_lock);
  if (!lock.owns_lock()) return 0;
  if (owner != s.owner || source != s.source || generation != s.generation ||
      epoch != s.platform_epoch || !s.initialized) return 0;
  if (!s.Valid(owner, generation, epoch, deadline) || s.deadline <= Now()) { s.Clear(); return -1; }
  if (!std::isfinite(gain) || gain <= 0 || gain > 1) { s.Clear(); return 0; }
  unsigned handle = 0;
  if (s.api.play(s.hash, 0, 0, 0, true, true, 0, &handle) != 0) { s.Clear(); return 0; }
  s.voice = handle;
  const float remaining = static_cast<float>(deadline - Now()) / 1000000.0f;
  if (remaining <= 0 || s.api.schedule_stop(handle, remaining) != 0) { s.Clear(); return -1; }
  const auto fade = std::min(0.2, static_cast<double>(remaining));
  s.api.fade_scheduled(handle, s.api.engine_time() + remaining - fade, 0, fade, true);
  if (
      !s.Valid(owner, generation, epoch, deadline) || s.api.pause(handle, false) != 0 ||
      !s.Valid(owner, generation, epoch, deadline)) { s.Clear(); return -1; }
  s.deadline = deadline; s.retiring = false; s.busy = true;
  s.api.fade(handle, gain, std::min(0.6f, remaining));
  s.changed.notify_all(); return 1;
}
void pomaMobileRevoke(int64_t owner, int64_t generation, int fade_ms) {
  auto& s = State();
  if (owner != s.owner) return;
  auto previous = s.floor.load();
  while (generation > previous && !s.floor.compare_exchange_weak(previous, generation)) {}
  if (generation < previous) return;
  // A pending load has no audible voice. Invalidate it without waiting for IO.
  std::unique_lock<std::mutex> lock(s.mutex, std::defer_lock);
  if (s.voice != 0) lock.lock(); else (void)lock.try_lock();
  if (lock.owns_lock() && owner == s.owner && generation >= s.generation) {
    if (fade_ms > 0 && s.voice && s.initialized) {
      const int duration = std::min(fade_ms, 200);
      s.api.fade(s.voice, 0, static_cast<float>(duration) / 1000);
      s.deadline = std::min(s.deadline, Now() + duration * 1000);
      s.retiring = true;
    } else { s.Clear(); s.Emit(7, generation); }
  } else if (!lock.owns_lock()) {
    s.busy = false;
  }
  s.changed.notify_all();
}
void pomaMobileVolume(int64_t owner, float gain) {
  auto& s = State(); std::unique_lock<std::mutex> lock(s.mutex, std::try_to_lock);
  if (!lock.owns_lock()) return; // Loading/teardown has no audible voice.
  if (owner != s.owner || !std::isfinite(gain)) return;
  if (gain <= 0) { s.Clear(); s.Emit(7, s.floor); return; }
  if (s.voice && s.initialized && s.generation == s.floor && s.platform_epoch == s.epoch)
    s.api.volume(s.voice, std::min(gain, 1.0f));
}
void pomaMobileRelease(int64_t owner, int64_t source) {
  auto& s = State(); std::unique_lock<std::mutex> lock(s.mutex);
  while (owner == s.owner && source == s.source && s.retiring && Now() < s.deadline)
    s.changed.wait_for(lock, std::chrono::microseconds(s.deadline - Now()));
  if (owner == s.owner && source == s.source) { s.Clear(); s.Emit(7, s.generation); }
}
void pomaMobileInterrupt(int kind) {
  auto& s = State(); ++s.epoch;
  const auto gen = s.floor.load();
  std::unique_lock<std::mutex> lock(s.mutex, std::defer_lock);
  if (s.voice != 0) lock.lock(); else (void)lock.try_lock();
  if (lock.owns_lock()) s.Clear();
  else s.busy = false;
  s.Emit(kind, gen); s.changed.notify_all();
}
void pomaMobileReconcile() {
  auto& s = State(); std::unique_lock<std::mutex> lock(s.mutex, std::try_to_lock);
  if (!lock.owns_lock()) return; // A pending load is silent and rechecks its lease.
  if (s.busy && !s.Valid(s.owner, s.generation, s.platform_epoch, s.deadline)) {
    const auto gen = s.generation; s.Clear(); s.Emit(0, gen);
  }
}
void pomaMobileClose(int64_t owner) {
  auto& s = State(); if (owner != s.owner) return;
  ++s.epoch;
  std::unique_lock<std::mutex> lock(s.mutex, std::defer_lock);
  if (s.voice != 0) lock.lock(); else (void)lock.try_lock();
  if (owner == s.owner) {
    if (lock.owns_lock()) s.Clear(); else s.busy = false;
    s.Emit(7, s.floor); ++s.owner;
  }
  s.changed.notify_all();
}
}
#ifdef POMA_MOBILE_AUDIO_TESTS
void pomaMobileTestRenderer(const PomaMobileRenderer& renderer) {
  auto& s = State(); std::lock_guard<std::mutex> lock(s.mutex);
  s.Clear(); s.Dispose(); s.api = renderer;
}
#endif

#include "focus_audio_runtime.h"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <thread>
#include <stdexcept>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <vector>
#include <cstdlib>
#include <windows.h>

namespace {
std::atomic<int> voices{0}, engines{0}, expired{0}, disposal{0};
std::atomic<bool> hold{false}, loading{false};
std::atomic<PomaDeviceCallback> device_callback{nullptr};
std::mutex gate_mutex;
std::condition_variable gate;
int checks = 0;
void Check(bool result, const char* message) { ++checks; if (!result) throw std::runtime_error(message); }
void Prepare() {}
void Attributes(unsigned) {}
int Init(int, unsigned, unsigned, unsigned, unsigned) { ++engines; return 0; }
int Load(char*, unsigned char*, int, int, unsigned* hash) {
  loading = true;
  std::unique_lock<std::mutex> lock(gate_mutex);
  gate.wait(lock, [] { return !hold; });
  *hash = 41; loading = false; return 0;
}
int Play(unsigned, unsigned, float, float, bool, bool, double, unsigned* handle) { *handle = 23; voices = 1; return 0; }
int Pause(unsigned, bool) { return 0; }
int Stop(unsigned) { voices = 0; return 0; }
int Volume(unsigned, float) { return 0; }
int Fade(unsigned, float, float) { return 0; }
int Schedule(unsigned, float) { return 0; }
double EngineTime() { return static_cast<double>(pomaMobileNow()) / 1000000.0; }
void FadeScheduled(unsigned, double, float, double, bool) {}
void Callbacks(PomaVoiceCallback, PomaFileCallback, PomaDeviceCallback callback) { device_callback = callback; }
void NativeFree(void* pointer) { std::free(pointer); }
void Dispose() { voices = 0; engines = 0; device_callback = nullptr; ++disposal; }
void Event(int kind, int64_t, int64_t, int64_t) { if (kind == 0) ++expired; }
int64_t PrepareSource(int64_t owner, int64_t gen, int64_t epoch, int64_t deadline = 0) {
  const unsigned char bytes[]{1, 2};
  return pomaMobilePrepare(owner, gen, epoch, deadline ? deadline : pomaMobileNow() + 2000000, 1, bytes, 2);
}
void Wait(const std::atomic<bool>& value) {
  const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(2);
  while (!value && std::chrono::steady_clock::now() < end) std::this_thread::sleep_for(std::chrono::milliseconds(1));
}
void WaitQuiet() {
  const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(2);
  while (engines != 0 && std::chrono::steady_clock::now() < end) std::this_thread::sleep_for(std::chrono::milliseconds(1));
}
PomaMobileRenderer real_api{};
unsigned real_voice = 0, real_hash = 0;
int RealLoad(char* name, unsigned char* bytes, int length, int mode, unsigned* hash) {
  const int result = real_api.load(name, bytes, length, mode, hash);
  real_hash = *hash; return result;
}
int RealPlay(unsigned hash, unsigned bus, float gain, float pan, bool paused, bool loop, double at, unsigned* voice) {
  const int result = real_api.play(hash, bus, gain, pan, paused, loop, at, voice);
  real_voice = *voice; return result;
}
void RealChecks(const std::filesystem::path& library_dir, const std::filesystem::path& assets) {
  SetDllDirectoryW(library_dir.c_str());
  const auto library = LoadLibraryW((library_dir / L"flutter_soloud_plugin.dll").c_str());
  Check(library != nullptr, "packaged playback DLL loads without installation");
#define LOAD(field, name) real_api.field = reinterpret_cast<decltype(real_api.field)>(GetProcAddress(library, name)); Check(real_api.field != nullptr, name)
  LOAD(prepare_init, "prepareEngineInit"); LOAD(attributes, "setAndroidAAudioAttributes");
  LOAD(init, "initEngine"); LOAD(load, "loadMem"); LOAD(play, "play"); LOAD(pause, "setPause");
  LOAD(stop, "stop"); LOAD(volume, "setVolume"); LOAD(fade, "fadeVolume");
  LOAD(schedule_stop, "scheduleStop"); LOAD(engine_time, "getEngineTime");
  LOAD(fade_scheduled, "fadeScheduled"); LOAD(dispose, "dispose");
  LOAD(callbacks, "setDartEventCallback"); LOAD(native_free, "nativeFree");
#undef LOAD
  auto api = real_api; api.load = RealLoad; api.play = RealPlay;
  pomaMobileTestRenderer(api);
  const auto seek = reinterpret_cast<int (*)(unsigned, float)>(GetProcAddress(library, "seek"));
  const auto length = reinterpret_cast<double (*)(unsigned)>(GetProcAddress(library, "getLength"));
  const auto valid = reinterpret_cast<int (*)(unsigned)>(GetProcAddress(library, "getIsValidVoiceHandle"));
  Check(seek && length && valid, "native codec probe exports present");
  const auto owner = pomaMobileOpen();
  const auto epoch = pomaMobileEpoch();
  const char* names[]{"tibetan_bells.ogg", "waterfall.ogg", "ocean_waves.ogg", "forest_birds.ogg"};
  for (int index = 0; index < 4; ++index) {
    std::ifstream input(assets / names[index], std::ios::binary);
    const std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    Check(!bytes.empty(), "bundled original asset readable");
    const auto generation = static_cast<int64_t>(index + 1);
    pomaMobileRevoke(owner, generation, 0);
    const auto source = pomaMobilePrepare(owner, generation, epoch, pomaMobileNow() + 5000000,
        index + 1, bytes.data(), static_cast<int>(bytes.size()));
    Check(source > 0, "real encoded asset prepared by mobile runtime");
    const auto deadline = pomaMobileNow() + 600000;
    const int before_expiry = expired;
    Check(pomaMobileStart(owner, source, generation, epoch, deadline, .05f) == 1, "real renderer starts through mobile lease guard");
    const auto duration = length(real_hash);
    Check(duration > 30 && duration <= 121, "real decoder reports expected duration range");
    for (int join = 0; join < 5; ++join) {
      Check(seek(real_voice, static_cast<float>(duration - .025)) == 0, "forced loop seek accepted");
      std::this_thread::sleep_for(std::chrono::milliseconds(50));
      Check(valid(real_voice) != 0, "native loop wraps without losing voice");
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(450));
    Check(pomaMobileBusy() == 0 && pomaMobilePlaying() == 0, "real output retired while foreground caller was blocked");
    Check(expired == before_expiry + 1, "real native expiry emitted once");
    std::cout << names[index] << ": five forced wraps; native cleanup observed " << pomaMobileNow() - deadline << " us after deadline (includes wait; not speaker latency)\n";
  }
  const unsigned char corrupt[]{0, 1, 2, 3, 4};
  pomaMobileRevoke(owner, 5, 0);
  Check(pomaMobilePrepare(owner, 5, epoch, pomaMobileNow() + 5000000, 1, corrupt, 5) == 0,
      "corrupt asset fails without an audible voice");
  Check(pomaMobilePlaying() == 0, "corrupt asset recovery stays silent");
  pomaMobileClose(owner);
  std::cout << "Real Windows backend qualification only; phone backends and human listening remain pending\n";
}
}
int main(int argc, char** argv) {
  try {
    pomaMobileTestRenderer({Prepare, Attributes, Init, Load, Play, Pause, Stop, Volume, Fade, Schedule, EngineTime, FadeScheduled, Dispose, Callbacks, NativeFree});
    pomaMobileSetEvent(Event);
    const auto owner = pomaMobileOpen();
    auto epoch = pomaMobileEpoch();
    pomaMobileRevoke(owner, 1, 0);
    auto source = PrepareSource(owner, 1, epoch);
    Check(source > 0, "source prepared");
    Check(pomaMobileStart(owner, source, 1, epoch, pomaMobileNow() + 60000, .35f) == 1, "voice starts");
    // No UI/Dart callback participates in this wait or native cleanup.
    std::this_thread::sleep_for(std::chrono::milliseconds(120));
    Check(voices == 0 && engines == 0 && pomaMobileBusy() == 0, "deadline retires voice and device without Dart");
    Check(expired == 1, "one native expiry");
    pomaMobileRevoke(owner, 2, 0);
    source = PrepareSource(owner, 2, epoch);
    pomaMobileRevoke(owner, 3, 0);
    Check(pomaMobileStart(owner, source, 2, epoch, pomaMobileNow() + 100000, .35f) != 1, "cancelled prepared source cannot start");
    Check(PrepareSource(owner, 2, epoch) == 0, "stale load rejected");
    source = PrepareSource(owner, 3, epoch);
    Check(pomaMobileStart(owner, source, 3, epoch, pomaMobileNow() - 1, .35f) != 1, "expired start rejected");
    pomaMobileRevoke(owner, 4, 0);
    source = PrepareSource(owner, 4, epoch);
    Check(pomaMobileStart(owner, source, 4, epoch, pomaMobileNow() + 1000000, .35f) == 1, "replacement starts");
    pomaMobileInterrupt(3);
    WaitQuiet();
    Check(voices == 0 && engines == 0, "route loss retires voice and engine immediately");
    Check(pomaMobileStart(owner, source, 4, epoch, pomaMobileNow() + 1000000, .35f) != 1, "old route epoch cannot resume");
    epoch = pomaMobileEpoch();
    pomaMobileRevoke(owner, 5, 0);
    hold = true;
    int64_t late = -1;
    std::thread load([&] { late = PrepareSource(owner, 5, epoch); });
    Wait(loading); Check(loading, "load held");
    const auto before = std::chrono::steady_clock::now();
    pomaMobileRevoke(owner, 6, 0);
    Check(std::chrono::steady_clock::now() - before < std::chrono::milliseconds(50), "cancellation does not wait for loading");
    hold = false; gate.notify_all(); load.join();
    WaitQuiet();
    Check(late == 0 && voices == 0 && engines == 0, "late load is disposed without playback");
    source = PrepareSource(owner, 6, epoch);
    Check(pomaMobileStart(owner, source, 6, epoch, pomaMobileNow() + 1000000, .35f) == 1, "post-cancel recovery");
    pomaMobileVolume(owner, 0);
    WaitQuiet();
    Check(voices == 0 && engines == 0, "zero gain cannot retain output device");
    source = PrepareSource(owner, 6, epoch);
    const auto newer = pomaMobileOpen();
    Check(newer != owner, "residency identity replaced");
    Check(pomaMobileStart(owner, source, 6, epoch, pomaMobileNow() + 1000000, .35f) != 1, "old residency rejected");
    pomaMobileClose(owner);
    Check(pomaMobileOwner() == newer, "old close cannot close a new owner");
    pomaMobileClose(newer);
    WaitQuiet();
    Check(voices == 0 && engines == 0 && disposal > 0, "terminal resources released");
    const auto closing_owner = pomaMobileOpen();
    const auto closing_epoch = pomaMobileEpoch();
    pomaMobileRevoke(closing_owner, 1, 0);
    hold = true; loading = false;
    std::thread closing_load([&] { late = PrepareSource(closing_owner, 1, closing_epoch); });
    Wait(loading);
    const auto closing_started = std::chrono::steady_clock::now();
    pomaMobileClose(closing_owner);
    Check(std::chrono::steady_clock::now() - closing_started < std::chrono::milliseconds(50), "close does not wait for silent loading");
    hold = false; gate.notify_all(); closing_load.join(); WaitQuiet();
    Check(late == 0 && engines == 0, "old residency cannot publish a late source after close");
    const auto route_owner = pomaMobileOpen();
    const auto route_epoch = pomaMobileEpoch();
    pomaMobileRevoke(route_owner, 1, 0);
    source = PrepareSource(route_owner, 1, route_epoch);
    Check(pomaMobileStart(route_owner, source, 1, route_epoch, pomaMobileNow() + 1000000, .35f) == 1, "device feedback fixture starts");
    auto* notification = static_cast<unsigned*>(std::malloc(sizeof(unsigned)));
    *notification = 2;
    const auto receive = device_callback.load();
    Check(receive != nullptr, "native backend route callback is registered");
    receive(notification);
    WaitQuiet();
    Check(voices == 0 && pomaMobileEpoch() > route_epoch, "backend reroute retires audio without Java or Dart callbacks");
    Check(pomaMobileStart(route_owner, source, 1, route_epoch, pomaMobileNow() + 1000000, .35f) != 1, "backend reroute rejects stale unpause");
    pomaMobileClose(route_owner);
    if (argc == 3) RealChecks(argv[1], argv[2]);
    std::cout << checks << " mobile native safety checks passed\n";
    return 0;
  } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}

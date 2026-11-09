#include "focus_audio_guard.h"
#include <windows.h>
#include <powrprof.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>
#include <algorithm>
#include <atomic>
#include <memory>
#include <mutex>
#include <thread>

namespace {
int64_t Now() { ULONGLONG ticks = 0; QueryInterruptTimePrecise(&ticks); return static_cast<int64_t>(ticks / 10); }
class Guard final : public IMMNotificationClient {
 public:
  explicit Guard(PomaAudioEvent callback) : callback_(callback) {
    const auto module = GetModuleHandleW(L"flutter_soloud_plugin.dll");
    if (!module) return;
    pause_ = reinterpret_cast<Pause>(GetProcAddress(module, "setPause"));
    stop_ = reinterpret_cast<Stop>(GetProcAddress(module, "stop"));
    volume_ = reinterpret_cast<Volume>(GetProcAddress(module, "setVolume"));
    if (!pause_ || !stop_ || !volume_) return;
    changed_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    ready_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!changed_ || !ready_) return;
    worker_ = std::thread([this] { Run(); });
    if (WaitForSingleObject(ready_, 5000) != WAIT_OBJECT_0 || !endpoint_ready_) return;
    DEVICE_NOTIFY_SUBSCRIBE_PARAMETERS parameters{Power, this};
    valid_ = PowerRegisterSuspendResumeNotification(DEVICE_NOTIFY_CALLBACK, &parameters, &power_) == ERROR_SUCCESS;
  }
  ~Guard() {
    if (power_) PowerUnregisterSuspendResumeNotification(power_);
    { std::lock_guard<std::mutex> lock(mutex_); Silence(); }
    ending_ = true;
    if (changed_) SetEvent(changed_);
    if (worker_.joinable()) worker_.join();
    if (changed_) CloseHandle(changed_);
    if (ready_) CloseHandle(ready_);
  }
  bool valid() const { return valid_; }
#if defined(POMA_FOCUS_AUDIO_TESTS) || defined(POMA_FOCUS_AUDIO_REVIEW)
  void TestPower(ULONG type) { Power(this, type, nullptr); }
  void TestRoute() { Route(); }
  int64_t TestStopOffset() const { return stop_offset_.load(); }
#endif
  int64_t epoch() const { return epoch_.load(); }
  bool Bind(unsigned voice, int64_t generation, int64_t epoch, int64_t deadline) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!valid_ || generation < floor_ || epoch != epoch_ || suspended_ || deadline <= Now()) {
      stop_(voice); return false;
    }
    Silence(); floor_ = generation; generation_ = generation;
    voice_ = voice; deadline_ = deadline;
    if (pause_(voice_, false) != 0 || deadline_ <= Now() || epoch != epoch_) {
      Silence(); return false;
    }
    SetEvent(changed_); return true;
  }
  void Revoke(int64_t generation, int delay_ms) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (generation < floor_) return;
    floor_ = generation;
    if (delay_ms > 0 && voice_) deadline_ = std::min(deadline_, Now() + static_cast<int64_t>(delay_ms) * 1000);
    else Silence();
    SetEvent(changed_);
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** result) override {
    if (!result) return E_POINTER;
    *result = nullptr;
    if (iid == __uuidof(IUnknown) || iid == __uuidof(IMMNotificationClient)) {
      *result = static_cast<IMMNotificationClient*>(this); AddRef(); return S_OK;
    }
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
  ULONG STDMETHODCALLTYPE Release() override { return --references_; }
  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow, ERole, LPCWSTR) override {
    if (flow == eRender) Route(); return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { Route(); return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override { Route(); return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) override { return S_OK; }
 private:
  using Pause = int (*)(unsigned, bool);
  using Stop = int (*)(unsigned);
  using Volume = int (*)(unsigned, float);
  static ULONG CALLBACK Power(PVOID context, ULONG type, PVOID) {
    auto* self = static_cast<Guard*>(context);
    std::lock_guard<std::mutex> lock(self->mutex_);
    if (type == PBT_APMSUSPEND) {
      self->suspended_ = true; ++self->epoch_;
      self->power_generation_ = self->floor_;
      if (self->voice_) { self->volume_(self->voice_, 0); self->pause_(self->voice_, true); }
      self->callback_(4, self->power_generation_, self->epoch_);
    } else if (type == PBT_APMRESUMEAUTOMATIC || type == PBT_APMRESUMESUSPEND) {
      self->suspended_ = false; ++self->epoch_;
      // Never unpause here. Dart must reconcile and bind a new eligible voice.
      self->callback_(5, self->power_generation_, self->epoch_);
    }
    SetEvent(self->changed_); return ERROR_SUCCESS;
  }
  void Route() { ++epoch_; route_changed_ = true; SetEvent(changed_); }
  void Silence() {
    if (voice_) { volume_(voice_, 0); stop_(voice_); }
    voice_ = 0; deadline_ = 0;
  }
  void Run() {
    const auto initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
    if (SUCCEEDED(initialized) && SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
        CLSCTX_ALL, IID_PPV_ARGS(&enumerator)))) {
      endpoint_ready_ = SUCCEEDED(enumerator->RegisterEndpointNotificationCallback(this));
    }
    SetEvent(ready_);
    while (!ending_) {
      DWORD wait = INFINITE;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        if (route_changed_.exchange(false)) {
          const auto generation = floor_; Silence(); callback_(3, generation, epoch_);
        }
        if (voice_) {
          const auto left = deadline_ - Now();
          if (left <= 0) {
            const auto generation = generation_; const auto deadline = deadline_;
            Silence(); stop_offset_ = Now() - deadline; callback_(0, generation, epoch_);
          } else wait = static_cast<DWORD>(std::min<int64_t>((left + 999) / 1000, MAXDWORD - 1));
        }
      }
      if (!ending_) WaitForSingleObject(changed_, wait);
    }
    if (endpoint_ready_) enumerator->UnregisterEndpointNotificationCallback(this);
    enumerator.Reset();
    if (SUCCEEDED(initialized)) CoUninitialize();
  }
  PomaAudioEvent callback_;
  Pause pause_ = nullptr;
  Stop stop_ = nullptr;
  Volume volume_ = nullptr;
  std::mutex mutex_;
  std::thread worker_;
  HANDLE changed_ = nullptr, ready_ = nullptr;
  HPOWERNOTIFY power_ = nullptr;
  std::atomic<bool> ending_{false}, route_changed_{false}, endpoint_ready_{false};
  std::atomic<int64_t> epoch_{0};
  std::atomic<int64_t> stop_offset_{-1};
  std::atomic<ULONG> references_{1};
  bool valid_ = false, suspended_ = false;
  unsigned voice_ = 0;
  int64_t deadline_ = 0, generation_ = 0, floor_ = 0, power_generation_ = 0;
};
std::unique_ptr<Guard> guard;
}
extern "C" {
int pomaAudioInitialize(PomaAudioEvent callback) {
  if (!callback || guard) return 0;
  guard = std::make_unique<Guard>(callback);
  if (!guard->valid()) { guard.reset(); return 0; }
  return 1;
}
int64_t pomaAudioNow() { return Now(); }
int64_t pomaAudioEpoch() { return guard ? guard->epoch() : -1; }
int pomaAudioBind(unsigned voice, int64_t generation, int64_t epoch, int64_t deadline) {
  return guard && guard->Bind(voice, generation, epoch, deadline) ? 1 : 0;
}
void pomaAudioRevoke(int64_t generation, int delay_ms) { if (guard) guard->Revoke(generation, delay_ms); }
void pomaAudioDetach() { guard.reset(); }
#if defined(POMA_FOCUS_AUDIO_TESTS) || defined(POMA_FOCUS_AUDIO_REVIEW)
__declspec(dllexport) void pomaAudioTestPower(ULONG type) { if (guard) guard->TestPower(type); }
__declspec(dllexport) void pomaAudioTestRoute() { if (guard) guard->TestRoute(); }
__declspec(dllexport) int64_t pomaAudioTestStopOffset() { return guard ? guard->TestStopOffset() : -1; }
#endif
}

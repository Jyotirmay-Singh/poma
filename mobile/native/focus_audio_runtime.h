#pragma once
#include <cstdint>

#if defined(_WIN32)
#define POMA_AUDIO_EXPORT __declspec(dllexport)
#else
#define POMA_AUDIO_EXPORT __attribute__((visibility("default"), used))
#endif

// Private ABI for the exactly pinned flutter_soloud 4.1.7 renderer. Native
// ownership deliberately does not share the Dart SoLoud singleton on mobile.
using PomaMobileEvent = void (*)(int kind, int64_t owner, int64_t generation,
                                int64_t epoch);
using PomaVoiceCallback = void (*)(unsigned*);
using PomaFileCallback = void (*)(int, char*, unsigned*, uint64_t*);
using PomaDeviceCallback = void (*)(unsigned*);
extern "C" {
POMA_AUDIO_EXPORT void pomaMobileSetEvent(PomaMobileEvent event);
POMA_AUDIO_EXPORT int64_t pomaMobileOpen();
POMA_AUDIO_EXPORT int64_t pomaMobileNow();
POMA_AUDIO_EXPORT int64_t pomaMobileOwner();
POMA_AUDIO_EXPORT int64_t pomaMobileGeneration();
POMA_AUDIO_EXPORT int64_t pomaMobileEpoch();
POMA_AUDIO_EXPORT int pomaMobileBusy();
POMA_AUDIO_EXPORT int pomaMobilePlaying();
POMA_AUDIO_EXPORT int64_t pomaMobilePrepare(int64_t owner, int64_t generation,
    int64_t epoch, int64_t startup_deadline, int sound,
    const unsigned char* bytes, int length);
POMA_AUDIO_EXPORT int pomaMobileStart(int64_t owner, int64_t source,
    int64_t generation, int64_t epoch, int64_t deadline, float gain);
POMA_AUDIO_EXPORT void pomaMobileRevoke(int64_t owner, int64_t generation,
    int fade_ms);
POMA_AUDIO_EXPORT void pomaMobileVolume(int64_t owner, float gain);
POMA_AUDIO_EXPORT void pomaMobileRelease(int64_t owner, int64_t source);
POMA_AUDIO_EXPORT void pomaMobileInterrupt(int kind);
POMA_AUDIO_EXPORT void pomaMobileReconcile();
POMA_AUDIO_EXPORT void pomaMobileClose(int64_t owner);
}

#ifdef POMA_MOBILE_AUDIO_TESTS
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
void pomaMobileTestRenderer(const PomaMobileRenderer& renderer);
#endif

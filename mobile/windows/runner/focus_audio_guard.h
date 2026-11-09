#ifndef POMA_FOCUS_AUDIO_GUARD_H_
#define POMA_FOCUS_AUDIO_GUARD_H_
#include <cstdint>
// Private ABI for the exactly pinned flutter_soloud 4.1.7 renderer. No timer state.
using PomaAudioEvent = void (*)(int, int64_t, int64_t);
extern "C" {
__declspec(dllexport) int pomaAudioInitialize(PomaAudioEvent callback);
__declspec(dllexport) int64_t pomaAudioNow();
__declspec(dllexport) int64_t pomaAudioEpoch();
__declspec(dllexport) int pomaAudioBind(unsigned voice, int64_t generation, int64_t epoch, int64_t deadline);
__declspec(dllexport) void pomaAudioRevoke(int64_t generation, int delay_ms);
__declspec(dllexport) void pomaAudioDetach();
}
#endif

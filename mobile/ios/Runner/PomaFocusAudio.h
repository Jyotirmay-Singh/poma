#ifndef PomaFocusAudio_h
#define PomaFocusAudio_h
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*PomaFocusAudioEvent)(int, int64_t, int64_t, int64_t);
void pomaMobileSetEvent(PomaFocusAudioEvent event);
int64_t pomaMobileNow(void);
int64_t pomaMobileOwner(void);
int64_t pomaMobileGeneration(void);
int64_t pomaMobileEpoch(void);
int pomaMobileBusy(void);
int pomaMobilePlaying(void);
int64_t pomaMobilePrepare(int64_t owner, int64_t generation, int64_t epoch,
    int64_t startupDeadline, int sound, const unsigned char* bytes, int length);
int pomaMobileStart(int64_t owner, int64_t source, int64_t generation,
    int64_t epoch, int64_t deadline, float gain);
void pomaMobileRelease(int64_t owner, int64_t source);
void pomaMobileInterrupt(int kind);
void pomaMobileReconcile(void);
#ifdef __cplusplus
}
#endif
#endif

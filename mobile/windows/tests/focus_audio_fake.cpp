#include <atomic>
static std::atomic<unsigned> live{0};
static std::atomic<bool> paused{true};
static std::atomic<float> gain{0};
extern "C" {
__declspec(dllexport) int setPause(unsigned voice, bool value) { live = voice; paused = value; return 0; }
__declspec(dllexport) int stop(unsigned voice) { if (live == voice) live = 0; return 0; }
__declspec(dllexport) int setVolume(unsigned, float value) { gain = value; return 0; }
__declspec(dllexport) int fakePlaying() { return live != 0 && !paused; }
}

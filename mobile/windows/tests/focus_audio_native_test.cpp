#include "focus_audio_guard.h"
#include <windows.h>
#include <atomic>
#include <iostream>
extern "C" void pomaAudioTestPower(ULONG type);
extern "C" void pomaAudioTestRoute();
static std::atomic<int> last_kind{-1};
static void Event(int kind, int64_t, int64_t) { last_kind = kind; }
int main() {
  wchar_t path[32768]{}; GetModuleFileNameW(nullptr, path, 32768);
  std::wstring directory(path); directory = directory.substr(0, directory.find_last_of(L"\\/"));
  const auto library = LoadLibraryW((directory + L"\\flutter_soloud_plugin.dll").c_str());
  if (!library) return 1;
  const auto playing = reinterpret_cast<int (*)()>(GetProcAddress(library, "fakePlaying"));
  int count = 0;
  auto check = [&](bool value, const char* name) { ++count; if (!value) { std::cerr << name << '\n'; exit(2); } };
  check(pomaAudioInitialize(Event) == 1, "guard initialized");
  auto epoch = pomaAudioEpoch();
  check(pomaAudioBind(11, 1, epoch, pomaAudioNow() + 100000) == 1, "eligible voice");
  check(playing() == 1, "voice started");
  Sleep(180);
  check(playing() == 0 && last_kind == 0, "native absolute expiry without Dart");
  pomaAudioRevoke(5, 0);
  check(pomaAudioBind(12, 2, epoch, pomaAudioNow() + 1000000) == 0, "stale registration rejected");
  check(pomaAudioBind(13, 6, epoch, pomaAudioNow() - 1) == 0, "expired lease rejected");
  check(pomaAudioBind(14, 7, epoch, pomaAudioNow() + 1000000) == 1, "fresh lease");
  pomaAudioTestPower(PBT_APMSUSPEND);
  check(!playing() && last_kind == 4, "suspend pauses before Dart");
  check(pomaAudioBind(15, 8, pomaAudioEpoch(), pomaAudioNow() + 1000000) == 0, "suspended bind rejected");
  pomaAudioTestPower(PBT_APMRESUMEAUTOMATIC);
  check(!playing() && last_kind == 5, "resume never unpauses");
  check(pomaAudioBind(16, 9, epoch, pomaAudioNow() + 1000000) == 0, "old platform epoch rejected");
  epoch = pomaAudioEpoch();
  check(pomaAudioBind(17, 10, epoch, pomaAudioNow() + 1000000) == 1, "reconciled new bind");
  pomaAudioTestRoute(); Sleep(100);
  check(!playing() && last_kind == 3, "route change stops before Dart");
  pomaAudioRevoke(12, 0);
  check(!playing(), "revoke stays stopped");
  pomaAudioDetach(); pomaAudioDetach();
  check(!playing(), "detach silent and idempotent");
  FreeLibrary(library);
  std::cout << count << " native audio guard checks passed; synthetic renderer, not audible acceptance\n";
  return 0;
}

#include "desktop_instance.h"
#include "calendar_credentials.h"
#include "calendar_links.h"
#include "focus_time.h"
#include <fstream>
#include <iterator>
#include <notificationactivationcallback.h>
#include <winrt/base.h>
#include <iostream>
#include <memory>
#include <vector>

namespace {
int checks = 0;
void Check(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
  ++checks;
  std::cout << "PASS " << message << std::endl;
}
bool Same(RECT a, RECT b) { return EqualRect(&a, &b) != FALSE; }
std::vector<std::wstring> received;
int button_clicks = 0;
LRESULT CALLBACK Receive(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_COMMAND && HIWORD(wparam) == BN_CLICKED) { ++button_clicks; return 0; }
  if (message == poma::kIpcMessage) {
    std::unique_ptr<std::wstring> value(reinterpret_cast<std::wstring*>(lparam));
    received.push_back(*value); return 0;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
void PumpUntil(size_t count) {
  const auto until = GetTickCount64() + 3000;
  while (received.size() < count && GetTickCount64() < until) {
    MSG message{};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) DispatchMessageW(&message);
    Sleep(5);
  }
}
}
int main(int argc, char** argv) {
  // Opt-in, non-mutating probe for owner-assisted real suspend/resume checks.
  // Sleep(20) below tests progress while awake, not system sleep semantics.
  if (argc == 2 && std::string(argv[1]) == "--clock-sample") {
    FILETIME utc{};
    GetSystemTimePreciseAsFileTime(&utc);
    ULARGE_INTEGER value{};
    value.LowPart = utc.dwLowDateTime; value.HighPart = utc.dwHighDateTime;
    ULONGLONG awake = 0;
    QueryUnbiasedInterruptTimePrecise(&awake);
    std::cout << "{\"utcMicros\":" << poma::FileTimeMicros(value.QuadPart)
              << ",\"elapsedMicros\":" << poma::ElapsedMicros()
              << ",\"awakeMicros\":" << awake / 10
              << ",\"bootCount\":null}\n";
    return 0;
  }
  winrt::init_apartment(winrt::apartment_type::single_threaded);
  try {
    if (argc > 1) {
      std::ifstream corpus(argv[1]);
      Check(corpus.is_open(), "Shared URL safety corpus is readable");
      std::string line;
      int row = 0;
      while (std::getline(corpus, line)) {
        ++row;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;
        const auto first = line.find('\t'), second = line.find('\t', first + 1);
        Check(first != std::string::npos && second != std::string::npos, "URL corpus row is valid");
        const auto kind = line.substr(0, first), url = line.substr(second + 1);
        Check(poma::ValidCalendarLink(poma::ToWide(url), kind) == (line.substr(first + 1, second - first - 1) == "1"), ("Shared URL safety case " + std::to_string(row)).c_str());
      }
    }
    Check(!poma::LocalCalendarTime(0).empty(), "Calendar time uses real Windows regional preferences");
    Check(!poma::LocalCalendarDate(L"2026-10-25").empty(), "Date-only event formats without an instant conversion");
    Check(poma::LocalCalendarDate(L"2026-99-25").empty(), "Invalid calendar date is rejected");
    Check(poma::FileTimeMicros(116444736000000000ULL) == 0, "Unix epoch conversion");
    Check(poma::FileTimeMicros(116444736012345670ULL) == 1234567, "Clock units");
    const auto elapsed = poma::ElapsedMicros(); Sleep(20);
    Check(poma::ElapsedMicros() > elapsed, "Native elapsed clock advances");
    const RECT negative{-1920, -1080, 0, 0};
    Check(Same(poma::ClampRect({-3000, -2000, -2000, -1200}, negative), {-1920, -1080, -920, -280}), "Negative monitor coordinates");
    Check(Same(poma::ClampRect({100, 100, 2000, 2000}, {0, 0, 800, 600}), {0, 0, 800, 600}), "Oversized window is reachable");
    Check(Same(poma::PopupRect({950, 950, 980, 980}, {0, 0, 1000, 950}, 380, 400), {600, 542, 980, 942}), "Bottom taskbar popup");
    Check(Same(poma::PopupRect({10, 0, 40, 30}, {0, 30, 1000, 900}, 380, 400), {0, 38, 380, 438}), "Top taskbar popup");
    Check(Same(poma::PopupAnchor(RECT{-100, 700, -70, 730}, POINT{20, 20}, negative), {-100, 700, -70, 730}), "Icon bounds override activation");
    Check(Same(poma::PopupAnchor(std::nullopt, POINT{-500, -30}, negative), {-500, -30, -499, -29}), "Missing icon uses activation point");
    Check(Same(poma::PopupAnchor(std::nullopt, std::nullopt, negative), {-8, -8, -7, -7}), "Settings fallback uses main work area");
    Check(Same(poma::PopupAnchor(RECT{}, std::nullopt, negative), {-8, -8, -7, -7}), "Invalid icon rectangle falls back safely");
    for (int dpi : {96, 120, 144, 192}) for (int text : {1, 2}) {
      const RECT work{-1280, -100, 0, 900};
      const auto placed = poma::PopupRect({-40, 880, -10, 910}, work, MulDiv(380, dpi, 96), MulDiv(700 * text, dpi, 96));
      Check(placed.left >= work.left && placed.right <= work.right && placed.top >= work.top && placed.bottom <= work.bottom,
          "Simulated DPI/text and auto-hide geometry stays reachable");
    }
    Check(poma::BoundedTooltip(std::wstring(200, L'x')).size() <= 127, "Tooltip obeys shell limit");
    const auto unicode_tip = poma::BoundedTooltip(std::wstring(125, L'x') + L"\xD83D\xDE00" + L"long title");
    Check(unicode_tip.size() == 126 && unicode_tip.back() == L'\u2026', "Tooltip does not split a Unicode surrogate pair");
    for (const auto* invalid : {L"", L"open|../x|1", L"open|x|0", L"open|x|-1", L"start|x|1", L"dismiss|x|1|2", L"open|x|999999999999999999999"})
      Check(!poma::ParseResponse(invalid), "Reject malformed activation");
    Check(poma::ParseResponse(L"open|run_1-Ab|7")->generation == 7, "Open activation identity");
    Check(poma::ParseResponse(L"dismiss|run_1-Ab|8")->action == L"dismiss", "Dismiss activation identity");
    const auto reminder_token = std::wstring(64, L'a');
    Check(poma::ParseCalendarReminderResponse(L"calendar|open|" + reminder_token + L"|7")->generation == 7, "Calendar activation has a separate namespace");
    Check(!poma::ParseResponse(L"calendar|open|" + reminder_token + L"|7"), "Calendar actions never enter the timer parser");
    Check(!poma::ParseCalendarReminderResponse(L"open|" + reminder_token + L"|7"), "Timer actions never enter the calendar parser");
    Check(!poma::ParseCalendarReminderResponse(L"calendar|start|" + reminder_token + L"|7"), "Calendar notification cannot start a timer");
    Check(!poma::ParseCalendarReminderResponse(L"calendar|open|../path|7"), "Reminder identity cannot be a path");
    Check(!poma::ValidReminderToken(std::wstring(64, L'z')), "Reminder identity is opaque hexadecimal");
    Check(poma::ToWide(poma::ToUtf8(L"Poma 日本語")) == L"Poma 日本語", "IPC Unicode conversion");

    const auto identity = L"Poma.NativeTest." + std::to_wstring(GetCurrentProcessId()) + L"." + std::to_wstring(GetTickCount64());
    wchar_t temporary[MAX_PATH]{}; GetTempPathW(MAX_PATH, temporary);
    const auto directory = std::wstring(temporary) + identity;
    Check(CreateDirectoryW(directory.c_str(), nullptr) != FALSE, "Isolated test profile");
    {
      using Store = poma::CalendarCredentialStore;
      const auto profile = std::filesystem::path(directory) / L"google-synthetic";
      const auto other = std::filesystem::path(directory) / L"google-other-profile";
      const auto blob = profile / L"calendar" / L"connection.dpapi";
      Store store(profile.wstring());
      Check(!store.Read().credential, "Fresh calendar store is disconnected");
      const std::string synthetic = "{\"refreshToken\":\"synthetic-native-refresh\"}";
      store.Write(0, synthetic, true);
      Check(store.Read().credential == synthetic, "Real current-user DPAPI round trip");
      Store reopened(profile.wstring());
      Check(reopened.Read().credential == synthetic, "Protected credentials survive store restart");
      std::ifstream bytes(blob, std::ios::binary);
      const std::string ciphertext((std::istreambuf_iterator<char>(bytes)), std::istreambuf_iterator<char>());
      bytes.close();
      Check(ciphertext.find("synthetic-native-refresh") == std::string::npos, "Credential bytes are not plaintext");
      std::filesystem::create_directories(other / L"calendar");
      Check(CopyFileW(blob.c_str(), (other / L"calendar" / L"connection.dpapi").c_str(), TRUE) != FALSE, "Isolated profile ciphertext fixture");
      bool rejected = false;
      try { Store different(other.wstring()); different.Read(); } catch (...) { rejected = true; }
      Check(rejected, "Profile-bound DPAPI context prevents copied credentials");
      Store failed_protection(profile.wstring(), [](const Store::Bytes&, const Store::Bytes&) -> Store::Bytes { throw std::runtime_error("Synthetic protection failure"); });
      rejected = false; try { failed_protection.Write(0, "replacement", false); } catch (...) { rejected = true; }
      Check(rejected && store.Read().credential == synthetic, "Protection failure preserves committed credentials");
      const HANDLE held = CreateFileW(blob.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
      Check(held != INVALID_HANDLE_VALUE, "Protected file sharing fixture");
      rejected = false; try { store.Write(0, "replacement", false); } catch (...) { rejected = true; }
      Check(rejected && store.Read().credential == synthetic, "Atomic replacement failure preserves previous credential");
      rejected = false; try { store.Clear(); } catch (...) { rejected = true; }
      Check(rejected && std::filesystem::exists(profile / L"calendar" / L"disconnected"), "Delete failure retains durable disconnected marker");
      rejected = false; try { Store restart(profile.wstring()); restart.Read(); } catch (...) { rejected = true; }
      Check(rejected, "Restart does not resurrect credential after incomplete disconnect");
      CloseHandle(held);
      Check(!store.Read().credential, "Restart cleanup retries after file becomes removable");
      rejected = false; try { store.Write(0, synthetic, false); } catch (...) { rejected = true; }
      Check(rejected, "Late credential writes rejected after invalidation");
      store.Write(1, synthetic, false);
      std::filesystem::create_directories(profile / L"calendar" / L"accounts" / L"synthetic-account");
      { std::ofstream fixture(profile / L"calendar" / L"accounts" / L"synthetic-account" / L"fixture.json"); fixture << "{}"; }
      Check(store.Clear() == 2 && !std::filesystem::exists(profile / L"calendar" / L"accounts"), "Disconnect purges account-derived data");
      store.Write(2, synthetic, false);
      { std::ofstream corrupt(blob, std::ios::binary | std::ios::trunc); corrupt << "corrupt protected fixture"; }
      rejected = false; try { store.Read(); } catch (...) { rejected = true; }
      Check(rejected, "Corrupt protected storage fails closed");
      store.Clear();
      std::filesystem::remove_all(profile); std::filesystem::remove_all(other);
      std::filesystem::create_directories(profile);
      { std::ofstream blocked(profile / L"calendar"); blocked << "synthetic blocked storage"; }
      rejected = false; try { Store blocked(profile.wstring()); blocked.Read(); } catch (...) { rejected = true; }
      Check(rejected, "Blocked credential directory reports read failure");
      std::filesystem::remove_all(profile);
      Check(!std::filesystem::exists(profile) && !std::filesystem::exists(other), "Synthetic credential profiles removed");
    }
    {
      using Store = poma::CalendarCredentialStore;
      const auto profile = std::filesystem::path(directory) / L"calendar-cache-synthetic";
      const std::string a(64, 'a'), b(64, 'b');
      Store store(profile.wstring()); store.Write(0, "synthetic-credential", false);
      const auto first = store.BindAccount(0, a);
      Check(!store.ReadAccount(0, first, a), "New account cache is absent, not a verified empty snapshot");
      store.WriteAccount(0, first, a, "{\"version\":1,\"synthetic\":true}");
      Check(store.ReadAccount(0, first, a).has_value(), "Account cache round trip");
      Check(!store.ReadAccount(0, first, a, true), "Reminder preferences default absent independently of event cache");
      store.WriteAccount(0, first, a, "synthetic-reminder-receipt", true);
      Check(store.ReadAccount(0, first, a, true) == "synthetic-reminder-receipt", "Reminder receipt uses the reader lease without rebinding");
      Check(store.ReadAccount(0, first, a)->find("synthetic") != std::string::npos, "Reminder commit does not replace the event snapshot");
      const auto reminders_file = profile / L"calendar" / L"accounts" / std::wstring(a.begin(), a.end()) / L"reminders.json";
      const HANDLE reminders_held = CreateFileW(reminders_file.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
      bool reminder_rejected = false;
      try { store.WriteAccount(0, first, a, "failed-reminder-replacement", true); } catch (...) { reminder_rejected = true; }
      Check(reminder_rejected && store.ReadAccount(0, first, a, true) == "synthetic-reminder-receipt", "Reminder atomic replacement failure preserves receipts");
      CloseHandle(reminders_held);
      const auto file = profile / L"calendar" / L"accounts" / std::wstring(a.begin(), a.end()) / L"state.json";
      const HANDLE held = CreateFileW(file.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
      Check(held != INVALID_HANDLE_VALUE, "Cache atomic replacement sharing fixture");
      bool rejected = false;
      try { store.WriteAccount(0, first, a, "replacement"); } catch (...) { rejected = true; }
      Check(rejected && store.ReadAccount(0, first, a)->find("synthetic") != std::string::npos,
          "Failed cache atomic replacement preserves complete committed document");
      CloseHandle(held);
      Check(!std::filesystem::exists(file.wstring() + L".tmp"), "Failed atomic write removes temporary data");
      const auto second = store.BindAccount(0, a);
      rejected = false; try { store.WriteAccount(0, first, a, "obsolete-selection"); } catch (...) { rejected = true; }
      Check(rejected, "Selection/window scope rejects obsolete cache commit");
      rejected = false; try { store.WriteAccount(0, first, a, "obsolete-reminder", true); } catch (...) { rejected = true; }
      Check(rejected, "Selection invalidates old reminder writes");
      store.WriteAccount(0, second, a, "{\"selected\":[]}");
      Check(store.ReadAccount(0, second, a) == "{\"selected\":[]}", "Selection and deselected data replace in one atomic document");
      rejected = false; try { store.ReadAccount(0, second, b); } catch (...) { rejected = true; }
      Check(rejected, "Cache lease cannot read a different account");
      for (const auto& path : {std::string("../escape"), std::string(63, 'a'), std::string(64, 'z')}) {
        rejected = false; try { store.BindAccount(0, path); } catch (...) { rejected = true; }
        Check(rejected, "Provider identities cannot become filesystem paths");
      }
      const auto retired_revision = store.Retire(0, "{\"version\":2,\"retired\":true,\"clientId\":\"synthetic\",\"accountId\":\"synthetic\"}");
      Check(retired_revision == 1 && !std::filesystem::exists(profile / L"calendar" / L"connection.dpapi"),
          "Retirement removes unusable credential and advances revision");
      Check(std::filesystem::exists(file), "Retirement preserves bounded stale cache");
      rejected = false; try { store.WriteAccount(0, second, a, "late"); } catch (...) { rejected = true; }
      Check(rejected, "Credential retirement invalidates in-flight cache writes");
      Store restored(profile.wstring());
      Check(restored.Read().credential->find("retired") != std::string::npos, "Restart reads protected retired identity");
      const auto third = store.BindAccount(1, a);
      Check(store.ReadAccount(1, third, a).has_value(), "Verified same-account scope can restore stale cache");
      rejected = false; try { store.WriteAccount(1, third, a, std::string(16 * 1024 * 1024 + 1, 'x')); } catch (...) { rejected = true; }
      Check(rejected && store.ReadAccount(1, third, a) == "{\"selected\":[]}", "Size limit fails without truncating valid cache");
      store.Clear();
      rejected = false; try { store.WriteAccount(1, third, a, "late-disconnect"); } catch (...) { rejected = true; }
      Check(rejected && !std::filesystem::exists(profile / L"calendar" / L"accounts"), "Disconnect prevents cache resurrection");
      rejected = false; try { store.WriteAccount(1, third, a, "late-reminder", true); } catch (...) { rejected = true; }
      Check(rejected && !std::filesystem::exists(reminders_file), "Disconnect purges reminder state and rejects late receipt writes");
      rejected = false; try { store.BindAccount(2, a); } catch (...) { rejected = true; }
      Check(rejected, "Durable disconnected marker prevents fresh cache binding");
      store.Write(2, "new-credential", true);
      const auto fourth = store.BindAccount(2, b);
      Check(!store.ReadAccount(2, fourth, b), "Different account has no inherited cache");
      store.WriteAccount(2, fourth, b, "new-account");
      store.InvalidateCache();
      rejected = false; try { store.WriteAccount(2, fourth, b, "post-quit"); } catch (...) { rejected = true; }
      Check(rejected, "Quit cache invalidation rejects remaining worker commits");
      store.Clear(); std::filesystem::remove_all(profile);
    }
    {
      using Store=poma::CalendarCredentialStore;
      const auto profile=std::filesystem::path(directory)/L"focus-session12";
      const std::string account(64,'a');Store store(profile.wstring());
      Check(store.Commit(0,0,"synthetic-credential",false)==1,"W13 atomic credential commit advances revision");
      bool rejected=false;try{store.Commit(0,0,"stale",false);}catch(...){rejected=true;}
      Check(rejected&&store.Read().credential=="synthetic-credential","W13 stale refresh cannot replace promoted credential");
      Store reopened(profile.wstring());Check(reopened.Read().commit_revision==1,"W13 commit revision survives process-style reopen");
      Check(reopened.Commit(0,1,"synthetic-upgrade",false)==2,"W13 next verified credential commits atomically");
      auto journal=reopened.OpenFocus(0,account);
      Check(!journal.document,"W17 empty write journal has no commands");
      Check(reopened.SaveFocus(0,journal.scope,0,account,"synthetic-operation")==1,"W02 journal atomic commit");
      rejected=false;try{reopened.SaveFocus(0,journal.scope,0,account,"stale");}catch(...){rejected=true;}
      Check(rejected,"W01 stale journal revision rejected");
      reopened.StopFocus();rejected=false;try{reopened.SaveFocus(0,journal.scope,1,account,"late");}catch(...){rejected=true;}
      Check(rejected,"W15 stop rejects queued saves before cleanup");
      journal=reopened.OpenFocus(0,account);Check(journal.stopped&&journal.document=="synthetic-operation","W04 durable stopped journal survives reopen without replay");
      reopened.DisableFocus(true);journal=reopened.OpenFocus(0,account);Check(journal.disabled,"W15 disablement persists independently of credential acknowledgement");
      reopened.DisableFocus(false);journal=reopened.OpenFocus(0,account);Check(!journal.disabled,"Explicit enable clears local scheduling disablement");
      Check(reopened.Commit(0,2,"synthetic-replacement-account",true)==3,"W15 account replacement commits with focus barrier");
      rejected=false;try{reopened.SaveFocus(0,journal.scope,0,account,"late-old-account");}catch(...){rejected=true;}
      Check(rejected,"W15 account replacement rejects queued old-account focus save before Dart acknowledgement");
      journal=reopened.OpenFocus(0,account);Check(!journal.document,"W15 account replacement cannot recreate purged focus records");
      reopened.StopFocus(true);journal=reopened.OpenFocus(0,account);Check(!journal.document,"W15 purge removes focus journal");
      reopened.Clear();rejected=false;try{reopened.SaveFocus(0,journal.scope,0,account,"late");}catch(...){rejected=true;}
      Check(rejected,"W15 full disconnect invalidates focus lease");std::filesystem::remove_all(profile);
    }
    {
      DYNAMIC_TIME_ZONE_INFORMATION eastern{},india{},entry{};bool found_east=false,found_india=false;
      for(DWORD i=0;EnumDynamicTimeZoneInformation(i,&entry)==ERROR_SUCCESS;++i){
        if(std::wstring(entry.TimeZoneKeyName)==L"Eastern Standard Time"){eastern=entry;found_east=true;}
        if(std::wstring(entry.TimeZoneKeyName)==L"India Standard Time"){india=entry;found_india=true;}
      }
      Check(found_east&&found_india,"W11 timezone fixtures use Windows rules without changing device settings");
      SYSTEMTIME wall{};wall.wYear=2026;wall.wMonth=3;wall.wDay=8;wall.wHour=2;wall.wMinute=30;
      Check(poma::FocusResolveWall(wall,eastern).empty(),"W11 nonexistent DST time rejected");
      wall.wMonth=11;wall.wDay=1;wall.wHour=1;
      Check(poma::FocusResolveWall(wall,eastern).size()==2,"W11 ambiguous DST fold rejected");
      wall.wDay=3;wall.wHour=10;const auto local=poma::FocusResolveWall(wall,india);
      Check(local.size()==1&&local.front().offset_minutes==330,"W11 unique device-local offset retained");
      wall.wMonth=2;wall.wDay=30;Check(poma::FocusResolveWall(wall,india).empty(),"W11 invalid calendar date rejected");
      Check(poma::FocusZoneFingerprint(eastern)!=poma::FocusZoneFingerprint(india),"W11 timezone change invalidates preview fingerprint");
    }
    WNDCLASSW cls{}; cls.lpfnWndProc = Receive; cls.lpszClassName = L"Poma.NativeTest"; cls.hInstance = GetModuleHandleW(nullptr);
    RegisterClassW(&cls);
    const auto window = CreateWindowW(cls.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, cls.hInstance, nullptr);
    Check(window != nullptr, "IPC target");
    const auto button = CreateWindowW(L"BUTTON", L"Open Poma", WS_CHILD | BS_OWNERDRAW,
        0, 0, 100, 40, window, reinterpret_cast<HMENU>(static_cast<INT_PTR>(204)), cls.hInstance, nullptr);
    Check(button != nullptr, "Native popup button fixture");
    Check(poma::ActivatePopupButton(window, button, WM_KEYDOWN, VK_RETURN) && button_clicks == 1, "Enter activates the focused native button");
    Check(!poma::ActivatePopupButton(window, button, WM_KEYDOWN, VK_SPACE), "Space retains native button handling");
    EnableWindow(button, FALSE);
    Check(!poma::ActivatePopupButton(window, button, WM_KEYDOWN, VK_RETURN) && button_clicks == 1, "Disabled timer controls cannot activate");
    Check(!poma::ActivatePopupButton(window, window, WM_KEYDOWN, VK_RETURN), "Enter does not activate a non-button");
    DestroyWindow(button);
    {
      poma::SingleInstance owner(directory, identity); Check(owner.owner(), "First launch owns profile"); owner.Listen(window);
      poma::SingleInstance secondary(directory, identity); Check(!secondary.owner(), "Second launch is relay only");
      Check(secondary.Forward(L"open"), "Relay Open"); PumpUntil(1);
      Check(received.size() == 1 && received[0] == L"open", "Owner receives Open");
      Check(secondary.Forward(L"action:open|opaque-run|3"), "Relay activation"); PumpUntil(2);
      Check(received.size() == 2 && received[1] == L"action:open|opaque-run|3", "Owner receives activation");
      Check(!secondary.Forward(L""), "Empty IPC rejected");
      Check(!secondary.Forward(std::wstring(2049, L'x')), "Oversized IPC rejected");
    }
    // Repeated immediate shutdown covers cancellation before connect starts.
    for (int i = 0; i < 25; ++i) {
      poma::SingleInstance owner(directory, identity); Check(owner.owner(), "Ownership released on exit"); owner.Listen(window);
    }
    {
      auto owner = std::make_unique<poma::SingleInstance>(directory, identity); owner->Listen(window);
      const auto pipeName = L"\\\\.\\pipe\\" + identity + L"." + poma::UserSid();
      HANDLE stalled = INVALID_HANDLE_VALUE;
      for (int i = 0; i < 100 && stalled == INVALID_HANDLE_VALUE; ++i) {
        stalled = CreateFileW(pipeName.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr); Sleep(5);
      }
      Check(stalled != INVALID_HANDLE_VALUE, "Connected silent client");
      const auto start = GetTickCount64(); owner.reset();
      Check(GetTickCount64() - start < 2000, "Shutdown cancels pending read"); CloseHandle(stalled);
    }
    {
      std::wstring activated;
      CLSID test_activator{};winrt::check_hresult(CoCreateGuid(&test_activator));
      poma::ToastActivationRegistration registration([&](std::wstring value) { activated = std::move(value); },test_activator);
      winrt::com_ptr<INotificationActivationCallback> callback;
      winrt::check_hresult(CoCreateInstance(test_activator, nullptr, CLSCTX_LOCAL_SERVER, __uuidof(INotificationActivationCallback), callback.put_void()));
      winrt::check_hresult(callback->Activate(L"test", L"dismiss|opaque-run|3", nullptr, 0));
      Check(activated == L"dismiss|opaque-run|3", "COM activation routes opaque arguments");
    }
    DestroyWindow(window); Check(RemoveDirectoryW(directory.c_str()) != FALSE, "Test profile removed");
    std::cout << checks << " native checks passed\n";
  } catch (const winrt::hresult_error& error) {
    std::cerr << "Windows API failure after " << checks << " checks: " << std::hex << error.code().value << " " << winrt::to_string(error.message()) << '\n'; return 1;
  } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
  catch (...) { std::cerr << "Windows API check failed\n"; return 1; }
  return 0;
}

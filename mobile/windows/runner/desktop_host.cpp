#include "desktop_host.h"
#include "resource.h"
#include "calendar_links.h"
#include "focus_time.h"
#include <initguid.h>
#include <oleacc.h>
#include <shellapi.h>
#include <shlobj.h>
#include <windowsx.h>
#include <wtsapi32.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Data.Xml.Dom.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.UI.ViewManagement.h>
#include <algorithm>
#include <cwctype>
#include <sstream>

namespace poma {
namespace {
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
constexpr UINT kTrayCallback = WM_APP + 60;
constexpr UINT_PTR kDeadline = 701;
constexpr UINT_PTR kReminderDeadline = 703;
constexpr UINT_PTR kBounds = 702;
constexpr int kPrimary = 201, kReset = 202, kSkip = 203, kOpen = 204, kSettings = 205;
constexpr int kQuit = 206;
constexpr int kRefresh = 207, kDay = 208;
#ifdef POMA_CALENDAR_REVIEW
constexpr bool kCalendarReview = true;
double review_text_scale = 0;
#else
constexpr bool kCalendarReview = false;
#endif
const V* Field(const M& map, const char* key) {
  const auto found = map.find(V(key));
  return found == map.end() ? nullptr : &found->second;
}
int64_t Number(const M& map, const char* key, int64_t fallback = 0) {
  const auto value = Field(map, key);
  if (value && std::holds_alternative<int32_t>(*value)) return std::get<int32_t>(*value);
  if (value && std::holds_alternative<int64_t>(*value)) return std::get<int64_t>(*value);
  return fallback;
}
bool Flag(const M& map, const char* key, bool fallback = false) {
  const auto value = Field(map, key);
  return value && std::holds_alternative<bool>(*value) ? std::get<bool>(*value) : fallback;
}
std::string Text(const M& map, const char* key) {
  const auto value = Field(map, key);
  return value && std::holds_alternative<std::string>(*value) ? std::get<std::string>(*value) : "";
}
RECT WorkArea(HMONITOR monitor) {
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfoW(monitor, &info) || info.rcWork.right <= info.rcWork.left || info.rcWork.bottom <= info.rcWork.top) {
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &info.rcWork, 0);
  }
  return info.rcWork;
}
std::wstring StartupStatus() {
  if (!IsPackaged()) return L"unavailable";
  using namespace winrt::Windows::ApplicationModel;
  const auto state = StartupTask::GetAsync(L"PomaStartup").get().State();
  switch (state) {
    case StartupTaskState::Enabled: return L"enabled";
    case StartupTaskState::DisabledByUser: return L"disabledByUser";
    case StartupTaskState::DisabledByPolicy: return L"disabledByPolicy";
    case StartupTaskState::EnabledByPolicy: return L"enabledByPolicy";
    default: return L"disabled";
  }
}
struct AsyncResponse {
  std::unique_ptr<flutter::MethodResult<V>> result;
  V value;
  bool failed = false;
  bool notify = false;
  std::thread::id worker;
};
// Windows filenames forbid '|'; use a delimiter forbidden by ValidRun instead.
std::wstring SafeResponseFile(const std::wstring& directory, const Response& value) {
  return directory + L"\\responses\\" + value.action + L"." + value.run + L"." + std::to_wstring(value.generation) + L".event";
}
void ClearJournal(const std::wstring& directory) {
  WIN32_FIND_DATAW item{};
  const auto folder = directory + L"\\responses\\";
  HANDLE search = FindFirstFileW((folder + L"*.event").c_str(), &item);
  if (search == INVALID_HANDLE_VALUE) return;
  bool failed = false;
  do {
    if (!(item.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
        !DeleteFileW((folder + item.cFileName).c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND) failed = true;
  } while (FindNextFileW(search, &item));
  FindClose(search);
  if (failed) winrt::throw_hresult(E_FAIL);
}
double TextScale() {
#ifdef POMA_CALENDAR_REVIEW
  if (review_text_scale > 0) return review_text_scale;
#endif
  try { return winrt::Windows::UI::ViewManagement::UISettings().TextScaleFactor(); }
  catch (...) { return 1.0; }
}
void AccessibleName(HWND control, const std::wstring& name) {
  IAccPropServices* services = nullptr;
  if (SUCCEEDED(CoCreateInstance(CLSID_AccPropServices, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&services)))) {
    if (name.empty()) {
      const MSAAPROPID property = PROPID_ACC_NAME;
      services->ClearHwndProps(control, static_cast<DWORD>(OBJID_CLIENT), CHILDID_SELF, &property, 1);
    } else {
      services->SetHwndPropStr(control, static_cast<DWORD>(OBJID_CLIENT), CHILDID_SELF, PROPID_ACC_NAME, name.c_str());
    }
    services->Release();
  }
}
void DestroyCalendarButton(HWND control) {
  if (!control) return;
  AccessibleName(control, L"");
  DestroyWindow(control);
}
}  // namespace

DesktopHost::DesktopHost(HWND window, flutter::BinaryMessenger* messenger, bool initially_hidden)
    : window_(window), initially_hidden_(initially_hidden), directory_(DataDirectory()) {
  channel_ = std::make_unique<flutter::MethodChannel<V>>(messenger,
      "dev.poma.poma/windows_desktop", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    try { Method(call, std::move(result)); }
    catch (...) { if (result) result->Error("windows", "Windows operation failed. Your data is kept."); }
  });
  clock_ = std::make_unique<flutter::MethodChannel<V>>(messenger,
      "dev.poma.poma/timer_clock", &flutter::StandardMethodCodec::GetInstance());
  clock_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "sample") { result->NotImplemented(); return; }
    FILETIME utc{};
    GetSystemTimePreciseAsFileTime(&utc);
    ULARGE_INTEGER integer{};
    integer.LowPart = utc.dwLowDateTime; integer.HighPart = utc.dwHighDateTime;
    result->Success(V(M{{V("utcMicros"), V(FileTimeMicros(integer.QuadPart))},
        {V("elapsedMicros"), V(ElapsedMicros())}, {V("bootCount"), V()}}));
  });
  WNDCLASSW cls{};
  cls.hInstance = GetModuleHandleW(nullptr); cls.lpszClassName = L"Poma.TimerPopup";
  cls.lpfnWndProc = PopupProc; cls.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&cls);
  popup_ = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST, cls.lpszClassName, L"Poma timer",
      WS_POPUP | WS_BORDER | WS_VSCROLL, 0, 0, 380, 430, window_, nullptr, cls.hInstance, this);
  if (popup_) {
    for (int i = 0; i < 4; ++i) labels_.push_back(CreateWindowW(L"STATIC", L"",
        WS_CHILD | WS_VISIBLE | SS_NOPREFIX | (i == 1 ? SS_CENTER : SS_LEFT),
        0, 0, 10, 10, popup_, nullptr, cls.hInstance, nullptr));
    for (int id = kPrimary; id <= kSettings; ++id) buttons_.push_back(CreateWindowW(L"BUTTON", L"",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_OWNERDRAW | BS_NOTIFY, 0, 0, 10, 10, popup_,
        reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), cls.hInstance, nullptr));
    ShowWindow(buttons_[1], SW_HIDE); ShowWindow(buttons_[2], SW_HIDE);
    preview_label_ = CreateWindowW(L"STATIC", L"Calendar preview - fictional data", WS_CHILD | WS_VISIBLE | SS_NOPREFIX,
        0, 0, 10, 10, popup_, nullptr, cls.hInstance, nullptr);
    day_combo_ = CreateWindowW(L"COMBOBOX", L"Agenda day", WS_CHILD | WS_VISIBLE | WS_TABSTOP | CBS_DROPDOWNLIST | WS_VSCROLL,
        0, 0, 10, 10, popup_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(kDay)), cls.hInstance, nullptr);
    AccessibleName(day_combo_, L"Agenda day");
  }
  session_registered_ = WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION) != FALSE;
  RefreshSessionState();
  AddTray();
  if (IsPackaged()) activation_ = std::make_unique<ToastActivationRegistration>([this](std::wstring arguments) {
    auto value = std::make_unique<std::wstring>(std::move(arguments));
    if (PostMessageW(window_, kAlertMessage, 0, reinterpret_cast<LPARAM>(value.get()))) value.release();
  });
}
DesktopHost::~DesktopHost() {
  closing_ = true;
  if (session_registered_) WTSUnRegisterSessionNotification(window_);
  KillTimer(window_, kDeadline); KillTimer(window_, kBounds); KillTimer(window_, kReminderDeadline);
  activation_.reset();
  for (auto& worker : workers_) if (worker.joinable()) worker.join();
  MSG message{};
  while (PeekMessageW(&message, window_, kAsyncMessage, kAsyncMessage, PM_REMOVE))
    delete reinterpret_cast<AsyncResponse*>(message.lParam);
  while (PeekMessageW(&message, window_, kAlertMessage, kAlertMessage, PM_REMOVE))
    delete reinterpret_cast<std::wstring*>(message.lParam);
  while (PeekMessageW(&message, window_, kIpcMessage, kIpcMessage, PM_REMOVE))
    delete reinterpret_cast<std::wstring*>(message.lParam);
  try { ClearAlerts(); } catch (...) {}
  RemoveTray();
  for (const auto& row : calendar_rows_) for (const auto& action : row.actions) AccessibleName(action.button, L"");
  if (popup_) DestroyWindow(popup_);
  if (body_font_) DeleteObject(body_font_);
  if (timer_font_) DeleteObject(timer_font_);
  if (background_) DeleteObject(background_);
}
void DesktopHost::Event(const std::string& name, M values) {
  if (!closing_) channel_->InvokeMethod(name, std::make_unique<V>(std::move(values)));
}
void DesktopHost::FirstFrame() {
  RECT bounds{}; GetWindowRect(window_, &bounds);
  const auto safe = ClampRect(bounds, WorkArea(MonitorFromRect(&bounds, MONITOR_DEFAULTTONEAREST)));
  SetWindowPos(window_, nullptr, safe.left, safe.top, safe.right - safe.left, safe.bottom - safe.top, SWP_NOACTIVATE | SWP_NOZORDER);
  if (!initially_hidden_ || !tray_added_) ShowMain();
}
bool DesktopHost::ProcessDialog(MSG* message) {
  if (!popup_ || !IsWindowVisible(popup_)) return false;
  // A held Pause/Space must not become Start if expiry repaints the button.
  const bool key_start = message->message == WM_KEYDOWN &&
      (message->wParam == VK_SPACE || message->wParam == VK_RETURN) && !(message->lParam & (1LL << 30));
  if (message->message == WM_LBUTTONDOWN || key_start) {
    for (size_t i = 0; i < std::min<size_t>(3, buttons_.size()); ++i) {
      if (message->hwnd == buttons_[i] && IsWindowEnabled(buttons_[i])) {
        pressed_timer_control_ = buttons_[i]; pressed_timer_snapshot_ = snapshot_;
      }
    }
  }
  if (ActivatePopupButton(popup_, GetFocus(), message->message, message->wParam)) return true;
  if (message->message == WM_KEYDOWN && message->wParam == VK_ESCAPE) {
    if (SendMessageW(day_combo_, CB_GETDROPPEDSTATE, 0, 0)) SendMessageW(day_combo_, CB_SHOWDROPDOWN, FALSE, 0);
    else HidePopup(true);
    return true;
  }
  const bool processed = IsDialogMessageW(popup_, message) != FALSE;
  if (processed) EnsurePopupFocusVisible();
  return processed;
}
void DesktopHost::ShowMain() {
  ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(window_);
  HidePopup(); Visibility();
}
void DesktopHost::Visibility() {
  Event("visibility", {{V("visible"), V((IsWindowVisible(window_) && !IsIconic(window_)) ||
      (popup_ && IsWindowVisible(popup_)))}});
}
bool DesktopHost::AddTray() {
  NOTIFYICONDATAW data{sizeof(NOTIFYICONDATAW)};
  data.hWnd = window_; data.guidItem = kTrayGuid;
  data.uFlags = NIF_GUID | NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kTrayCallback;
  HIGHCONTRASTW contrast{sizeof(HIGHCONTRASTW)};
  SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
  int icon = IDI_TRAY_ICON;
  if (contrast.dwFlags & HCF_HIGHCONTRASTON) {
    const auto color = GetSysColor(COLOR_WINDOWTEXT);
    icon = GetRValue(color) + GetGValue(color) + GetBValue(color) > 384 ? IDI_TRAY_WHITE : IDI_TRAY_BLACK;
  }
  data.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(icon));
  wcscpy_s(data.szTip, L"Poma");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &data) != FALSE;
  if (tray_added_) {
    data.uVersion = NOTIFYICON_VERSION_4;
    if (!Shell_NotifyIconW(NIM_SETVERSION, &data)) { RemoveTray(); return false; }
  }
  return tray_added_;
}
void DesktopHost::RemoveTray() {
  if (!tray_added_) return;
  NOTIFYICONDATAW data{sizeof(NOTIFYICONDATAW)};
  data.hWnd = window_; data.guidItem = kTrayGuid; data.uFlags = NIF_GUID;
  Shell_NotifyIconW(NIM_DELETE, &data); tray_added_ = false;
}
void DesktopHost::HidePopup(bool restore_focus) {
  if (popup_ && IsWindowVisible(popup_)) {
    ShowWindow(popup_, SW_HIDE); Visibility();
    if (restore_focus && popup_from_tray_) {
      NOTIFYICONDATAW data{sizeof(data)}; data.hWnd = window_; data.guidItem = kTrayGuid; data.uFlags = NIF_GUID;
      Shell_NotifyIconW(NIM_SETFOCUS, &data);
    } else if (restore_focus && IsWindowVisible(window_)) {
      SetForegroundWindow(window_);
      if (IsWindow(popup_return_focus_)) SetFocus(popup_return_focus_);
    }
  }
  preview_mode_ = false;
}
void DesktopHost::TogglePopup(bool from_tray, POINT activation, bool preview) {
  if (session_state_ == "locked") return;
  if (!popup_) { ShowMain(); return; }
  if (IsWindowVisible(popup_)) { HidePopup(); return; }
  if (from_tray && tray_dismissed_at_ && GetTickCount64() - tray_dismissed_at_ < 500) {
    tray_dismissed_at_ = 0; return;
  }
  tray_dismissed_at_ = 0;
  preview_mode_ = preview;
  popup_from_tray_ = from_tray; activation_point_ = activation;
  popup_return_focus_ = GetFocus(); selected_day_ = 0;
  scroll_offset_ = 0;
  PlacePopup();
  ShowWindow(popup_, SW_SHOW);
  SetForegroundWindow(popup_); SetFocus(IsWindowEnabled(buttons_[0]) ? buttons_[0] : buttons_[3]); EnsurePopupFocusVisible(); Visibility();
  Event("openPopup", {{V("preview"), V(preview_mode_)}});
}
void DesktopHost::PlacePopup() {
  NOTIFYICONIDENTIFIER id{sizeof(NOTIFYICONIDENTIFIER)};
  id.hWnd = window_; id.guidItem = kTrayGuid;
  RECT icon{};
  const bool has_icon = SUCCEEDED(Shell_NotifyIconGetRect(&id, &icon));
  std::optional<POINT> activation;
  if (popup_from_tray_) {
    POINT point = activation_point_;
    if (point.x == -1 && point.y == -1) GetCursorPos(&point);
    activation = point;
  }
  icon = PopupAnchor(has_icon ? std::optional<RECT>(icon) : std::nullopt, activation,
      WorkArea(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST)));
  const RECT work = WorkArea(MonitorFromRect(&icon, MONITOR_DEFAULTTONEAREST));
  // Move to the icon's monitor first. Per-monitor DPI is then obtained from
  // the popup itself, even when the main window is on a different display.
  if (MonitorFromWindow(popup_, MONITOR_DEFAULTTONEAREST) != MonitorFromRect(&icon, MONITOR_DEFAULTTONEAREST))
    SetWindowPos(popup_, nullptr, work.left, work.top, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  const int width = MulDiv(380, static_cast<int>(GetDpiForWindow(popup_)), 96);
  RECT current{}; GetWindowRect(popup_, &current);
  SetWindowPos(popup_, nullptr, 0, 0, std::min<int>(width, work.right - work.left), current.bottom - current.top,
      SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  PaintPopup();
  const int height = std::min(content_height_ + 2, static_cast<int>(work.bottom - work.top - 16));
  const RECT position = PopupRect(icon, work, width, std::max(height, 120));
  SetWindowPos(popup_, HWND_TOPMOST, position.left, position.top,
      position.right - position.left, position.bottom - position.top, SWP_NOACTIVATE);
  LayoutPopup();
}
void DesktopHost::PaintPopup() {
  if (!popup_) return;
  const auto appearance = Text(snapshot_, "appearance");
  HIGHCONTRASTW contrast{sizeof(HIGHCONTRASTW)};
  SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0);
  high_contrast_ = (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;
  bool system_dark = false;
  try {
    auto color = winrt::Windows::UI::ViewManagement::UISettings().GetColorValue(
        winrt::Windows::UI::ViewManagement::UIColorType::Background);
    system_dark = (color.R + color.G + color.B) < 384;
  } catch (...) {}
  dark_ = !high_contrast_ && (appearance == "dark" || (appearance != "light" && system_dark));
  if (background_) DeleteObject(background_);
  background_ = CreateSolidBrush(high_contrast_ ? GetSysColor(COLOR_WINDOW) : dark_ ? RGB(28,35,50) : RGB(248,249,253));
  const double scale = static_cast<double>(GetDpiForWindow(popup_)) / 96.0 * TextScale();
  if (scale != popup_scale_) {
    popup_scale_ = scale;
    if (body_font_) DeleteObject(body_font_);
    if (timer_font_) DeleteObject(timer_font_);
    body_font_ = CreateFontW(-static_cast<int>(16 * scale), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
  timer_font_ = CreateFontW(-static_cast<int>(24 * scale), 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
  }
  const int64_t seconds = Number(snapshot_, "seconds", 1500);
  wchar_t time[40]{};
  swprintf_s(time, L"%02lld:%02lld", seconds / 60, seconds % 60);
  const auto status = Text(snapshot_, "status");
  const auto phase = Text(snapshot_, "phaseLabel");
  SetWindowTextW(labels_[0], ToWide("Poma  /  " + (phase.empty() ? "Focus" : phase) + "  /  " + status).c_str());
  SetWindowTextW(labels_[1], time);
  const auto task = Text(snapshot_, "task");
  SetWindowTextW(labels_[2], ToWide((task.empty() ? "No task selected" : task) + "  /  " +
      std::to_string(Number(snapshot_, "rounds")) + " of " + std::to_string(Number(snapshot_, "targetRounds", 4)) + " rounds").c_str());
  SetWindowTextW(labels_[3], ToWide(Text(snapshot_, "error").empty() && Flag(snapshot_, "locked")
      ? "Strict mode - timer controls locked" : Text(snapshot_, "error")).c_str());
  for (size_t i = 0; i < labels_.size(); ++i) SendMessageW(labels_[i], WM_SETFONT,
      reinterpret_cast<WPARAM>(i == 1 ? timer_font_ : body_font_), TRUE);
  for (auto button : buttons_) SendMessageW(button, WM_SETFONT, reinterpret_cast<WPARAM>(body_font_), TRUE);
  const auto primary = status == "running" ? "Pause" : status == "paused" ? "Resume" : "Start " + (phase.empty() ? "Focus" : phase);
  SetWindowTextW(buttons_[0], ToWide(primary).c_str());
  SetWindowTextW(buttons_[1], L"Reset"); SetWindowTextW(buttons_[2], L"Skip");
  SetWindowTextW(buttons_[3], L"Open Poma"); SetWindowTextW(buttons_[4], L"Calendar settings");
  const bool available = configured_ && Text(snapshot_, "error").empty();
  for (size_t i = 0; i < 3; ++i) EnableWindow(buttons_[i], available && !Flag(snapshot_, "locked"));
  SendMessageW(preview_label_, WM_SETFONT, reinterpret_cast<WPARAM>(body_font_), TRUE);
  SendMessageW(day_combo_, WM_SETFONT, reinterpret_cast<WPARAM>(body_font_), TRUE);
  SetWindowTextW(preview_label_, session_state_ == "unlocked" ? (preview_mode_ ? L"Calendar preview - fictional data" : L"Google Calendar") : L"Calendar details hidden - Windows lock state unavailable or locked");
  EnableWindow(day_combo_, session_state_ == "unlocked");
  SyncCalendar();
  for (auto& row : calendar_rows_) {
    for (auto control : {row.title, row.body}) if (control) SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(body_font_), TRUE);
    for (const auto& action : row.actions) SendMessageW(action.button, WM_SETFONT, reinterpret_cast<WPARAM>(body_font_), TRUE);
  }
  LayoutPopup(); InvalidateRect(popup_, nullptr, TRUE);
}
void DesktopHost::LayoutPopup() {
  if (!popup_ || labels_.empty()) return;
  const double dpi = static_cast<double>(GetDpiForWindow(popup_)) / 96.0;
  const double text = TextScale();
  RECT area{}; GetClientRect(popup_, &area);
  const int pad = static_cast<int>(16 * dpi), gap = static_cast<int>(6 * dpi);
  const int width = std::max(1L, area.right - 2 * pad);
  int y = pad - scroll_offset_;
  HDC dc = GetDC(popup_);
  const int header_height = static_cast<int>(40 * dpi * text);
  if (text > 1.4) {
    MoveWindow(labels_[0], pad, y, width, header_height, TRUE); y += header_height + gap;
    MoveWindow(labels_[1], pad, y, width, header_height, TRUE); y += header_height + gap;
  } else {
    const int time_width = static_cast<int>(100 * dpi);
    MoveWindow(labels_[0], pad, y, std::max(1, width - time_width - gap), header_height, TRUE);
    MoveWindow(labels_[1], pad + width - time_width, y, time_width, header_height, TRUE);
    y += header_height + gap;
  }
  for (size_t i = 2; i < labels_.size(); ++i) {
    std::wstring label(static_cast<size_t>(GetWindowTextLengthW(labels_[i])) + 1, L'\0');
    GetWindowTextW(labels_[i], label.data(), static_cast<int>(label.size()));
    const auto previous = SelectObject(dc, i == 1 ? timer_font_ : body_font_);
    RECT measure{0, 0, width, 0};
    DrawTextW(dc, label.c_str(), -1, &measure, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    SelectObject(dc, previous);
    int height = std::max(static_cast<int>(24 * dpi * text), static_cast<int>(measure.bottom + 4 * dpi));
    if (i == 3 && Text(snapshot_, "error").empty() && !Flag(snapshot_, "locked")) height = 0;
    MoveWindow(labels_[i], pad, y, width, height, TRUE); y += height + (height ? gap : 0);
  }
  const int height = static_cast<int>(44 * dpi * text);
  if (text > 1.4) {
    for (auto index : {0, 3}) { MoveWindow(buttons_[index], pad, y, width, height, TRUE); y += height + gap; }
  } else {
    const int half = (width - gap) / 2;
    MoveWindow(buttons_[0], pad, y, half, height, TRUE);
    MoveWindow(buttons_[3], pad + half + gap, y, half, height, TRUE);
    y += height + gap;
  }
  const auto layout_text = [&](HWND control) {
    if (!control) return;
    const int length = GetWindowTextLengthW(control);
    std::wstring value(static_cast<size_t>(length) + 1, L'\0');
    GetWindowTextW(control, value.data(), length + 1);
    const auto previous = SelectObject(dc, body_font_);
    RECT measure{0, 0, width, 0}; DrawTextW(dc, value.c_str(), -1, &measure, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    SelectObject(dc, previous);
    const int measured = length ? std::max(static_cast<int>(24 * dpi * text), static_cast<int>(measure.bottom + 4 * dpi)) : 0;
    MoveWindow(control, pad, y, width, measured, TRUE); y += measured + (measured ? gap : 0);
  };
  layout_text(preview_label_);
  MoveWindow(day_combo_, pad, y, width, height * 8, TRUE); y += height + gap;
  const auto* dates = Field(CalendarDisplay(), "calendarDates");
  std::string day;
  if (dates && std::holds_alternative<flutter::EncodableList>(*dates)) {
    const auto& values = std::get<flutter::EncodableList>(*dates);
    if (selected_day_ >= 0 && selected_day_ < static_cast<int>(values.size()) && std::holds_alternative<std::string>(values[selected_day_]))
      day = std::get<std::string>(values[selected_day_]);
  }
  for (auto& row : calendar_rows_) {
    const bool visible = row.day.empty() || row.day == day;
    for (auto control : {row.title, row.body}) if (control) ShowWindow(control, visible ? SW_SHOW : SW_HIDE);
    for (const auto& action : row.actions) ShowWindow(action.button, visible ? SW_SHOW : SW_HIDE);
    if (!visible) continue;
    layout_text(row.title); layout_text(row.body);
    for (const auto& action : row.actions) {
      // Stack full-width actions: 200% text must not shrink to fit two buttons.
      const auto previous = SelectObject(dc, body_font_);
      RECT measure{0, 0, std::max(1, width - 12), 0};
      const auto label = ToWide(action.label);
      DrawTextW(dc, label.c_str(), -1, &measure, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
      SelectObject(dc, previous);
      const int action_height = std::max(height, static_cast<int>(measure.bottom + 12 * dpi));
      MoveWindow(action.button, pad, y, width, action_height, TRUE); y += action_height + gap;
    }
    y += gap;
  }
  MoveWindow(buttons_[4], pad, y, width, height, TRUE); y += height + gap;
  ReleaseDC(popup_, dc);
  content_height_ = y + scroll_offset_ + pad;
  const int clamped = std::max(0, std::min(scroll_offset_, content_height_ - static_cast<int>(area.bottom)));
  if (clamped != scroll_offset_) { scroll_offset_ = clamped; LayoutPopup(); return; }
  SCROLLINFO scroll{sizeof(SCROLLINFO), SIF_RANGE | SIF_PAGE | SIF_POS};
  scroll.nMax = std::max(0, content_height_ - 1); scroll.nPage = area.bottom; scroll.nPos = scroll_offset_;
  SetScrollInfo(popup_, SB_VERT, &scroll, TRUE);
}
const DesktopHost::Map& DesktopHost::CalendarDisplay() const {
  if (!preview_mode_) return snapshot_;
  const auto* preview = Field(snapshot_, "calendarPreview");
  static const M empty;
  return preview && std::holds_alternative<M>(*preview) ? std::get<M>(*preview) : empty;
}
void DesktopHost::SyncCalendar() {
  const auto& display = CalendarDisplay();
  const auto* keys = Field(display, "calendarDates");
  std::vector<std::string> new_keys;
  if (keys && std::holds_alternative<flutter::EncodableList>(*keys)) for (const auto& key : std::get<flutter::EncodableList>(*keys))
    if (std::holds_alternative<std::string>(key)) new_keys.push_back(std::get<std::string>(key));
  if (new_keys != calendar_date_keys_) {
    const auto selected = selected_day_ >= 0 && selected_day_ < static_cast<int>(calendar_date_keys_.size()) ? calendar_date_keys_[selected_day_] : "";
    const auto retained = std::find(new_keys.begin(), new_keys.end(), selected);
    selected_day_ = retained == new_keys.end() ? 0 : static_cast<int>(retained - new_keys.begin());
    calendar_date_keys_ = new_keys;
  }
  const auto* dates = Field(display, "calendarDateLabels");
  if (dates && !(*dates == calendar_dates_) && std::holds_alternative<flutter::EncodableList>(*dates)) {
    calendar_dates_ = *dates;
    SendMessageW(day_combo_, CB_RESETCONTENT, 0, 0);
    for (const auto& value : std::get<flutter::EncodableList>(*dates)) if (std::holds_alternative<std::string>(value)) {
      const auto label = ToWide(std::get<std::string>(value));
      SendMessageW(day_combo_, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(label.c_str()));
    }
  }
  SendMessageW(day_combo_, CB_SETCURSEL, selected_day_, 0);
  const auto* supplied = Field(display, "secondarySections");
  const Value sections = session_state_ == "unlocked" && supplied ? *supplied : Value(flutter::EncodableList{});
  for (auto& row : calendar_rows_) row.generation = Number(display, "calendarGeneration");
  if (sections == calendar_sections_) return;
  calendar_sections_ = sections;
  std::string focused_row, focused_label;
  const auto focus = GetFocus();
  auto previous = std::move(calendar_rows_);
  calendar_rows_.clear();
  for (const auto& row : previous) for (const auto& action : row.actions) if (action.button == focus) {
    focused_row = row.id; focused_label = action.label;
  }
  if (std::holds_alternative<flutter::EncodableList>(sections)) for (const auto& value : std::get<flutter::EncodableList>(sections)) {
    if (!std::holds_alternative<M>(value)) continue;
    const auto& map = std::get<M>(value);
    CalendarRow row;
    const auto old = std::find_if(previous.begin(), previous.end(), [&](const auto& item) { return item.id == Text(map, "id"); });
    if (old != previous.end()) { row = std::move(*old); old->title = old->body = nullptr; old->actions.clear(); }
    row.id = Text(map, "id"); row.day = Text(map, "day");
    row.generation = Number(display, "calendarGeneration");
    const auto make_text = [&](const char* key) {
      return CreateWindowW(L"STATIC", ToWide(Text(map, key)).c_str(), WS_CHILD | SS_NOPREFIX,
          0, 0, 10, 10, popup_, nullptr, GetModuleHandleW(nullptr), nullptr);
    };
    if (!row.title) row.title = make_text("title");
    if (!row.body) row.body = make_text("body");
    SetWindowTextW(row.title, ToWide(Text(map, "title")).c_str());
    SetWindowTextW(row.body, ToWide(Text(map, "body")).c_str());
    flutter::EncodableList actions;
    const auto* list = Field(map, "actions");
    if (list && std::holds_alternative<flutter::EncodableList>(*list)) actions = std::get<flutter::EncodableList>(*list);
    // Legacy fixture rows remain local previews, isolated from real actions.
    if (!Text(map, "actionId").empty()) actions.push_back(V(M{{V("id"), V(Text(map, "actionId"))}, {V("label"), V(Text(map, "actionLabel"))}}));
    auto old_actions = std::move(row.actions); row.actions.clear();
    for (const auto& action_value : actions) {
      if (!std::holds_alternative<M>(action_value)) continue;
      const auto& action_map = std::get<M>(action_value);
      CalendarRow::Action action;
      action.id = Text(action_map, "id"); action.label = Text(action_map, "label");
      if (action.id.empty()) continue;
      const auto reused = std::find_if(old_actions.begin(), old_actions.end(), [&](const auto& item) { return item.label == action.label; });
      if (reused != old_actions.end()) { action.button = reused->button; reused->button = nullptr; }
      if (!action.button) action.button = CreateWindowW(L"BUTTON", L"", WS_CHILD | WS_TABSTOP | BS_OWNERDRAW | BS_NOTIFY,
          0, 0, 10, 10, popup_, nullptr, GetModuleHandleW(nullptr), nullptr);
      SetWindowTextW(action.button, ToWide(action.label).c_str());
      EnableWindow(action.button, Flag(action_map, "enabled", true));
      AccessibleName(action.button, ToWide(Text(action_map, "accessibleName").empty() ? action.label : Text(action_map, "accessibleName")));
      row.actions.push_back(std::move(action));
    }
    for (const auto& action : old_actions) DestroyCalendarButton(action.button);
    for (auto control : {row.title, row.body}) SetWindowPos(control, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    for (const auto& action : row.actions) SetWindowPos(action.button, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    calendar_rows_.push_back(std::move(row));
  }
  for (const auto& row : previous) {
    for (auto control : {row.title, row.body}) if (control) DestroyWindow(control);
    for (const auto& action : row.actions) DestroyCalendarButton(action.button);
  }
  // Reuse a bounded set of control IDs instead of growing across resident refreshes.
  int control_id = 1000;
  for (const auto& row : calendar_rows_) for (const auto& action : row.actions) SetWindowLongPtrW(action.button, GWLP_ID, control_id++);
  if (!focused_row.empty() && !IsWindow(focus)) {
    HWND target = buttons_[3];
    for (const auto& row : calendar_rows_) if (row.id == focused_row) for (const auto& action : row.actions)
      if (action.label == focused_label) target = action.button;
    // Visibility/layout is applied before focus is restored.
    LayoutPopup(); SetFocus(target);
  }
  SetWindowPos(buttons_[4], HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}
void DesktopHost::CalendarAction(const std::string& action, int64_t generation, bool preview) {
  if (session_state_ == "unlocked") Event("calendarAction", {{V("actionId"), V(action)}, {V("generation"), V(generation)}, {V("preview"), V(preview)}});
}
void DesktopHost::UpdateTooltip() {
  std::wstring tip = L"Poma - " + ToWide(Text(snapshot_, "error").empty() ? Text(snapshot_, "phaseLabel") + " " + Text(snapshot_, "status") : "Needs attention");
  if (session_state_ == "unlocked" && !Text(snapshot_, "calendarTooltip").empty()) tip += L" | " + ToWide(Text(snapshot_, "calendarTooltip"));
  tip = BoundedTooltip(tip);
  if (tip == tooltip_ || !tray_added_) return;
  tooltip_ = tip; NOTIFYICONDATAW data{sizeof(data)};
  data.hWnd = window_; data.guidItem = kTrayGuid; data.uFlags = NIF_GUID | NIF_TIP;
  wcscpy_s(data.szTip, tip.c_str()); Shell_NotifyIconW(NIM_MODIFY, &data);
}
void DesktopHost::SetSessionState(const std::string& state) {
  if (state == session_state_) return;
  session_state_ = state;
  if (state != "unlocked") {
    HidePopup();
    snapshot_[V("secondarySections")] = V(flutter::EncodableList{});
    snapshot_[V("calendarTooltip")] = V("");
    snapshot_[V("calendarPreview")] = V(M{});
    if (popup_) SyncCalendar();
  }
  UpdateTooltip();
  Event("sessionState", {{V("state"), V(state)}});
}
void DesktopHost::RefreshSessionState() {
  std::string state = "unknown";
  LPWSTR buffer = nullptr; DWORD bytes = 0, session = 0;
  if (session_registered_ && ProcessIdToSessionId(GetCurrentProcessId(), &session) &&
      WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, session, WTSSessionInfoEx, &buffer, &bytes)) {
    if (bytes >= sizeof(WTSINFOEXW)) {
      const auto info = reinterpret_cast<WTSINFOEXW*>(buffer);
      if (info->Level == 1 && info->Data.WTSInfoExLevel1.SessionState == WTSActive) {
        const auto flags = info->Data.WTSInfoExLevel1.SessionFlags;
        if (flags == WTS_SESSIONSTATE_UNLOCK) state = "unlocked";
        else if (flags == WTS_SESSIONSTATE_LOCK) state = "locked";
      }
    }
  }
  if (buffer) WTSFreeMemory(buffer);
  SetSessionState(state);
}
void DesktopHost::EnsurePopupFocusVisible() {
  const HWND focused = GetFocus();
  if (!focused || !IsChild(popup_, focused)) return;
  RECT bounds{}, client{}; GetWindowRect(focused, &bounds); GetClientRect(popup_, &client);
  MapWindowPoints(nullptr, popup_, reinterpret_cast<POINT*>(&bounds), 2);
  int delta = bounds.top < 0 ? bounds.top - 8 : bounds.bottom > client.bottom ? bounds.bottom - client.bottom + 8 : 0;
  if (delta) {
    scroll_offset_ = std::max(0, std::min(scroll_offset_ + delta, content_height_ - static_cast<int>(client.bottom)));
    LayoutPopup(); InvalidateRect(popup_, nullptr, TRUE);
  }
}
void DesktopHost::TimerAction(const std::string& action, const M& snapshot) {
  Event("timer", {{V("action"), V(action)}, {V("revision"), V(Number(snapshot, "revision"))},
      {V("runId"), Field(snapshot, "runId") ? *Field(snapshot, "runId") : V()}});
}
void DesktopHost::Menu() {
  const M captured = snapshot_;
  const auto status = Text(captured, "status");
  HMENU menu = CreatePopupMenu();
  const UINT enabled = configured_ && Text(captured, "error").empty() && !Flag(captured, "locked") ? MF_ENABLED : MF_GRAYED;
  const auto primary = status == "running" ? L"Pause" : status == "paused" ? L"Resume" : L"Start " + ToWide(Text(captured, "phaseLabel"));
  AppendMenuW(menu, MF_STRING, kOpen, L"Open Poma");
  AppendMenuW(menu, MF_STRING | enabled, kPrimary, primary.c_str());
  AppendMenuW(menu, MF_STRING | enabled, kReset, L"Reset");
  AppendMenuW(menu, MF_STRING | enabled, kSkip, L"Skip");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING | (session_state_ == "unlocked" && Flag(captured, "calendarRefreshAvailable") ? MF_ENABLED : MF_GRAYED), kRefresh, L"Refresh calendar");
  AppendMenuW(menu, MF_STRING, kSettings, L"Calendar settings");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kQuit, L"Quit");
  menu_open_ = true;
  POINT cursor{}; GetCursorPos(&cursor); SetForegroundWindow(window_);
  const int selected = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, cursor.x, cursor.y, 0, window_, nullptr);
  menu_open_ = false; DestroyMenu(menu); PostMessageW(window_, WM_NULL, 0, 0);
  if (selected == kPrimary) TimerAction(status == "running" ? "pause" : status == "paused" ? "resume" : "start", captured);
  if (selected == kReset) TimerAction("reset", captured);
  if (selected == kSkip) TimerAction("skip", captured);
  if (selected == kOpen) { ShowMain(); Event("open"); }
  if (selected == kSettings) { ShowMain(); Event("settings"); }
  if (selected == kRefresh) CalendarAction(Text(captured, "calendarRefreshAction"), Number(captured, "calendarGeneration"));
  if (selected == kQuit) Event("quit");
}
void DesktopHost::Arm(const V* value) {
  if (!value || !std::holds_alternative<M>(*value)) {
    KillTimer(window_, kDeadline); elapsed_deadline_ = 0; deadline_run_.clear(); return;
  }
  const auto& args = std::get<M>(*value);
  const int64_t deadline = Number(args, "elapsedDeadlineMicros");
  const auto run = Text(args, "runId");
  if (deadline == elapsed_deadline_ && run == deadline_run_) return;
  KillTimer(window_, kDeadline); elapsed_deadline_ = deadline; deadline_run_ = run;
  const int64_t milliseconds = std::max<int64_t>(1, (deadline - ElapsedMicros() + 999) / 1000);
  if (!SetTimer(window_, kDeadline, static_cast<UINT>(std::min<int64_t>(milliseconds, USER_TIMER_MAXIMUM)), nullptr))
    winrt::throw_hresult(HRESULT_FROM_WIN32(GetLastError()));
}
void DesktopHost::SaveBounds() {
  if (!configured_ || IsIconic(window_) || IsZoomed(window_)) return;
  RECT bounds{}; GetWindowRect(window_, &bounds);
  const int dpi = static_cast<int>(GetDpiForWindow(window_));
  Event("bounds", {{V("x"), V(static_cast<int32_t>(bounds.left))}, {V("y"), V(static_cast<int32_t>(bounds.top))},
      {V("width"), V(MulDiv(bounds.right - bounds.left, 96, dpi))},
      {V("height"), V(MulDiv(bounds.bottom - bounds.top, 96, dpi))}});
}
void DesktopHost::InitializeAlerts() {
  alerts_initialized_ = true;
  if (IsPackaged()) {
    // No registry permission writes, no OS future scheduling.
    auto notifier = winrt::Windows::UI::Notifications::ToastNotificationManager::CreateToastNotifier();
    (void)notifier.Setting();
  }
}
void DesktopHost::ClearAlerts() {
  if (IsPackaged() && alerts_initialized_)
    winrt::Windows::UI::Notifications::ToastNotificationManager::History().Clear();
}
void DesktopHost::ClearCalendarReminders() {
  KillTimer(window_, kReminderDeadline);
  reminder_tokens_.clear(); reminder_shown_.clear(); reminder_responses_.clear();
  if (IsPackaged()) winrt::Windows::UI::Notifications::ToastNotificationManager::History().RemoveGroup(L"calendar");
}
void DesktopHost::Activate(const std::wstring& arguments) {
  if (arguments.rfind(L"calendar|", 0) == 0) {
    const auto response = ParseCalendarReminderResponse(arguments);
    if (!response || session_state_ != "unlocked" || response->generation != reminder_generation_) return;
    const auto token = ToUtf8(response->run);
    if (!reminder_tokens_.count(token) || !reminder_shown_.count(token)) return;
    const auto duplicate = std::find_if(reminder_responses_.begin(), reminder_responses_.end(), [&](const M& item) {
      return Text(item, "token") == token && Text(item, "action") == ToUtf8(response->action);
    });
    if (duplicate == reminder_responses_.end() && reminder_responses_.size() < 512) {
      reminder_responses_.push_back(M{{V("token"), V(token)}, {V("action"), V(ToUtf8(response->action))}, {V("generation"), V(reminder_generation_)}});
    }
    if (IsPackaged()) winrt::Windows::UI::Notifications::ToastNotificationManager::History().Remove(ToWide(token.substr(0, 16)), L"calendar");
    Event("calendarReminderAction"); return;
  }
  const auto response = ParseResponse(arguments);
  if (!response) return;
  const auto folder = directory_ + L"\\responses";
  const int code = SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
  if (code != ERROR_SUCCESS && code != ERROR_ALREADY_EXISTS && code != ERROR_FILE_EXISTS) return;
  HANDLE file = CreateFileW(SafeResponseFile(directory_, *response).c_str(), GENERIC_WRITE, FILE_SHARE_READ,
      nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH, nullptr);
  if (file != INVALID_HANDLE_VALUE) { FlushFileBuffers(file); CloseHandle(file); }
  if (response->action == L"dismiss" && IsPackaged()) {
    // The controller receipt handles repeat ingestion; dismissal changes no timer state.
  }
  Event("alertsChanged");
}
void DesktopHost::RunAsync(std::function<V()> action, std::unique_ptr<Result> result, bool notify) {
  HWND target = window_;
  workers_.emplace_back([target, notify, action = std::move(action), result = std::move(result)]() mutable {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    auto response = std::make_unique<AsyncResponse>(); response->result = std::move(result);
    response->worker = std::this_thread::get_id();
    response->notify = notify;
    try { response->value = action(); } catch (...) { response->failed = true; }
    if (PostMessageW(target, kAsyncMessage, 0, reinterpret_cast<LPARAM>(response.get()))) response.release();
    CoUninitialize();
  });
}
void DesktopHost::Method(const flutter::MethodCall<V>& call, std::unique_ptr<Result> result) {
  const auto& method = call.method_name();
  const auto* value = call.arguments();
  const M empty{};
  const M& args = value && std::holds_alternative<M>(*value) ? std::get<M>(*value) : empty;
  try {
    if(method=="focusTimeResolve"||method=="focusTimeZone") {
      const auto zone=FocusDeviceZone();
      M resolved{{V("zone"),V(ToUtf8(zone.TimeZoneKeyName[0]?zone.TimeZoneKeyName:zone.StandardName))},
        {V("fingerprint"),V(ToUtf8(FocusZoneFingerprint(zone)))}};
      if(method=="focusTimeResolve"){
        SYSTEMTIME wall{};wall.wYear=static_cast<WORD>(Number(args,"year"));wall.wMonth=static_cast<WORD>(Number(args,"month"));wall.wDay=static_cast<WORD>(Number(args,"day"));
        wall.wHour=static_cast<WORD>(Number(args,"hour"));wall.wMinute=static_cast<WORD>(Number(args,"minute"));wall.wSecond=static_cast<WORD>(Number(args,"second"));
        const auto matches=FocusResolveWall(wall,zone);
        if(matches.size()!=1){result->Error("focus_time","Choose an unambiguous local time.");return;}
        resolved[V("utcMicros")]=V(matches.front().utc_micros);resolved[V("offsetMinutes")]=V(matches.front().offset_minutes);
      }result->Success(V(resolved));return;
    }
    if(method=="focusJournalOpen"||method=="focusJournalSave"||method=="focusJournalStop"||method=="focusJournalDisable") {
      if(!calendar_credentials_)calendar_credentials_=std::make_unique<CalendarCredentialStore>(directory_);
      auto* store=calendar_credentials_.get();
      if(method=="focusJournalDisable"){store->DisableFocus(Flag(args,"disabled"));result->Success();}
      else if(method=="focusJournalStop"){store->StopFocus(Flag(args,"purge"));result->Success();}
      else if(method=="focusJournalOpen"){
        const auto saved=store->OpenFocus(Number(args,"revision",-1),Text(args,"accountKey"));
        result->Success(V(M{{V("generation"),V(saved.scope)},{V("revision"),V(saved.revision)},
          {V("stopped"),V(saved.stopped)},{V("disabled"),V(saved.disabled)},{V("document"),saved.document?V(*saved.document):V()}}));
      }else{
        RunAsync([store,args]()->V{return V(store->SaveFocus(Number(args,"credentialRevision",-1),Number(args,"generation",-1),Number(args,"revision",-1),Text(args,"accountKey"),Text(args,"document")));},std::move(result));
      }return;
    }
    if (method == "calendarCacheBind" || method == "calendarCacheInvalidate" ||
        method == "calendarCacheRead" || method == "calendarCacheWrite" ||
        method == "calendarReminderRead" || method == "calendarReminderWrite") {
      if (!calendar_credentials_) calendar_credentials_ = std::make_unique<CalendarCredentialStore>(directory_);
      auto* store = calendar_credentials_.get();
      if (method == "calendarCacheBind") {
        result->Success(V(store->BindAccount(Number(args, "revision", -1), Text(args, "accountKey"))));
      } else if (method == "calendarCacheInvalidate") {
        store->InvalidateCache(); result->Success();
      } else {
        const auto revision = Number(args, "revision", -1), scope = Number(args, "scope", -1);
        const auto account = Text(args, "accountKey"), document = Text(args, "document");
        const bool write = method == "calendarCacheWrite" || method == "calendarReminderWrite";
        const bool reminders = method == "calendarReminderRead" || method == "calendarReminderWrite";
        RunAsync([store, revision, scope, account, document, write, reminders]() -> V {
          if (write) { store->WriteAccount(revision, scope, account, document, reminders); return V(); }
          const auto value = store->ReadAccount(revision, scope, account, reminders);
          return value ? V(*value) : V();
        }, std::move(result));
      }
      return;
    }
    if (method == "calendarCredentialsRead" || method == "calendarCredentialsCommit" || method == "calendarCredentialsWrite" || method == "calendarCredentialsClear" || method == "calendarCredentialsRetire") {
      if (!calendar_credentials_) calendar_credentials_ = std::make_unique<CalendarCredentialStore>(directory_);
      if (method == "calendarCredentialsRead") {
        const auto saved = calendar_credentials_->Read();
        result->Success(V(M{{V("revision"), V(saved.revision)}, {V("commitRevision"),V(saved.commit_revision)},
          {V("credential"), saved.credential ? V(*saved.credential) : V()}}));
      } else if(method=="calendarCredentialsCommit") {
        result->Success(V(calendar_credentials_->Commit(Number(args,"revision",-1),Number(args,"commitRevision",-1),Text(args,"credential"),Flag(args,"purgeAccountData"))));
      } else if (method == "calendarCredentialsWrite") {
        calendar_credentials_->Write(Number(args, "revision", -1), Text(args, "credential"), Flag(args, "purgeAccountData"));
        result->Success();
      } else if (method == "calendarCredentialsRetire") {
        result->Success(V(calendar_credentials_->Retire(Number(args, "revision", -1), Text(args, "identity"))));
      } else {
        result->Success(V(calendar_credentials_->Clear()));
      }
      return;
    }
#ifdef POMA_CALENDAR_REVIEW
    if (method == "reviewVisibility") {
      if (Flag(args, "visible")) ShowMain();
      else { HidePopup(); ShowWindow(window_, SW_HIDE); Visibility(); }
      result->Success(); return;
    }
    if (method == "reviewTextScale") {
      review_text_scale = Number(args, "percent", 100) / 100.0;
      if (popup_ && IsWindowVisible(popup_)) PlacePopup();
      result->Success(); return;
    }
#endif
    if (method == "calendarFormat") {
      RunAsync([args] {
        M formatted;
        const auto* times = Field(args, "times");
        const auto* dates = Field(args, "dates");
        if (times && std::holds_alternative<flutter::EncodableList>(*times)) {
          const auto& values = std::get<flutter::EncodableList>(*times);
          if (values.size() > 100000) winrt::throw_hresult(E_INVALIDARG);
          for (const auto& time : values) {
            M sample{{V("value"), time}};
            const auto instant = Number(sample, "value");
            const auto label = LocalCalendarTime(instant);
            if (label.empty()) winrt::throw_hresult(E_FAIL);
            formatted[V(std::to_string(instant))] = V(ToUtf8(label));
          }
        }
        if (dates && std::holds_alternative<flutter::EncodableList>(*dates)) {
          const auto& values = std::get<flutter::EncodableList>(*dates);
          if (values.size() > 7) winrt::throw_hresult(E_INVALIDARG);
          for (const auto& date : values) {
            if (!std::holds_alternative<std::string>(date)) winrt::throw_hresult(E_INVALIDARG);
            const auto key = std::get<std::string>(date);
            const auto label = LocalCalendarDate(ToWide(key));
            if (label.empty()) winrt::throw_hresult(E_FAIL);
            formatted[V(key)] = V(ToUtf8(label));
          }
        }
        return V(formatted);
      }, std::move(result)); return;
    }
    if (method == "calendarOpenLink") {
      const auto url = ToWide(Text(args, "url"));
      if (session_state_ != "unlocked" || preview_mode_ || Number(args, "generation", -1) != Number(snapshot_, "calendarGeneration", -2) ||
          !ValidCalendarLink(url, Text(args, "kind"))) {
        result->Error("browser", "Calendar action is no longer available."); return;
      }
      const auto code = reinterpret_cast<INT_PTR>(ShellExecuteW(window_, L"open", url.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
      if (code <= 32) { result->Error("browser", "Default browser unavailable."); return; }
      result->Success(); return;
    }
    if (method == "calendarAuthorizationBrowser") {
      const auto url = value && std::holds_alternative<std::string>(*value) ? std::get<std::string>(*value) : "";
      const std::string prefix = "https://accounts.google.com/o/oauth2/v2/auth?";
      if (url.size() > 8192 || url.rfind(prefix, 0) != 0 || url.find_first_of("\r\n") != std::string::npos || url.find('#') != std::string::npos) {
        result->Error("browser", "Google authorization browser unavailable."); return;
      }
      const auto wide = ToWide(url);
      const auto code = reinterpret_cast<INT_PTR>(ShellExecuteW(window_, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
      if (code <= 32) { result->Error("browser", "Google authorization browser unavailable."); return; }
      result->Success(); return;
    }
    if (method == "environment") {
      std::string version = POMA_WINDOWS_VERSION;
      if (IsPackaged()) {
        const auto v = winrt::Windows::ApplicationModel::Package::Current().Id().Version();
        version = std::to_string(v.Major) + "." + std::to_string(v.Minor) + "." + std::to_string(v.Build) + "." + std::to_string(v.Revision);
      }
      result->Success(V(M{{V("dataDirectory"), V(ToUtf8(directory_))}, {V("packaged"), V(IsPackaged())},
          {V("version"), V(version)}, {V("visible"), V(IsWindowVisible(window_) != FALSE)},
          {V("sessionState"), V(session_state_)}, {V("calendarReview"), V(kCalendarReview)}})); return;
    }
    if (method == "configure") {
      close_to_tray_ = Flag(args, "closeToTray", true); close_explained_ = Flag(args, "closeExplained");
      const V* bounds = Field(args, "bounds");
      if (bounds && std::holds_alternative<M>(*bounds)) {
        const auto& map = std::get<M>(*bounds);
        POINT point{static_cast<LONG>(Number(map, "x")), static_cast<LONG>(Number(map, "y"))};
        RECT work = WorkArea(MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST));
        SetWindowPos(window_, nullptr, work.left, work.top, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        const int dpi = static_cast<int>(GetDpiForWindow(window_));
        RECT desired{point.x, point.y, point.x + MulDiv(static_cast<int>(Number(map, "width", 1080)), dpi, 96),
            point.y + MulDiv(static_cast<int>(Number(map, "height", 760)), dpi, 96)};
        desired = ClampRect(desired, work);
        SetWindowPos(window_, nullptr, desired.left, desired.top, desired.right - desired.left,
            desired.bottom - desired.top, SWP_NOZORDER | SWP_NOACTIVATE);
      }
      configured_ = true; Visibility(); result->Success(); return;
    }
    if (method == "publish") {
      const auto* previous_sections = Field(snapshot_, "secondarySections");
      const auto* next_sections = Field(args, "secondarySections");
      const auto* previous_preview = Field(snapshot_, "calendarPreview");
      const auto* next_preview = Field(args, "calendarPreview");
      const bool layout_changed = (!previous_sections || !next_sections || !(*previous_sections == *next_sections)) ||
          (preview_mode_ && (!previous_preview || !next_preview || !(*previous_preview == *next_preview))) ||
          Text(snapshot_, "appearance") != Text(args, "appearance") || Text(snapshot_, "error") != Text(args, "error") ||
          Text(snapshot_, "task") != Text(args, "task") || Flag(snapshot_, "locked") != Flag(args, "locked");
      snapshot_ = args; close_to_tray_ = Flag(args, "closeToTray", true); close_explained_ = Flag(args, "closeExplained");
      if (session_state_ != "unlocked") {
        snapshot_[V("secondarySections")] = V(flutter::EncodableList{});
        snapshot_[V("calendarTooltip")] = V("");
        snapshot_[V("calendarPreview")] = V(M{});
      }
      UpdateTooltip();
      if (popup_ && IsWindowVisible(popup_)) { if (layout_changed) PlacePopup(); else PaintPopup(); }
      result->Success(); return;
    }
    if (method == "armDeadline") { Arm(value); result->Success(); return; }
    if (method == "showMain") { ShowMain(); result->Success(); return; }
    if (method == "showPopup") {
      if (!popup_ || !IsWindowVisible(popup_)) TogglePopup(false, {-1, -1}, Flag(args, "preview"));
      result->Success(); return;
    }
    if (method == "exit") {
      try { ClearCalendarReminders(); } catch (...) {}
      try { ClearAlerts(); } catch (...) { /* No future OS requests exist. */ }
      KillTimer(window_, kDeadline); RemoveTray();
      result->Success(); closing_ = true; PostMessageW(window_, WM_CLOSE, 0, 0); return;
    }
    if (method == "startupState" || method == "setStartup") {
      const bool change = method == "setStartup";
      const bool enabled = value && std::holds_alternative<bool>(*value) && std::get<bool>(*value);
      RunAsync([change, enabled]() -> V {
        if (!IsPackaged()) return V("unavailable");
        if (change) {
          auto task = winrt::Windows::ApplicationModel::StartupTask::GetAsync(L"PomaStartup").get();
          if (enabled) task.RequestEnableAsync().get(); else task.Disable();
        }
        return V(ToUtf8(StartupStatus()));
      }, std::move(result), change); return;
    }
    if (method == "initializeAlerts") { InitializeAlerts(); result->Success(); return; }
    if (method == "calendarReminderAvailability") {
      using namespace winrt::Windows::UI::Notifications;
      result->Success(V(!IsPackaged() ? "unavailable" : ToastNotificationManager::CreateToastNotifier().Setting() == NotificationSetting::Enabled ? "ready" : "denied")); return;
    }
    if (method == "calendarReminderReplace") {
      const auto generation = Number(args, "generation");
      if (generation < reminder_generation_) { result->Success(); return; }
      std::set<std::string> tokens;
      const auto list = Field(args, "tokens");
      if (list && std::holds_alternative<flutter::EncodableList>(*list)) {
        for (const auto& item : std::get<flutter::EncodableList>(*list)) {
          if (!std::holds_alternative<std::string>(item)) continue;
          const auto token = std::get<std::string>(item);
          if (ValidReminderToken(ToWide(token)) && tokens.size() < 4096) tokens.insert(token);
        }
      }
      KillTimer(window_, kReminderDeadline);
      for (const auto& old : reminder_tokens_) if (!tokens.count(old)) {
        if (IsPackaged()) winrt::Windows::UI::Notifications::ToastNotificationManager::History().Remove(ToWide(old.substr(0, 16)), L"calendar");
        reminder_shown_.erase(old);
      }
      if (generation != reminder_generation_) reminder_responses_.clear();
      reminder_generation_ = generation; reminder_tokens_ = std::move(tokens);
      result->Success(); return;
    }
    if (method == "calendarReminderArm") {
      if (Number(args, "generation") != reminder_generation_) { result->Success(); return; }
      KillTimer(window_, kReminderDeadline);
      const auto deadline = Number(args, "deadline");
      if (deadline > 0 && !reminder_tokens_.empty()) {
        FILETIME file{}; GetSystemTimePreciseAsFileTime(&file); ULARGE_INTEGER time{};
        time.LowPart = file.dwLowDateTime; time.HighPart = file.dwHighDateTime;
        const auto delay = std::max<int64_t>(1, (deadline - FileTimeMicros(time.QuadPart) + 999) / 1000);
        if (!SetTimer(window_, kReminderDeadline, static_cast<UINT>(std::min<int64_t>(delay, USER_TIMER_MAXIMUM)), nullptr)) winrt::throw_hresult(E_FAIL);
      }
      result->Success(); return;
    }
    if (method == "calendarReminderShow") {
      const auto token = Text(args, "token");
      if (Number(args, "generation") == reminder_generation_ && reminder_tokens_.count(token) &&
          !reminder_shown_.count(token) && IsPackaged()) {
        using namespace winrt::Windows::UI::Notifications;
        auto notifier = ToastNotificationManager::CreateToastNotifier();
        FILETIME file{}; GetSystemTimePreciseAsFileTime(&file); ULARGE_INTEGER time{};
        time.LowPart = file.dwLowDateTime; time.HighPart = file.dwHighDateTime;
        if (notifier.Setting() == NotificationSetting::Enabled && Number(args, "expires") > FileTimeMicros(time.QuadPart)) {
          reminder_shown_.insert(token);
          const auto action = L"calendar|open|" + ToWide(token) + L"|" + std::to_wstring(reminder_generation_);
          const auto dismiss = L"calendar|dismiss|" + ToWide(token) + L"|" + std::to_wstring(reminder_generation_);
          const auto xml = L"<toast launch=\"" + action + L"\"><visual><binding template=\"ToastGeneric\"><text>Meeting coming up</text><text>Open Poma to see your schedule.</text></binding></visual><actions><action content=\"Open agenda\" arguments=\"" + action + L"\" activationType=\"foreground\"/><action content=\"Dismiss\" arguments=\"" + dismiss + L"\" activationType=\"foreground\"/></actions></toast>";
          winrt::Windows::Data::Xml::Dom::XmlDocument doc; doc.LoadXml(xml);
          ToastNotification toast(doc); toast.Tag(ToWide(token.substr(0, 16))); toast.Group(L"calendar");
          toast.ExpirationTime(winrt::Windows::Foundation::DateTime{winrt::clock::duration{(Number(args, "expires") + 11644473600000000LL) * 10}});
          notifier.Show(toast);
        }
      }
      result->Success(); return;
    }
    if (method == "calendarReminderResponses") {
      flutter::EncodableList responses;
      for (const auto& item : reminder_responses_) responses.push_back(V(item));
      result->Success(V(responses)); return;
    }
    if (method == "calendarReminderAcknowledge") {
      const auto token = Text(args, "token"), action = Text(args, "action");
      reminder_responses_.erase(std::remove_if(reminder_responses_.begin(), reminder_responses_.end(), [&](const M& item) {
        return Text(item, "token") == token && Text(item, "action") == action;
      }), reminder_responses_.end());
      result->Success(); return;
    }
    if (method == "synchronizeAlerts") {
      alerts_enabled_ = Flag(args, "enabled");
      if (!alerts_enabled_) {
        if (IsPackaged()) winrt::Windows::UI::Notifications::ToastNotificationManager::History().RemoveGroup(L"timer");
        result->Success(V("disabled")); return;
      }
      if (!IsPackaged()) { result->Success(V("unavailable")); return; }
      using namespace winrt::Windows::UI::Notifications;
      const auto retired = Field(args, "retiredIds");
      if (retired && std::holds_alternative<flutter::EncodableList>(*retired)) {
        for (const auto& id : std::get<flutter::EncodableList>(*retired)) {
          const int64_t number = std::holds_alternative<int32_t>(id) ? std::get<int32_t>(id) : std::get<int64_t>(id);
          ToastNotificationManager::History().Remove(std::to_wstring(number), L"timer");
        }
      }
      result->Success(V(ToastNotificationManager::CreateToastNotifier().Setting() == NotificationSetting::Enabled ? "ready" : "denied")); return;
    }
    if (method == "showCompletion") {
      if (IsPackaged() && alerts_enabled_) {
        using namespace winrt::Windows::UI::Notifications;
        auto notifier = ToastNotificationManager::CreateToastNotifier();
        const auto run = ToWide(Text(args, "runId"));
        if (!ValidRun(run)) { result->Error("invalid", "Invalid notification identity."); return; }
        if (notifier.Setting() == NotificationSetting::Enabled) {
          const auto serial = std::to_wstring(Number(args, "generation"));
          const auto open = L"open|" + run + L"|" + serial, dismiss = L"dismiss|" + run + L"|" + serial;
          const auto title = Flag(args, "focus") ? L"Focus complete" : L"Break complete";
          const auto xml = L"<toast launch=\"" + open + L"\"><visual><binding template=\"ToastGeneric\"><text>" + title +
              L"</text><text>Open Poma when you're ready.</text></binding></visual><actions><action content=\"Open timer\" arguments=\"" + open +
              L"\" activationType=\"foreground\"/><action content=\"Dismiss\" arguments=\"" + dismiss + L"\" activationType=\"foreground\"/></actions></toast>";
          winrt::Windows::Data::Xml::Dom::XmlDocument doc; doc.LoadXml(xml);
          ToastNotification toast(doc); toast.Tag(std::to_wstring(Number(args, "notificationId"))); toast.Group(L"timer");
          notifier.Show(toast);
        }
      }
      result->Success(); return;
    }
    if (method == "notificationSettings") {
      const auto code = reinterpret_cast<INT_PTR>(ShellExecuteW(window_, L"open", L"ms-settings:notifications", nullptr, nullptr, SW_SHOWNORMAL));
      if (code <= 32) winrt::throw_hresult(E_FAIL);
      result->Success(); return;
    }
    if (method == "responses") {
      flutter::EncodableList responses;
      WIN32_FIND_DATAW item{}; const auto folder = directory_ + L"\\responses\\";
      HANDLE search = FindFirstFileW((folder + L"*.event").c_str(), &item);
      if (search != INVALID_HANDLE_VALUE) {
        do {
          auto name = std::wstring(item.cFileName);
          if (name.size() < 7) continue;
          name.resize(name.size() - 6); std::replace(name.begin(), name.end(), L'.', L'|');
          const auto response = ParseResponse(name);
          if (response) responses.push_back(V(M{{V("runId"), V(ToUtf8(response->run))},
              {V("generation"), V(response->generation)}, {V("action"), V(ToUtf8(response->action))}}));
        } while (responses.size() < 512 && FindNextFileW(search, &item));
        FindClose(search);
      }
      result->Success(V(responses)); return;
    }
    if (method == "acknowledgeResponse") {
      const auto response = ParseResponse(ToWide(Text(args, "action") + "|" + Text(args, "runId") + "|" + std::to_string(Number(args, "generation"))));
      if (response && !DeleteFileW(SafeResponseFile(directory_, *response).c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND)
        winrt::throw_hresult(E_FAIL);
      result->Success(); return;
    }
    if (method == "clearForReset") {
      ClearCalendarReminders();
      ClearAlerts(); const auto directory = directory_;
      RunAsync([directory]() -> V {
        if (IsPackaged()) winrt::Windows::ApplicationModel::StartupTask::GetAsync(L"PomaStartup").get().Disable();
        ClearJournal(directory); return V();
      }, std::move(result), true); return;
    }
    result->NotImplemented();
  } catch (...) {
    if (result) result->Error("windows", "Windows operation failed. Your saved data is kept.");
  }
}

std::optional<LRESULT> DesktopHost::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  static const UINT taskbar = RegisterWindowMessageW(L"TaskbarCreated");
  if (message == taskbar) { tray_added_ = false; tooltip_.clear(); if (!AddTray()) ShowMain(); else UpdateTooltip(); return 0; }
  if (message == kTrayCallback) {
    const auto event = LOWORD(lparam);
    if (event == NIN_SELECT || event == NIN_KEYSELECT) TogglePopup(true, {GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)});
    if (event == WM_CONTEXTMENU) Menu();
    return 0;
  }
  if (message == kIpcMessage || message == kAlertMessage) {
    std::unique_ptr<std::wstring> value(reinterpret_cast<std::wstring*>(lparam));
    if (!value) return 0;
    if (message == kAlertMessage) Activate(*value);
    else if (*value == L"open") { ShowMain(); Event("open"); }
    else if (value->rfind(L"action:", 0) == 0) Activate(value->substr(7));
    return 0;
  }
  if (message == kAsyncMessage) {
    std::unique_ptr<AsyncResponse> response(reinterpret_cast<AsyncResponse*>(lparam));
    const auto worker = std::find_if(workers_.begin(), workers_.end(), [&](const auto& thread) { return thread.get_id() == response->worker; });
    if (worker != workers_.end()) { worker->join(); workers_.erase(worker); }
    if (response->failed) response->result->Error("windows", "Windows service operation failed.");
    else response->result->Success(response->value);
    if (response->notify) Event("startupChanged"); return 0;
  }
  if (message == WM_CLOSE && !closing_) {
    if (configured_ && close_to_tray_ && tray_added_) {
      SaveBounds();
      if (!close_explained_) {
        MessageBoxW(window_, L"Poma keeps running in the system tray when you close this window. Use the tray menu's Quit action to stop Poma and its alerts.", L"Poma is still running", MB_OK | MB_ICONINFORMATION);
        close_explained_ = true; Event("closeExplained");
      }
      HidePopup(); ShowWindow(window_, SW_HIDE); Visibility();
    } else Event("quit");
    return 0;
  }
  if (message == WM_TIMER && wparam == kReminderDeadline) {
    KillTimer(window_, kReminderDeadline);
    Event("calendarReminderDeadline", {{V("generation"), V(reminder_generation_)}}); return 0;
  }
  if (message == WM_TIMER && wparam == kDeadline) {
    KillTimer(window_, kDeadline); const auto run = deadline_run_; elapsed_deadline_ = 0;
    Event("deadline", {{V("runId"), V(run)}}); return 0;
  }
  if (message == WM_TIMER && wparam == kBounds) { KillTimer(window_, kBounds); SaveBounds(); return 0; }
  if (message == WM_SIZE || message == WM_SHOWWINDOW) Visibility();
  if (message == WM_EXITSIZEMOVE || (message == WM_SIZE && wparam == SIZE_RESTORED))
    SetTimer(window_, kBounds, 500, nullptr);
  if (message == WM_POWERBROADCAST && wparam == PBT_APMSUSPEND) {
    try { ClearCalendarReminders(); } catch (...) {}
    Event("suspend");
  }
  if (message == WM_POWERBROADCAST && (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND)) {
    try { ClearCalendarReminders(); } catch (...) {}
    RefreshSessionState();
    // Relative window timers need not count suspended time. Re-arm from the
    // sleep-inclusive clock even when resume happens before phase expiry.
    KillTimer(window_, kDeadline); elapsed_deadline_ = 0;
    Event("resume");
  }
  if (message == WM_TIMECHANGE) Event("timeChanged");
  if (message == WM_WTSSESSION_CHANGE) {
    if (wparam == WTS_SESSION_LOCK) SetSessionState("locked");
    else RefreshSessionState();
    return 0;
  }
  if (message == WM_SETTINGCHANGE || message == WM_THEMECHANGED) {
    if (message == WM_THEMECHANGED || wparam == SPI_SETHIGHCONTRAST) {
      RemoveTray(); tooltip_.clear(); if (!AddTray()) ShowMain(); else UpdateTooltip();
    }
    if (popup_ && IsWindowVisible(popup_)) PlacePopup(); Event("timeChanged");
  }
  if (message == WM_DISPLAYCHANGE) {
    HidePopup(); RECT bounds{}; GetWindowRect(window_, &bounds);
    const RECT safe = ClampRect(bounds, WorkArea(MonitorFromRect(&bounds, MONITOR_DEFAULTTONEAREST)));
    SetWindowPos(window_, nullptr, safe.left, safe.top, safe.right - safe.left, safe.bottom - safe.top, SWP_NOACTIVATE | SWP_NOZORDER);
  }
  if (message == WM_GETMINMAXINFO) {
    auto info = reinterpret_cast<MINMAXINFO*>(lparam);
    const auto work = WorkArea(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST));
    const auto dpi = static_cast<int>(GetDpiForWindow(window_));
    info->ptMinTrackSize = {std::min<LONG>(MulDiv(640, dpi, 96), work.right - work.left),
        std::min<LONG>(MulDiv(480, dpi, 96), work.bottom - work.top)}; return 0;
  }
  if (message == WM_QUERYENDSESSION) { Event("quit"); return TRUE; }
  return std::nullopt;
}

LRESULT CALLBACK DesktopHost::PopupProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto host = reinterpret_cast<DesktopHost*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    host = static_cast<DesktopHost*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(host));
  }
  if (!host) return DefWindowProcW(hwnd, message, wparam, lparam);
  if (message == WM_CLOSE) { host->HidePopup(true); return 0; }
  if (message == WM_ACTIVATE && LOWORD(wparam) == WA_INACTIVE && !host->menu_open_) {
    wchar_t name[128]{}; GetClassNameW(reinterpret_cast<HWND>(lparam), name, 128);
    if (std::wstring(name).find(L"Tray") != std::wstring::npos || std::wstring(name).find(L"Overflow") != std::wstring::npos)
      host->tray_dismissed_at_ = GetTickCount64();
    host->HidePopup();
  }
  if (message == WM_DPICHANGED) {
    const auto suggested = reinterpret_cast<RECT*>(lparam);
    const auto safe = ClampRect(*suggested, WorkArea(MonitorFromRect(suggested, MONITOR_DEFAULTTONEAREST)));
    SetWindowPos(hwnd, nullptr, safe.left, safe.top, safe.right - safe.left, safe.bottom - safe.top, SWP_NOZORDER | SWP_NOACTIVATE);
    host->PaintPopup(); return 0;
  }
  if (message == WM_SIZE) host->LayoutPopup();
  if (message == WM_VSCROLL || message == WM_MOUSEWHEEL) {
    SCROLLINFO info{sizeof(SCROLLINFO), SIF_ALL}; GetScrollInfo(hwnd, SB_VERT, &info);
    int next = host->scroll_offset_;
    if (message == WM_MOUSEWHEEL) next -= GET_WHEEL_DELTA_WPARAM(wparam) / WHEEL_DELTA * 48;
    else switch (LOWORD(wparam)) {
      case SB_LINEUP: next -= 32; break; case SB_LINEDOWN: next += 32; break;
      case SB_PAGEUP: next -= info.nPage; break; case SB_PAGEDOWN: next += info.nPage; break;
      case SB_THUMBTRACK: next = info.nTrackPos; break;
    }
    host->scroll_offset_ = std::max(0, std::min(next, info.nMax - static_cast<int>(info.nPage) + 1));
    host->LayoutPopup(); InvalidateRect(hwnd, nullptr, TRUE); return 0;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == BN_SETFOCUS) host->EnsurePopupFocusVisible();
  if (message == WM_COMMAND && LOWORD(wparam) == kDay && HIWORD(wparam) == CBN_SELCHANGE) {
    host->selected_day_ = static_cast<int>(SendMessageW(host->day_combo_, CB_GETCURSEL, 0, 0));
    host->scroll_offset_ = 0; host->PlacePopup(); return 0;
  }
  if (message == WM_COMMAND && LOWORD(wparam) == kDay && HIWORD(wparam) == CBN_SETFOCUS) host->EnsurePopupFocusVisible();
  if (message == WM_COMMAND && HIWORD(wparam) == BN_CLICKED) {
    const int id = LOWORD(wparam);
    const M captured = host->pressed_timer_control_ == reinterpret_cast<HWND>(lparam) ? host->pressed_timer_snapshot_ : host->snapshot_;
    host->pressed_timer_control_ = nullptr; host->pressed_timer_snapshot_.clear();
    const auto status = Text(captured, "status");
    if (id == kPrimary) host->TimerAction(status == "running" ? "pause" : status == "paused" ? "resume" : "start", captured);
    if (id == kReset) host->TimerAction("reset", captured);
    if (id == kSkip) host->TimerAction("skip", captured);
    if (id == kOpen) { host->ShowMain(); host->Event("open"); }
    if (id == kSettings) { host->ShowMain(); host->Event("settings"); }
    for (const auto& row : host->calendar_rows_) for (const auto& action : row.actions)
      if (action.button == reinterpret_cast<HWND>(lparam) && GetDlgCtrlID(action.button) == id)
        host->CalendarAction(action.id, row.generation, host->preview_mode_);
    return 0;
  }
  if (message == WM_CTLCOLORSTATIC) {
    HDC dc = reinterpret_cast<HDC>(wparam); SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, host->high_contrast_ ? GetSysColor(COLOR_WINDOWTEXT) : host->dark_ ? RGB(241,243,252) : RGB(37,45,67));
    return reinterpret_cast<LRESULT>(host->background_);
  }
  if (message == WM_ERASEBKGND && host->background_) {
    RECT area{}; GetClientRect(hwnd, &area); FillRect(reinterpret_cast<HDC>(wparam), &area, host->background_); return 1;
  }
  if (message == WM_DRAWITEM) {
    const auto draw = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
    const bool primary = draw->CtlID == kPrimary && !(draw->itemState & ODS_DISABLED);
    COLORREF background = host->high_contrast_ ? GetSysColor(primary ? COLOR_HIGHLIGHT : COLOR_BTNFACE)
        : primary ? (host->dark_ ? RGB(201,191,255) : RGB(104,84,200)) : host->dark_ ? RGB(40,49,68) : RGB(235,237,245);
    COLORREF foreground = host->high_contrast_ ? GetSysColor(primary ? COLOR_HIGHLIGHTTEXT : COLOR_BTNTEXT)
        : primary ? host->dark_ ? RGB(40,27,92) : RGB(255,255,255) : host->dark_ ? RGB(241,243,252) : RGB(37,45,67);
    if (draw->itemState & ODS_DISABLED) foreground = GetSysColor(COLOR_GRAYTEXT);
    HBRUSH brush = CreateSolidBrush(background); FillRect(draw->hDC, &draw->rcItem, brush); DeleteObject(brush);
    if (draw->itemState & ODS_SELECTED) FrameRect(draw->hDC, &draw->rcItem, GetSysColorBrush(COLOR_HIGHLIGHT));
    SetBkMode(draw->hDC, TRANSPARENT); SetTextColor(draw->hDC, foreground);
    const auto previous = SelectObject(draw->hDC, host->body_font_);
    const int length = GetWindowTextLengthW(draw->hwndItem);
    std::wstring label(static_cast<size_t>(length) + 1, L'\0'); GetWindowTextW(draw->hwndItem, label.data(), length + 1);
    RECT text = draw->rcItem; InflateRect(&text, -6, -2);
    RECT measure{0, 0, text.right - text.left, 0};
    DrawTextW(draw->hDC, label.c_str(), -1, &measure, DT_CALCRECT | DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
    text.top += std::max(0L, (text.bottom - text.top - measure.bottom) / 2);
    DrawTextW(draw->hDC, label.c_str(), -1, &text, DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
    SelectObject(draw->hDC, previous);
    if (draw->itemState & ODS_FOCUS) { InflateRect(&text, -4, -4); DrawFocusRect(draw->hDC, &text); }
    return TRUE;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}
}  // namespace poma

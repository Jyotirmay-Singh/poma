#ifndef POMA_DESKTOP_UTIL_H_
#define POMA_DESKTOP_UTIL_H_
#include <windows.h>
#include <algorithm>
#include <cstdint>
#include <string>
#include <optional>

namespace poma {
#ifdef POMA_FOCUS_AUDIO_REVIEW
inline constexpr wchar_t kActivatorString[] = L"{970A3EE5-5721-4FC9-8AB1-FA8994C723D7}";
inline constexpr GUID kActivator = {0x970a3ee5, 0x5721, 0x4fc9,
    {0x8a, 0xb1, 0xfa, 0x89, 0x94, 0xc7, 0x23, 0xd7}};
inline constexpr GUID kTrayGuid = {0x6d191081, 0xc183, 0x49bb,
    {0x83, 0xee, 0x19, 0x42, 0x6a, 0x36, 0xd4, 0x0d}};
#else
inline constexpr wchar_t kActivatorString[] = L"{970A3EE4-5721-4FC9-8AB1-FA8994C723D7}";
inline constexpr GUID kActivator = {0x970a3ee4, 0x5721, 0x4fc9,
    {0x8a, 0xb1, 0xfa, 0x89, 0x94, 0xc7, 0x23, 0xd7}};
inline constexpr GUID kTrayGuid = {0x6d191080, 0xc183, 0x49bb,
    {0x83, 0xee, 0x19, 0x42, 0x6a, 0x36, 0xd4, 0x0d}};
#endif
inline constexpr UINT kIpcMessage = WM_APP + 51;
inline constexpr UINT kAlertMessage = WM_APP + 52;
inline constexpr UINT kAsyncMessage = WM_APP + 53;

inline int64_t FileTimeMicros(uint64_t value) {
  return static_cast<int64_t>(value / 10) - 11644473600000000LL;
}
inline int64_t ElapsedMicros() {
  ULONGLONG ticks = 0;
  QueryInterruptTimePrecise(&ticks);
  return static_cast<int64_t>(ticks / 10);
}
inline RECT ClampRect(RECT desired, const RECT& work) {
  const LONG width = std::max<LONG>(1, std::min(desired.right - desired.left, work.right - work.left));
  const LONG height = std::max<LONG>(1, std::min(desired.bottom - desired.top, work.bottom - work.top));
  const LONG x = std::max(work.left, std::min(desired.left, work.right - width));
  const LONG y = std::max(work.top, std::min(desired.top, work.bottom - height));
  return RECT{x, y, x + width, y + height};
}
inline RECT PopupRect(RECT icon, const RECT& work, int width, int height) {
  // Prefer above the icon, then below it; clamp rather than assume a bottom taskbar.
  int y = icon.top - height - 8;
  if (y < work.top) y = icon.bottom + 8;
  return ClampRect({icon.right - width, y, icon.right, y + height}, work);
}
inline RECT PopupAnchor(const std::optional<RECT>& icon, const std::optional<POINT>& activation, const RECT& main_work) {
  if (icon && icon->right > icon->left && icon->bottom > icon->top) return *icon;
  const auto point = activation.value_or(POINT{main_work.right - 8, main_work.bottom - 8});
  return {point.x, point.y, point.x + 1, point.y + 1};
}
inline std::wstring BoundedTooltip(const std::wstring& text) {
  if (text.size() <= 127) return text;
  size_t length = 126;
  if (text[length - 1] >= 0xD800 && text[length - 1] <= 0xDBFF) --length;
  return text.substr(0, length) + L"\u2026";
}
inline bool ActivatePopupButton(HWND popup, HWND focused, UINT message, WPARAM key) {
  if (message != WM_KEYDOWN || key != VK_RETURN || !focused || !IsChild(popup, focused) || !IsWindowEnabled(focused)) return false;
  wchar_t name[32]{}; GetClassNameW(focused, name, 32);
  if (wcscmp(name, L"Button") != 0) return false;
  SendMessageW(focused, BM_CLICK, 0, 0);
  return true;
}
// Opaque timer identities only: never task titles, paths, or executable commands.
inline bool ValidRun(const std::wstring& value) {
  return !value.empty() && value.size() <= 128 && std::all_of(value.begin(), value.end(),
      [](wchar_t c) { return (c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z') ||
          (c >= L'0' && c <= L'9') || c == L'-' || c == L'_'; });
}
struct Response { std::wstring run, action; int64_t generation; };
inline std::optional<Response> ParseResponse(const std::wstring& value) {
  const auto first = value.find(L'|'), last = value.rfind(L'|');
  if (first == std::wstring::npos || first == last) return std::nullopt;
  const auto action = value.substr(0, first), run = value.substr(first + 1, last - first - 1);
  const auto serial = value.substr(last + 1);
  if ((action != L"open" && action != L"dismiss") || !ValidRun(run) || serial.empty() ||
      serial.size() > 16 || !std::all_of(serial.begin(), serial.end(), [](wchar_t c) { return c >= L'0' && c <= L'9'; })) return std::nullopt;
  const int64_t generation = _wtoi64(serial.c_str());
  if (generation < 1) return std::nullopt;
  return Response{run, action, generation};
}
inline bool ValidReminderToken(const std::wstring& token) {
  return token.size() == 64 && token.find_first_not_of(L"0123456789abcdef") == std::wstring::npos;
}
inline std::optional<Response> ParseCalendarReminderResponse(const std::wstring& value) {
  if (value.rfind(L"calendar|", 0) != 0) return std::nullopt;
  auto response = ParseResponse(value.substr(9));
  if (!response || !ValidReminderToken(response->run)) return std::nullopt;
  return response;
}
std::wstring DataDirectory();
bool IsPackaged();
std::wstring ToWide(const std::string& value);
std::string ToUtf8(const std::wstring& value);
std::wstring UserSid();
// GDI static text does not apply OpenType tnum. Give the Sora countdown fixed
// digit cells while retaining the full accessible text on the static control.
struct CountdownMetrics {
  int digit = 0;
  int colon = 0;
  int height = 0;
  int Width(const std::wstring& value) const {
    int width = 0;
    for (const auto character : value) width += character == L':' ? colon : digit;
    return width;
  }
};
inline CountdownMetrics MeasureCountdown(HDC dc) {
  CountdownMetrics result;
  for (wchar_t digit = L'0'; digit <= L'9'; ++digit) {
    SIZE size{}; GetTextExtentPoint32W(dc, &digit, 1, &size);
    result.digit = std::max(result.digit, static_cast<int>(size.cx));
    result.height = std::max(result.height, static_cast<int>(size.cy));
  }
  SIZE colon{}; GetTextExtentPoint32W(dc, L":", 1, &colon);
  result.colon = static_cast<int>(colon.cx);
  return result;
}
inline void DrawCountdown(HDC dc, const std::wstring& value, const RECT& bounds) {
  const auto metrics = MeasureCountdown(dc);
  int x = bounds.left + (bounds.right - bounds.left - metrics.Width(value)) / 2;
  for (const auto character : value) {
    const int width = character == L':' ? metrics.colon : metrics.digit;
    RECT cell{x, bounds.top, x + width, bounds.bottom};
    DrawTextW(dc, &character, 1, &cell, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
    x += width;
  }
}
}  // namespace poma
#endif

#ifndef POMA_CALENDAR_LINKS_H_
#define POMA_CALENDAR_LINKS_H_
#include <windows.h>
#include <winhttp.h>
#include <algorithm>
#include <cstdint>
#include <regex>
#include <string>

namespace poma {
// Independent native gate. Never pass unvalidated channel data to ShellExecute.
inline bool ValidCalendarLink(const std::wstring& value, const std::string& kind) {
  if (value.empty() || value.size() > 4096 || std::any_of(value.begin(), value.end(), [](wchar_t c) {
    return c <= 32 || c == 127 || c == L'\\' || c == L'<' || c == L'>' || c == L'"' || c == L'\'' ||
      (c >= 0x202A && c <= 0x202E) || (c >= 0x2066 && c <= 0x2069);
  })) return false;
  if (std::regex_search(value, std::wregex(LR"(%(0[0-9a-f]|1[0-9a-f]|7f|5c))", std::regex::icase))) return false;
  for (size_t i = 0; i < value.size(); ++i) if (value[i] == L'%') {
    const auto hex = [](wchar_t c) { return (c >= L'0' && c <= L'9') || (c >= L'a' && c <= L'f') || (c >= L'A' && c <= L'F'); };
    if (i + 2 >= value.size() || !hex(value[i + 1]) || !hex(value[i + 2])) return false;
  }
  if (!std::regex_search(value, std::wregex(LR"(^https://[a-z0-9.-]+(:443)?/)", std::regex::icase)) || value.find(L'#') != std::wstring::npos) return false;
  URL_COMPONENTS parts{}; parts.dwStructSize = sizeof(parts);
  parts.dwHostNameLength = parts.dwUrlPathLength = parts.dwUserNameLength = parts.dwPasswordLength = parts.dwExtraInfoLength = static_cast<DWORD>(-1);
  if (!WinHttpCrackUrl(value.c_str(), static_cast<DWORD>(value.size()), 0, &parts) ||
      parts.nScheme != INTERNET_SCHEME_HTTPS || parts.nPort != 443 || parts.dwUserNameLength || parts.dwPasswordLength) return false;
  std::wstring host(parts.lpszHostName, parts.dwHostNameLength), path(parts.lpszUrlPath, parts.dwUrlPathLength);
  std::transform(host.begin(), host.end(), host.begin(), [](wchar_t c) { return static_cast<wchar_t>(c >= L'A' && c <= L'Z' ? c + (L'a' - L'A') : c); });
  if (!std::regex_match(host, std::wregex(LR"([a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*)"))) return false;
  if (kind == "calendar") return value == L"https://calendar.google.com/calendar/";
  if (kind == "event") return (host == L"calendar.google.com" || host == L"www.google.com") &&
      std::regex_match(path, std::wregex(LR"(/calendar/(u/\d+/)?event(/[^/]+)?/*)"));
  if (kind != "join") return false;
  if (host == L"meet.google.com") return std::regex_match(path,
      std::wregex(LR"(/([a-z]{3}-[a-z]{4}-[a-z]{3}|lookup/[A-Za-z0-9_-]+)/*)"));
  if (host == L"teams.microsoft.com" || host == L"teams.live.com" || host == L"teams.cloud.microsoft")
    return std::regex_match(path, std::wregex(LR"(/(l/meetup-join/[^/]+/\d+|meet/[A-Za-z0-9_-]+)/*)"));
  if (host == L"zoom.us" || (host.size() > 8 && host.compare(host.size() - 8, 8, L".zoom.us") == 0))
    return std::regex_match(path, std::wregex(LR"(/(j/\d+|s/\d+|wc/join/\d+|my/[A-Za-z0-9._-]+)/*)"));
  return false;
}

inline std::wstring LocalCalendarTime(int64_t micros) {
  if (micros < -11644473600000000LL || micros > 900000000000000000LL) return L"";
  ULARGE_INTEGER ticks{}; ticks.QuadPart = static_cast<ULONGLONG>(micros + 11644473600000000LL) * 10;
  const FILETIME file{ticks.LowPart, ticks.HighPart};
  SYSTEMTIME utc{}, local{}; DYNAMIC_TIME_ZONE_INFORMATION zone{};
  if (!FileTimeToSystemTime(&file, &utc) || GetDynamicTimeZoneInformation(&zone) == TIME_ZONE_ID_INVALID ||
      !SystemTimeToTzSpecificLocalTimeEx(&zone, &utc, &local)) return L"";
  wchar_t pattern[128]{}, result[256]{};
  if (!GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SSHORTTIME, pattern, 128) ||
      !GetTimeFormatEx(LOCALE_NAME_USER_DEFAULT, 0, &local, pattern, result, 256)) return L"";
  return result;
}
inline std::wstring LocalCalendarDate(const std::wstring& value) {
  if (!std::regex_match(value, std::wregex(LR"(\d{4}-\d{2}-\d{2})"))) return L"";
  SYSTEMTIME date{};
  date.wYear = static_cast<WORD>(std::stoi(value.substr(0, 4)));
  date.wMonth = static_cast<WORD>(std::stoi(value.substr(5, 2)));
  date.wDay = static_cast<WORD>(std::stoi(value.substr(8, 2)));
  wchar_t result[256]{};
  return GetDateFormatEx(LOCALE_NAME_USER_DEFAULT, DATE_SHORTDATE, &date, nullptr, result, 256, nullptr) ? result : L"";
}
}  // namespace poma
#endif

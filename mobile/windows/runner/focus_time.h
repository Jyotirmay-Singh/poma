#ifndef POMA_FOCUS_TIME_H_
#define POMA_FOCUS_TIME_H_
#include <windows.h>
#include <set>
#include <sstream>
#include <stdexcept>
#include <vector>

namespace poma {
inline DYNAMIC_TIME_ZONE_INFORMATION FocusDeviceZone() {
  DYNAMIC_TIME_ZONE_INFORMATION zone{};
  if(GetDynamicTimeZoneInformation(&zone)==TIME_ZONE_ID_INVALID)throw std::runtime_error("Device timezone unavailable.");
  return zone;
}
inline std::wstring FocusZoneFingerprint(const DYNAMIC_TIME_ZONE_INFORMATION& z) {
  std::wostringstream s;s<<z.TimeZoneKeyName<<L'|'<<z.Bias<<L'|'<<z.StandardBias<<L'|'<<z.DaylightBias<<L'|'<<z.DynamicDaylightTimeDisabled;
  for(const auto* t:{&z.StandardDate,&z.DaylightDate})s<<L'|'<<t->wYear<<L','<<t->wMonth<<L','<<t->wDayOfWeek<<L','<<t->wDay<<L','<<t->wHour<<L','<<t->wMinute<<L','<<t->wSecond;
  return s.str();
}
struct FocusResolvedTime {int64_t utc_micros;int offset_minutes;};
inline bool FocusSameWall(const SYSTEMTIME& a,const SYSTEMTIME& b) {
  return a.wYear==b.wYear&&a.wMonth==b.wMonth&&a.wDay==b.wDay&&a.wHour==b.wHour&&a.wMinute==b.wMinute&&a.wSecond==b.wSecond;
}
inline std::vector<FocusResolvedTime> FocusResolveWall(const SYSTEMTIME& wall,DYNAMIC_TIME_ZONE_INFORMATION zone) {
  FILETIME file{};
  if(wall.wYear<1602||wall.wYear>9998||wall.wMilliseconds!=0||!SystemTimeToFileTime(&wall,&file))return {};
  SYSTEMTIME verified{};FileTimeToSystemTime(&file,&verified);
  if(!FocusSameWall(wall,verified))return {};
  ULARGE_INTEGER local{};local.LowPart=file.dwLowDateTime;local.HighPart=file.dwHighDateTime;
  std::set<LONG> biases;
  for(int year=wall.wYear-1;year<=wall.wYear+1;year++){
    TIME_ZONE_INFORMATION rules{};
    if(!GetTimeZoneInformationForYear(static_cast<USHORT>(year),&zone,&rules))throw std::runtime_error("Timezone rules unavailable.");
    biases.insert(rules.Bias+rules.StandardBias);biases.insert(rules.Bias+rules.DaylightBias);
  }
  std::vector<FocusResolvedTime> results;std::set<int64_t> seen;
  for(const auto bias:biases){
    const int64_t ticks=static_cast<int64_t>(local.QuadPart)+static_cast<int64_t>(bias)*600000000LL;
    if(ticks<0)continue;ULARGE_INTEGER candidate{};candidate.QuadPart=static_cast<ULONGLONG>(ticks);
    FILETIME utc_file{candidate.LowPart,candidate.HighPart};SYSTEMTIME utc{},roundtrip{};
    if(!FileTimeToSystemTime(&utc_file,&utc)||!SystemTimeToTzSpecificLocalTimeEx(&zone,&utc,&roundtrip))continue;
    const int64_t micros=ticks/10-11644473600000000LL;
    if(FocusSameWall(wall,roundtrip)&&seen.insert(micros).second)results.push_back({micros,-bias});
  }
  return results;
}
}
#endif

#include <windows.h>
#include <iostream>
#include <string>
#include <vector>
#include "resource.h"
#include "desktop_util.h"

namespace {
int checks = 0;
bool Check(bool value, const char* description) {
  ++checks;
  if (!value) std::cerr << "FAIL " << description << '\n';
  return value;
}
}

int main() {
  const auto module = GetModuleHandleW(nullptr);
  std::vector<HANDLE> resources;
  bool passed = true;
  for (const int id : {IDR_POMA_FONT_REGULAR, IDR_POMA_FONT_MEDIUM, IDR_POMA_FONT_SEMIBOLD,
                       IDR_POMA_SORA_MEDIUM, IDR_POMA_SORA_SEMIBOLD}) {
    const auto resource = FindResourceW(module, MAKEINTRESOURCEW(id), RT_RCDATA);
    passed &= Check(resource != nullptr, "Production font resource is embedded");
    if (!resource) continue;
    const auto data = LockResource(LoadResource(module, resource));
    DWORD count = 0;
    const auto font = AddFontMemResourceEx(data, SizeofResource(module, resource), nullptr, &count);
    passed &= Check(font != nullptr && count > 0, "GDI loads the process-private font");
    if (font) resources.push_back(font);
  }
  const auto dc = CreateCompatibleDC(nullptr);
  for (const int scale : {100, 150, 200}) {
    for (const auto role : {std::pair<int, int>{16, FW_NORMAL}, {14, FW_SEMIBOLD}, {24, FW_MEDIUM}}) {
      const auto font = CreateFontW(-MulDiv(role.first, scale, 100), 0, 0, 0, role.second,
          FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
          CLEARTYPE_QUALITY, DEFAULT_PITCH, role.first == 24 ? L"Sora Medium" : L"Source Sans 3");
      passed &= Check(font != nullptr, "Font is available at the requested role and text scale");
      const auto previous = SelectObject(dc, font);
      wchar_t face[64]{};
      GetTextFaceW(dc, 64, face);
      passed &= Check(std::wstring(face).find(role.first == 24 ? L"Sora Medium" : L"Source Sans 3") == 0,
          "Native text resolves to the bundled family rather than a silent fallback");
      SIZE size{};
      GetTextExtentPoint32W(dc, L"Start focus", 11, &size);
      passed &= Check(size.cy > 0 && size.cy < MulDiv(48, scale, 100),
          "Native control text fits its accessible scaled height");
      if (role.first == 24) {
        const auto metrics = poma::MeasureCountdown(dc);
        passed &= Check(metrics.digit > 0 && metrics.Width(L"11:11") == metrics.Width(L"88:88"),
            "Native Sora countdown has stable fixed digit cells");
        passed &= Check(metrics.Width(L"120:00") < MulDiv(340, scale, 100),
            "Maximum configured duration fits the native countdown");
      }
      SelectObject(dc, previous);
      DeleteObject(font);
    }
  }
  DeleteDC(dc);
  for (const auto resource : resources) RemoveFontMemResourceEx(resource);
  if (passed) std::cout << checks << " native font checks passed\n";
  return passed ? 0 : 1;
}

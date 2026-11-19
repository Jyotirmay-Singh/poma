#ifndef POMA_COMPLETION_BELL_H_
#define POMA_COMPLETION_BELL_H_

#include <string>

namespace poma {
inline std::wstring CompletionAudioXml(bool enabled) {
  return enabled
      ? L"<audio src=\"ms-appx:///data/flutter_assets/native/resources/raw/completion_bell.wav\"/>"
      : L"<audio silent=\"true\"/>";
}

inline std::wstring CompletionBellPreviewXml() {
  return L"<toast><visual><binding template=\"ToastGeneric\">"
      L"<text>Completion bell preview</text>"
      L"<text>Sound follows your notification and quiet-mode settings.</text>"
      L"</binding></visual>" + CompletionAudioXml(true) + L"</toast>";
}
}  // namespace poma
#endif

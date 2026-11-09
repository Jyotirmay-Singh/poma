#include <flutter/dart_project.h>
#include <windows.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.ApplicationModel.Activation.h>

#include "flutter_window.h"
#include "desktop_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE, _In_opt_ HINSTANCE,
                      _In_ wchar_t*, _In_ int) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  int code = EXIT_SUCCESS;
  try {
    const auto arguments = GetCommandLineArguments();
    bool hidden = false, toast = false;
    for (const auto& argument : arguments) {
      if (argument == "--startup" || argument.rfind("-StartupTask:", 0) == 0) hidden = true;
      if (argument == "--toast-activation" || argument == "-Embedding") toast = true;
    }
    if (poma::IsPackaged()) {
      try {
        hidden = hidden || winrt::Windows::ApplicationModel::AppInstance::GetActivatedEventArgs().Kind() ==
            winrt::Windows::ApplicationModel::Activation::ActivationKind::StartupTask;
      } catch (...) {}
    }
#ifdef POMA_FOCUS_AUDIO_REVIEW
    poma::SingleInstance instance(poma::DataDirectory(), L"Poma.FocusAudioReview.Session2");
#else
    poma::SingleInstance instance(poma::DataDirectory());
#endif
    if (!instance.owner()) {
      const bool forwarded = toast ? poma::RelayToastActivation(instance) : instance.Forward(L"open");
      if (!forwarded && !toast) MessageBoxW(nullptr,
          L"Poma is already running but could not be reached. Try opening it from the system tray.", L"Poma", MB_OK | MB_ICONINFORMATION);
    } else {
      flutter::DartProject project(L"data");
      project.set_dart_entrypoint_arguments(arguments);
      FlutterWindow window(project, hidden || toast);
      if (!window.Create(L"Poma", Win32Window::Point(80, 60), Win32Window::Size(1080, 760))) {
        code = EXIT_FAILURE;
      } else {
        window.SetQuitOnClose(true);
        instance.Listen(window.GetHandle());
        MSG message{};
        while (GetMessageW(&message, nullptr, 0, 0) > 0) {
          if (!window.ProcessDialog(&message)) { TranslateMessage(&message); DispatchMessageW(&message); }
        }
        instance.StopListening();
      }
    }
  } catch (...) {
    MessageBoxW(nullptr, L"Poma could not open its local Windows storage or desktop services. Existing data has been kept.", L"Poma could not start", MB_OK | MB_ICONERROR);
    code = EXIT_FAILURE;
  }

  ::CoUninitialize();
  return code;
}

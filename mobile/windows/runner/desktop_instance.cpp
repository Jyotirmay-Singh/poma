#include "desktop_instance.h"
#include <shlobj.h>
#include <sddl.h>
#include <appmodel.h>
#include <notificationactivationcallback.h>
#include <winrt/Windows.Storage.h>
#include <wrl.h>
#include <vector>
#include <memory>

namespace poma {
using Microsoft::WRL::ComPtr;
bool IsPackaged() {
  UINT32 size = 0;
  return GetCurrentPackageFullName(&size, nullptr) != APPMODEL_ERROR_NO_PACKAGE;
}
std::wstring ToWide(const std::string& value) {
  if (value.empty()) return {};
  int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (!count) return {};
  std::wstring result(count, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), static_cast<int>(value.size()), result.data(), count);
  return result;
}
std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  int count = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  std::string result(count, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), count, nullptr, nullptr);
  return result;
}
std::wstring DataDirectory() {
  if (IsPackaged()) {
    return std::wstring(winrt::Windows::Storage::ApplicationData::Current().LocalFolder().Path());
  }
  PWSTR location = nullptr;
  winrt::check_hresult(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &location));
  std::wstring directory = std::wstring(location) + L"\\Poma\\Development";
#if defined(POMA_CALENDAR_REVIEW) || defined(POMA_FOCUS_AUDIO_REVIEW)
  wchar_t executable[32768]{};
  GetModuleFileNameW(nullptr, executable, 32768);
  directory = std::wstring(executable);
  directory = directory.substr(0, directory.find_last_of(L"\\/")) + L"\\fictional-review-profile";
#endif
  CoTaskMemFree(location);
  const int code = SHCreateDirectoryExW(nullptr, directory.c_str(), nullptr);
  if (code != ERROR_SUCCESS && code != ERROR_ALREADY_EXISTS && code != ERROR_FILE_EXISTS) {
    winrt::throw_hresult(HRESULT_FROM_WIN32(code));
  }
  return directory;
}
std::wstring UserSid() {
  HANDLE token = nullptr;
  winrt::check_bool(OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token));
  DWORD size = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  std::vector<BYTE> buffer(size);
  const bool read = GetTokenInformation(token, TokenUser, buffer.data(), size, &size) != FALSE;
  CloseHandle(token);
  winrt::check_bool(read);
  LPWSTR sid = nullptr;
  winrt::check_bool(ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid));
  std::wstring result(sid);
  LocalFree(sid);
  return result;
}

class UserSecurity {
 public:
  UserSecurity() {
    const auto text = L"D:P(A;;GA;;;" + UserSid() + L")";
    winrt::check_bool(ConvertStringSecurityDescriptorToSecurityDescriptorW(text.c_str(), SDDL_REVISION_1, &descriptor_, nullptr));
    attributes_ = {sizeof(SECURITY_ATTRIBUTES), descriptor_, FALSE};
  }
  ~UserSecurity() { LocalFree(descriptor_); }
  SECURITY_ATTRIBUTES* get() { return &attributes_; }
 private:
  PSECURITY_DESCRIPTOR descriptor_ = nullptr;
  SECURITY_ATTRIBUTES attributes_{};
};

SingleInstance::SingleInstance(const std::wstring& directory, const std::wstring& identity) {
  const auto sid = UserSid();
  UserSecurity security;
  const auto name = L"Local\\" + identity + L"." + sid;
  mutex_ = CreateMutexW(security.get(), FALSE, name.c_str());
  winrt::check_pointer(mutex_);
  const bool existing = GetLastError() == ERROR_ALREADY_EXISTS;
  pipe_ = L"\\\\.\\pipe\\" + identity + L"." + sid;
  if (existing) return;
  lock_ = CreateFileW((directory + L"\\owner.lock").c_str(), GENERIC_READ | GENERIC_WRITE,
      0, security.get(), OPEN_ALWAYS, FILE_ATTRIBUTE_HIDDEN | FILE_FLAG_DELETE_ON_CLOSE, nullptr);
  if (lock_ == INVALID_HANDLE_VALUE) {
    const auto error = GetLastError();
    if (error != ERROR_SHARING_VIOLATION) winrt::throw_hresult(HRESULT_FROM_WIN32(error));
    return;
  }
  owner_ = true;
}
SingleInstance::~SingleInstance() {
  StopListening();
  if (stop_) CloseHandle(stop_);
  if (lock_ != INVALID_HANDLE_VALUE) CloseHandle(lock_);
  if (mutex_) CloseHandle(mutex_);
}
void SingleInstance::StopListening() {
  if (stop_) SetEvent(stop_);
  if (listener_.joinable()) {
    listener_.join();
  }
}
bool SingleInstance::Forward(const std::wstring& value) const {
  const auto bytes = ToUtf8(value);
  if (bytes.empty() || bytes.size() > 2048) return false;
  for (int i = 0; i < 100; ++i) {
    const HANDLE pipe = CreateFileW(pipe_.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) {
      DWORD written = 0;
      const bool ok = WriteFile(pipe, bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr) != FALSE;
      CloseHandle(pipe);
      return ok && written == bytes.size();
    }
    Sleep(50);
  }
  return false;
}
void SingleInstance::Listen(HWND target) {
  if (!owner_ || listener_.joinable()) return;
  stop_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  winrt::check_pointer(stop_);
  listener_ = std::thread([this, target]() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    try {
      UserSecurity security;
      while (WaitForSingleObject(stop_, 0) != WAIT_OBJECT_0) {
        HANDLE pipe = CreateNamedPipeW(pipe_.c_str(), PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
            1, 0, 4096, 0, security.get());
        if (pipe == INVALID_HANDLE_VALUE) break;
        OVERLAPPED operation{};
        operation.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!operation.hEvent) { CloseHandle(pipe); break; }
        // Both connect and read wait on shutdown. There is no gap in which a
        // synchronous read can start after the destructor tried to cancel it.
        auto finish = [&](BOOL ready, DWORD error) {
          if (ready || error == ERROR_PIPE_CONNECTED) return true;
          if (error != ERROR_IO_PENDING) return false;
          HANDLE events[] = {stop_, operation.hEvent};
          const DWORD signaled = WaitForMultipleObjects(2, events, FALSE, INFINITE);
          if (signaled != WAIT_OBJECT_0 + 1) {
            CancelIoEx(pipe, &operation);
            DWORD ignored = 0;
            GetOverlappedResult(pipe, &operation, &ignored, TRUE);
            return false;
          }
          DWORD count = 0;
          return GetOverlappedResult(pipe, &operation, &count, FALSE) != FALSE;
        };
        const BOOL connected = ConnectNamedPipe(pipe, &operation);
        if (finish(connected, GetLastError()) && WaitForSingleObject(stop_, 0) != WAIT_OBJECT_0) {
          char bytes[2049]{};
          DWORD count = 0;
          ResetEvent(operation.hEvent);
          const BOOL read = ReadFile(pipe, bytes, 2048, &count, &operation);
          const DWORD error = GetLastError();
          if (finish(read, error) && GetOverlappedResult(pipe, &operation, &count, FALSE) && count > 0) {
            auto value = std::make_unique<std::wstring>(ToWide(std::string(bytes, count)));
            if (!value->empty() && PostMessageW(target, kIpcMessage, 0, reinterpret_cast<LPARAM>(value.get()))) value.release();
          }
        }
        CloseHandle(operation.hEvent);
        DisconnectNamedPipe(pipe);
        CloseHandle(pipe);
      }
    } catch (...) { /* Failure cannot start another timer owner. */ }
    CoUninitialize();
  });
}

class ToastActivator final : public Microsoft::WRL::RuntimeClass<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, INotificationActivationCallback> {
 public:
  explicit ToastActivator(std::function<void(std::wstring)> callback) : callback_(std::move(callback)) {}
  HRESULT STDMETHODCALLTYPE Activate(LPCWSTR, LPCWSTR arguments, const NOTIFICATION_USER_INPUT_DATA*, ULONG) override {
    try { callback_(arguments ? arguments : L""); return S_OK; } catch (...) { return E_FAIL; }
  }
 private:
  std::function<void(std::wstring)> callback_;
};
class ToastFactory final : public Microsoft::WRL::RuntimeClass<
    Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, IClassFactory> {
 public:
  explicit ToastFactory(std::function<void(std::wstring)> callback) : callback_(std::move(callback)) {}
  HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID iid, void** result) override {
    if (outer) return CLASS_E_NOAGGREGATION;
    auto object = Microsoft::WRL::Make<ToastActivator>(callback_);
    return object ? object.CopyTo(iid, result) : E_OUTOFMEMORY;
  }
  HRESULT STDMETHODCALLTYPE LockServer(BOOL) override { return S_OK; }
 private:
  std::function<void(std::wstring)> callback_;
};
ToastActivationRegistration::ToastActivationRegistration(std::function<void(std::wstring)> callback, const CLSID& class_id) {
  auto factory = Microsoft::WRL::Make<ToastFactory>(std::move(callback));
  winrt::check_hresult(CoRegisterClassObject(class_id, factory.Get(), CLSCTX_LOCAL_SERVER, REGCLS_MULTIPLEUSE, &cookie_));
}
ToastActivationRegistration::~ToastActivationRegistration() {
  if (cookie_) CoRevokeClassObject(cookie_);
}
bool RelayToastActivation(const SingleInstance& instance) {
  HANDLE arrived = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!arrived) return false;
  bool forwarded = false;
  {
    ToastActivationRegistration registration([&](std::wstring value) {
      forwarded = instance.Forward(L"action:" + value);
      SetEvent(arrived);
    });
    const auto until = GetTickCount64() + 8000;
    while (GetTickCount64() < until) {
      const DWORD result = MsgWaitForMultipleObjects(1, &arrived, FALSE, 100, QS_ALLINPUT);
      if (result == WAIT_OBJECT_0) break;
      MSG message{};
      while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message); DispatchMessageW(&message);
      }
    }
  }
  CloseHandle(arrived);
  return forwarded;
}
}  // namespace poma

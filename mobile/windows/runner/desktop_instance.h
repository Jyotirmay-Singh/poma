#ifndef POMA_DESKTOP_INSTANCE_H_
#define POMA_DESKTOP_INSTANCE_H_
#include "desktop_util.h"
#include <atomic>
#include <functional>
#include <thread>

namespace poma {
class SingleInstance {
 public:
  explicit SingleInstance(const std::wstring& directory, const std::wstring& identity = L"Poma.Desktop");
  ~SingleInstance();
  bool owner() const { return owner_; }
  bool Forward(const std::wstring& value) const;
  void Listen(HWND target);
  void StopListening();
 private:
  bool owner_ = false;
  HANDLE mutex_ = nullptr;
  HANDLE lock_ = INVALID_HANDLE_VALUE;
  std::wstring pipe_;
  HANDLE stop_ = nullptr;
  std::thread listener_;
};

// Process-local COM registration; package manifest supplies persistent identity.
class ToastActivationRegistration {
 public:
  explicit ToastActivationRegistration(std::function<void(std::wstring)> callback, const CLSID& class_id = kActivator);
  ~ToastActivationRegistration();
 private:
  DWORD cookie_ = 0;
};
bool RelayToastActivation(const SingleInstance& instance);
}  // namespace poma
#endif

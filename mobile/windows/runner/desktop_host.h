#ifndef POMA_DESKTOP_HOST_H_
#define POMA_DESKTOP_HOST_H_
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "desktop_instance.h"
#include "calendar_credentials.h"
#include <optional>
#include <vector>
#include <set>

namespace poma {
class DesktopHost {
 public:
  DesktopHost(HWND window, flutter::BinaryMessenger* messenger, bool initially_hidden);
  ~DesktopHost();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void FirstFrame();
  bool ProcessDialog(MSG* message);
 private:
  using Value = flutter::EncodableValue;
  using Map = flutter::EncodableMap;
  using Result = flutter::MethodResult<Value>;
  void Method(const flutter::MethodCall<Value>& call, std::unique_ptr<Result> result);
  void Event(const std::string& name, Map values = {});
  void ShowMain();
  void Visibility();
  bool AddTray();
  void RemoveTray();
  void TogglePopup(bool from_tray = true, POINT activation = {-1, -1}, bool preview = false);
  void HidePopup(bool restore_focus = false);
  void LayoutPopup();
  void PlacePopup();
  void EnsurePopupFocusVisible();
  void PaintPopup();
  void SyncCalendar();
  void CalendarAction(const std::string& action, int64_t generation, bool preview = false);
  const Map& CalendarDisplay() const;
  void UpdateTooltip();
  void RefreshSessionState();
  void SetSessionState(const std::string& state);
  void Menu();
  void TimerAction(const std::string& action, const Map& snapshot);
  void Arm(const Value* values);
  void SaveBounds();
  void InitializeAlerts();
  void Activate(const std::wstring& arguments);
  void ClearAlerts();
  void ClearCalendarReminders();
  void RunAsync(std::function<Value()> action, std::unique_ptr<Result> result, bool notify = false);
  static LRESULT CALLBACK PopupProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  HWND window_;
  HWND popup_ = nullptr;
  std::vector<HWND> labels_;
  std::vector<HWND> buttons_;
  struct CalendarRow {
    struct Action { HWND button = nullptr; std::string id, label; };
    HWND title = nullptr, body = nullptr;
    std::string id, day;
    std::vector<Action> actions;
    int64_t generation = 0;
  };
  std::vector<CalendarRow> calendar_rows_;
  Value calendar_sections_;
  Value calendar_dates_;
  std::vector<std::string> calendar_date_keys_;
  HWND day_combo_ = nullptr;
  HWND preview_label_ = nullptr;
  HWND popup_return_focus_ = nullptr;
  int next_calendar_id_ = 1000;
  int selected_day_ = 0;
  bool popup_from_tray_ = true;
  bool preview_mode_ = false;
  POINT activation_point_{-1, -1};
  ULONGLONG tray_dismissed_at_ = 0;
  std::string session_state_ = "unknown";
  bool session_registered_ = false;
  HFONT body_font_ = nullptr;
  HFONT timer_font_ = nullptr;
  HFONT control_font_ = nullptr;
  std::vector<HANDLE> font_resources_;
  HBRUSH background_ = nullptr;
  bool dark_ = false;
  bool high_contrast_ = false;
  bool initially_hidden_;
  bool tray_added_ = false;
  bool closing_ = false;
  bool configured_ = false;
  bool menu_open_ = false;
  bool close_to_tray_ = true;
  bool close_explained_ = false;
  bool alerts_initialized_ = false;
  bool alerts_enabled_ = true;
  int64_t reminder_generation_ = 0;
  std::set<std::string> reminder_tokens_, reminder_shown_;
  std::vector<Map> reminder_responses_;
  int64_t elapsed_deadline_ = 0;
  std::string deadline_run_;
  Map snapshot_;
  Map pressed_timer_snapshot_;
  HWND pressed_timer_control_ = nullptr;
  int scroll_offset_ = 0;
  int content_height_ = 0;
  double popup_scale_ = 0;
  std::wstring tooltip_;
  std::wstring directory_;
  std::unique_ptr<CalendarCredentialStore> calendar_credentials_;
  std::unique_ptr<ToastActivationRegistration> activation_;
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unique_ptr<flutter::MethodChannel<Value>> clock_;
  std::vector<std::thread> workers_;
};
}  // namespace poma
#endif

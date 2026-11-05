#ifndef POMA_CALENDAR_CREDENTIALS_H_
#define POMA_CALENDAR_CREDENTIALS_H_
#include <windows.h>
#include <dpapi.h>
#include <filesystem>
#include <functional>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace poma {
// No caller-controlled paths. All material is under this host's profile root.
class CalendarCredentialStore {
 public:
  using Bytes = std::vector<BYTE>;
  using Protection = std::function<Bytes(const Bytes&, const Bytes&)>;
  explicit CalendarCredentialStore(std::wstring profile,
      Protection protect = Protect, Protection unprotect = Unprotect)
      : profile_(std::move(profile)), folder_(profile_ / L"calendar"),
        protect_(std::move(protect)), unprotect_(std::move(unprotect)) {}
  struct ReadResult { int64_t revision; std::optional<std::string> credential; int64_t commit_revision = 0; };
  ReadResult Read() {
    std::lock_guard<std::mutex> guard(mutex_);
    CheckDirectory(profile_); CheckDirectory(folder_);
    if (Exists(folder_ / L"disconnected")) {
      Purge();
      return {revision_, std::nullopt, commit_revision_};
    }
    const auto retired = folder_ / L"retired.dpapi";
    const auto file = Exists(retired) ? retired : folder_ / L"connection.dpapi";
    if (!Exists(file)) return {revision_, std::nullopt, commit_revision_};
    auto plaintext = unprotect_(ReadBytes(file), Entropy());
    if (plaintext.empty() || plaintext.size() > kLimit) Fail();
    std::string value(plaintext.begin(), plaintext.end());
    SecureZeroMemory(plaintext.data(), plaintext.size());
    const std::string prefix = "POMA-CREDENTIAL-3\n";
    if (value.compare(0, prefix.size(), prefix) == 0) {
      const auto end = value.find('\n', prefix.size());
      if (end == std::string::npos) Fail();
      const auto number = value.substr(prefix.size(), end - prefix.size());
      if (number.empty() || number.find_first_not_of("0123456789") != std::string::npos) Fail();
      commit_revision_ = std::stoll(number);
      if (commit_revision_ <= 0) Fail();
      value = value.substr(end + 1);
    }
    return {revision_, std::move(value), commit_revision_};
  }
  int64_t Commit(int64_t expected_revision, int64_t expected_commit, const std::string& value, bool purge_data) {
    Read(); // Load the durable commit revision, including after process restart.
    std::lock_guard<std::mutex> guard(mutex_);
    if (expected_revision != revision_ || expected_commit != commit_revision_ || value.empty() || value.size() > kLimit / 2) Fail();
    const auto next = commit_revision_ + 1;
    WriteLocked(expected_revision, "POMA-CREDENTIAL-3\n" + std::to_string(next) + "\n" + value, purge_data);
    commit_revision_ = next;
    return next;
  }
  void Write(int64_t expected_revision, const std::string& value, bool purge_data) {
    std::lock_guard<std::mutex> guard(mutex_);
    WriteLocked(expected_revision, value, purge_data);
  }
 private:
  void WriteLocked(int64_t expected_revision, const std::string& value, bool purge_data) {
    if (expected_revision != revision_ || value.empty() || value.size() > kLimit) Fail();
    EnsureFolder();
    Bytes plaintext(value.begin(), value.end());
    Bytes encrypted;
    try { encrypted = protect_(plaintext, Entropy()); }
    catch (...) { SecureZeroMemory(plaintext.data(), plaintext.size()); throw; }
    SecureZeroMemory(plaintext.data(), plaintext.size());
    if (encrypted.empty() || encrypted.size() > kLimit) Fail();
    if (purge_data) {
      InvalidateCacheLocked();
      // Account replacement must reject worker saves before Dart publishes the
      // new identity, including a crash between credential commit and notify.
      ++focus_scope_; focus_account_.clear();
      PurgeAccounts();
    }
    AtomicWrite(folder_ / L"connection.dpapi", encrypted);
    RemoveFile(folder_ / L"retired.dpapi");
    RemoveFile(folder_ / L"retired.dpapi.tmp");
    RemoveFile(folder_ / L"disconnected");
  }
 public:
  struct FocusRead { int64_t scope, revision; bool stopped; std::optional<std::string> document; bool disabled; };
  FocusRead OpenFocus(int64_t expected_revision, const std::string& account) {
    std::lock_guard<std::mutex> guard(mutex_);
    if(expected_revision != revision_ || Exists(folder_ / L"disconnected")) Fail();
    ValidateAccount(account); ++focus_scope_; focus_account_ = account; focus_revision_ = 0;
    const auto file = FocusPath(expected_revision, focus_scope_, account) / L"focus-blocks.json";
    std::optional<std::string> document;
    if(Exists(file)) {const auto bytes=ReadBytes(file,kCacheLimit);document=std::string(bytes.begin(),bytes.end());}
    return {focus_scope_, focus_revision_, Exists(folder_ / L"focus-stopped"), document, Exists(folder_ / L"focus-disabled")};
  }
  void DisableFocus(bool disabled) {
    std::lock_guard<std::mutex> guard(mutex_);EnsureFolder();
    if(disabled){++focus_scope_;focus_account_.clear();AtomicWrite(folder_ / L"focus-disabled",Bytes{1});}
    else{RemoveFile(folder_ / L"focus-disabled");}
  }
  int64_t SaveFocus(int64_t expected_revision,int64_t scope,int64_t expected_commit,const std::string& account,const std::string& value) {
    std::lock_guard<std::mutex> guard(mutex_);
    if(expected_commit != focus_revision_ || value.empty() || value.size()>kCacheLimit) Fail();
    const auto path=FocusPath(expected_revision,scope,account);
    std::filesystem::create_directories(path);CheckDirectory(path);
    AtomicWrite(path / L"focus-blocks.json",Bytes(value.begin(),value.end()));
    return ++focus_revision_;
  }
  void StopFocus(bool purge=false) {
    std::lock_guard<std::mutex> guard(mutex_);
    const auto account=focus_account_; ++focus_scope_;focus_account_.clear();
    EnsureFolder();AtomicWrite(folder_ / L"focus-stopped",Bytes{1});
    if(purge&&!account.empty()) {
      const auto path=folder_ / L"accounts" / std::wstring(account.begin(),account.end());CheckDirectory(path);
      RemoveFile(path / L"focus-blocks.json");RemoveFile(path / L"focus-blocks.json.tmp");
    }
  }
  int64_t Retire(int64_t expected_revision, const std::string& identity) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (expected_revision != revision_ || identity.empty() || identity.size() > kLimit) Fail();
    ++revision_; InvalidateCacheLocked(); ++focus_scope_;focus_account_.clear();
    EnsureFolder();
    Bytes plaintext(identity.begin(), identity.end()), encrypted;
    try { encrypted = protect_(plaintext, Entropy()); }
    catch (...) { SecureZeroMemory(plaintext.data(), plaintext.size()); throw; }
    SecureZeroMemory(plaintext.data(), plaintext.size());
    if (encrypted.empty() || encrypted.size() > kLimit) Fail();
    // Restart prefers this protected no-token identity even if deletion fails.
    AtomicWrite(folder_ / L"retired.dpapi", encrypted);
    RemoveFile(folder_ / L"connection.dpapi");
    RemoveFile(folder_ / L"connection.dpapi.tmp");
    return revision_;
  }
  int64_t BindAccount(int64_t expected_revision, const std::string& account) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (expected_revision != revision_ || Exists(folder_ / L"disconnected")) Fail();
    ValidateAccount(account); InvalidateCacheLocked(); account_ = account;
    return cache_scope_;
  }
  void InvalidateCache() {
    std::lock_guard<std::mutex> guard(mutex_); InvalidateCacheLocked();
  }
  std::optional<std::string> ReadAccount(int64_t revision, int64_t scope, const std::string& account, bool reminders = false) {
    std::lock_guard<std::mutex> guard(mutex_);
    const auto path = AccountPath(revision, scope, account);
    const auto file = path / (reminders ? L"reminders.json" : L"state.json");
    if (!Exists(file)) return std::nullopt;
    const auto bytes = ReadBytes(file, kCacheLimit);
    return std::string(bytes.begin(), bytes.end());
  }
  void WriteAccount(int64_t revision, int64_t scope, const std::string& account, const std::string& value, bool reminders = false) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (value.empty() || value.size() > kCacheLimit) Fail();
    const auto path = AccountPath(revision, scope, account);
    std::filesystem::create_directories(path); CheckDirectory(path);
    AtomicWrite(path / (reminders ? L"reminders.json" : L"state.json"), Bytes(value.begin(), value.end()));
  }
  int64_t Clear() {
    std::lock_guard<std::mutex> guard(mutex_);
    ++revision_; InvalidateCacheLocked(); ++focus_scope_;focus_account_.clear(); // Invalidate even when disk cleanup fails.
    EnsureFolder();
    AtomicWrite(folder_ / L"disconnected", Bytes{1});
    Purge();
    return revision_;
  }
 private:
  static constexpr size_t kLimit = 64 * 1024;
  static constexpr size_t kCacheLimit = 16 * 1024 * 1024;
  void InvalidateCacheLocked() { ++cache_scope_; account_.clear(); }
  std::filesystem::path FocusPath(int64_t revision,int64_t scope,const std::string& account) {
    ValidateAccount(account);
    if(revision!=revision_||scope!=focus_scope_||account!=focus_account_||Exists(folder_ / L"disconnected"))Fail();
    CheckDirectory(profile_);CheckDirectory(folder_);const auto parent=folder_ / L"accounts";
    const auto path=parent / std::wstring(account.begin(),account.end());CheckDirectory(parent);CheckDirectory(path);return path;
  }
  static void ValidateAccount(const std::string& value) {
    if (value.size() != 64 || value.find_first_not_of("0123456789abcdef") != std::string::npos) Fail();
  }
  std::filesystem::path AccountPath(int64_t revision, int64_t scope, const std::string& account) {
    ValidateAccount(account);
    if (revision != revision_ || scope != cache_scope_ || account != account_ || Exists(folder_ / L"disconnected")) Fail();
    CheckDirectory(profile_); CheckDirectory(folder_);
    const auto parent = folder_ / L"accounts";
    const auto path = parent / std::wstring(account.begin(), account.end());
    CheckDirectory(parent); CheckDirectory(path);
    return path;
  }
  [[noreturn]] static void Fail() { throw std::runtime_error("Protected calendar storage unavailable."); }
  static bool Exists(const std::filesystem::path& path) {
    const auto attrs = GetFileAttributesW(path.c_str());
    if (attrs != INVALID_FILE_ATTRIBUTES) return true;
    const auto error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) return false;
    Fail();
  }
  static void CheckPath(const std::filesystem::path& path) {
    if (!Exists(path)) return;
    if (GetFileAttributesW(path.c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) Fail();
  }
  static void CheckDirectory(const std::filesystem::path& path) {
    CheckPath(path);
    if (Exists(path) && !(GetFileAttributesW(path.c_str()) & FILE_ATTRIBUTE_DIRECTORY)) Fail();
  }
  void EnsureFolder() {
    CheckDirectory(profile_); CheckDirectory(folder_);
    std::filesystem::create_directories(folder_);
    CheckPath(folder_);
  }
  Bytes Entropy() const {
    const std::wstring context = L"Poma.GoogleCalendar.v1|" +
      std::filesystem::absolute(profile_).lexically_normal().wstring();
    const auto* begin = reinterpret_cast<const BYTE*>(context.data());
    return Bytes(begin, begin + context.size() * sizeof(wchar_t));
  }
  static Bytes Crypt(const Bytes& bytes, const Bytes& entropy, bool decrypt) {
    DATA_BLOB input{static_cast<DWORD>(bytes.size()), const_cast<BYTE*>(bytes.data())};
    DATA_BLOB extra{static_cast<DWORD>(entropy.size()), const_cast<BYTE*>(entropy.data())};
    DATA_BLOB output{};
    const BOOL ok = decrypt
      ? CryptUnprotectData(&input, nullptr, &extra, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)
      : CryptProtectData(&input, L"Poma Google Calendar", &extra, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output);
    if (!ok) Fail();
    Bytes result(output.pbData, output.pbData + output.cbData);
    SecureZeroMemory(output.pbData, output.cbData); LocalFree(output.pbData);
    return result;
  }
  static Bytes Protect(const Bytes& value, const Bytes& entropy) { return Crypt(value, entropy, false); }
  static Bytes Unprotect(const Bytes& value, const Bytes& entropy) { return Crypt(value, entropy, true); }
  static Bytes ReadBytes(const std::filesystem::path& file, size_t limit = kLimit) {
    CheckPath(file);
    const auto handle = CreateFileW(file.c_str(), GENERIC_READ, FILE_SHARE_READ,
      nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (handle == INVALID_HANDLE_VALUE) Fail();
    LARGE_INTEGER size{};
    if (!GetFileSizeEx(handle, &size) || size.QuadPart <= 0 || size.QuadPart > static_cast<LONGLONG>(limit)) {
      CloseHandle(handle); Fail();
    }
    Bytes bytes(static_cast<size_t>(size.QuadPart)); DWORD read = 0;
    const bool ok = ReadFile(handle, bytes.data(), static_cast<DWORD>(bytes.size()), &read, nullptr) != FALSE;
    CloseHandle(handle);
    if (!ok || read != bytes.size()) Fail();
    return bytes;
  }
  static void RemoveFile(const std::filesystem::path& file) {
    CheckPath(file);
    if (!DeleteFileW(file.c_str())) {
      const auto error = GetLastError();
      if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND) Fail();
    }
  }
  static void AtomicWrite(const std::filesystem::path& file, const Bytes& bytes) {
    auto temporary = file; temporary += L".tmp";
    CheckPath(file); CheckPath(temporary);
    const auto handle = CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, nullptr,
      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (handle == INVALID_HANDLE_VALUE) Fail();
    DWORD written = 0;
    const bool ok = WriteFile(handle, bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr) &&
      written == bytes.size() && FlushFileBuffers(handle);
    CloseHandle(handle);
    if (!ok || !MoveFileExW(temporary.c_str(), file.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
      DeleteFileW(temporary.c_str()); Fail();
    }
  }
  void PurgeAccounts() {
    const auto path = folder_ / L"accounts";
    CheckDirectory(path);
    if (!Exists(path)) return;
    // Refuse junctions rather than traversing an unexpected external target.
    for (const auto& entry : std::filesystem::recursive_directory_iterator(path)) CheckPath(entry.path());
    std::filesystem::remove_all(path);
  }
  void Purge() {
    RemoveFile(folder_ / L"connection.dpapi");
    RemoveFile(folder_ / L"connection.dpapi.tmp");
    RemoveFile(folder_ / L"retired.dpapi");
    RemoveFile(folder_ / L"retired.dpapi.tmp");
    PurgeAccounts();
  }
  std::filesystem::path profile_, folder_;
  Protection protect_, unprotect_;
  std::mutex mutex_;
  int64_t revision_ = 0;
  int64_t commit_revision_ = 0, focus_scope_ = 0, focus_revision_ = 0;
  std::string focus_account_;
  int64_t cache_scope_ = 0;
  std::string account_;
};
}  // namespace poma
#endif

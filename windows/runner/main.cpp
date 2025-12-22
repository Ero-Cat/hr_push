#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>

#include <cstdarg>
#include <cstdio>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kWindowTitle[] = L"hr_push";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"hr_osc_single_instance_mutex";
constexpr const wchar_t kLogSubdir[] = L"hr_osc\\logs";
constexpr const wchar_t kLogFileName[] = L"hr_push.log";
constexpr ULONGLONG kMaxLogBytes = 2ULL * 1024 * 1024;

struct FileLogger {
  std::wstring path;
  FILE* file = nullptr;
};

struct LogGuard {
  std::wstring path;
  HANDLE stop_event = nullptr;
  HANDLE thread = nullptr;
};

std::wstring JoinPath(const std::wstring& base, const std::wstring& leaf) {
  if (base.empty()) {
    return leaf;
  }
  if (base.back() == L'\\') {
    return base + leaf;
  }
  return base + L'\\' + leaf;
}

std::wstring GetLogFilePath() {
  PWSTR app_data_path = nullptr;
  HRESULT result = ::SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr,
                                          &app_data_path);
  if (FAILED(result) || !app_data_path) {
    return L"";
  }

  std::wstring base(app_data_path);
  ::CoTaskMemFree(app_data_path);

  std::wstring log_dir = JoinPath(base, kLogSubdir);
  ::SHCreateDirectoryExW(nullptr, log_dir.c_str(), nullptr);
  return JoinPath(log_dir, kLogFileName);
}

void RotateLogIfNeeded(const std::wstring& log_path) {
  WIN32_FILE_ATTRIBUTE_DATA attrs{};
  if (!::GetFileAttributesExW(log_path.c_str(), GetFileExInfoStandard,
                              &attrs)) {
    return;
  }
  ULONGLONG size =
      (static_cast<ULONGLONG>(attrs.nFileSizeHigh) << 32) |
      attrs.nFileSizeLow;
  if (size <= kMaxLogBytes) {
    return;
  }

  std::wstring backup = log_path + L".1";
  ::DeleteFileW(backup.c_str());
  ::MoveFileW(log_path.c_str(), backup.c_str());
}

void LogLine(FileLogger* logger, const wchar_t* format, ...) {
  if (!logger || !logger->file) {
    return;
  }

  va_list args;
  va_start(args, format);
  vfwprintf(logger->file, format, args);
  va_end(args);
  fputwc(L'\n', logger->file);
  fflush(logger->file);
}

bool InitFileLogger(FileLogger* logger) {
  if (!logger) {
    return false;
  }

  logger->path = GetLogFilePath();
  if (logger->path.empty()) {
    return false;
  }

  RotateLogIfNeeded(logger->path);

  logger->file = _wfopen(logger->path.c_str(), L"a+, ccs=UTF-8");
  if (!logger->file) {
    return false;
  }

  setvbuf(logger->file, nullptr, _IOLBF, 1024);
  return true;
}

bool RedirectStdToLog(const std::wstring& log_path) {
  if (log_path.empty()) {
    return false;
  }

  FILE* stdout_file = _wfreopen(log_path.c_str(), L"a+, ccs=UTF-8", stdout);
  FILE* stderr_file = _wfreopen(log_path.c_str(), L"a+, ccs=UTF-8", stderr);
  if (!stdout_file || !stderr_file) {
    return false;
  }

  setvbuf(stdout, nullptr, _IOLBF, 1024);
  setvbuf(stderr, nullptr, _IOLBF, 1024);
  return true;
}

DWORD WINAPI LogGuardThread(LPVOID param) {
  auto guard = static_cast<LogGuard*>(param);
  if (!guard) {
    return 0;
  }

  while (true) {
    DWORD wait = ::WaitForSingleObject(guard->stop_event, 30000);
    if (wait != WAIT_TIMEOUT) {
      break;
    }

    WIN32_FILE_ATTRIBUTE_DATA attrs{};
    if (!::GetFileAttributesExW(guard->path.c_str(), GetFileExInfoStandard,
                                &attrs)) {
      continue;
    }
    ULONGLONG size =
        (static_cast<ULONGLONG>(attrs.nFileSizeHigh) << 32) |
        attrs.nFileSizeLow;
    if (size <= kMaxLogBytes) {
      continue;
    }

    HANDLE file = ::CreateFileW(
        guard->path.c_str(), GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
      continue;
    }
    ::SetFilePointer(file, 0, nullptr, FILE_BEGIN);
    ::SetEndOfFile(file);
    ::CloseHandle(file);
  }

  return 0;
}

void StartLogGuard(LogGuard* guard, const std::wstring& log_path) {
  if (!guard || log_path.empty()) {
    return;
  }

  guard->path = log_path;
  guard->stop_event = ::CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (!guard->stop_event) {
    return;
  }

  guard->thread =
      ::CreateThread(nullptr, 0, LogGuardThread, guard, 0, nullptr);
  if (!guard->thread) {
    ::CloseHandle(guard->stop_event);
    guard->stop_event = nullptr;
  }
}

void StopLogGuard(LogGuard* guard) {
  if (!guard) {
    return;
  }

  if (guard->stop_event) {
    ::SetEvent(guard->stop_event);
  }
  if (guard->thread) {
    ::WaitForSingleObject(guard->thread, 2000);
    ::CloseHandle(guard->thread);
    guard->thread = nullptr;
  }
  if (guard->stop_event) {
    ::CloseHandle(guard->stop_event);
    guard->stop_event = nullptr;
  }
}

void CleanupLogging(FileLogger* logger, LogGuard* guard) {
  StopLogGuard(guard);
  if (logger && logger->file) {
    fclose(logger->file);
    logger->file = nullptr;
  }
}

bool ActivateExistingWindow() {
  HWND existing =
      ::FindWindow(kWindowClassName, kWindowTitle);
  if (!existing) {
    return false;
  }

  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  } else {
    ::ShowWindow(existing, SW_SHOW);
  }
  ::SetForegroundWindow(existing);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  FileLogger logger;
  LogGuard log_guard;
  const bool logging_ready = InitFileLogger(&logger);
  if (logging_ready) {
    LogLine(&logger, L"[startup] log=%ls", logger.path.c_str());
    wchar_t module_path[MAX_PATH] = {};
    ::GetModuleFileNameW(nullptr, module_path, MAX_PATH);
    LogLine(&logger, L"[startup] exe=%ls", module_path);
    wchar_t current_dir[MAX_PATH] = {};
    ::GetCurrentDirectoryW(MAX_PATH, current_dir);
    LogLine(&logger, L"[startup] cwd=%ls", current_dir);
    LogLine(&logger, L"[startup] cmdline=%ls",
            command_line ? command_line : L"");
    StartLogGuard(&log_guard, logger.path);
  }

  HANDLE instance_mutex =
      ::CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);
  if (!instance_mutex) {
    LogLine(&logger, L"[error] CreateMutex failed, code=%lu",
            ::GetLastError());
    CleanupLogging(&logger, &log_guard);
    return EXIT_FAILURE;
  }

  const DWORD mutex_error = ::GetLastError();
  if (mutex_error == ERROR_ALREADY_EXISTS ||
      mutex_error == ERROR_ACCESS_DENIED) {
    LogLine(&logger, L"[single-instance] already running");
    ActivateExistingWindow();
    ::CloseHandle(instance_mutex);
    CleanupLogging(&logger, &log_guard);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
  if (logging_ready && ::GetConsoleWindow() == nullptr) {
    RedirectStdToLog(logger.path);
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    LogLine(&logger, L"[error] window.Create failed");
    ::CloseHandle(instance_mutex);
    CleanupLogging(&logger, &log_guard);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(instance_mutex);
  CleanupLogging(&logger, &log_guard);
  return EXIT_SUCCESS;
}

#include "flutter_window.h"

#include <cstdarg>
#include <cstdio>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

void LogLine(const wchar_t* format, ...) {
  SYSTEMTIME st{};
  ::GetLocalTime(&st);
  const DWORD pid = ::GetCurrentProcessId();
  const DWORD tid = ::GetCurrentThreadId();
  va_list args;
  va_start(args, format);
  fwprintf(stderr, L"[%04d-%02d-%02d %02d:%02d:%02d.%03d][pid=%lu][tid=%lu] ",
           st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
           st.wMilliseconds, pid, tid);
  vfwprintf(stderr, format, args);
  va_end(args);
  fputwc(L'\n', stderr);
  fflush(stderr);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  LogLine(L"[window] OnCreate begin");
  if (!Win32Window::OnCreate()) {
    LogLine(L"[error] Win32Window::OnCreate failed");
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    LogLine(L"[error] FlutterViewController init failed");
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  LogLine(L"[window] OnCreate done");
  return true;
}

void FlutterWindow::OnDestroy() {
  LogLine(L"[window] OnDestroy begin");
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
  LogLine(L"[window] OnDestroy done");
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      LogLine(L"[window] WM_CLOSE");
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

import 'dart:js_interop';

@JS('adaExamGuardStart')
external void _start(JSFunction callback);

@JS('adaExamGuardStop')
external void _stop();

@JS('adaExamFullscreen')
external void _fullscreen();

@JS('adaExamExitFullscreen')
external void _exitFullscreen();

/// Penjaga ujian untuk web / PWA (laptop, Chromebook, iPhone, Android).
class ExamGuard {
  ExamGuard._();

  static bool get isWeb => true;

  /// [onEvent] menerima jenis kejadian: tab_hidden, window_blur, fullscreen_exit,
  /// copy, paste, contextmenu, print_screen, devtools, app_background.
  static void start(void Function(String type) onEvent) {
    try {
      _start(((JSString type) => onEvent(type.toDart)).toJS);
    } catch (_) {
      // exam_guard.js tidak termuat: server tetap mencatat dari sisi lain.
    }
  }

  static void stop() {
    try {
      _stop();
    } catch (_) {}
  }

  /// Harus dipanggil langsung dari tap tombol (syarat browser).
  static void requestFullscreen() {
    try {
      _fullscreen();
    } catch (_) {}
  }

  static void exitFullscreen() {
    try {
      _exitFullscreen();
    } catch (_) {}
  }
}

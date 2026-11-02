/// Implementasi kosong untuk platform non-web.
class ExamGuard {
  ExamGuard._();

  static bool get isWeb => false;

  static void start(void Function(String type) onEvent) {}

  static void stop() {}

  static void requestFullscreen() {}

  static void exitFullscreen() {}
}

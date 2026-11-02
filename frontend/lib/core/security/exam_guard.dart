// Penjaga ujian lintas-platform. Di web / PWA memakai exam_guard.js;
// di Android / iOS / desktop tidak melakukan apa-apa (pelanggaran di sana
// dideteksi lewat lifecycle aplikasi di TimedQuizPage).
export 'exam_guard_stub.dart' if (dart.library.js_interop) 'exam_guard_web.dart';

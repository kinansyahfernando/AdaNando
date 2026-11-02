/* AdaNando · penjaga ujian untuk versi web / PWA (laptop, Chromebook, iPhone, Android).
 * Dipanggil dari Dart (lib/core/security/exam_guard_web.dart).
 * Catatan jujur: browser TIDAK bisa memblokir screenshot sepenuhnya. Penjaga ini
 * mendeteksi pindah tab/jendela, keluar layar penuh, copy-paste, dan pintasan umum,
 * menutup layar saat jendela kehilangan fokus, lalu melapor ke server.
 * Keputusan akhir (peringatan / ujian diakhiri) ada di server, bukan di sini. */
(function () {
  'use strict';
  var cb = null;
  var active = false;
  var wantFullscreen = false;

  function emit(type) {
    if (!active || !cb) return;
    try { cb(type); } catch (e) { /* abaikan */ }
  }

  function cover(on) {
    var b = document.body;
    if (!b) return;
    b.style.transition = 'filter .05s';
    b.style.filter = on ? 'blur(18px) brightness(.4)' : '';
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { cover(true); emit('tab_hidden'); } else { cover(false); }
  });
  window.addEventListener('blur', function () {
    if (!active) return;
    cover(true);
    emit('window_blur');
  });
  window.addEventListener('focus', function () { cover(false); });
  window.addEventListener('pagehide', function () { emit('app_background'); });

  document.addEventListener('fullscreenchange', function () {
    if (wantFullscreen && !document.fullscreenElement) emit('fullscreen_exit');
  });
  document.addEventListener('webkitfullscreenchange', function () {
    if (wantFullscreen && !document.webkitFullscreenElement) emit('fullscreen_exit');
  });

  ['copy', 'cut', 'paste'].forEach(function (name) {
    document.addEventListener(name, function (e) {
      if (!active) return;
      e.preventDefault();
      emit(name === 'paste' ? 'paste' : 'copy');
    }, true);
  });
  document.addEventListener('contextmenu', function (e) {
    if (!active) return;
    e.preventDefault();
    emit('contextmenu');
  }, true);
  ['selectstart', 'dragstart'].forEach(function (name) {
    document.addEventListener(name, function (e) { if (active) e.preventDefault(); }, true);
  });

  document.addEventListener('keyup', function (e) {
    if (active && e.key === 'PrintScreen') {
      try { navigator.clipboard.writeText(''); } catch (x) { /* abaikan */ }
      emit('print_screen');
    }
  }, true);

  document.addEventListener('keydown', function (e) {
    if (!active) return;
    var k = (e.key || '').toLowerCase();
    var ctrl = e.ctrlKey || e.metaKey;
    if (e.key === 'F12' || (ctrl && e.shiftKey && (k === 'i' || k === 'j' || k === 'c')) || (ctrl && k === 'u')) {
      e.preventDefault(); emit('devtools'); return;
    }
    if (ctrl && (k === 'p' || k === 's')) { e.preventDefault(); emit('print_screen'); return; }
    if (ctrl && (k === 'c' || k === 'x' || k === 'v' || k === 'a')) { e.preventDefault(); emit('copy'); }
  }, true);

  window.addEventListener('beforeunload', function (e) {
    if (!active) return;
    e.preventDefault();
    e.returnValue = '';
  });

  window.adaExamGuardStart = function (fn) { cb = fn; active = true; };
  window.adaExamGuardStop = function () {
    active = false; cb = null; cover(false);
  };
  window.adaExamFullscreen = function () {
    var el = document.documentElement;
    var req = el.requestFullscreen || el.webkitRequestFullscreen;
    if (!req) return; // iPhone Safari tidak mendukung: dilewati
    try {
      var p = req.call(el);
      wantFullscreen = true;
      if (p && p.catch) p.catch(function () { wantFullscreen = false; });
    } catch (e) { wantFullscreen = false; }
  };
  window.adaExamExitFullscreen = function () {
    wantFullscreen = false;
    try {
      if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen();
      else if (document.webkitFullscreenElement && document.webkitExitFullscreen) document.webkitExitFullscreen();
    } catch (e) { /* abaikan */ }
  };
})();

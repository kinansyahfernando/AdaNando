import 'package:flutter/material.dart';

/// Kunci navigator global. Dipakai agar aplikasi bisa kembali ke halaman utama
/// dari mana saja (mis. saat sesi login dicabut server).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

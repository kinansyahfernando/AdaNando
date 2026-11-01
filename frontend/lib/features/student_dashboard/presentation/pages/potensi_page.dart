import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/bank_lookup.dart';
import '../../data/models/result_entry.dart';
import '../../data/models/subtest.dart';
import '../../data/results_repository.dart';
import '../../data/room_repository.dart' show ApiException;
import '../widgets/section_card.dart';

/// Halaman Potensi: grafik naik/turun tiap subtes dari latihan dan try out.
class PotensiPage extends StatefulWidget {
  const PotensiPage({super.key, required this.active});

  /// True saat tab ini sedang dibuka. Data dimuat ulang tiap tab dibuka.
  final bool active;

  @override
  State<PotensiPage> createState() => _PotensiPageState();
}

class _PotensiPageState extends State<PotensiPage> {
  final ResultsRepository _repo = ResultsRepository();

  List<ResultEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  String _source = 'all'; // all | latihan | tryout

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PotensiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await _repo.history();
      if (!mounted) return;
      setState(() {
        _entries = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : (e is DioException
                  ? 'Tidak bisa terhubung ke server.'
                  : 'Gagal memuat data.');
        _loading = false;
      });
    }
  }

  List<_Trend> _buildTrends() {
    final filtered = _entries.where((e) {
      if (_source == 'latihan') return !e.isTryout;
      if (_source == 'tryout') return e.isTryout;
      return true;
    }).toList();

    final trends = <_Trend>[];
    for (final subtest in BankLookup.allSubtests) {
      final list = filtered.where((e) => e.subtestId == subtest.id).toList();
      trends.add(_Trend(subtest: subtest, entries: list));
    }
    return trends;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);

    Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      content = _MessageBox(
        icon: Icons.wifi_off_rounded,
        text: _error!,
        actionLabel: 'Coba Lagi',
        onAction: _load,
      );
    } else if (_entries.isEmpty) {
      content = const _MessageBox(
        icon: Icons.insights_outlined,
        text:
            'Belum ada data. Kerjakan latihan subtes atau try out mandiri, lalu perkembanganmu muncul di sini.',
      );
    } else {
      final trends = _buildTrends();
      content = _TrendContent(
        trends: trends,
        onOpen: (t) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _DetailPage(trend: t)),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
          child: ContentWidth(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Potensi',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pantau naik-turunnya nilai tiap subtes dari latihan dan try out mandiri.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in const [
                      ('all', 'Semua'),
                      ('latihan', 'Latihan Subtes'),
                      ('tryout', 'Try Out Mandiri'),
                    ])
                      ChoiceChip(
                        label: Text(f.$2),
                        selected: _source == f.$1,
                        onSelected: (_) => setState(() => _source = f.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Data tren ─────────────────────────

class _Trend {
  _Trend({required this.subtest, required this.entries});

  final Subtest subtest;

  /// Urut dari yang terlama ke terbaru.
  final List<ResultEntry> entries;

  bool get hasData => entries.isNotEmpty;
  double? get latest => entries.isEmpty ? null : entries.last.accuracy;

  double get average =>
      entries.isEmpty
      ? 0
      : entries.map((e) => e.accuracy).reduce((a, b) => a + b) /
            entries.length;

  double get best =>
      entries.isEmpty ? 0 : entries.map((e) => e.accuracy).reduce(_max);

  /// Rata-rata 3 percobaan terakhir (untuk menilai terkuat / terlemah).
  double get recentAverage {
    if (entries.isEmpty) return 0;
    final recent = entries.length > 3
        ? entries.sublist(entries.length - 3)
        : entries;
    return recent.map((e) => e.accuracy).reduce((a, b) => a + b) /
        recent.length;
  }

  /// Selisih akurasi percobaan terakhir vs sebelumnya (poin persen).
  int? get delta {
    if (entries.length < 2) return null;
    final diff =
        entries[entries.length - 1].accuracy -
        entries[entries.length - 2].accuracy;
    return (diff * 100).round();
  }

  static double _max(double a, double b) => a > b ? a : b;
}

class _TrendLabel {
  const _TrendLabel(this.text, this.color, this.icon);

  final String text;
  final Color color;
  final IconData icon;

  factory _TrendLabel.of(int? delta) {
    if (delta == null) {
      return const _TrendLabel(
        'Baru 1 data',
        AppColors.muted,
        Icons.fiber_new_rounded,
      );
    }
    if (delta >= 1) {
      return _TrendLabel(
        'Naik +$delta%',
        AppColors.success,
        Icons.trending_up_rounded,
      );
    }
    if (delta <= -1) {
      return _TrendLabel(
        'Turun $delta%',
        AppColors.danger,
        Icons.trending_down_rounded,
      );
    }
    return const _TrendLabel(
      'Stabil',
      AppColors.muted,
      Icons.trending_flat_rounded,
    );
  }
}

String _pct(double v) => '${(v * 100).round()}%';

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

// ───────────────────────── Isi halaman ─────────────────────────

class _TrendContent extends StatelessWidget {
  const _TrendContent({required this.trends, required this.onOpen});

  final List<_Trend> trends;
  final ValueChanged<_Trend> onOpen;

  @override
  Widget build(BuildContext context) {
    final withData = trends.where((t) => t.hasData).toList();

    final _Trend? strongest;
    final _Trend? weakest;
    if (withData.length >= 2) {
      final sorted = [...withData]
        ..sort((a, b) => b.recentAverage.compareTo(a.recentAverage));
      strongest = sorted.first;
      weakest = sorted.last;
    } else {
      strongest = null;
      weakest = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
        const gap = 12.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (strongest != null && weakest != null) ...[
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width >= 560 ? (width - gap) / 2 : width,
                    child: _HighlightCard(
                      icon: Icons.emoji_events_outlined,
                      color: AppColors.success,
                      title: 'Paling kuat',
                      trend: strongest,
                    ),
                  ),
                  SizedBox(
                    width: width >= 560 ? (width - gap) / 2 : width,
                    child: _HighlightCard(
                      icon: Icons.flag_outlined,
                      color: AppColors.penalaran,
                      title: 'Perlu ditingkatkan',
                      trend: weakest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in trends)
                  SizedBox(
                    width: itemWidth,
                    child: _TrendCard(trend: t, onTap: () => onOpen(t)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.trend,
  });

  final IconData icon;
  final Color color;
  final String title;
  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  trend.subtest.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _pct(trend.recentAverage),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend, required this.onTap});

  final _Trend trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtest = trend.subtest;
    final label = _TrendLabel.of(trend.delta);
    final recent = trend.entries.length > 10
        ? trend.entries.sublist(trend.entries.length - 10)
        : trend.entries;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: trend.hasData ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: subtest.color.withAlpha(28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subtest.code,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: subtest.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subtest.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!trend.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Belum ada data untuk subtes ini.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _pct(trend.latest!),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: subtest.color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        'terakhir',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: label.color.withAlpha(24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(label.icon, size: 16, color: label.color),
                          const SizedBox(width: 4),
                          Text(
                            label.text,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: label.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      values: recent.map((e) => e.accuracy).toList(),
                      color: subtest.color,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${trend.entries.length} percobaan · rata-rata ${_pct(trend.average)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Detail subtes ─────────────────────────

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.trend});

  final _Trend trend;

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final subtest = trend.subtest;
    final label = _TrendLabel.of(trend.delta);
    final chartEntries = trend.entries.length > 30
        ? trend.entries.sublist(trend.entries.length - 30)
        : trend.entries;
    final history = trend.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subtest.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          child: ContentWidth(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Akurasi tiap percobaan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Icon(label.icon, size: 18, color: label.color),
                          const SizedBox(width: 4),
                          Text(
                            label.text,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: label.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _TrendPainter(
                            values: chartEntries.map((e) => e.accuracy).toList(),
                            color: subtest.color,
                            detailed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Percobaan',
                        value: '${trend.entries.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Rata-rata',
                        value: _pct(trend.average),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Terbaik',
                        value: _pct(trend.best),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Riwayat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                for (final e in history) ...[
                  _HistoryTile(entry: e, color: subtest.color),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.color});

  final ResultEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isTryout ? 'Try Out Mandiri' : 'Latihan Subtes',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(entry.date)} · ${entry.correct}/${entry.total} benar',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _pct(entry.accuracy),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                '${entry.points} poin',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Grafik garis ─────────────────────────

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.color,
    this.detailed = false,
  });

  /// Nilai 0..1, urut dari lama ke baru.
  final List<double> values;
  final Color color;

  /// Grafik besar dengan garis bantu 0/50/100%.
  final bool detailed;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final left = detailed ? 38.0 : 6.0;
    const right = 8.0;
    final top = detailed ? 12.0 : 6.0;
    final bottom = detailed ? 12.0 : 6.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;

    double xAt(int i) =>
        values.length == 1 ? left + w / 2 : left + w * i / (values.length - 1);
    double yAt(double v) => top + h * (1 - v.clamp(0.0, 1.0));

    if (detailed) {
      final gridPaint = Paint()
        ..color = AppColors.border
        ..strokeWidth = 1;
      for (final level in [0.0, 0.5, 1.0]) {
        final y = yAt(level);
        canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);

        final tp = TextPainter(
          text: TextSpan(
            text: '${(level * 100).round()}%',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(0, y - tp.height / 2));
      }
    }

    final points = [
      for (var i = 0; i < values.length; i++) Offset(xAt(i), yAt(values[i])),
    ];

    if (points.length > 1) {
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }

      final area = Path.from(line)
        ..lineTo(points.last.dx, top + h)
        ..lineTo(points.first.dx, top + h)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withAlpha(28));

      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = detailed ? 3 : 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    final dotRadius = detailed ? 5.0 : 3.5;
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      canvas.drawCircle(
        points[i],
        isLast ? dotRadius + 1.5 : dotRadius,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        points[i],
        isLast ? dotRadius : dotRadius - 1.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.color != color ||
        oldDelegate.detailed != detailed;
  }
}

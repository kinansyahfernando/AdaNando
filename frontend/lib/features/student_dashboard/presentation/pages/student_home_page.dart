import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subtest.dart';
import '../../data/subtest_catalog.dart';
import '../widgets/subtest_card.dart';
import 'practice_page.dart';

/// Beranda siswa: pilih subtes yang ingin dilatih.
class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key, required this.onOpenBelajarBareng});

  final VoidCallback onOpenBelajarBareng;

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final name = context.select<AuthProvider, String?>((a) => a.userName);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
        child: ContentWidth(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroHeader(name: name),
              const SizedBox(height: 28),
              const Text(
                'Pilih subtes yang ingin kamu latih',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mulai dari bagian yang menurutmu paling perlu ditingkatkan.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              for (final category in SubtestCatalog.categories) ...[
                _CategorySection(category: category),
                const SizedBox(height: 28),
              ],
              _BelajarBarengBanner(onTap: onOpenBelajarBareng),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.compact;
    final trimmed = (name ?? '').trim();
    final firstName = trimmed.isEmpty
        ? 'Pejuang UTBK'
        : trimmed.split(' ').first;

    return Container(
      padding: EdgeInsets.all(wide ? 28 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $firstName! 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: wide ? 28 : 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Latihan soal per subtes, lengkap dengan pembahasan di setiap soal.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.category_outlined,
                label: '${SubtestCatalog.categories.length} kategori',
              ),
              _HeroChip(
                icon: Icons.quiz_outlined,
                label: '${SubtestCatalog.totalSubtests} subtes',
              ),
              const _HeroChip(
                icon: Icons.lightbulb_outline,
                label: 'Ada pembahasan',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final SubtestCategory category;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final extent = 136 * (textScale < 1 ? 1.0 : textScale);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.subtests.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: extent,
              ),
              itemBuilder: (context, index) {
                final subtest = category.subtests[index];
                return SubtestCard(
                  subtest: subtest,
                  onTap: () =>
                      Navigator.of(context).push(PracticePage.route(subtest)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _BelajarBarengBanner extends StatelessWidget {
  const _BelajarBarengBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.bareng.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups, color: AppColors.bareng),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Belajar Bareng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Buat atau gabung room, kerjakan soal bersama teman, lalu lihat skor dan peringkat. Bisa juga try out mandiri.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

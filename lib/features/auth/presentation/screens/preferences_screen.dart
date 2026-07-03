import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/user_profile_providers.dart';

/// First-run personalization. New users pick the regions, languages and genres
/// they care about; these drive the "Made for You" feed and region ordering on
/// Home. Existing preferences are pre-selected when re-opened from Settings.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key, this.fromSettings = false});

  /// When opened from Settings we show a back button + "Save"; during first-run
  /// onboarding we show "Skip" + "Start Listening".
  final bool fromSettings;

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  static const _languages = [
    'Garhwali',
    'Kumaoni',
    'Jaunsari',
    'Himachali',
    'Hindi',
  ];

  late Set<String> _regions;
  late Set<String> _languages0;
  late Set<String> _genres;

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider);
    _regions = p.preferredRegions.toSet();
    _languages0 = p.preferredLanguages.toSet();
    _genres = p.preferredGenres.toSet();
  }

  Future<void> _save() async {
    await ref.read(userProfileProvider.notifier).completeOnboarding(
          regions: _regions.toList(),
          languages: _languages0.toList(),
          genres: _genres.toList(),
        );
    if (mounted) {
      if (widget.fromSettings) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _skip() async {
    await ref.read(userProfileProvider.notifier).markOnboardingComplete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  if (widget.fromSettings)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  const Spacer(),
                  if (!widget.fromSettings)
                    TextButton(
                      onPressed: _skip,
                      child: Text('Skip',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7))),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                'Tune your HimRaag',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Pick what you love — your home feed adapts to it.',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _ChipGroup(
                    title: 'Regions',
                    options: AppConstants.pahadiRegions,
                    selected: _regions,
                    onToggle: (v) => setState(() => _regions.toggle(v)),
                  ),
                  const SizedBox(height: 24),
                  _ChipGroup(
                    title: 'Languages',
                    options: _languages,
                    selected: _languages0,
                    onToggle: (v) => setState(() => _languages0.toggle(v)),
                  ),
                  const SizedBox(height: 24),
                  _ChipGroup(
                    title: 'Genres',
                    options: AppConstants.pahadiGenres,
                    selected: _genres,
                    onToggle: (v) => setState(() => _genres.toggle(v)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.fromSettings ? 'Save' : 'Start Listening',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ToggleSet on Set<String> {
  void toggle(String v) => contains(v) ? remove(v) : add(v);
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((o) {
            final isSel = selected.contains(o);
            return GestureDetector(
              onTap: () => onToggle(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSel
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSel)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    Text(o,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

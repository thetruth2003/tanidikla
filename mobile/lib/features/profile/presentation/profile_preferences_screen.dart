import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';
import 'package:ankara_proje/features/profile/presentation/widgets/profile_preference_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilePreferencesScreen extends ConsumerStatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  ConsumerState<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState
    extends ConsumerState<ProfilePreferencesScreen> {
  bool _initialized = false;
  bool _saving = false;
  Set<String> _receive = {};
  Set<String> _provide = {};

  void _initialize(ProfileSettings settings) {
    if (_initialized) return;
    _receive = {...settings.receiveCategoryIds};
    _provide = {...settings.provideCategoryIds};
    _initialized = true;
  }

  Future<void> _save(ProfileSettings settings) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateCurrentUserDetails(
            displayName: settings.displayName,
            city: settings.city,
            district: settings.district,
            bio: settings.bio,
            gender: settings.gender,
            receiveCategoryIds: _receive,
            provideCategoryIds: _provide,
          );
      ref.invalidate(currentUserProfileSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İlgi ve bildirim alanların kaydedildi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tercihler kaydedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(currentUserProfileSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İlgi ve bildirim alanlarım')),
      body: settings.when(
        data: (data) {
          _initialize(data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              const AppInfoBanner(
                title: 'Tamamen isteğe bağlı',
                message:
                    'Seçimlerin yalnızca sana uygun ilanları ve bildirimleri iyileştirir. İstediğin zaman değiştirebilirsin.',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 16),
              CategoryPreferencesEditor(
                receiveCategoryIds: _receive,
                provideCategoryIds: _provide,
                onReceiveChanged: (value) => setState(() => _receive = value),
                onProvideChanged: (value) => setState(() => _provide = value),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(data),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Tercihleri Kaydet'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ana kategori seçimi o kategorinin bütün alt hizmetlerini kapsar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Tercihler yüklenemedi: $error')),
      ),
    );
  }
}

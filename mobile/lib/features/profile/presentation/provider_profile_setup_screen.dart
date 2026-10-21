import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/profile/data/turkey_location_catalog.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';
import 'package:ankara_proje/features/profile/presentation/widgets/profile_preference_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class ProviderProfileSetupScreen extends ConsumerStatefulWidget {
  const ProviderProfileSetupScreen({super.key});

  @override
  ConsumerState<ProviderProfileSetupScreen> createState() =>
      _ProviderProfileSetupScreenState();
}

class _ProviderProfileSetupScreenState
    extends ConsumerState<ProviderProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _city;
  String? _district;
  GenderOption? _gender;
  Set<String> _receiveCategoryIds = {};
  Set<String> _provideCategoryIds = {};

  bool _profileLoaded = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillProfile(ProfileSettings profile, TurkeyLocationCatalog locations) {
    if (_profileLoaded) return;
    _displayNameController.text = profile.displayName;
    _bioController.text = profile.bio;
    _city = locations.provinces.contains(profile.city) ? profile.city : null;
    _district = locations.contains(profile.city, profile.district)
        ? profile.district
        : null;
    _gender = profile.gender;
    _receiveCategoryIds = {...profile.receiveCategoryIds};
    _provideCategoryIds = {...profile.provideCategoryIds};
    _avatarUrl = profile.avatarUrl;
    _profileLoaded = true;
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamerayı aç'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 3000,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (image == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(bytes: await image.readAsBytes(), filename: image.name);
      final userId = ref.read(currentUserIdProvider);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserProfileSettingsProvider);
      if (userId != null) ref.invalidate(providerProfileProvider(userId));
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil görselin güncellendi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Görsel yüklenemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final url = _avatarUrl;
    if (url == null || _uploadingAvatar) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil fotoğrafı kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(profileRepositoryProvider).removeAvatar(url);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserProfileSettingsProvider);
      if (mounted) setState(() => _avatarUrl = null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf kaldırılamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final city = _city;
    final district = _district;
    if (city == null || district == null) return;
    setState(() => _saving = true);

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateCurrentUserDetails(
            displayName: _displayNameController.text,
            city: city,
            district: district,
            bio: _bioController.text,
            gender: _gender,
            receiveCategoryIds: _receiveCategoryIds,
            provideCategoryIds: _provideCategoryIds,
          );
      final userId = ref.read(currentUserIdProvider);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserProfileSettingsProvider);
      ref.invalidate(currentUserProfileCompleteProvider);
      if (userId != null) ref.invalidate(providerProfileProvider(userId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil bilgilerin kaydedildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profil kaydedilemedi: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileSettingsProvider);
    final locations = ref.watch(turkeyLocationCatalogProvider);
    if (profile.isLoading || locations.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile.hasError || locations.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profili düzenle')),
        body: Center(
          child: Text(
            'Profil yüklenemedi: ${profile.error ?? locations.error}',
          ),
        ),
      );
    }
    if (!_profileLoaded) {
      _fillProfile(profile.requireValue, locations.requireValue);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppSurfaceCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Profil Bilgilerim',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: AppColors.turquoiseDark,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Düzenle',
                        style: TextStyle(
                          color: AppColors.turquoiseDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.aqua,
                          foregroundColor: AppColors.turquoiseDeep,
                          backgroundImage: _avatarUrl == null
                              ? null
                              : NetworkImage(_avatarUrl!),
                          child: _avatarUrl == null
                              ? const Icon(Icons.person_rounded, size: 40)
                              : null,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: Material(
                            color: AppColors.turquoise,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _uploadingAvatar ? null : _pickAvatar,
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: _uploadingAvatar
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _uploadingAvatar ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _avatarUrl == null
                              ? 'Profil fotoğrafı ekle'
                              : 'Fotoğrafı değiştir',
                        ),
                      ),
                      if (_avatarUrl != null)
                        TextButton.icon(
                          onPressed: _uploadingAvatar ? null : _removeAvatar,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Kaldır'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _displayNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Görünen ad *',
                      helperText:
                          'Türkçe karakterleri kullanabilirsin: ç, ğ, ı, İ, ö, ş, ü.',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 2) return 'En az 2 karakter yaz.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ProfileLocationFields(
                    catalog: locations.requireValue,
                    city: _city,
                    district: _district,
                    onCityChanged: (value) => setState(() {
                      _city = value;
                      _district = null;
                    }),
                    onDistrictChanged: (value) =>
                        setState(() => _district = value),
                  ),
                  const SizedBox(height: 12),
                  GenderSelectionField(
                    value: _gender,
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Hakkında',
                      helperText: 'Türkçe karakterlerin tamamı desteklenir.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Profil Bilgilerini Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

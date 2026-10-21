import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/profile/data/turkey_location_catalog.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';
import 'package:ankara_proje/features/profile/presentation/widgets/profile_preference_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({this.returnTo, super.key});

  final String? returnTo;

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  TurkeyLocationCatalog? _locations;
  String? _city;
  String? _district;
  GenderOption? _gender;
  Set<String> _receiveCategoryIds = {};
  Set<String> _provideCategoryIds = {};
  String? _avatarUrl;
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(apiAuthSessionProvider).currentUser;
    if (user == null) {
      if (mounted) context.go(AppRoutes.auth);
      return;
    }
    try {
      final results = await Future.wait<Object>([
        TurkeyLocationCatalog.load(),
        ref.read(profileRepositoryProvider).currentUserSettings(),
      ]);
      final locations = results[0] as TurkeyLocationCatalog;
      final profile = results[1] as ProfileSettings;
      _displayNameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _locations = locations;
      _city = locations.provinces.contains(profile.city) ? profile.city : null;
      _district = locations.contains(profile.city, profile.district)
          ? profile.district
          : null;
      _gender = profile.gender;
      _receiveCategoryIds = {...profile.receiveCategoryIds};
      _provideCategoryIds = {...profile.provideCategoryIds};
      _avatarUrl = profile.avatarUrl;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil bilgileri yüklenemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextStep() {
    if (_step == 0 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_step < 2) setState(() => _step++);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    final city = _city;
    final district = _district;
    if (city == null || district == null) {
      setState(() => _step = 0);
      return;
    }
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
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserProfileSettingsProvider);
      ref.invalidate(currentUserProfileCompleteProvider);
      if (mounted) context.go(_safeReturnDestination());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Profil kaydedilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      maxWidth: 2000,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (image == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(bytes: await image.readAsBytes(), filename: image.name);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserProfileSettingsProvider);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilini Oluştur'),
        automaticallyImplyLeading: false,
        leading: _step > 0
            ? IconButton(
                onPressed: _saving ? null : () => setState(() => _step--),
                tooltip: 'Geri',
                icon: const Icon(Icons.arrow_back),
              )
            : widget.returnTo == null
            ? null
            : IconButton(
                onPressed: () => context.go(AppRoutes.discovery),
                tooltip: 'Vazgeç',
                icon: const Icon(Icons.close),
              ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _signOut,
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: _loading || _locations == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
                      child: Row(
                        children: [
                          for (var index = 0; index < 3; index++) ...[
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 5,
                                decoration: BoxDecoration(
                                  color: index <= _step
                                      ? AppColors.turquoise
                                      : AppColors.outline,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            if (index != 2) const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                key: ValueKey(_step),
                                child: switch (_step) {
                                  0 => _identityStep(),
                                  1 => _categoryStep(),
                                  _ => _photoStep(),
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Row(
                          children: [
                            if (_step > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _step--),
                                  child: const Text('Geri'),
                                ),
                              ),
                            if (_step > 0) const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _saving || _uploadingAvatar
                                    ? null
                                    : _step == 2
                                    ? _save
                                    : _nextStep,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _step == 2
                                            ? Icons.check_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                label: Text(
                                  _step == 2
                                      ? 'Profili Kaydet ve Devam Et'
                                      : _step == 1
                                      ? 'Devam Et (Seçimler İsteğe Bağlı)'
                                      : 'Devam Et',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _identityStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Temel bilgilerin',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'İl ve ilçeni listeden seç. Ad ve açıklama alanlarında Türkçe karakterleri özgürce kullanabilirsin.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 22),
      TextFormField(
        controller: _displayNameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Görünen ad *',
          helperText: 'Örn. Çağrı Şen — Türkçe karakter kullanabilirsin.',
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
        catalog: _locations!,
        city: _city,
        district: _district,
        onCityChanged: (value) => setState(() {
          _city = value;
          _district = null;
        }),
        onDistrictChanged: (value) => setState(() => _district = value),
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
          labelText: 'Kısa açıklama (isteğe bağlı)',
          helperText: 'ç, ğ, ı, İ, ö, ş ve ü karakterleri desteklenir.',
          alignLabelWithHint: true,
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
    ],
  );

  Widget _categoryStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Hangi alanlarla ilgileniyorsun?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'Bu adım isteğe bağlıdır. Seçimlerini daha sonra Profil bölümünden değiştirebilirsin.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      CategoryPreferencesEditor(
        receiveCategoryIds: _receiveCategoryIds,
        provideCategoryIds: _provideCategoryIds,
        onReceiveChanged: (value) =>
            setState(() => _receiveCategoryIds = value),
        onProvideChanged: (value) =>
            setState(() => _provideCategoryIds = value),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _nextStep,
        icon: const Icon(Icons.fast_forward_outlined),
        label: const Text('Şimdilik geç, sonra profilimden seçerim'),
      ),
    ],
  );

  Widget _photoStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Profil fotoğrafını ekle',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'Fotoğraf güveni artırır; ancak zorunlu değildir. Şimdi geçip daha sonra profilinden ekleyebilirsin.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 32),
      Center(
        child: CircleAvatar(
          radius: 72,
          backgroundColor: AppColors.aqua,
          foregroundColor: AppColors.turquoiseDeep,
          backgroundImage: _avatarUrl == null
              ? null
              : NetworkImage(_avatarUrl!),
          child: _avatarUrl == null
              ? const Icon(Icons.person_outline_rounded, size: 82)
              : null,
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _uploadingAvatar ? null : _pickAvatar,
        icon: _uploadingAvatar
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(_avatarUrl == null ? 'Fotoğraf seç' : 'Fotoğrafı değiştir'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _saving || _uploadingAvatar ? null : _save,
        child: const Text('Fotoğrafsız devam et'),
      ),
      const SizedBox(height: 6),
      Text(
        'Fotoğraf eklemeden de “Profili Kaydet ve Devam Et” diyebilirsin.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
    ],
  );

  Future<void> _signOut() async {
    await ref.read(apiAuthSessionProvider).logout();
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(currentUserProfileSettingsProvider);
    ref.invalidate(currentUserProfileCompleteProvider);
    ref.invalidate(providerProfileProvider);
    ref.invalidate(activeListingsProvider);
    ref.invalidate(listingsByOwnerProvider);
    ref.invalidate(conversationSummariesProvider);
    if (mounted) context.go(AppRoutes.auth);
  }

  String _safeReturnDestination() {
    final returnTo = widget.returnTo;
    if (returnTo == null || !returnTo.startsWith('/')) {
      return AppRoutes.discovery;
    }
    return returnTo;
  }
}

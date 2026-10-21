import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/config/app_environment.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/privacy/application/privacy_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ankara_proje/core/network/api_client.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.returnTo = AppRoutes.discovery, super.key});

  final String returnTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  bool _registerMode = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  bool _submitting = false;
  bool _acceptedTerms = false;
  bool _messageEmailNotifications = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);

    try {
      final auth = ref.read(apiAuthSessionProvider);
      if (_registerMode) {
        final policies = await ref.read(policiesProvider.future);
        final terms = policies.where((item) => item.type == 'terms').toList();
        if (terms.isNotEmpty && !_acceptedTerms) {
          _showMessage('Kullanım Koşulları’nı okuyup kabul etmelisin.');
          return;
        }
        await auth.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmationController.text,
          displayName: _displayNameController.text.trim(),
          messageEmailNotifications: _messageEmailNotifications,
        );
        if (terms.isNotEmpty) {
          await ref
              .read(privacyClientProvider)
              .recordConsents(terms.map((item) => item.id).toList());
        }
      } else {
        await auth.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      _invalidateSessionData();
      if (mounted) context.go(widget.returnTo);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Giriş sırasında beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _quickLogin(String email, String password) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(apiAuthSessionProvider)
          .login(email: email, password: password);
      _invalidateSessionData();
      if (mounted) context.go(widget.returnTo);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      _showMessage('Önce geçerli e-posta adresini yaz.');
      return;
    }
    try {
      await ref.read(apiAuthSessionProvider).requestPasswordReset(email);
      if (mounted) {
        _showMessage('Şifre yenileme bağlantısı e-postana gönderildi.');
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _invalidateSessionData() {
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(currentUserProfileCompleteProvider);
    ref.invalidate(providerProfileProvider);
    ref.invalidate(activeListingsProvider);
    ref.invalidate(listingsByOwnerProvider);
    ref.invalidate(conversationSummariesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final policiesState = ref.watch(policiesProvider);
    final hasPublishedTerms =
        policiesState.asData?.value.any((item) => item.type == 'terms') ??
        false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => context.go(AppRoutes.discovery),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Üye olmadan keşfete dön',
                      ),
                    ),
                    AppPageHeader(
                      title: _registerMode ? 'Hesabını Oluştur' : 'Hoş Geldin',
                      subtitle: _registerMode
                          ? 'Tanıdık hizmetlere ulaşmak ve ilan vermek için kaydol.'
                          : 'Yakınındaki hizmetlere hemen ulaş',
                    ),
                    const SizedBox(height: 22),
                    const _AuthIllustration(),
                    const SizedBox(height: 18),
                    AppSegmentedControl<bool>(
                      segments: const [
                        AppSegment(value: false, label: 'Giriş Yap'),
                        AppSegment(value: true, label: 'Kayıt Ol'),
                      ],
                      selected: _registerMode,
                      onChanged: (value) {
                        if (!_submitting) {
                          setState(() => _registerMode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_registerMode) ...[
                      TextFormField(
                        controller: _displayNameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Görünen ad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 2) return 'En az 2 karakter yaz.';
                          if (text.length > 60) {
                            return 'En fazla 60 karakter yaz.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) => _looksLikeEmail(value?.trim() ?? '')
                          ? null
                          : 'Geçerli bir e-posta adresi yaz.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: _registerMode
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (!_registerMode) {
                          return (value ?? '').isEmpty ? 'Şifreni yaz.' : null;
                        }
                        return _passwordValidationMessage(value ?? '');
                      },
                    ),
                    if (_registerMode) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'En az 10 karakter; harf, rakam ve özel karakter kullan.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordConfirmationController,
                        obscureText: _obscurePasswordConfirmation,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Şifreyi tekrar yaz',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            tooltip: _obscurePasswordConfirmation
                                ? 'Şifreyi göster'
                                : 'Şifreyi gizle',
                            onPressed: () => setState(
                              () => _obscurePasswordConfirmation =
                                  !_obscurePasswordConfirmation,
                            ),
                            icon: Icon(
                              _obscurePasswordConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == _passwordController.text
                            ? null
                            : 'Şifreler aynı olmalı.',
                      ),
                    ],
                    if (!_registerMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : _resetPassword,
                          child: const Text('Şifremi unuttum'),
                        ),
                      )
                    else
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: _messageEmailNotifications,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'Yeni mesaj geldiğinde e-posta ile bildirim almak istiyorum.',
                              style: TextStyle(fontSize: 12),
                            ),
                            onChanged: _submitting
                                ? null
                                : (value) => setState(
                                    () => _messageEmailNotifications =
                                        value ?? false,
                                  ),
                          ),
                          if (hasPublishedTerms)
                            CheckboxListTile(
                              value: _acceptedTerms,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Kullanım Koşulları’nı okudum ve kabul ediyorum.',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: _submitting
                                  ? null
                                  : (value) => setState(
                                      () => _acceptedTerms = value ?? false,
                                    ),
                            ),
                          TextButton(
                            onPressed: () async {
                              final items = await ref.read(
                                policiesProvider.future,
                              );
                              if (!context.mounted) return;
                              if (items.isEmpty) {
                                _showMessage(
                                  'Hukuk ekibi henüz bir metin yayımlamadı.',
                                );
                                return;
                              }
                              showDialog<void>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Yasal Metinler'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final item in items) ...[
                                          Text(
                                            '${item.title} · ${item.version}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          SelectableText(item.content),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Kapat'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('Yasal metinleri görüntüle'),
                          ),
                          const AppInfoBanner(
                            title: 'KVKK bilgilendirmesi ayrı tutulur',
                            message:
                                'KVKK Aydınlatma Metni ve Gizlilik Politikası bir açık rıza değildir. Mesaj e-postası tercihini de istediğin zaman ayarlardan değiştirebilirsin.',
                            icon: Icons.privacy_tip_outlined,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registerMode ? 'Kayıt Ol' : 'Giriş Yap'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => context.go(AppRoutes.discovery),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Üye olmadan keşfet'),
                    ),
                    if (kDebugMode && AppEnvironment.hasDebugTestAccounts) ...[
                      const SizedBox(height: 16),
                      AppSurfaceCard(
                        color: AppColors.aquaSoft,
                        borderColor: AppColors.aqua,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Test Girişi',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _quickLogin(
                                            AppEnvironment.testUser1Email,
                                            AppEnvironment.testUser1Password,
                                          ),
                                    child: const Text('Test 1'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _quickLogin(
                                            AppEnvironment.testUser2Email,
                                            AppEnvironment.testUser2Password,
                                          ),
                                    child: const Text('Test 2'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Yöneticiler senden hiçbir zaman şifreni istemez.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIllustration extends StatelessWidget {
  const _AuthIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      decoration: BoxDecoration(
        color: AppColors.aquaSoft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.aqua),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 28,
            bottom: 30,
            child: Icon(
              Icons.location_city_rounded,
              size: 72,
              color: AppColors.turquoise.withValues(alpha: .16),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 28,
            child: Icon(
              Icons.storefront_rounded,
              size: 70,
              color: AppColors.turquoise.withValues(alpha: .18),
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: AppColors.turquoise,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const Positioned(
            right: 78,
            top: 25,
            child: AppIconBadge(icon: Icons.handyman_outlined, size: 42),
          ),
        ],
      ),
    );
  }
}

bool _looksLikeEmail(String value) {
  final separator = value.indexOf('@');
  return separator > 0 &&
      separator < value.length - 3 &&
      value.contains('.', separator);
}

String? _passwordValidationMessage(String value) {
  if (value.length < 10) return 'Şifre en az 10 karakter olmalı.';
  if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(value)) {
    return 'Şifre en az bir harf içermeli.';
  }
  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Şifre en az bir rakam içermeli.';
  }
  if (!RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü\d\s]').hasMatch(value)) {
    return 'Şifre en az bir özel karakter içermeli.';
  }
  return null;
}

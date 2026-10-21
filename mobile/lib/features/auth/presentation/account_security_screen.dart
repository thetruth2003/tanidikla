import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _email = TextEditingController();
  final _emailPassword = TextEditingController();
  final _phone = TextEditingController();
  final _phoneCode = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _messageEmails = false;
  bool _busy = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirmation = false;
  List<Map<String, dynamic>> _sessions = const [];

  @override
  void initState() {
    super.initState();
    final user = apiAuthSession.currentUser;
    _email.text = user?.email ?? '';
    _phone.text = user?.phoneE164 ?? '';
    _messageEmails = user?.messageEmailNotifications ?? false;
    _loadSessions();
  }

  @override
  void dispose() {
    for (final controller in [
      _email,
      _emailPassword,
      _phone,
      _phoneCode,
      _currentPassword,
      _newPassword,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await apiClient.get('/account/sessions');
      if (mounted) {
        setState(() {
          _sessions = (data['items'] as List? ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(growable: false);
        });
      }
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');

  String? _passwordError(String value) {
    if (value.length < 10) return 'En az 10 karakter olmalı.';
    if (!RegExp(r'[A-Za-zÀ-ſ]').hasMatch(value)) {
      return 'En az bir harf olmalı.';
    }
    if (!RegExp(r'\d').hasMatch(value)) return 'En az bir rakam olmalı.';
    if (!RegExp(r'[^A-Za-zÀ-ſ\d\s]').hasMatch(value)) {
      return 'En az bir özel karakter olmalı.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = apiAuthSession.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve Güvenlik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          _statusCard(user),
          const SizedBox(height: 14),
          _section(
            title: 'E-posta adresi',
            subtitle: 'Yeni adres, gönderilen bağlantı açılınca etkinleşir.',
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Yeni e-posta'),
              ),
              const SizedBox(height: 10),
              _passwordField(
                controller: _emailPassword,
                label: 'Mevcut şifre',
                visible: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await apiClient.post(
                          '/account/email/change',
                          body: {
                            'new_email': _email.text.trim(),
                            'current_password': _emailPassword.text,
                          },
                        );
                      }, 'Doğrulama bağlantısı yeni adresine gönderildi.'),
                child: const Text('E-posta değişikliğini doğrula'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Telefon doğrulama',
            subtitle: 'Türkiye cep numaran +905xxxxxxxxx biçiminde saklanır.',
            children: [
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon numarası',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await apiClient.post(
                          '/account/phone/request',
                          body: {'phone': _phone.text.trim()},
                        );
                      }, 'SMS doğrulama kodu gönderildi.'),
                child: const Text('SMS kodu iste'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '6 haneli kod'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await apiClient.post(
                          '/account/phone/verify',
                          body: {'code': _phoneCode.text.trim()},
                        );
                        await apiAuthSession.refreshUser();
                        setState(() {});
                      }, 'Telefon numaran doğrulandı.'),
                child: const Text('Telefonu doğrula'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Şifre değiştir',
            subtitle: 'En az 10 karakter; harf, rakam ve özel karakter kullan.',
            children: [
              _passwordField(
                controller: _currentPassword,
                label: 'Mevcut şifre',
                visible: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(height: 10),
              _passwordField(
                controller: _newPassword,
                label: 'Yeni şifre',
                visible: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
              ),
              const SizedBox(height: 10),
              _passwordField(
                controller: _confirmation,
                label: 'Yeni şifreyi tekrar gir',
                visible: _showConfirmation,
                onToggle: () =>
                    setState(() => _showConfirmation = !_showConfirmation),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        final error = _passwordError(_newPassword.text);
                        if (error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                        if (_newPassword.text != _confirmation.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Şifreler aynı değil.'),
                            ),
                          );
                          return;
                        }
                        _run(
                          () async {
                            await apiClient.put(
                              '/account/password',
                              body: {
                                'current_password': _currentPassword.text,
                                'password': _newPassword.text,
                                'password_confirmation': _confirmation.text,
                              },
                            );
                          },
                          'Şifren değiştirildi; diğer cihazlardaki oturumlar kapatıldı.',
                        );
                      },
                child: const Text('Şifreyi değiştir'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Bildirim tercihi',
            subtitle: 'Pazarlama izninden ayrıdır.',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _messageEmails,
                title: const Text('Yeni mesajda e-posta bildirimi al'),
                onChanged: _busy
                    ? null
                    : (value) async {
                        setState(() => _messageEmails = value);
                        await _run(() async {
                          await apiClient.put(
                            '/account/preferences',
                            body: {'message_email_notifications': value},
                          );
                          await apiAuthSession.refreshUser();
                        }, 'Bildirim tercihin kaydedildi.');
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Aktif oturumlar',
            subtitle: 'Hesabının açık olduğu cihazlar.',
            children: [
              if (_sessions.isEmpty) const Text('Aktif oturum yükleniyor…'),
              for (final session in _sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session['session_kind'] == 'mobile'
                        ? Icons.phone_android
                        : Icons.computer,
                  ),
                  title: Text(
                    session['device_name']?.toString() ?? 'Bilinmeyen cihaz',
                  ),
                  subtitle: Text(session['last_seen_at']?.toString() ?? ''),
                  trailing: session['is_current'] == true
                      ? const Chip(label: Text('Bu cihaz'))
                      : null,
                ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await apiClient.post('/account/sessions/revoke-others');
                        await _loadSessions();
                      }, 'Diğer cihazlardaki oturumlar kapatıldı.'),
                icon: const Icon(Icons.logout),
                label: const Text('Diğer cihazlardan çıkış yap'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard(ApiUser? user) => Card(
    child: ListTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('Doğrulama durumu'),
      subtitle: Text(
        'E-posta: ${user?.emailVerified == true ? 'Doğrulandı' : 'Bekliyor'}  ·  '
        'Telefon: ${user?.phoneVerified == true ? 'Doğrulandı' : 'Bekliyor'}',
      ),
    ),
  );

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) => TextField(
    controller: controller,
    obscureText: !visible,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        onPressed: onToggle,
        tooltip: visible ? 'Şifreyi gizle' : 'Şifreyi göster',
        icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
      ),
    ),
  );
}

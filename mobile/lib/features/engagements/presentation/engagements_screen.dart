import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EngagementsScreen extends StatefulWidget {
  const EngagementsScreen({super.key});

  @override
  State<EngagementsScreen> createState() => _EngagementsScreenState();
}

class _EngagementsScreenState extends State<EngagementsScreen> {
  late Future<List<Map<String, dynamic>>> _items = _load();
  String _status = '';

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await apiClient.get(
      '/engagements',
      query: {if (_status.isNotEmpty) 'status': _status},
    );
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  void _reload() => setState(() => _items = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İşlerim')),
    body: Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            scrollDirection: Axis.horizontal,
            children: [
              _filter('Tümü', ''),
              _filter('Bekleyen', 'requested'),
              _filter('Devam eden', 'in_progress'),
              _filter('Onay bekleyen', 'provider_completed'),
              _filter('Tamamlanan', 'completed'),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'İş kayıtları yüklenemedi',
                  message: '${snapshot.error}',
                  onRetry: _reload,
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return _EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'Bu durumda iş kaydın yok',
                  message:
                      'Bir hizmet talebi gönderdiğinde süreç burada görünür.',
                  onRetry: _reload,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _EngagementCard(
                    item: items[index],
                    currentUserId: apiAuthSession.currentUser?.id ?? '',
                    onAction: _act,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _filter(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _status == value,
      onSelected: (_) {
        _status = value;
        _reload();
      },
    ),
  );

  Future<void> _act(Map<String, dynamic> item, String action) async {
    if (action == 'messages') {
      context.push(AppRoutes.chat(item['conversation_id']?.toString() ?? ''));
      return;
    }
    if (action == 'review') {
      await _review(item['id'].toString());
      return;
    }
    var reason = '';
    if (action == 'cancel' || action == 'dispute') {
      final controller = TextEditingController();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(action == 'dispute' ? 'Sorunu bildir' : 'İşi iptal et'),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Neden',
              hintText: 'En az 3 karakter',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gönder'),
            ),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (accepted != true) return;
      if (reason.length < 3) {
        _message('Neden en az 3 karakter olmalı.');
        return;
      }
    }
    try {
      await apiClient.post(
        '/engagements/${item['id']}/actions/$action',
        body: {if (reason.isNotEmpty) 'reason': reason},
      );
      _message('İş durumu güncellendi.');
      _reload();
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _review(String id) async {
    var rating = 5;
    final comment = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Doğrulanmış işi değerlendir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Puan'),
                items: [5, 4, 3, 2, 1]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value yıldız'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => rating = value ?? 5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Yorum (isteğe bağlı)',
                ),
              ),
              const Text(
                'Puanın, iki taraf da gönderene veya 14 gün geçene kadar gizli tutulur.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      comment.dispose();
      return;
    }
    try {
      await apiClient.post(
        '/reviews',
        body: {
          'engagement_id': id,
          'rating': rating,
          'comment': comment.text.trim(),
        },
      );
      _message('Değerlendirmen kaydedildi.');
    } catch (error) {
      _message('$error');
    } finally {
      comment.dispose();
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({
    required this.item,
    required this.currentUserId,
    required this.onAction,
  });
  final Map<String, dynamic> item;
  final String currentUserId;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  @override
  Widget build(BuildContext context) {
    final provider = item['provider_id']?.toString() == currentUserId;
    final status = item['status']?.toString() ?? '';
    final actions = <(String, String)>[];
    if (provider && status == 'requested') {
      actions.addAll([('Kabul et', 'accept'), ('Reddet', 'reject')]);
    }
    if (provider && status == 'accepted') actions.add(('İşi başlat', 'start'));
    if (provider && status == 'in_progress') {
      actions.add(('Tamamladım', 'mark_completed'));
    }
    if (!provider && status == 'provider_completed') {
      actions.addAll([
        ('Tamamlandığını onayla', 'confirm_completed'),
        ('Sorun bildir', 'dispute'),
      ]);
    }
    if (['requested', 'accepted', 'in_progress'].contains(status)) {
      actions.add(('İptal et', 'cancel'));
    }
    if (status == 'completed') actions.add(('Değerlendir', 'review'));
    actions.add(('Mesajlar', 'messages'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider ? 'HİZMET VERİYORUM' : 'HİZMET ALIYORUM',
              style: const TextStyle(
                color: AppColors.turquoiseDark,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item['service_name_snapshot']?.toString() ?? 'Hizmet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${provider ? item['requester_name'] : item['provider_name']} · ${_statusLabel(status)}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const Divider(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions
                  .map(
                    (entry) =>
                        entry.$2 == 'accept' ||
                            entry.$2 == 'start' ||
                            entry.$2 == 'mark_completed' ||
                            entry.$2 == 'confirm_completed' ||
                            entry.$2 == 'review'
                        ? FilledButton(
                            onPressed: () => onAction(item, entry.$2),
                            child: Text(entry.$1),
                          )
                        : OutlinedButton(
                            onPressed: () => onAction(item, entry.$2),
                            child: Text(entry.$1),
                          ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String value) =>
    const {
      'requested': 'Yanıt bekliyor',
      'accepted': 'Kabul edildi',
      'rejected': 'Reddedildi',
      'in_progress': 'Devam ediyor',
      'provider_completed': 'Onay bekliyor',
      'completed': 'Tamamlandı',
      'canceled': 'İptal edildi',
      'disputed': 'İncelemede',
    }[value] ??
    value;

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.turquoiseDark),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Yenile')),
        ],
      ),
    ),
  );
}

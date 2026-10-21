import 'dart:convert';

import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/privacy/application/privacy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  Future<void> _showPolicy(
    BuildContext context,
    PolicyDocument document,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        minChildSize: .55,
        maxChildSize: .96,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          children: [
            Text(document.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Sürüm ${document.version}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (!document.configurationComplete) ...[
              const SizedBox(height: 14),
              const AppInfoBanner(
                title: 'Yayın yapılandırması eksik',
                message:
                    'Veri sorumlusu adı, adresi ve KVKK iletişim bilgileri sunucuda tamamlanmadan bu metin canlı yayına hazır değildir.',
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: 18),
            SelectableText(
              document.content,
              style: const TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRequest(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required String title,
    required String explanation,
    bool destructive = false,
  }) async {
    final controller = TextEditingController();
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(explanation, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 7,
              maxLength: 2000,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Talep ayrıntısı',
                hintText: 'Hangi veri veya işlemle ilgili olduğunu açıkla.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                  : null,
              onPressed: () {
                if (controller.text.trim().length < 10) return;
                Navigator.pop(sheetContext, true);
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Başvuruyu Gönder'),
            ),
          ],
        ),
      ),
    );
    final details = controller.text.trim();
    controller.dispose();
    if (accepted != true || details.length < 10) return;
    try {
      await ref
          .read(privacyClientProvider)
          .request(type: type, details: details);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KVKK başvurun kayıt altına alındı.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Talep oluşturulamadı: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(policiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Yasal Metinler', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          policies.when(
            data: (items) => items.isEmpty
                ? const AppInfoBanner(
                    title: 'Henüz metin yayımlanmadı',
                    message:
                        'Hukuk ekibinin onayladığı içerikler yayımlandığında burada görünür.',
                    icon: Icons.gavel_outlined,
                  )
                : Column(
                    children: [
                      for (final item in items)
                        ListTile(
                          title: Text(item.title),
                          subtitle: Text('Sürüm ${item.version}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _showPolicy(context, item),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
          ),
          const SizedBox(height: 28),
          Text('KVKK Hakların', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Başvurular en kısa sürede ve en geç 30 gün içinde değerlendirilir.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final data = await ref.read(privacyClientProvider).exportData();
                await Clipboard.setData(
                  ClipboardData(
                    text: const JsonEncoder.withIndent('  ').convert(data),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veri kopyan panoya kopyalandı.'),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Veriler alınamadı: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Verilerimin Kopyasını Al'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _createRequest(
              context,
              ref,
              type: 'correction',
              title: 'Düzeltme Talebi',
              explanation:
                  'Eksik veya yanlış olduğunu düşündüğün kişisel veriyi ve doğru hâlini açıkla.',
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Veri Düzeltme Talebi'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _createRequest(
              context,
              ref,
              type: 'objection',
              title: 'İtiraz ve İnceleme Talebi',
              explanation:
                  'İtiraz ettiğin veri işleme faaliyetini veya otomatik değerlendirmeyi açıkla.',
            ),
            icon: const Icon(Icons.rule_rounded),
            label: const Text('İtiraz / İnceleme Talebi'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => _createRequest(
              context,
              ref,
              type: 'deletion',
              title: 'Hesap ve Veri Silme Talebi',
              explanation:
                  'Talep kabul edilip tamamlandığında hesabın anonimleştirilir, ilanların kaldırılır ve oturumların kapatılır. Silinmesini istediğin kapsamı açıkla.',
              destructive: true,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Hesabımı Silme Talebi'),
          ),
        ],
      ),
    );
  }
}

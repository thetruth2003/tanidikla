import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/notifications/application/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationInboxProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          TextButton(
            onPressed: inbox.value?.unreadCount == 0
                ? null
                : () async {
                    await ref.read(notificationClientProvider).markAllRead();
                    ref.invalidate(notificationInboxProvider);
                  },
            child: const Text('Tümünü oku'),
          ),
        ],
      ),
      body: inbox.when(
        data: (data) => data.items.isEmpty
            ? const AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Yeni Bildirim Yok',
                message:
                    'Mesaj, ilan ve değerlendirme bildirimlerin burada görünecek.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(notificationInboxProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final item = data.items[index];
                    return AppSurfaceCard(
                      onTap: () async {
                        if (!item.read) {
                          await ref
                              .read(notificationClientProvider)
                              .markRead(item.id);
                          ref.invalidate(notificationInboxProvider);
                        }
                        if (!context.mounted) return;
                        final conversationId = item.data['conversation_id']
                            ?.toString();
                        if (conversationId?.isNotEmpty == true) {
                          context.push(AppRoutes.chat(conversationId!));
                          return;
                        }
                        final listingId = item.data['listing_id']?.toString();
                        if (listingId?.isNotEmpty == true) {
                          context.push(AppRoutes.listingDetail(listingId!));
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: item.read
                                ? AppColors.aquaSoft
                                : AppColors.aqua,
                            foregroundColor: AppColors.turquoiseDeep,
                            child: Icon(switch (item.type) {
                              'message' => Icons.chat_bubble_outline_rounded,
                              'listing' => Icons.campaign_outlined,
                              'review' => Icons.star_outline_rounded,
                              _ => Icons.notifications_none_rounded,
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: item.read
                                        ? FontWeight.w700
                                        : FontWeight.w900,
                                  ),
                                ),
                                if (item.body.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!item.read)
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: AppColors.turquoiseDark,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Bildirimler Yüklenemedi',
          message: error.toString(),
        ),
      ),
    );
  }
}

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:ankara_proje/features/notifications/application/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  ConversationSection _selectedSection = ConversationSection.receivingService;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationSummariesProvider);
    final unreadCount =
        ref.watch(notificationInboxProvider).value?.unreadCount ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Mesajlar',
              trailing: IconButton(
                onPressed: () => context.push(AppRoutes.notifications),
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                tooltip: 'Bildirimler',
              ),
            ),
            const SizedBox(height: 6),
            AppSegmentedControl<ConversationSection>(
              segments: const [
                AppSegment(
                  value: ConversationSection.receivingService,
                  label: 'Hizmet Al',
                ),
                AppSegment(
                  value: ConversationSection.providingService,
                  label: 'Hizmet Ver',
                ),
              ],
              selected: _selectedSection,
              onChanged: (value) => setState(() {
                _selectedSection = value;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: 'Konuşma veya ilan ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: conversations.when(
                data: (items) {
                  final normalizedQuery = _query.toLowerCase();
                  final visibleItems = items
                      .where((item) {
                        if (item.section != _selectedSection) return false;
                        if (normalizedQuery.isEmpty) return true;
                        return item.otherUserName.toLowerCase().contains(
                              normalizedQuery,
                            ) ||
                            item.listingTitle.toLowerCase().contains(
                              normalizedQuery,
                            ) ||
                            item.lastMessage.toLowerCase().contains(
                              normalizedQuery,
                            );
                      })
                      .toList(growable: false);
                  return visibleItems.isEmpty
                      ? _EmptyMessages(section: _selectedSection)
                      : RefreshIndicator(
                          onRefresh: () async =>
                              ref.refresh(conversationSummariesProvider.future),
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount: visibleItems.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) =>
                                _ConversationCard(item: visibleItems[index]),
                          ),
                        );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Konuşmalar Yüklenemedi',
                  message: error.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.item});

  final ConversationSummary item;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: () => context.push(AppRoutes.chat(item.id)),
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.aqua,
                foregroundColor: AppColors.turquoiseDeep,
                backgroundImage: item.otherUserAvatar == null
                    ? null
                    : NetworkImage(item.otherUserAvatar!),
                child: item.otherUserAvatar == null
                    ? Text(
                        item.otherUserName.isEmpty
                            ? '?'
                            : item.otherUserName.characters.first.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      )
                    : null,
              ),
              const Positioned(
                right: -1,
                bottom: 1,
                child: CircleAvatar(
                  radius: 6,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.otherUserName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      _conversationTimeLabel(item.updatedAt),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.turquoiseDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          if (item.unreadCount > 0)
            CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.turquoiseDark,
              foregroundColor: Colors.white,
              child: Text(
                item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.section});

  final ConversationSection section;

  @override
  Widget build(BuildContext context) {
    final receiving = section == ConversationSection.receivingService;
    return AppEmptyState(
      icon: Icons.mark_chat_unread_outlined,
      title: 'Henüz Konuşma Yok',
      message: receiving
          ? 'Hizmet almak için bir ilana yazdığında konuşman burada görünecek.'
          : 'Bir kullanıcı ilanına yazdığında konuşmanız burada görünecek.',
      action: FilledButton.tonalIcon(
        onPressed: () => context.go(AppRoutes.discovery),
        icon: const Icon(Icons.explore_outlined),
        label: const Text('İlanları Keşfet'),
      ),
    );
  }
}

String _conversationTimeLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (difference == 1) return 'Dün';
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
}

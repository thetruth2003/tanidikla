import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  XFile? _pendingImage;
  int _renderedMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNewestAfterLayout(int messageCount) {
    if (_renderedMessageCount == messageCount) return;
    _renderedMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    final image = _pendingImage;
    if ((body.isEmpty && image == null) || _sending) return;
    setState(() => _sending = true);
    try {
      final uploads = image == null
          ? const <MessageImageUpload>[]
          : [
              MessageImageUpload(
                bytes: await image.readAsBytes(),
                filename: image.name,
              ),
            ];
      await ref
          .read(messageRepositoryProvider)
          .sendMessage(widget.conversationId, body, attachments: uploads);
      _messageController.clear();
      if (mounted) setState(() => _pendingImage = null);
      ref.invalidate(conversationSummariesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mesaj gönderilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
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
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (image != null && mounted) setState(() => _pendingImage = image);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final summaries = ref.watch(conversationSummariesProvider);
    final summary = summaries.whenOrNull(
      data: (items) => items.cast<ConversationSummary?>().firstWhere(
        (item) => item?.id == widget.conversationId,
        orElse: () => null,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('İlan Görüşmesi')),
      body: Column(
        children: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Column(
                children: [
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const AppIconBadge(
                          icon: Icons.campaign_outlined,
                          size: 44,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.listingTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bu konuşma yalnızca bu ilana bağlıdır.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 19,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.aqua,
                        foregroundColor: AppColors.turquoiseDeep,
                        backgroundImage: summary.otherUserAvatar == null
                            ? null
                            : NetworkImage(summary.otherUserAvatar!),
                        child: summary.otherUserAvatar == null
                            ? Text(
                                summary.otherUserName.isEmpty
                                    ? '?'
                                    : summary.otherUserName.characters.first
                                          .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.otherUserName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Text(
                              'Çevrimiçi',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: summary.otherUserId.isEmpty
                            ? null
                            : () => context.push(
                                AppRoutes.providerProfile(summary.otherUserId),
                              ),
                        icon: const Icon(Icons.person_outline_rounded),
                        tooltip: 'Profili gör',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: messages.when(
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'İlk mesajı gönder.',
                    message:
                        'Fiyatı, zamanı ve hizmet detaylarını bu ilan üzerinden konuşabilirsin.',
                  );
                }
                final newestFirst = [...items]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                _scrollToNewestAfterLayout(newestFirst.length);
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: newestFirst.length,
                  itemBuilder: (context, index) {
                    final item = newestFirst[index];
                    final mine = item.senderId == currentUserId;
                    final isOldestMessageOfDay =
                        index == newestFirst.length - 1 ||
                        !_isSameDay(
                          item.createdAt,
                          newestFirst[index + 1].createdAt,
                        );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isOldestMessageOfDay)
                          _DateSeparator(date: item.createdAt),
                        Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 310),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.turquoise
                                  : AppColors.surface,
                              border: Border.all(
                                color: mine
                                    ? AppColors.turquoise
                                    : AppColors.outline,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(mine ? 18 : 5),
                                bottomRight: Radius.circular(mine ? 5 : 18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (item.body.isNotEmpty)
                                  Text(
                                    item.body,
                                    style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                for (final attachment in item.attachments)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        attachment.url,
                                        headers: {
                                          if (apiClient.bearerToken != null)
                                            'Authorization':
                                                'Bearer ${apiClient.bearerToken}',
                                        },
                                        width: 260,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox(
                                              width: 220,
                                              height: 90,
                                              child: Center(
                                                child: Text(
                                                  'Fotoğraf açılamadı',
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  _timeLabel(item.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: mine
                                            ? Colors.white70
                                            : AppColors.muted,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Mesajlar yüklenemedi: $error')),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingImage != null)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.image_outlined),
                      title: Text(
                        _pendingImage!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: _sending
                            ? null
                            : () => setState(() => _pendingImage = null),
                        icon: const Icon(Icons.close),
                        tooltip: 'Fotoğrafı kaldır',
                      ),
                    ),
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed: _sending ? null : _pickImage,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.turquoise,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Mesaj yaz',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _dateLabel(date),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Bugün';
  if (difference == 1) return 'Dün';
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

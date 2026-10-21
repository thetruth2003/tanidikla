import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/marketplace/application/marketplace_controller.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingByIdProvider(listingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('İlan Detayı'),
        actions: [
          IconButton(
            onPressed: () => _toggleFavorite(context, ref),
            icon: Icon(
              ref.watch(favoriteListingIdsProvider).contains(listingId)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
            tooltip: 'Kaydet',
          ),
          IconButton(
            onPressed: () => _showActions(context, ref),
            icon: const Icon(Icons.more_vert),
            tooltip: 'Bildir veya engelle',
          ),
        ],
      ),
      body: listing.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('İlan bulunamadı.'));
          }
          if (item.bundleId == null || item.bundleItemCount <= 1) {
            return _ListingDetailsPager(items: [item]);
          }
          return _BundleDetails(bundleId: item.bundleId!);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<ServiceListing?> _listing(WidgetRef ref) =>
      ref.read(listingByIdProvider(listingId).future);

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    if (apiAuthSession.initialized && !apiAuthSession.isAuthenticated) {
      context.push(AppRoutes.authFor(AppRoutes.listingDetail(listingId)));
      return;
    }
    try {
      final item = await _listing(ref);
      if (item == null) return;
      final parentId = item.bundleId ?? listingId;
      final favorite = ref.read(favoriteListingIdsProvider).contains(parentId);
      final client = ref.read(marketplaceClientProvider);
      if (favorite) {
        await client.unfavorite(parentId);
      } else {
        await client.favorite(parentId);
      }
      ref.invalidate(favoriteListingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              favorite ? 'Favorilerden çıkarıldı.' : 'Favorilere eklendi.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İşlem yapılamadı: $error')));
      }
    }
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final item = await _listing(ref);
    if (item == null || !context.mounted) return;
    final ownListing = apiAuthSession.currentUser?.id == item.ownerId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Bağlantıyı kopyala'),
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            if (!ownListing && apiAuthSession.isAuthenticated) ...[
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Telefonu göster'),
                onTap: () => Navigator.pop(sheetContext, 'phone'),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Hizmeti değerlendir'),
                onTap: () => Navigator.pop(sheetContext, 'review'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('İlanı bildir'),
                onTap: () => Navigator.pop(sheetContext, 'report'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Kullanıcıyı engelle'),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final parentId = item.bundleId ?? listingId;
    switch (action) {
      case 'copy':
        final webBase = apiClient.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
        await Clipboard.setData(
          ClipboardData(text: '$webBase/ilan/${item.bundleId ?? listingId}'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı.')));
        }
        break;
      case 'review':
        await _review(context, ref, parentId, item.ownerId);
        break;
      case 'phone':
        await _revealPhone(context, item.ownerId);
        break;
      case 'report':
        await _report(context, ref, parentId);
        break;
      case 'block':
        await _block(context, ref, item.ownerId);
        break;
    }
  }

  Future<void> _revealPhone(BuildContext context, String ownerId) async {
    try {
      final data = await apiClient.post('/profiles/$ownerId/phone-reveal');
      final phone = data['phone_e164']?.toString() ?? '';
      if (!context.mounted || phone.isEmpty) return;
      final copy = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Telefon numarası'),
          content: SelectableText(phone),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Kapat'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Kopyala'),
            ),
          ],
        ),
      );
      if (copy == true) await Clipboard.setData(ClipboardData(text: phone));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Telefon gösterilemedi: $error')),
        );
      }
    }
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String parentId,
    String ownerId,
  ) async {
    Map<String, dynamic>? existing;
    try {
      existing = await ref
          .read(marketplaceClientProvider)
          .ownReview(ownerId: ownerId, listingId: parentId);
    } catch (_) {}
    if (!context.mounted) return;
    final controller = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );
    var rating = double.tryParse(existing?['rating']?.toString() ?? '') ?? 5.0;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Hizmeti değerlendir'
                : 'Değerlendirmeni düzenle',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<double>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Puan'),
                items: [5, 4.5, 4, 3.5, 3, 2.5, 2, 1.5, 1]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value.toDouble(),
                        child: Text('$value yıldız'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => rating = value ?? 5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Yorumun',
                  hintText: 'Deneyimini kısaca anlat',
                ),
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
    if (accepted == true && context.mounted) {
      final comment = controller.text.trim();
      if (comment.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum en az 3 karakter olmalı.')),
        );
        controller.dispose();
        return;
      }
      try {
        await ref
            .read(marketplaceClientProvider)
            .review(
              reviewId: existing?['id']?.toString(),
              listingId: parentId,
              rating: rating,
              comment: comment,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing == null
                    ? 'Değerlendirmen yayınlandı.'
                    : 'Değerlendirmen güncellendi.',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gönderilemedi: $error')));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    String parentId,
  ) async {
    final controller = TextEditingController();
    var reason = 'inappropriate';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('İlanı bildir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Neden'),
                items: const [
                  DropdownMenuItem(
                    value: 'inappropriate',
                    child: Text('Uygunsuz içerik'),
                  ),
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(
                    value: 'fraud',
                    child: Text('Dolandırıcılık şüphesi'),
                  ),
                  DropdownMenuItem(
                    value: 'safety',
                    child: Text('Güvenlik riski'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Diğer')),
                ],
                onChanged: (value) =>
                    setState(() => reason = value ?? 'inappropriate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'İncelememize yardımcı olacak ayrıntı',
                ),
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
              child: const Text('Bildir'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      try {
        await ref
            .read(marketplaceClientProvider)
            .reportListing(
              listingId: parentId,
              reason: reason,
              details: controller.text.trim(),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bildirimin incelemeye alındı.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Bildirilemedi: $error')));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _block(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kullanıcı engellensin mi?'),
        content: const Text(
          'Birbirinizin ilanlarını göremez ve yeni mesaj gönderemezsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await ref.read(marketplaceClientProvider).blockUser(ownerId);
      ref.invalidate(activeListingsProvider);
      if (context.mounted) context.go(AppRoutes.discovery);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Engellenemedi: $error')));
      }
    }
  }
}

class _BundleDetails extends ConsumerWidget {
  const _BundleDetails({required this.bundleId});

  final String bundleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(listingBundleProvider(bundleId));
    return bundle.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('İlan paketi bulunamadı.'))
          : _ListingDetailsPager(items: items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }
}

class _ListingDetailsPager extends StatefulWidget {
  const _ListingDetailsPager({required this.items});

  final List<ServiceListing> items;

  @override
  State<_ListingDetailsPager> createState() => _ListingDetailsPagerState();
}

class _ListingDetailsPagerState extends State<_ListingDetailsPager> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.items.length > 1)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tek ilan • ${widget.items.length} hizmet ihtiyacı',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${_currentPage + 1} / ${widget.items.length}'),
              ],
            ),
          ),
        Expanded(
          child: PageView.builder(
            itemCount: widget.items.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) => _ListingDetails(
              listing: widget.items[index],
              pageIndex: index,
              pageCount: widget.items.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListingDetails extends ConsumerWidget {
  const _ListingDetails({
    required this.listing,
    required this.pageIndex,
    required this.pageCount,
  });

  final ServiceListing listing;
  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffer = listing.type == ListingType.serviceOffer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              AppIconBadge(
                icon: categoryIcon(listing.category),
                size: 104,
                backgroundColor: AppColors.aquaSoft,
              ),
              const SizedBox(height: 12),
              if (listing.availableNow)
                const AppStatusPill(
                  label: 'Şu an müsait',
                  icon: Icons.circle,
                  backgroundColor: Color(0xFFE6F6EC),
                  foregroundColor: AppColors.success,
                ),
              const SizedBox(height: 10),
              Text(
                listing.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                listing.priceLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.turquoiseDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${listing.locationLabel} · ${listing.distanceKm.toStringAsFixed(1)} km',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${listing.category.label} · ${isOffer ? 'Hizmet veriyor' : 'Hizmet arıyor'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              if (pageCount > 1) ...[
                const SizedBox(height: 8),
                AppStatusPill(
                  label: 'Hizmet ${pageIndex + 1} / $pageCount · Yana kaydır',
                  icon: Icons.swipe_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () => context.push(AppRoutes.providerProfile(listing.ownerId)),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.aqua,
                  foregroundColor: AppColors.turquoiseDeep,
                  child: Text(
                    listing.ownerName.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.ownerName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (listing.ownerReviewCount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: AppColors.rating,
                            ),
                            Text(
                              '${listing.ownerRating.toStringAsFixed(1)} (${listing.ownerReviewCount})',
                            ),
                          ],
                        )
                      else
                        const Text('Profili ve hizmetleri görüntüle'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        _DetailRow(
          icon: Icons.description_outlined,
          title: 'Açıklama',
          value: listing.description,
        ),
        const Divider(),
        if (listing.imageUrls.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                listing.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.aquaSoft,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
          const Divider(),
        ],
        _DetailRow(
          icon: Icons.schedule_outlined,
          title: isOffer ? 'Çalışma saatleri' : 'Gerekli zaman',
          value: listing.availabilityLabel.trim().isEmpty
              ? (isOffer
                    ? 'Müsaitlik görüşülür'
                    : 'Genel ilan • Tarih görüşülür')
              : listing.availabilityLabel,
        ),
        const Divider(),
        _DetailRow(
          icon: Icons.location_on_outlined,
          title: 'Konum bilgisi',
          value:
              '${listing.locationLabel}\n${_locationPrivacyLabel(listing)} · ${listing.distanceKm.toStringAsFixed(1)} km',
        ),
        const Divider(),
        _DetailRow(
          icon: Icons.payments_outlined,
          title: isOffer ? 'Fiyat bilgisi' : 'Bütçe bilgisi',
          value: listing.priceLabel,
        ),
        if (!isOffer &&
            (listing.preferredProviderKind != null ||
                listing.preferredProviderGender != null)) ...[
          const Divider(),
          _DetailRow(
            icon: Icons.tune_outlined,
            title: 'Tercih edilen hizmet veren',
            value: [
              if (listing.preferredProviderKind == 'person') 'Şahıs',
              if (listing.preferredProviderKind == 'business') 'Kurumsal',
              if (listing.preferredProviderGender == 'female') 'Kadın',
              if (listing.preferredProviderGender == 'male') 'Erkek',
            ].join(' • '),
          ),
        ],
        const SizedBox(height: 18),
        if (isOffer) ...[
          FilledButton.icon(
            onPressed: _isOwnListing(listing)
                ? null
                : () => _requestService(context, ref, listing),
            icon: const Icon(Icons.handshake_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _isOwnListing(listing)
                    ? 'Bu hizmet sana ait'
                    : 'Hizmet talebi gönder',
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: _isOwnListing(listing)
              ? null
              : () => _startConversation(context, ref, listing),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              _isOwnListing(listing) ? 'Bu ilan sana ait' : 'Mesaj gönder',
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              context.push(AppRoutes.providerProfile(listing.ownerId)),
          icon: const Icon(Icons.person_outline),
          label: const Text('Profili görüntüle'),
        ),
      ],
    );
  }

  bool _isOwnListing(ServiceListing listing) {
    return apiAuthSession.currentUser?.id == listing.ownerId;
  }

  Future<void> _requestService(
    BuildContext context,
    WidgetRef ref,
    ServiceListing listing,
  ) async {
    final returnTo = AppRoutes.listingDetail(listing.bundleId ?? listing.id);
    if (!apiAuthSession.isAuthenticated) {
      context.push(AppRoutes.authFor(returnTo));
      return;
    }
    try {
      final profileComplete = await ref.read(
        currentUserProfileCompleteProvider.future,
      );
      if (!profileComplete) {
        if (context.mounted) {
          context.push(AppRoutes.profileCompletionFor(returnTo));
        }
        return;
      }
      final engagement = await apiClient.post(
        '/engagements',
        body: {
          'listing_id': listing.bundleId ?? listing.id,
          'listing_item_id': listing.id,
        },
      );
      ref.invalidate(conversationSummariesProvider);
      if (context.mounted) {
        context.push(
          AppRoutes.chat(engagement['conversation_id']?.toString() ?? ''),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hizmet talebi gönderilemedi: $error')),
      );
    }
  }

  Future<void> _startConversation(
    BuildContext context,
    WidgetRef ref,
    ServiceListing listing,
  ) async {
    // Widget/demo mode has no persisted API session. Keep its fake repositories
    // consistent without weakening the production auth/profile gate.
    if (!apiAuthSession.initialized) {
      final conversationId = await ref
          .read(messageRepositoryProvider)
          .startListingConversation(listing.bundleId ?? listing.id);
      if (context.mounted) context.push(AppRoutes.chat(conversationId));
      return;
    }
    if (!apiAuthSession.isAuthenticated) {
      context.push(AppRoutes.authFor(AppRoutes.listingDetail(listing.id)));
      return;
    }
    try {
      final profileComplete = await ref.read(
        currentUserProfileCompleteProvider.future,
      );
      if (!profileComplete) {
        if (context.mounted) {
          context.push(
            AppRoutes.profileCompletionFor(AppRoutes.listingDetail(listing.id)),
          );
        }
        return;
      }

      final conversationId = await ref
          .read(messageRepositoryProvider)
          .startListingConversation(listing.bundleId ?? listing.id);
      ref.invalidate(conversationSummariesProvider);
      if (context.mounted) context.push(AppRoutes.chat(conversationId));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konuşma başlatılamadı: $error')));
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted, size: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

String _locationPrivacyLabel(ServiceListing listing) {
  if (listing.locationPrecision == LocationPrecision.neighborhood) {
    return 'Yakın konum • Tam adres paylaşılmadı';
  }
  if (listing.type == ListingType.serviceRequest) {
    return 'Net konum • Tam adres korumalı';
  }
  return 'İşletme konumu açık';
}

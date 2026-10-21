import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/listing_card.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  ListingType _type = ListingType.serviceOffer;
  String? _removingId;

  Future<void> _remove(ServiceListing listing) async {
    final id = listing.bundleId ?? listing.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlan kaldırılsın mı?'),
        content: Text('“${listing.title}” kalıcı olarak kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('İlanı kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removingId = id);
    try {
      await ref.read(listingRepositoryProvider).removeListing(id);
      ref.invalidate(activeListingsProvider);
      ref.invalidate(listingsByOwnerProvider);
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İlan kaldırıldı.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İlan kaldırılamadı: $error')));
      }
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = ref.watch(currentUserIdProvider);
    final listings = ownerId == null
        ? const AsyncValue<List<ServiceListing>>.data([])
        : ref.watch(listingsByOwnerProvider(ownerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Aktif İlanlarım')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          AppSegmentedControl<ListingType>(
            segments: const [
              AppSegment(
                value: ListingType.serviceOffer,
                label: 'Hizmet Veriyorum',
              ),
              AppSegment(
                value: ListingType.serviceRequest,
                label: 'Hizmet Arıyorum',
              ),
            ],
            selected: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 14),
          listings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('İlanlar yüklenemedi: $error'),
            data: (items) {
              final filtered = items
                  .where((listing) => listing.type == _type)
                  .toList(growable: false);
              if (filtered.isEmpty) {
                return const AppInfoBanner(
                  title: 'Aktif ilanın yok',
                  message:
                      'İlan Ver sekmesinden yeni bir ilan oluşturabilirsin.',
                  icon: Icons.campaign_outlined,
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < filtered.length; index++) ...[
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          ListingCard(
                            listing: filtered[index],
                            isOwnListing: true,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => context.push(
                                  AppRoutes.editListing(
                                    filtered[index].bundleId ??
                                        filtered[index].id,
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Düzenle'),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _removingId ==
                                        (filtered[index].bundleId ??
                                            filtered[index].id)
                                    ? null
                                    : () => _remove(filtered[index]),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Kaldır'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (index != filtered.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/notifications/application/notification_controller.dart';
import 'package:ankara_proje/features/profile/domain/provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileComplete = ref.watch(currentUserProfileCompleteProvider);
    if (profileComplete.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (shouldOpenProfileCompletion(profileComplete)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.profileCompletionFor(AppRoutes.profile));
        }
      });
      return const Center(child: CircularProgressIndicator());
    }

    final profile = ref.watch(currentUserProfileProvider);
    final ownerId = ref.watch(currentUserIdProvider) ?? '';
    final listings = ref.watch(listingsByOwnerProvider(ownerId));
    final unreadCount =
        ref.watch(notificationInboxProvider).value?.unreadCount ?? 0;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
            child: AppTopBar(
              title: 'Profilim',
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
          ),
          Expanded(
            child: profile.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              data: (item) => listings.when(
                data: (ownerListings) => _ProfileOverview(
                  profile: item,
                  listings: ownerListings,
                  onEdit: () => context.push(AppRoutes.providerProfileSetup),
                  onPreferences: () =>
                      context.push(AppRoutes.profilePreferences),
                  onListings: () => context.push(AppRoutes.myListings),
                  onFavorites: () => context.push(AppRoutes.favorites),
                  onPhone: () => _phoneSettings(context, ref),
                  onSignOut: () => _signOut(context, ref),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('$error')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('$error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(apiAuthSessionProvider).logout();
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(currentUserProfileCompleteProvider);
    ref.invalidate(listingsByOwnerProvider);
    ref.invalidate(activeListingsProvider);
    if (context.mounted) context.go(AppRoutes.auth);
  }

  Future<void> _phoneSettings(BuildContext context, WidgetRef ref) async {
    final user = apiAuthSession.currentUser;
    if (user == null) return;
    final controller = TextEditingController(text: user.phoneE164);
    var visible = user.phoneVisible;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Telefon gizliliği'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  hintText: '+905xxxxxxxxx',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: visible,
                onChanged: (value) => setState(() => visible = value),
                title: const Text('Numaramı göster'),
                subtitle: const Text(
                  'Kapalıyken numaran hiçbir public yanıtta yer almaz.',
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
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      controller.dispose();
      return;
    }
    try {
      await apiClient.put(
        '/profile',
        body: {
          'display_name': user.displayName,
          'bio': user.bio,
          'city': user.city,
          'district': user.district,
          'phone_e164': controller.text.trim(),
          'phone_visible': visible,
        },
      );
      await apiAuthSession.refreshUser();
      ref.invalidate(currentUserProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon gizliliği kaydedildi.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $error')));
      }
    } finally {
      controller.dispose();
    }
  }
}

class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({
    required this.profile,
    required this.listings,
    required this.onEdit,
    required this.onPreferences,
    required this.onListings,
    required this.onFavorites,
    required this.onPhone,
    required this.onSignOut,
  });

  final ProviderProfile profile;
  final List<ServiceListing> listings;
  final VoidCallback onEdit;
  final VoidCallback onPreferences;
  final VoidCallback onListings;
  final VoidCallback onFavorites;
  final VoidCallback onPhone;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final offers = listings
        .where((item) => item.type == ListingType.serviceOffer)
        .length;
    final requests = listings
        .where((item) => item.type == ListingType.serviceRequest)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.aqua,
              foregroundColor: AppColors.turquoiseDeep,
              backgroundImage: profile.avatarUrl == null
                  ? null
                  : NetworkImage(profile.avatarUrl!),
              child: profile.avatarUrl == null
                  ? Text(
                      _initials(profile.displayName),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.district,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.rating,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.reviewCount == 0
                            ? 'Henüz değerlendirme yok'
                            : '${profile.rating.toStringAsFixed(1)} (${profile.reviewCount} değerlendirme)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _ProfileStat(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                value: '${profile.completedJobs}',
                label: 'Tamamlanan',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                icon: Icons.work_outline_rounded,
                color: const Color(0xFF2E70C5),
                value: '$offers',
                label: 'Verilen Hizmet',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _ProfileStat(
                icon: Icons.campaign_outlined,
                color: AppColors.turquoiseDark,
                value: '$requests',
                label: 'İş İhtiyacı',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _ProfileMenuRow(
          icon: Icons.edit_rounded,
          color: AppColors.turquoiseDark,
          title: 'Profilimi Düzenle',
          subtitle: 'Fotoğraf, ad, il, ilçe, cinsiyet ve hakkımda',
          onTap: onEdit,
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.notifications_active_outlined,
          color: AppColors.turquoiseDark,
          title: 'İlgi ve Bildirim Alanlarım',
          subtitle: 'Hizmet almak ve vermek istediğin kategoriler',
          onTap: onPreferences,
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.bookmark_rounded,
          color: AppColors.turquoiseDark,
          title: 'Favorilerim',
          subtitle: 'Kaydettiğin ilanları görüntüle',
          onTap: onFavorites,
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.work_outline_rounded,
          color: const Color(0xFF2E70C5),
          title: 'Aktif İlanlarım',
          subtitle: 'Hizmet ve iş ilanlarını yönet',
          onTap: onListings,
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.handshake_outlined,
          color: AppColors.turquoiseDark,
          title: 'İşlerim',
          subtitle: 'Talepleri, işleri ve değerlendirmeleri yönet',
          onTap: () => context.push(AppRoutes.engagements),
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.phone_outlined,
          color: AppColors.turquoiseDark,
          title: 'Telefon Gizliliği',
          subtitle: apiAuthSession.currentUser?.phoneVisible == true
              ? 'Numaran yalnız açık istekle gösteriliyor'
              : 'Numaran gizli',
          onTap: onPhone,
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.security_outlined,
          color: AppColors.turquoiseDark,
          title: 'Hesap ve Güvenlik',
          subtitle: 'E-posta, telefon, şifre ve aktif oturumlar',
          onTap: () => context.push(AppRoutes.accountSecurity),
        ),
        const SizedBox(height: 9),
        _ProfileMenuRow(
          icon: Icons.shield_outlined,
          color: AppColors.turquoiseDark,
          title: 'Gizlilik ve KVKK',
          subtitle: 'Yasal metinler, veri kopyası ve hesap silme',
          onTap: () => context.push(AppRoutes.privacy),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onSignOut,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Çıkış Yap'),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.characters.first)
      .join()
      .toUpperCase();
}

bool shouldOpenProfileCompletion(AsyncValue<bool> profileComplete) {
  return !profileComplete.isLoading &&
      profileComplete.hasValue &&
      !profileComplete.requireValue;
}

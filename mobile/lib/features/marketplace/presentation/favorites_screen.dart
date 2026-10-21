import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/features/marketplace/application/marketplace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Favoriler yüklenemedi',
          message: error.toString(),
          action: () => ref.invalidate(favoriteListingsProvider),
        ),
        data: (items) => items.isEmpty
            ? _MessageState(
                icon: Icons.bookmark_border_rounded,
                title: 'Henüz favorin yok',
                message: 'Beğendiğin ilanları kaydedip burada bulabilirsin.',
                action: () => context.go(AppRoutes.discovery),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(favoriteListingsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.aqua,
                          foregroundColor: AppColors.turquoiseDeep,
                          child: Icon(Icons.bookmark_rounded),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${item.ownerName} • ${item.district}\n${item.priceLabel}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push(AppRoutes.listingDetail(item.id)),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.turquoise),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: action, child: const Text('Devam et')),
          ],
        ),
      ),
    );
  }
}

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileRequiredGate extends ConsumerWidget {
  const ProfileRequiredGate({
    required this.returnTo,
    required this.child,
    super.key,
  });

  final String returnTo;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = ref.watch(currentUserProfileCompleteProvider);
    return complete.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: (isComplete) {
        if (isComplete) return child;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(AppRoutes.profileCompletionFor(returnTo));
          }
        });
        return const Center(child: CircularProgressIndicator());
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 46),
              const SizedBox(height: 12),
              const Text(
                'Profil durumu kontrol edilemedi.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(currentUserProfileCompleteProvider),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

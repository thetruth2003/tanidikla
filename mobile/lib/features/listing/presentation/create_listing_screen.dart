import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  bool _isRequest = true;

  void _continue() {
    context.push(
      _isRequest
          ? AppRoutes.createServiceRequest
          : AppRoutes.createServiceOffer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AppTopBar(title: 'İlan Oluştur'),
            const SizedBox(height: 22),
            Text(
              'Ne yapmak istiyorsun?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Seçimini yaptıktan sonra ilan detaylarını adım adım dolduracaksın.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ListingModeCard(
                    icon: Icons.handyman_rounded,
                    title: 'Hizmet Veriyorum',
                    subtitle: 'Yeteneklerini paylaş',
                    selected: !_isRequest,
                    onTap: () => setState(() => _isRequest = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ListingModeCard(
                    icon: Icons.search_rounded,
                    title: 'Hizmet Alıyorum',
                    subtitle: 'İhtiyacını duyur',
                    selected: _isRequest,
                    onTap: () => setState(() => _isRequest = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingModeCard extends StatelessWidget {
  const _ListingModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.aquaSoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.turquoise : AppColors.outline,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 122,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconBadge(icon: icon, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 9,
                  right: 9,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.turquoise,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = path.startsWith(AppRoutes.createListing)
        ? 1
        : path.startsWith(AppRoutes.messages)
        ? 2
        : path.startsWith(AppRoutes.profile)
        ? 3
        : switch (path) {
            _ => 0,
          };

    return Scaffold(
      body: child,
      bottomNavigationBar: _MinimalNavigationBar(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.discovery);
            case 1:
              context.go(AppRoutes.createListing);
            case 2:
              context.go(AppRoutes.messages);
            case 3:
              context.go(AppRoutes.profile);
          }
        },
      ),
    );
  }
}

class _MinimalNavigationBar extends StatelessWidget {
  const _MinimalNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.explore_outlined, selected: Icons.explore, label: 'Keşfet'),
    (icon: Icons.add_box_outlined, selected: Icons.add_box, label: 'İlan Ver'),
    (
      icon: Icons.chat_bubble_outline_rounded,
      selected: Icons.chat_bubble_rounded,
      label: 'Mesajlar',
    ),
    (
      icon: Icons.person_outline_rounded,
      selected: Icons.person,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(top: 7),
        child: SizedBox(
          height: 67,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _NavigationItem(
                    item: _items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selected, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.turquoiseDark : AppColors.ink;
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 30,
            decoration: BoxDecoration(
              color: selected ? AppColors.aqua : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              selected ? item.selected : item.icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              color: selected ? AppColors.turquoiseDark : AppColors.muted,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

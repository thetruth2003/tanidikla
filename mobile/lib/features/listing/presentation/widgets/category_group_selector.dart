import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:flutter/material.dart';

class CategoryGroupSelector extends StatelessWidget {
  const CategoryGroupSelector({
    required this.selectedCategory,
    required this.onChanged,
    super.key,
  });

  final ServiceCategory? selectedCategory;
  final ValueChanged<ServiceCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final group in ServiceCategoryGroup.values) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: PageStorageKey(group.id),
              initiallyExpanded: group == ServiceCategoryGroup.homeTechnical,
              leading: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.aquaSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryGroupIcon(group),
                  color: AppColors.turquoiseDark,
                ),
              ),
              title: Text(
                group.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${group.categories.length} seçenek'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in group.categories)
                        FilterChip(
                          avatar: Icon(
                            selectedCategory == category
                                ? Icons.check_circle_rounded
                                : categoryIcon(category),
                            size: 18,
                          ),
                          label: Text(category.label),
                          selected: selectedCategory == category,
                          showCheckmark: false,
                          onSelected: (_) => onChanged(category),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

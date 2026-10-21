import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/profile/data/turkey_location_catalog.dart';
import 'package:ankara_proje/features/profile/domain/profile_settings.dart';
import 'package:flutter/material.dart';

class ProfileLocationFields extends StatelessWidget {
  const ProfileLocationFields({
    required this.catalog,
    required this.city,
    required this.district,
    required this.onCityChanged,
    required this.onDistrictChanged,
    super.key,
  });

  final TurkeyLocationCatalog catalog;
  final String? city;
  final String? district;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;

  @override
  Widget build(BuildContext context) {
    final districts = catalog.districtsFor(city);
    final safeCity = catalog.provinces.contains(city) ? city : null;
    final safeDistrict = districts.contains(district) ? district : null;
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: safeCity,
          isExpanded: true,
          menuMaxHeight: 440,
          decoration: const InputDecoration(
            labelText: 'İl *',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: [
            for (final province in catalog.provinces)
              DropdownMenuItem(value: province, child: Text(province)),
          ],
          onChanged: onCityChanged,
          validator: (value) => value == null ? 'İl seçmelisin.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(safeCity),
          initialValue: safeDistrict,
          isExpanded: true,
          menuMaxHeight: 440,
          decoration: const InputDecoration(
            labelText: 'İlçe *',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: [
            for (final item in districts)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: safeCity == null ? null : onDistrictChanged,
          validator: (value) => value == null ? 'İlçe seçmelisin.' : null,
        ),
      ],
    );
  }
}

class GenderSelectionField extends StatelessWidget {
  const GenderSelectionField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final GenderOption? value;
  final ValueChanged<GenderOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<GenderOption>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Cinsiyet (isteğe bağlı)',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: [
        for (final option in GenderOption.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class CategoryPreferencesEditor extends StatelessWidget {
  const CategoryPreferencesEditor({
    required this.receiveCategoryIds,
    required this.provideCategoryIds,
    required this.onReceiveChanged,
    required this.onProvideChanged,
    this.compact = false,
    super.key,
  });

  final Set<String> receiveCategoryIds;
  final Set<String> provideCategoryIds;
  final ValueChanged<Set<String>> onReceiveChanged;
  final ValueChanged<Set<String>> onProvideChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreferenceGroup(
          title: 'Hizmet almak istediğim alanlar',
          description:
              'Seçtiğin başlıklardaki yeni hizmet ilanları sana gösterilir.',
          icon: Icons.search_rounded,
          selected: receiveCategoryIds,
          onChanged: onReceiveChanged,
          compact: compact,
        ),
        const SizedBox(height: 14),
        _PreferenceGroup(
          title: 'Hizmet vermek istediğim alanlar',
          description:
              'Seçtiğin başlıkların altındaki yeni iş taleplerinde bildirim alırsın.',
          icon: Icons.work_outline_rounded,
          selected: provideCategoryIds,
          onChanged: onProvideChanged,
          compact: compact,
        ),
        const SizedBox(height: 10),
        const AppInfoBanner(
          title: 'Üst başlık bütün alt alanları kapsar',
          message:
              'Örneğin Eğitim seçimi; yabancı dil, matematik/okul dersi ve diğer eğitim ilanlarını kapsar. Bilgisayar ve IT seçimi; format, modem ve teknik destek ilanlarını kapsar.',
          icon: Icons.notifications_active_outlined,
        ),
      ],
    );
  }
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onChanged,
    required this.compact,
  });

  final String title;
  final String description;
  final IconData icon;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.turquoiseDark),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in ServiceCategoryGroup.values)
                FilterChip(
                  avatar: Icon(categoryGroupIcon(group), size: 17),
                  label: Text(group.label),
                  selected: selected.contains(group.id),
                  onSelected: (checked) {
                    final next = {...selected};
                    checked ? next.add(group.id) : next.remove(group.id);
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EditListingScreen extends ConsumerWidget {
  const EditListingScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingByIdProvider(listingId));
    return Scaffold(
      appBar: AppBar(title: const Text('İlanı Düzenle')),
      body: listing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('İlan yüklenemedi: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('İlan bulunamadı.'));
          }
          if (item.ownerId != ref.watch(currentUserIdProvider)) {
            return const Center(
              child: Text('Yalnızca kendi ilanını düzenleyebilirsin.'),
            );
          }
          final parentId = item.bundleId ?? item.id;
          if (item.bundleId == null || item.bundleItemCount <= 1) {
            return _EditListingForm(parentId: parentId, items: [item]);
          }
          final bundle = ref.watch(listingBundleProvider(parentId));
          return bundle.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('İlan sayfaları yüklenemedi: $error')),
            data: (items) => _EditListingForm(
              key: ValueKey(parentId),
              parentId: parentId,
              items: items,
            ),
          );
        },
      ),
    );
  }
}

class _EditListingForm extends ConsumerStatefulWidget {
  const _EditListingForm({
    required this.parentId,
    required this.items,
    super.key,
  });

  final String parentId;
  final List<ServiceListing> items;

  @override
  ConsumerState<_EditListingForm> createState() => _EditListingFormState();
}

class _EditListingFormState extends ConsumerState<_EditListingForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _districtController;
  late final TextEditingController _neighborhoodController;
  late final List<_EditableItem> _items;
  late double _serviceRadiusKm;
  late bool _limitServiceDistance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _districtController = TextEditingController(
      text: widget.items.first.district,
    );
    _neighborhoodController = TextEditingController(
      text: widget.items.first.neighborhood,
    );
    _items = widget.items.map(_EditableItem.new).toList();
    _limitServiceDistance = widget.items.first.serviceRadiusKm != null;
    _serviceRadiusKm = (widget.items.first.serviceRadiusKm ?? 25).toDouble();
  }

  @override
  void dispose() {
    _districtController.dispose();
    _neighborhoodController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = [
        for (final item in _items)
          item.source.copyWith(
            title: item.title.text.trim(),
            description: item.description.text.trim(),
            category: item.category,
            priceAmount:
                item.pricingUnit == PricingUnit.negotiable ||
                    item.pricingUnit == PricingUnit.free
                ? 0
                : double.parse(item.price.text.trim().replaceAll(',', '.')),
            pricingUnit: item.pricingUnit,
            priceIncludesVat: item.priceIncludesVat,
            district: _districtController.text.trim(),
            neighborhood: _neighborhoodController.text.trim(),
            availableNow: item.availableNow,
            availabilityLabel: item.schedule.text.trim(),
            serviceRadiusKm: _limitServiceDistance
                ? _serviceRadiusKm.round()
                : null,
            clearServiceRadius: !_limitServiceDistance,
          ),
      ];
      await ref
          .read(listingRepositoryProvider)
          .updateListings(widget.parentId, updated);
      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İlan kaydedilemedi: $error')));
      setState(() => _saving = false);
    }
  }

  void _addItem() {
    if (_items.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bir ilanda en fazla 20 hizmet olabilir.'),
        ),
      );
      return;
    }
    setState(() => _items.add(_EditableItem.fresh(_items.first.source)));
  }

  void _removeItem(int index) {
    if (_items.length == 1) return;
    final removed = _items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _moveItem(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
  }

  Future<void> _remove() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İlan kaldırılsın mı?'),
        content: const Text(
          'İlan harita ve listelerden kaldırılacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('İlanı Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(listingRepositoryProvider).removeListing(widget.parentId);
      ref.invalidate(activeListingsProvider);
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İlan kaldırılamadı: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.items.first.type;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppSurfaceCard(
            color: const Color(0xFFF7FBF8),
            child: Row(
              children: [
                const AppStatusPill(
                  label: 'Yayında',
                  backgroundColor: Color(0xFFE6F6EC),
                  foregroundColor: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type == ListingType.serviceOffer
                        ? 'Hizmet ilanı aktif ve yayında.'
                        : 'Hizmet talebi aktif ve yayında.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _items.length; index++) ...[
            _ListingItemEditor(
              item: _items[index],
              index: index,
              count: _items.length,
              onChanged: () => setState(() {}),
              onRemove: () => _removeItem(index),
              onMoveUp: index == 0 ? null : () => _moveItem(index, -1),
              onMoveDown: index == _items.length - 1
                  ? null
                  : () => _moveItem(index, 1),
            ),
            if (index != _items.length - 1) const SizedBox(height: 14),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saving || _items.length >= 20 ? null : _addItem,
            icon: const Icon(Icons.add_rounded),
            label: Text('Alt hizmet ekle (${_items.length}/20)'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _districtController,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'İlçe / şehir *'),
            validator: _requiredTwoCharacters,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _neighborhoodController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Mahalle / yakın bölge *',
            ),
            validator: _requiredTwoCharacters,
          ),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Hizmet mesafesi belirle'),
                  subtitle: const Text(
                    'Online hizmetlerde veya her yere uygun ilanlarda kapalı bırak.',
                  ),
                  value: _limitServiceDistance,
                  onChanged: (value) =>
                      setState(() => _limitServiceDistance = value),
                ),
                if (_limitServiceDistance)
                  Slider(
                    value: _serviceRadiusKm,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${_serviceRadiusKm.round()} km',
                    onChanged: (value) =>
                        setState(() => _serviceRadiusKm = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _saving ? null : _remove,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.outline),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('İlanı Kaldır'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Değişiklikleri kaydet'),
          ),
        ],
      ),
    );
  }
}

class _ListingItemEditor extends StatelessWidget {
  const _ListingItemEditor({
    required this.item,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _EditableItem item;
  final int index;
  final int count;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count > 1) ...[
          Row(
            children: [
              AppIconBadge(icon: categoryIcon(item.category), size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hizmet sayfası ${index + 1} / $count',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Yukarı taşı',
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Aşağı taşı',
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Hizmeti sil',
                onPressed: count > 1 ? onRemove : null,
                color: AppColors.danger,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<ServiceCategory>(
          isExpanded: true,
          initialValue: item.category,
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: [
            for (final category in ServiceCategory.values)
              DropdownMenuItem(
                value: category,
                child: Text(
                  category.fullLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            item.category = value ?? item.category;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: item.title,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Başlık *'),
          validator: (value) =>
              (value?.trim().length ?? 0) < 3 ? 'En az 3 karakter yaz.' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: item.description,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Açıklama *',
            alignLabelWithHint: true,
          ),
          validator: (value) => (value?.trim().length ?? 0) < 10
              ? 'En az 10 karakter yaz.'
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: item.schedule,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'Tahmini süre / uygun zaman (isteğe bağlı)',
            prefixIcon: Icon(Icons.schedule_outlined),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<PricingUnit>(
          initialValue: item.pricingUnit,
          decoration: const InputDecoration(labelText: 'Fiyat türü'),
          items: const [
            DropdownMenuItem(
              value: PricingUnit.fixed,
              child: Text('Toplam ücret'),
            ),
            DropdownMenuItem(value: PricingUnit.hourly, child: Text('Saatlik')),
            DropdownMenuItem(value: PricingUnit.daily, child: Text('Günlük')),
            DropdownMenuItem(
              value: PricingUnit.perSession,
              child: Text('Seans başına'),
            ),
            DropdownMenuItem(
              value: PricingUnit.startingAt,
              child: Text('Başlangıç fiyatı'),
            ),
            DropdownMenuItem(
              value: PricingUnit.negotiable,
              child: Text('Teklif alınır'),
            ),
            DropdownMenuItem(value: PricingUnit.free, child: Text('Ücretsiz')),
          ],
          onChanged: (value) {
            item.pricingUnit = value ?? item.pricingUnit;
            onChanged();
          },
        ),
        if (item.pricingUnit != PricingUnit.negotiable &&
            item.pricingUnit != PricingUnit.free) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: item.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fiyat *',
              prefixText: '₺ ',
            ),
            validator: (value) {
              final amount = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              return amount == null || amount < 0
                  ? 'Geçerli bir fiyat yaz.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fiyat KDV dahil'),
              value: item.priceIncludesVat,
              onChanged: (value) {
                item.priceIncludesVat = value;
                onChanged();
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Şu an müsait / acil'),
            value: item.availableNow,
            onChanged: (value) {
              item.availableNow = value;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _EditableItem {
  _EditableItem(this.source)
    : title = TextEditingController(text: source.title),
      description = TextEditingController(text: source.description),
      schedule = TextEditingController(text: source.availabilityLabel),
      price = TextEditingController(text: _priceText(source.priceAmount)),
      category = source.category,
      pricingUnit = source.pricingUnit,
      priceIncludesVat = source.priceIncludesVat,
      availableNow = source.availableNow;

  _EditableItem.fresh(this.source)
    : title = TextEditingController(),
      description = TextEditingController(),
      schedule = TextEditingController(),
      price = TextEditingController(),
      category = source.category,
      pricingUnit = PricingUnit.fixed,
      priceIncludesVat = false,
      availableNow = false;

  final ServiceListing source;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController schedule;
  final TextEditingController price;
  ServiceCategory category;
  PricingUnit pricingUnit;
  bool priceIncludesVat;
  bool availableNow;

  void dispose() {
    title.dispose();
    description.dispose();
    schedule.dispose();
    price.dispose();
  }
}

String? _requiredTwoCharacters(String? value) =>
    (value?.trim().length ?? 0) < 2 ? 'En az 2 karakter yaz.' : null;

String _priceText(double value) => value.truncateToDouble() == value
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

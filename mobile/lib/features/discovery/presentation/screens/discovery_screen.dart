import 'dart:async';

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/location/user_location.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/listing_card.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/map_preview.dart';
import 'package:ankara_proje/features/notifications/application/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _searchController = TextEditingController();
  Set<String>? _viewportListingIds;
  MapViewportSnapshot? _lastMapViewport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLocationIntro());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryControllerProvider);
    final listings = ref.watch(visibleListingsProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);
    final currentUserId = ref.watch(currentUserIdProvider);
    final unreadCount =
        ref.watch(notificationInboxProvider).value?.unreadCount ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Tanıdıkla',
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
            const SizedBox(height: 6),
            AppSegmentedControl<DiscoveryMode>(
              segments: const [
                AppSegment(
                  value: DiscoveryMode.findService,
                  label: 'Hizmet Bul',
                ),
                AppSegment(value: DiscoveryMode.findWork, label: 'İş Bul'),
              ],
              selected: state.mode,
              onChanged: controller.setMode,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onTap: controller.startMapSearch,
                    onChanged: controller.setSearchQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: state.mode == DiscoveryMode.findService
                          ? 'Hangi hizmeti arıyorsun?'
                          : 'Yakındaki iş taleplerinde ara',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                controller.setSearchQuery('');
                              },
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Aramayı temizle',
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                AppSurfaceCard(
                  padding: EdgeInsets.zero,
                  child: SizedBox.square(
                    dimension: 52,
                    child: IconButton(
                      onPressed: () => _openFilters(context, state, controller),
                      icon: Badge(
                        isLabelVisible: state.activeFilterCount > 0,
                        label: Text('${state.activeFilterCount}'),
                        child: const Icon(Icons.tune_rounded),
                      ),
                      tooltip: 'Filtreler',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final group in ServiceCategoryGroup.values)
                    _CategoryShortcut(
                      label: group.label,
                      icon: categoryGroupIcon(group),
                      selected:
                          state.selectedCategory?.group == group ||
                          state.selectedGroup == group,
                      onTap: () =>
                          _openCategoryGroup(context, group, state, controller),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: listings.when(
                      data: (items) => _buildLoadedResults(
                        context,
                        state,
                        items,
                        currentUserId,
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => AppEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'İlanlar yüklenemedi',
                        message: error.toString(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: state.viewMode == DiscoveryViewMode.map ? 188 : 12,
                    child: _ViewSwitcher(
                      selected: state.viewMode,
                      onChanged: controller.setViewMode,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationIntro() async {
    final service = ref.read(userLocationServiceProvider);
    if (!await service.shouldExplain() || !mounted) return;
    final useLocation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.my_location_rounded, size: 34),
        title: const Text('Yakınındaki ilanları gör'),
        content: const Text(
          'Konum izni yalnızca sana yakın ilanları haritada göstermek ve mesafeyi hesaplamak için kullanılır. Konumun iznin olmadan paylaşılmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.near_me_rounded),
            label: const Text('Konumumu kullan'),
          ),
        ],
      ),
    );
    await service.markExplanationSeen();
    if (useLocation == true) await _requestLocation();
  }

  Future<void> _requestLocation() async {
    final location = await ref
        .read(userLocationServiceProvider)
        .requestCurrent();
    if (!mounted) return;
    ref.invalidate(userLocationProvider);
    ref.invalidate(activeListingsProvider);
    if (location.isFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Konum alınamadı. Telefonunun konum servisini ve uygulama iznini kontrol et.',
          ),
        ),
      );
    }
  }

  Widget _buildLoadedResults(
    BuildContext context,
    DiscoveryState state,
    List<ServiceListing> items,
    String? currentUserId,
  ) {
    if (state.viewMode == DiscoveryViewMode.map) {
      return MapPreview(
        listings: items,
        currentUserId: currentUserId,
        initialViewport: _lastMapViewport,
        onViewportChanged: (viewport) => _lastMapViewport = viewport,
        onViewportListingsChanged: _setViewportListings,
        onListingTap: (listing) {
          _showListingPreview(context, listing, currentUserId);
        },
      );
    }

    final viewportIds = _viewportListingIds;
    final visibleItems = viewportIds == null
        ? items
        : items.where((item) => viewportIds.contains(item.id)).toList();

    if (visibleItems.isEmpty) {
      return _EmptyListings(
        mode: state.mode,
        areaEmpty: viewportIds != null && items.isNotEmpty,
      );
    }

    final Widget list = state.searchQuery.trim().isNotEmpty
        ? _GroupedListingList(
            listings: visibleItems,
            currentUserId: currentUserId,
          )
        : ListView.separated(
            padding: const EdgeInsets.only(bottom: 76),
            itemCount: visibleItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final listing = visibleItems[index];
              return ListingCard(
                listing: listing,
                isOwnListing: listing.ownerId == currentUserId,
                onTap: () => context.push(
                  AppRoutes.listingDetail(listing.bundleId ?? listing.id),
                ),
              );
            },
          );

    if (viewportIds == null) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AreaResultsHeader(count: visibleItems.length),
        const SizedBox(height: 10),
        Expanded(child: list),
      ],
    );
  }

  void _setViewportListings(List<ServiceListing> listings) {
    final nextIds = listings.map((item) => item.id).toSet();
    final currentIds = _viewportListingIds;
    if (currentIds != null &&
        currentIds.length == nextIds.length &&
        currentIds.containsAll(nextIds)) {
      return;
    }
    if (mounted) setState(() => _viewportListingIds = nextIds);
  }

  void _openCategoryGroup(
    BuildContext context,
    ServiceCategoryGroup group,
    DiscoveryState state,
    DiscoveryController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          children: [
            Row(
              children: [
                AppIconBadge(icon: categoryGroupIcon(group), size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: Text('Tüm ${group.label} ilanları'),
              trailing:
                  state.selectedGroup == group && state.selectedCategory == null
                  ? const Icon(Icons.check_circle, color: AppColors.turquoise)
                  : null,
              onTap: () {
                controller.selectGroup(group);
                Navigator.pop(sheetContext);
              },
            ),
            for (final category in group.categories)
              ListTile(
                leading: Icon(categoryIcon(category)),
                title: Text(category.label),
                subtitle: category.isOpenEnded
                    ? const Text('Özel hizmet adını ilan başlığında belirt')
                    : null,
                trailing: state.selectedCategory == category
                    ? const Icon(Icons.check_circle, color: AppColors.turquoise)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  controller.selectCategory(category);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    DiscoveryState state,
    DiscoveryController controller,
  ) async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _DiscoveryFiltersSheet(initialState: state, mode: state.mode),
    );
    if (result == null) return;
    controller.applyFilters(
      group: result.group,
      category: result.category,
      onlyAvailableNow: result.onlyAvailableNow,
      onlyWithWorkingHours: result.onlyWithWorkingHours,
      onlyVatIncluded: result.onlyVatIncluded,
      minPrice: result.minPrice,
      maxPrice: result.maxPrice,
      maxDistanceKm: result.maxDistanceKm,
      minRating: result.minRating,
      pricingUnit: result.pricingUnit,
      locationPrecision: result.locationPrecision,
      providerKind: result.providerKind,
      gender: result.gender,
    );
    if (result.openMap) controller.setViewMode(DiscoveryViewMode.map);
  }

  void _showListingPreview(
    BuildContext context,
    ServiceListing listing,
    String? currentUserId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListingCard(
          listing: listing,
          isOwnListing: listing.ownerId == currentUserId,
          onTap: () {
            Navigator.of(context).pop();
            context.push(
              AppRoutes.listingDetail(listing.bundleId ?? listing.id),
            );
          },
        ),
      ),
    );
  }
}

class _FilterResult {
  const _FilterResult({
    required this.group,
    required this.category,
    required this.onlyAvailableNow,
    required this.onlyWithWorkingHours,
    required this.onlyVatIncluded,
    required this.minPrice,
    required this.maxPrice,
    required this.maxDistanceKm,
    required this.minRating,
    required this.pricingUnit,
    required this.locationPrecision,
    required this.providerKind,
    required this.gender,
    this.openMap = false,
  });

  final ServiceCategoryGroup? group;
  final ServiceCategory? category;
  final bool onlyAvailableNow;
  final bool onlyWithWorkingHours;
  final bool onlyVatIncluded;
  final double? minPrice;
  final double? maxPrice;
  final double? maxDistanceKm;
  final double? minRating;
  final PricingUnit? pricingUnit;
  final LocationPrecision? locationPrecision;
  final String? providerKind;
  final String? gender;
  final bool openMap;
}

class _DiscoveryFiltersSheet extends StatefulWidget {
  const _DiscoveryFiltersSheet({
    required this.initialState,
    required this.mode,
  });

  final DiscoveryState initialState;
  final DiscoveryMode mode;

  @override
  State<_DiscoveryFiltersSheet> createState() => _DiscoveryFiltersSheetState();
}

class _DiscoveryFiltersSheetState extends State<_DiscoveryFiltersSheet> {
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late ServiceCategoryGroup? _group;
  late ServiceCategory? _category;
  late bool _onlyAvailableNow;
  late bool _onlyWithWorkingHours;
  late bool _onlyVatIncluded;
  late double? _maxDistanceKm;
  late double? _minRating;
  late PricingUnit? _pricingUnit;
  late LocationPrecision? _locationPrecision;
  late String? _providerKind;
  late String? _gender;

  @override
  void initState() {
    super.initState();
    final state = widget.initialState;
    _group = state.selectedGroup;
    _category = state.selectedCategory;
    _onlyAvailableNow = state.onlyAvailableNow;
    _onlyWithWorkingHours = state.onlyWithWorkingHours;
    _onlyVatIncluded = state.onlyVatIncluded;
    _maxDistanceKm = state.maxDistanceKm;
    _minRating = state.minRating;
    _pricingUnit = state.pricingUnit;
    _locationPrecision = state.locationPrecision;
    _providerKind = state.providerKind;
    _gender = state.gender;
    _minPriceController = TextEditingController(
      text: _formatNumber(state.minPrice),
    );
    _maxPriceController = TextEditingController(
      text: _formatNumber(state.maxPrice),
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  static String _formatNumber(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  double? _parsePrice(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }

  void _reset() {
    setState(() {
      _group = null;
      _category = null;
      _onlyAvailableNow = false;
      _onlyWithWorkingHours = false;
      _onlyVatIncluded = false;
      _maxDistanceKm = null;
      _minRating = null;
      _pricingUnit = null;
      _locationPrecision = null;
      _providerKind = null;
      _gender = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _submit({bool openMap = false}) {
    final minPrice = _parsePrice(_minPriceController);
    final maxPrice = _parsePrice(_maxPriceController);
    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En düşük fiyat, en yüksek fiyattan büyük olamaz.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _FilterResult(
        group: _group,
        category: _category,
        onlyAvailableNow: _onlyAvailableNow,
        onlyWithWorkingHours: _onlyWithWorkingHours,
        onlyVatIncluded: _onlyVatIncluded,
        minPrice: minPrice,
        maxPrice: maxPrice,
        maxDistanceKm: _maxDistanceKm,
        minRating: _minRating,
        pricingUnit: _pricingUnit,
        locationPrecision: _locationPrecision,
        providerKind: _providerKind,
        gender: _gender,
        openMap: openMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableLabel = widget.mode == DiscoveryMode.findService
        ? 'Şu an açık / müsait'
        : 'Şu an aktif iş talebi';
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtreler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Temizle')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  _FilterSection(
                    icon: Icons.category_outlined,
                    title: 'İlan türü ve kategori',
                    subtitle:
                        _category?.fullLabel ??
                        _group?.label ??
                        'Tüm kategoriler',
                    initiallyExpanded: _category != null || _group != null,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ChoiceChip(
                          label: const Text('Tüm kategoriler'),
                          selected: _category == null && _group == null,
                          onSelected: (_) => setState(() {
                            _category = null;
                            _group = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final group in ServiceCategoryGroup.values)
                        ExpansionTile(
                          key: PageStorageKey(group.id),
                          initiallyExpanded: _group == group,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 10),
                          leading: Icon(
                            categoryGroupIcon(group),
                            color: AppColors.turquoiseDark,
                          ),
                          title: Text(
                            group.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ChoiceChip(
                                label: Text('Tüm ${group.label}'),
                                selected: _group == group && _category == null,
                                onSelected: (_) => setState(() {
                                  _group = group;
                                  _category = null;
                                }),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final category in group.categories)
                                  ChoiceChip(
                                    avatar: Icon(
                                      categoryIcon(category),
                                      size: 16,
                                    ),
                                    label: Text(category.label),
                                    selected: _category == category,
                                    onSelected: (_) => setState(() {
                                      _group = group;
                                      _category = category;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FilterSection(
                    icon: Icons.payments_outlined,
                    title: 'Fiyat',
                    subtitle: _priceSummary,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'En düşük',
                                suffixText: '₺',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'En yüksek',
                                suffixText: '₺',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ChoiceChip(
                            label: const Text('Tüm fiyat türleri'),
                            selected: _pricingUnit == null,
                            onSelected: (_) =>
                                setState(() => _pricingUnit = null),
                          ),
                          for (final unit in PricingUnit.values)
                            ChoiceChip(
                              label: Text(_pricingUnitLabel(unit)),
                              selected: _pricingUnit == unit,
                              onSelected: (_) =>
                                  setState(() => _pricingUnit = unit),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FilterSection(
                    icon: Icons.schedule_outlined,
                    title: 'Müsaitlik ve çalışma saatleri',
                    subtitle: _availabilitySummary,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(availableLabel),
                        subtitle: const Text(
                          'Yalnızca şu anda hizmet verebilen veya aktif olanlar',
                        ),
                        value: _onlyAvailableNow,
                        onChanged: (value) =>
                            setState(() => _onlyAvailableNow = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Çalışma saatleri belirtilmiş'),
                        subtitle: const Text(
                          'Saat veya müsaitlik bilgisi yazılmış ilanlar',
                        ),
                        value: _onlyWithWorkingHours,
                        onChanged: (value) =>
                            setState(() => _onlyWithWorkingHours = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FilterSection(
                    icon: Icons.near_me_outlined,
                    title: 'Mesafe ve konum',
                    subtitle: _distanceSummary,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'En fazla mesafe',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final distance in <double?>[null, 5, 10, 25, 50])
                            ChoiceChip(
                              label: Text(
                                distance == null ? 'Sınır yok' : '$distance km',
                              ),
                              selected: _maxDistanceKm == distance,
                              onSelected: (_) =>
                                  setState(() => _maxDistanceKm = distance),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Konum hassasiyeti',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ChoiceChip(
                            label: const Text('Tümü'),
                            selected: _locationPrecision == null,
                            onSelected: (_) =>
                                setState(() => _locationPrecision = null),
                          ),
                          ChoiceChip(
                            label: const Text('Net konum'),
                            selected:
                                _locationPrecision == LocationPrecision.exact,
                            onSelected: (_) => setState(
                              () =>
                                  _locationPrecision = LocationPrecision.exact,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Yakın konum'),
                            selected:
                                _locationPrecision ==
                                LocationPrecision.neighborhood,
                            onSelected: (_) => setState(
                              () => _locationPrecision =
                                  LocationPrecision.neighborhood,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _FilterSection(
                    icon: Icons.star_outline_rounded,
                    title: 'Puan ve diğer seçenekler',
                    subtitle: _otherSummary,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'En düşük kullanıcı puanı',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final rating in <double?>[null, 3, 4, 4.5])
                            ChoiceChip(
                              label: Text(
                                rating == null ? 'Tümü' : '$rating ve üzeri',
                              ),
                              selected: _minRating == rating,
                              onSelected: (_) =>
                                  setState(() => _minRating = rating),
                            ),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('KDV dahil fiyat'),
                        value: _onlyVatIncluded,
                        onChanged: (value) =>
                            setState(() => _onlyVatIncluded = value),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hizmet veren türü',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final option in const <(String?, String)>[
                            (null, 'Tümü'),
                            ('person', 'Şahıs'),
                            ('business', 'Kurumsal'),
                          ])
                            ChoiceChip(
                              label: Text(option.$2),
                              selected: _providerKind == option.$1,
                              onSelected: (_) =>
                                  setState(() => _providerKind = option.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Cinsiyet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final option in const <(String?, String)>[
                            (null, 'Tümü'),
                            ('female', 'Kadın'),
                            ('male', 'Erkek'),
                          ])
                            ChoiceChip(
                              label: Text(option.$2),
                              selected: _gender == option.$1,
                              onSelected: (_) =>
                                  setState(() => _gender = option.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.mode == DiscoveryMode.findService) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _group = ServiceCategoryGroup.vehicleRoad;
                          _category = ServiceCategory.tireRepair;
                          _onlyAvailableNow = true;
                        });
                        _submit(openMap: true);
                      },
                      icon: const Icon(Icons.near_me_outlined),
                      label: const Text('En yakın müsait lastikçiyi göster'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Filtreleri Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _priceSummary {
    final min = _minPriceController.text.trim();
    final max = _maxPriceController.text.trim();
    if (min.isEmpty && max.isEmpty && _pricingUnit == null) {
      return 'Fiyat aralığı ve ücret türü';
    }
    final range = [
      if (min.isNotEmpty) '$min ₺ üzeri',
      if (max.isNotEmpty) '$max ₺ altı',
      if (_pricingUnit != null) _pricingUnitLabel(_pricingUnit!),
    ];
    return range.join(' • ');
  }

  String get _availabilitySummary {
    if (!_onlyAvailableNow && !_onlyWithWorkingHours) {
      return 'Müsaitlik ve saat bilgisi';
    }
    return [
      if (_onlyAvailableNow) 'Şu an müsait',
      if (_onlyWithWorkingHours) 'Saatleri belirtilmiş',
    ].join(' • ');
  }

  String get _distanceSummary {
    final distance = _maxDistanceKm == null
        ? 'Mesafe sınırı yok'
        : 'En fazla ${_maxDistanceKm!.toStringAsFixed(0)} km';
    final precision = switch (_locationPrecision) {
      LocationPrecision.exact => 'Net konum',
      LocationPrecision.neighborhood => 'Yakın konum',
      null => null,
    };
    return <String>[distance, ?precision].join(' • ');
  }

  String get _otherSummary =>
      [
        if (_minRating != null) '${_minRating!} puan ve üzeri',
        if (_onlyVatIncluded) 'KDV dahil',
      ].isEmpty
      ? 'Puan ve KDV seçenekleri'
      : [
          if (_minRating != null) '${_minRating!} puan ve üzeri',
          if (_onlyVatIncluded) 'KDV dahil',
        ].join(' • ');

  String _pricingUnitLabel(PricingUnit unit) => switch (unit) {
    PricingUnit.fixed => 'Sabit fiyat',
    PricingUnit.hourly => 'Saatlik',
    PricingUnit.daily => 'Günlük',
    PricingUnit.perSession => 'Seans başına',
    PricingUnit.startingAt => 'Başlangıç fiyatı',
    PricingUnit.negotiable => 'Teklif alınır',
    PricingUnit.free => 'Ücretsiz',
  };
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon, color: AppColors.turquoiseDark),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        children: children,
      ),
    );
  }
}

class _AreaResultsHeader extends StatelessWidget {
  const _AreaResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const Icon(
            Icons.crop_free_rounded,
            size: 19,
            color: AppColors.turquoiseDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Haritada görünen bölgede $count ilan',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedListingList extends StatelessWidget {
  const _GroupedListingList({
    required this.listings,
    required this.currentUserId,
  });

  final List<ServiceListing> listings;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 76),
      children: [
        for (final group in ServiceCategoryGroup.values)
          if (listings.any((listing) => listing.category.group == group)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
              child: Row(
                children: [
                  Icon(
                    categoryGroupIcon(group),
                    size: 20,
                    color: AppColors.turquoiseDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            for (final listing in listings.where(
              (listing) => listing.category.group == group,
            )) ...[
              ListingCard(
                listing: listing,
                isOwnListing: listing.ownerId == currentUserId,
                onTap: () => context.push(
                  AppRoutes.listingDetail(listing.bundleId ?? listing.id),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
      ],
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.selected, required this.onChanged});

  final DiscoveryViewMode selected;
  final ValueChanged<DiscoveryViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewButton(
            icon: Icons.map_rounded,
            label: 'Harita',
            selected: selected == DiscoveryViewMode.map,
            onTap: () => onChanged(DiscoveryViewMode.map),
          ),
          const Divider(),
          _ViewButton(
            icon: Icons.view_list_rounded,
            label: 'Liste',
            selected: selected == DiscoveryViewMode.list,
            onTap: () => onChanged(DiscoveryViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 42,
        color: selected ? AppColors.aquaSoft : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.turquoiseDark : AppColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.turquoiseDark : AppColors.muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: selected ? AppColors.turquoise : AppColors.aquaSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.turquoise : AppColors.outline,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 29,
                  color: selected ? Colors.white : AppColors.turquoiseDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.turquoiseDark : AppColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListings extends StatefulWidget {
  const _EmptyListings({required this.mode, this.areaEmpty = false});

  final DiscoveryMode mode;
  final bool areaEmpty;

  @override
  State<_EmptyListings> createState() => _EmptyListingsState();
}

class _EmptyListingsState extends State<_EmptyListings> {
  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void didUpdateWidget(covariant _EmptyListings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.areaEmpty != widget.areaEmpty) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _visible = true;
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final findingService = widget.mode == DiscoveryMode.findService;
    if (widget.areaEmpty) {
      return const AppEmptyState(
        icon: Icons.location_searching_rounded,
        title: 'Bu bölgede ilan yok',
        message:
            'Haritayı başka bir bölgeye taşıyıp tekrar listeye bakabilirsin.',
      );
    }
    return AppEmptyState(
      icon: findingService ? Icons.handyman_outlined : Icons.work_outline,
      title: findingService
          ? 'Henüz aktif hizmet yok'
          : 'Henüz aktif iş ilanı yok',
      message: findingService
          ? 'İlk hizmet veren profilini oluşturduğunda burada görünecek.'
          : 'İlk hizmet talebini sen yayınlayabilirsin.',
      action: findingService
          ? null
          : FilledButton.icon(
              onPressed: () => context.go(AppRoutes.createListing),
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk İlanı Oluştur'),
            ),
    );
  }
}

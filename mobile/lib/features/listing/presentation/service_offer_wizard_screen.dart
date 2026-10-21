import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/listing/data/reverse_geocoding_service.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/category_group_selector.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/request_location_picker.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class ServiceOfferWizardScreen extends ConsumerStatefulWidget {
  const ServiceOfferWizardScreen({super.key});

  @override
  ConsumerState<ServiceOfferWizardScreen> createState() =>
      _ServiceOfferWizardScreenState();
}

class _ServiceOfferWizardScreenState
    extends ConsumerState<ServiceOfferWizardScreen> {
  static const _turkeyCenter = LatLng(39.0, 35.0);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _priceController = TextEditingController();
  final _districtController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingNumberController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  ServiceCategory? _category;

  LatLng _selectedPoint = _turkeyCenter;
  ResolvedAddress? _resolvedAddress;
  LocationPrecision _precision = LocationPrecision.neighborhood;
  PricingUnit _pricingUnit = PricingUnit.fixed;
  bool _locationConfirmed = false;
  bool _resolvingAddress = false;
  bool _availableNow = true;
  bool _priceIncludesVat = false;
  bool _publishing = false;
  double _serviceRadiusKm = 25;
  bool _limitServiceDistance = false;
  XFile? _selectedImage;
  final List<_AdditionalServiceDraft> _additionalServices = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _scheduleController.dispose();
    _priceController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    for (final item in _additionalServices) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveLocation(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _locationConfirmed = false;
      _resolvingAddress = true;
    });
    try {
      final address = await ref
          .read(reverseGeocodingServiceProvider)
          .resolve(point);
      if (!mounted) return;
      setState(() {
        _resolvedAddress = address;
        _districtController.text = address.district;
        _neighborhoodController.text = address.neighborhood;
        _streetController.text = address.street;
        _buildingNumberController.text = address.buildingNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _resolvedAddress = ResolvedAddress(
          displayName:
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          district: '',
          neighborhood: '',
          street: '',
          buildingNumber: '',
          city: '',
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  Future<void> _publish() async {
    if (_publishing || !_formKey.currentState!.validate()) return;
    if (!_locationConfirmed) {
      _message('Önce haritadaki konumu doğrula.');
      return;
    }
    if (_category == null) {
      _message('Bir hizmet kategorisi seç.');
      return;
    }

    final parsedPrice =
        {_pricingUnit}.any(
          (unit) => unit == PricingUnit.negotiable || unit == PricingUnit.free,
        )
        ? 0.0
        : double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
    if (parsedPrice == null || parsedPrice < 0) {
      _message('Geçerli bir fiyat yaz.');
      return;
    }

    setState(() => _publishing = true);
    final district = _districtController.text.trim();
    final neighborhood = _neighborhoodController.text.trim();
    final bundleId = 'offer-${DateTime.now().microsecondsSinceEpoch}';
    final listings = [
      ServiceListing(
        id: '$bundleId-${_category!.name}',
        ownerName: 'Sen',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: ListingType.serviceOffer,
        category: _category!,
        priceAmount: parsedPrice,
        pricingUnit: _pricingUnit,
        priceIncludesVat: _priceIncludesVat,
        district: district.isEmpty ? 'Haritadan seçilen bölge' : district,
        neighborhood: neighborhood.isEmpty
            ? 'Haritadan seçilen konum'
            : neighborhood,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        locationPrecision: _precision,
        distanceKm: 0,
        availableNow: _availableNow,
        availabilityLabel: _scheduleController.text.trim(),
        bundleId: bundleId,
        bundleItemIndex: 0,
        bundleItemCount: 1,
        privateDistrict: district,
        privateNeighborhood: neighborhood,
        privateStreet: _streetController.text.trim(),
        privateBuildingNumber: _buildingNumberController.text.trim(),
        city: _resolvedAddress?.city ?? '',
        serviceRadiusKm: _limitServiceDistance
            ? _serviceRadiusKm.round()
            : null,
      ),
      for (var index = 0; index < _additionalServices.length; index++)
        ServiceListing(
          id: '$bundleId-extra-$index',
          ownerName: 'Sen',
          title: _additionalServices[index].title.text.trim(),
          description: _additionalServices[index].description.text.trim(),
          type: ListingType.serviceOffer,
          category: _additionalServices[index].category,
          priceAmount: _additionalServices[index].priceAmount,
          pricingUnit: _additionalServices[index].pricingUnit,
          priceIncludesVat: false,
          district: district.isEmpty ? 'Haritadan seçilen bölge' : district,
          neighborhood: neighborhood.isEmpty
              ? 'Haritadan seçilen konum'
              : neighborhood,
          latitude: _selectedPoint.latitude,
          longitude: _selectedPoint.longitude,
          locationPrecision: _precision,
          distanceKm: 0,
          availableNow: _availableNow,
          availabilityLabel: _additionalServices[index].duration.text.trim(),
          bundleId: bundleId,
          bundleItemIndex: index + 1,
          bundleItemCount: _additionalServices.length + 1,
          privateDistrict: district,
          privateNeighborhood: neighborhood,
          privateStreet: _streetController.text.trim(),
          privateBuildingNumber: _buildingNumberController.text.trim(),
          city: _resolvedAddress?.city ?? '',
          serviceRadiusKm: _limitServiceDistance
              ? _serviceRadiusKm.round()
              : null,
        ),
    ];

    try {
      final repository = ref.read(listingRepositoryProvider);
      final createdId = await repository.addListings(listings);
      final image = _selectedImage;
      var imageWarning = false;
      if (createdId != null && image != null) {
        try {
          await repository.uploadListingImage(
            listingId: createdId,
            bytes: await image.readAsBytes(),
            filename: image.name,
          );
        } catch (_) {
          imageWarning = true;
        }
      }
      ref.invalidate(activeListingsProvider);
      ref.invalidate(listingsByOwnerProvider);
      ref.invalidate(currentUserProfileProvider);
      ref.read(discoveryControllerProvider.notifier)
        ..setMode(DiscoveryMode.findService)
        ..setOnlyAvailableNow(false)
        ..setViewMode(DiscoveryViewMode.map);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.discovery);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            imageWarning
                ? 'Hizmet yayınlandı; fotoğraf yüklenemedi, daha sonra düzenleyebilirsin.'
                : 'Hizmetin yayınlandı.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _message('Hizmet yayınlanamadı: $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hizmet Sun'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(58),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: AppStepProgress(
              currentStep: 1,
              labels: ['Kategori', 'Detaylar', 'Ek Bilgiler', 'Onay'],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AppStatusPill(
                label: 'Hizmet Veriyorum',
                icon: Icons.handyman_outlined,
              ),
            ),
            const SizedBox(height: 22),
            const AppSectionHeader(
              title: 'Hizmetin',
              subtitle:
                  'Ana hizmeti seç; aynı konumdaki diğer hizmetlerini aşağıdan ekleyebilirsin.',
            ),
            const SizedBox(height: 10),
            CategoryGroupSelector(
              selectedCategory: _category,
              onChanged: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: 18),
            if (_category?.isOpenEnded == true) ...[
              const AppSurfaceCard(
                color: AppColors.aquaSoft,
                borderColor: AppColors.aqua,
                child: Text(
                  'Açık bir kategori seçtin. Özel hizmetin adını hizmet başlığına açıkça yaz; kullanıcılar aramayla bulabilsin.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Hizmet başlığı *'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'En az 3 karakter yaz.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Deneyimin ve hizmet ayrıntıları *',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'En az 10 karakter açıklama yaz.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _scheduleController,
              decoration: const InputDecoration(
                labelText: 'Çalışma / müsaitlik saatleri (isteğe bağlı)',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const AppSectionHeader(title: 'Fiyat Türü'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const <(PricingUnit, String)>[
                  (PricingUnit.fixed, 'Toplam Ücret'),
                  (PricingUnit.hourly, 'Saatlik'),
                  (PricingUnit.daily, 'Günlük'),
                  (PricingUnit.perSession, 'Seans Başına'),
                  (PricingUnit.startingAt, 'Başlangıç Fiyatı'),
                  (PricingUnit.negotiable, 'Teklif Alınır'),
                  (PricingUnit.free, 'Ücretsiz'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _pricingUnit == option.$1,
                    onSelected: (_) => setState(() {
                      _pricingUnit = option.$1;
                    }),
                  ),
              ],
            ),
            if (_pricingUnit != PricingUnit.negotiable &&
                _pricingUnit != PricingUnit.free) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fiyat *',
                  prefixText: '₺ ',
                ),
              ),
              AppSurfaceCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile.adaptive(
                  title: const Text('Fiyat KDV Dahil'),
                  value: _priceIncludesVat,
                  onChanged: (value) =>
                      setState(() => _priceIncludesVat = value),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: AppSectionHeader(
                    title: 'Diğer alt hizmetler',
                    subtitle: 'Aynı ana ilan ve konum altında gösterilir.',
                  ),
                ),
                Text('${_additionalServices.length + 1}/20'),
              ],
            ),
            const SizedBox(height: 10),
            for (
              var index = 0;
              index < _additionalServices.length;
              index++
            ) ...[
              _AdditionalServiceEditor(
                key: ObjectKey(_additionalServices[index]),
                draft: _additionalServices[index],
                index: index,
                onChanged: () => setState(() {}),
                onRemove: () {
                  final removed = _additionalServices.removeAt(index);
                  removed.dispose();
                  setState(() {});
                },
                onMoveUp: index == 0
                    ? null
                    : () => setState(() {
                        final item = _additionalServices.removeAt(index);
                        _additionalServices.insert(index - 1, item);
                      }),
                onMoveDown: index == _additionalServices.length - 1
                    ? null
                    : () => setState(() {
                        final item = _additionalServices.removeAt(index);
                        _additionalServices.insert(index + 1, item);
                      }),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _additionalServices.length >= 19
                  ? null
                  : () => setState(
                      () => _additionalServices.add(
                        _AdditionalServiceDraft(
                          category: _category ?? ServiceCategory.values.first,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Alt hizmet ekle'),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              padding: EdgeInsets.zero,
              color: _availableNow ? AppColors.aquaSoft : AppColors.surface,
              child: SwitchListTile.adaptive(
                title: const Text('Şu An Müsaitim'),
                subtitle: const Text('Hizmet vermeye hazır olduğunu göster.'),
                value: _availableNow,
                onChanged: (value) => setState(() => _availableNow = value),
              ),
            ),
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'Konum',
              subtitle: 'Sabit iğnenin altına hizmet verdiğin noktayı getir.',
            ),
            const SizedBox(height: 10),
            RequestLocationPicker(
              selectedPoint: _selectedPoint,
              onMoving: () => setState(() => _locationConfirmed = false),
              onChanged: _resolveLocation,
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: _resolvingAddress
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(
                        _locationConfirmed
                            ? Icons.check_circle
                            : Icons.location_on_outlined,
                      ),
                title: Text(
                  _resolvedAddress?.displayName ?? 'Haritayı hareket ettir',
                ),
                subtitle: Text(
                  _locationConfirmed ? 'Konum doğrulandı' : 'Konumu kontrol et',
                ),
                trailing: _resolvedAddress == null || _resolvingAddress
                    ? null
                    : FilledButton(
                        onPressed: () =>
                            setState(() => _locationConfirmed = true),
                        child: const Text('Doğrula'),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            AppSegmentedControl<LocationPrecision>(
              segments: const [
                AppSegment(
                  value: LocationPrecision.exact,
                  label: 'İşletme adresi',
                  icon: Icons.store_outlined,
                ),
                AppSegment(
                  value: LocationPrecision.neighborhood,
                  label: 'Yakın konum',
                  icon: Icons.location_searching,
                ),
              ],
              selected: _precision,
              onChanged: (value) => setState(() => _precision = value),
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Hizmet mesafesi belirle'),
                    subtitle: const Text(
                      'Online hizmet veriyorsan veya her yere gidiyorsan kapalı bırak.',
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _selectedImage == null
                    ? 'İsteğe bağlı hizmet fotoğrafı ekle'
                    : 'Fotoğrafı değiştir: ${_selectedImage!.name}',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: const Text('Hizmeti Yayınla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdditionalServiceDraft {
  _AdditionalServiceDraft({required this.category});

  ServiceCategory category;
  PricingUnit pricingUnit = PricingUnit.fixed;
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final duration = TextEditingController();

  double get priceAmount {
    if (pricingUnit == PricingUnit.negotiable ||
        pricingUnit == PricingUnit.free) {
      return 0;
    }
    return double.tryParse(price.text.trim().replaceAll(',', '.')) ?? -1;
  }

  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    duration.dispose();
  }
}

class _AdditionalServiceEditor extends StatelessWidget {
  const _AdditionalServiceEditor({
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final _AdditionalServiceDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alt hizmet ${index + 2}',
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
                tooltip: 'Sil',
                onPressed: onRemove,
                color: AppColors.danger,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          DropdownButtonFormField<ServiceCategory>(
            isExpanded: true,
            initialValue: draft.category,
            decoration: const InputDecoration(labelText: 'Alt kategori *'),
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
              draft.category = value ?? draft.category;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Hizmet adı *'),
            validator: (value) => (value?.trim().length ?? 0) < 3
                ? 'En az 3 karakter yaz.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.description,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Kısa açıklama *'),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'En az 10 karakter yaz.'
                : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<PricingUnit>(
            initialValue: draft.pricingUnit,
            decoration: const InputDecoration(labelText: 'Fiyatlandırma'),
            items: const [
              DropdownMenuItem(
                value: PricingUnit.fixed,
                child: Text('Sabit fiyat'),
              ),
              DropdownMenuItem(
                value: PricingUnit.hourly,
                child: Text('Saatlik'),
              ),
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
                child: Text('Teklif üzerine'),
              ),
              DropdownMenuItem(
                value: PricingUnit.free,
                child: Text('Ücretsiz'),
              ),
            ],
            onChanged: (value) {
              draft.pricingUnit = value ?? draft.pricingUnit;
              onChanged();
            },
          ),
          if (draft.pricingUnit != PricingUnit.negotiable &&
              draft.pricingUnit != PricingUnit.free) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fiyat *',
                prefixText: '₺ ',
              ),
              validator: (_) =>
                  draft.priceAmount < 0 ? 'Geçerli bir fiyat yaz.' : null,
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.duration,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Tahmini süre (isteğe bağlı)',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/core/widgets/app_ui.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/listing/data/reverse_geocoding_service.dart';
import 'package:ankara_proje/features/listing/domain/service_request_draft.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/category_group_selector.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/request_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class ServiceRequestWizardScreen extends ConsumerStatefulWidget {
  const ServiceRequestWizardScreen({super.key});

  @override
  ConsumerState<ServiceRequestWizardScreen> createState() =>
      _ServiceRequestWizardScreenState();
}

class _ServiceRequestWizardScreenState
    extends ConsumerState<ServiceRequestWizardScreen> {
  static const _turkeyCenter = LatLng(39.0, 35.0);

  final _districtController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingNumberController = TextEditingController();
  final Set<ServiceCategory> _selectedCategories = {};
  final Map<ServiceCategory, _RequestItemFormData> _forms = {};
  final ImagePicker _imagePicker = ImagePicker();

  LocationPrecision _locationPrecision = LocationPrecision.neighborhood;
  LatLng _selectedPoint = _turkeyCenter;
  bool _hasChosenLocation = false;
  bool _locationMoving = false;
  bool _resolvingAddress = false;
  bool _addressLookupFailed = false;
  ResolvedAddress? _resolvedAddress;
  int _locationRequestId = 0;
  bool _publishing = false;
  int _step = 0;
  double _serviceRadiusKm = 25;
  bool _limitServiceDistance = false;
  XFile? _selectedImage;

  List<ServiceCategory> get _orderedCategories =>
      ServiceCategory.values.where(_selectedCategories.contains).toList();

  bool get _isReviewStep => _step == _orderedCategories.length + 2;

  int get _visualStep {
    if (_step == 0) return 0;
    if (_step == 1) return 1;
    if (_isReviewStep) return 3;
    return 2;
  }

  ServiceCategory? get _currentCategory {
    final categoryIndex = _step - 2;
    if (categoryIndex < 0 || categoryIndex >= _orderedCategories.length) {
      return null;
    }
    return _orderedCategories[categoryIndex];
  }

  @override
  void dispose() {
    _districtController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    for (final form in _forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectCategory(ServiceCategory category) {
    setState(() {
      _selectedCategories
        ..clear()
        ..add(category);
      _forms.putIfAbsent(category, () => _RequestItemFormData(category));
    });
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  Future<void> _pickNeededDate(_RequestItemFormData form) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: form.neededAt ?? now,
      helpText: 'Hizmet tarihini seç',
    );
    if (selected != null && mounted) setState(() => form.neededAt = selected);
  }

  void _handleLocationMoving() {
    if (_locationMoving && !_hasChosenLocation && _resolvedAddress == null) {
      return;
    }
    setState(() {
      _locationMoving = true;
      _hasChosenLocation = false;
      _resolvedAddress = null;
      _addressLookupFailed = false;
    });
  }

  Future<void> _resolveLocation(LatLng point) async {
    final requestId = ++_locationRequestId;
    setState(() {
      _selectedPoint = point;
      _locationMoving = false;
      _resolvingAddress = true;
      _hasChosenLocation = false;
      _addressLookupFailed = false;
    });

    try {
      final address = await ref
          .read(reverseGeocodingServiceProvider)
          .resolve(point);
      if (!mounted || requestId != _locationRequestId) return;
      setState(() {
        _resolvedAddress = address;
        _resolvingAddress = false;
        if (address.district.isNotEmpty) {
          _districtController.text = address.district;
        }
        if (address.neighborhood.isNotEmpty) {
          _neighborhoodController.text = address.neighborhood;
        }
        if (address.street.isNotEmpty) {
          _streetController.text = address.street;
        }
        if (address.buildingNumber.isNotEmpty) {
          _buildingNumberController.text = address.buildingNumber;
        }
      });
    } catch (_) {
      if (!mounted || requestId != _locationRequestId) return;
      setState(() {
        _resolvedAddress = ResolvedAddress(
          displayName:
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          district: '',
          neighborhood: '',
          street: '',
          buildingNumber: '',
          city: '',
        );
        _resolvingAddress = false;
        _addressLookupFailed = true;
      });
    }
  }

  void _confirmLocation() {
    if (_resolvedAddress == null) return;
    setState(() => _hasChosenLocation = true);
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      if (!_hasChosenLocation) {
        _showError('Haritayı hareket ettirip seçtiğin konumu doğrula.');
        return false;
      }
      if (_locationPrecision == LocationPrecision.exact &&
          (_districtController.text.trim().isEmpty ||
              _neighborhoodController.text.trim().isEmpty ||
              _streetController.text.trim().isEmpty)) {
        _showError('Net adres için ilçe, mahalle ve sokak bilgilerini doldur.');
        return false;
      }
      return true;
    }

    if (_step == 1) {
      if (_selectedCategories.isEmpty) {
        _showError('En az bir hizmet kategorisi seç.');
        return false;
      }
      return true;
    }

    final category = _currentCategory;
    if (category == null) return true;
    final form = _forms[category]!;
    if (form.titleController.text.trim().isEmpty ||
        form.descriptionController.text.trim().length < 10) {
      _showError(
        '${category.label} için başlık ve en az 10 karakter açıklama yaz.',
      );
      return false;
    }
    if (form.hasSpecificDate && form.neededAt == null) {
      _showError('Belirli tarih seçeneği için tarihi seç.');
      return false;
    }
    if (form.pricingUnit != PricingUnit.negotiable) {
      final budget = double.tryParse(
        form.budgetController.text.trim().replaceAll(',', '.'),
      );
      if (budget == null || budget <= 0) {
        _showError('${category.label} için geçerli bir bütçe yaz.');
        return false;
      }
    }
    return true;
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_isReviewStep) {
      _publish();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step += 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);

    final requestId = 'request-bundle-${DateTime.now().microsecondsSinceEpoch}';
    final draft = ServiceRequestDraft(
      id: requestId,
      location: ServiceRequestLocationDraft(
        precision: _locationPrecision,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        district: _districtController.text,
        neighborhood: _neighborhoodController.text,
        street: _streetController.text,
        buildingNumber: _buildingNumberController.text,
        city: _resolvedAddress?.city ?? '',
        serviceRadiusKm: _limitServiceDistance
            ? _serviceRadiusKm.round()
            : null,
      ),
      items: [
        for (final category in _orderedCategories)
          _forms[category]!.toDraft(category),
      ],
    );

    final listings = draft.toListings(ownerName: 'Sen');
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
      ref.read(discoveryControllerProvider.notifier)
        ..setMode(DiscoveryMode.findWork)
        ..setOnlyAvailableNow(false)
        ..setViewMode(DiscoveryViewMode.map);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.discovery);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            imageWarning
                ? 'İlan yayınlandı; fotoğraf yüklenemedi, daha sonra düzenleyebilirsin.'
                : 'Hizmet ihtiyacın haritaya eklendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _showError('İlan yayınlanamadı: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hizmet Talebi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: AppStepProgress(
              currentStep: _visualStep,
              labels: const ['Konum', 'Kategori', 'Detaylar', 'Onay'],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey('request-step-$_step'),
          child: _buildCurrentStep(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _publishing ? null : _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _publishing ? null : _next,
                  icon: _publishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isReviewStep
                              ? Icons.publish_outlined
                              : Icons.arrow_forward,
                        ),
                  label: Text(_isReviewStep ? 'İlanı yayınla' : 'Devam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_step == 0) return _buildLocationStep();
    if (_step == 1) return _buildCategoryStep();
    final category = _currentCategory;
    if (category != null) return _buildItemStep(category);
    return _buildReviewStep();
  }

  Widget _buildLocationStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const AppPageHeader(
          title: 'Hizmet nerede yapılacak?',
          subtitle:
              'İğne ortada sabit. Haritayı sürükleyerek hizmet noktasını iğnenin altına getir.',
        ),
        const SizedBox(height: 16),
        RequestLocationPicker(
          selectedPoint: _selectedPoint,
          onMoving: _handleLocationMoving,
          onChanged: _resolveLocation,
        ),
        const SizedBox(height: 12),
        _buildLocationConfirmation(),
        const SizedBox(height: 16),
        SegmentedButton<LocationPrecision>(
          segments: const [
            ButtonSegment(
              value: LocationPrecision.exact,
              icon: Icon(Icons.home_work_outlined),
              label: Text('Net adres'),
            ),
            ButtonSegment(
              value: LocationPrecision.neighborhood,
              icon: Icon(Icons.location_searching),
              label: Text('Yakın konum'),
            ),
          ],
          selected: {_locationPrecision},
          onSelectionChanged: (selection) {
            setState(() => _locationPrecision = selection.first);
          },
        ),
        const SizedBox(height: 14),
        if (_locationPrecision == LocationPrecision.exact)
          _buildExactAddressFields()
        else
          const _PrivacyNote(
            icon: Icons.shield_outlined,
            text:
                'Tam adres yazmana gerek yok. Evin yerine yakındaki bir sokak veya buluşma noktasına iğne bırakabilirsin.',
          ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Hizmet mesafesi belirle'),
                subtitle: const Text(
                  'Online veya her yere uygun taleplerde kapalı bırakabilirsin.',
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
        const SizedBox(height: 10),
        Text(
          _hasChosenLocation
              ? 'Konum doğrulandı. Devam edebilirsin.'
              : 'Devam etmek için haritayı taşı ve bulunan konumu doğrula.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _hasChosenLocation
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationConfirmation() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_locationMoving) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.open_with_outlined),
          title: Text('Konumu ayarlıyorsun'),
          subtitle: Text('Haritayı bıraktıktan 1 saniye sonra adres aranacak.'),
        ),
      );
    }
    if (_resolvingAddress) {
      return const Card(
        child: ListTile(
          leading: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Adres bulunuyor…'),
          subtitle: Text('İğnenin altındaki konumu kontrol ediyoruz.'),
        ),
      );
    }
    final address = _resolvedAddress;
    if (address == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.touch_app_outlined),
          title: Text('Haritayı hareket ettir'),
          subtitle: Text('Sabit iğneyi istediğin adresin üzerine getir.'),
        ),
      );
    }

    return Card(
      color: _hasChosenLocation ? const Color(0xFFE1F5E8) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _hasChosenLocation
                      ? Icons.check_circle
                      : Icons.location_on_outlined,
                  color: _hasChosenLocation
                      ? const Color(0xFF176B3A)
                      : colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasChosenLocation
                            ? 'Konum doğrulandı'
                            : 'Burası doğru mu?',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(address.displayName),
                      if (_addressLookupFailed) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Adres adı alınamadı; koordinatı yine de doğrulayabilirsin.',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!_hasChosenLocation) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _confirmLocation,
                icon: const Icon(Icons.check),
                label: const Text('Bu konumu doğrula'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExactAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PrivacyNote(
          icon: Icons.lock_outline,
          text:
              'Net adres korumalı tutulacak; genel ilan kartında yalnızca ilçe ve mahalle görünecek.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _districtController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'İlçe *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _neighborhoodController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Mahalle *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _streetController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Cadde / Sokak *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _buildingNumberController,
          decoration: const InputDecoration(labelText: 'Bina / Kapı no'),
        ),
      ],
    );
  }

  Widget _buildCategoryStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const AppPageHeader(
          title: 'Hangi Hizmete İhtiyacın Var?',
          subtitle:
              'Her ilan tek bir hizmet içindir. Başka bir ihtiyaç için yeni ilan açabilirsin.',
        ),
        const SizedBox(height: 20),
        if (_selectedCategories.isNotEmpty)
          _PrivacyNote(
            icon: Icons.check_circle_outline,
            text:
                '${_selectedCategories.first.label} seçildi. Aşağıdan başka bir hizmete dokunarak değiştirebilirsin.',
          ),
        if (_selectedCategories.isNotEmpty) const SizedBox(height: 14),
        CategoryGroupSelector(
          selectedCategory: _selectedCategories.firstOrNull,
          onChanged: _selectCategory,
        ),
      ],
    );
  }

  Widget _buildItemStep(ServiceCategory category) {
    final form = _forms[category]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            AppIconBadge(icon: categoryIcon(category), size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category.label} ihtiyacı',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text('Tek hizmet ilanı'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (category.isOpenEnded) ...[
          _PrivacyNote(
            icon: Icons.edit_note_rounded,
            text:
                'Açık kategoriyi seçtin. Aranan özel hizmetin adını ilan başlığına açıkça yaz; aramalarda bu başlık bulunacak.',
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: ValueKey('request-title-${category.name}'),
          controller: form.titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'İlan başlığı *',
            hintText: 'Örn. Bu akşam deneyimli garson lazım',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: form.descriptionController,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'İhtiyacın ayrıntıları *',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Belirli bir tarih var'),
                subtitle: const Text(
                  'Kapalıysa ilan, hizmeti bulana kadar aktif kalır.',
                ),
                value: form.hasSpecificDate,
                onChanged: (value) =>
                    setState(() => form.hasSpecificDate = value),
              ),
              if (form.hasSpecificDate)
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    form.neededAt == null
                        ? 'Tarih seç'
                        : _dateLabel(form.neededAt!),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickNeededDate(form),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PricingUnit>(
          initialValue: form.pricingUnit,
          decoration: const InputDecoration(labelText: 'Ücret türü'),
          items: [
            for (final unit in PricingUnit.values)
              DropdownMenuItem(
                value: unit,
                child: Text(_pricingUnitLabel(unit)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => form.pricingUnit = value);
          },
        ),
        if (form.pricingUnit != PricingUnit.negotiable) ...[
          const SizedBox(height: 12),
          TextField(
            controller: form.budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bütçe *',
              prefixText: '₺ ',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bütçe KDV dahil'),
            value: form.priceIncludesVat,
            onChanged: (value) {
              setState(() => form.priceIncludesVat = value);
            },
          ),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Acil / şu an gerekli'),
          subtitle: const Text('Haritada öncelikli olarak gösterilir.'),
          value: form.isUrgent,
          onChanged: (value) => setState(() => form.isUrgent = value),
        ),
        const SizedBox(height: 12),
        const AppSectionHeader(
          title: 'Hizmet veren tercihi',
          subtitle: 'İstersen belirt; boş bırakırsan herkes başvurabilir.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const <(String?, String)>[
              (null, 'Fark etmez'),
              ('person', 'Şahıs'),
              ('business', 'Kurumsal'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: form.preferredProviderKind == option.$1,
                onSelected: (_) =>
                    setState(() => form.preferredProviderKind = option.$1),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const <(String?, String)>[
              (null, 'Cinsiyet fark etmez'),
              ('female', 'Kadın'),
              ('male', 'Erkek'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: form.preferredProviderGender == option.$1,
                onSelected: (_) =>
                    setState(() => form.preferredProviderGender = option.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _selectedImage == null
                ? 'İsteğe bağlı fotoğraf ekle'
                : 'Fotoğrafı değiştir: ${_selectedImage!.name}',
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final locationLabel = _locationPrecision == LocationPrecision.exact
        ? '${_neighborhoodController.text.trim()}, ${_districtController.text.trim()}'
        : 'Haritada seçtiğin yakın konum';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        AppPageHeader(
          title: 'İlanı Kontrol Et',
          subtitle:
              'Tek hizmet ilanını yayınlamadan önce bilgileri kontrol et.',
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(locationLabel),
            subtitle: Text(
              _locationPrecision == LocationPrecision.exact
                  ? 'Net adres • Tam bilgi korumalı'
                  : 'Yakın konum • Adres bilgisi yok',
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < _orderedCategories.length; index++) ...[
          _ReviewItemCard(
            index: index,
            category: _orderedCategories[index],
            form: _forms[_orderedCategories[index]]!,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: AppColors.aquaSoft,
      borderColor: AppColors.aqua,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.turquoiseDark),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.index,
    required this.category,
    required this.form,
  });

  final int index;
  final ServiceCategory category;
  final _RequestItemFormData form;

  @override
  Widget build(BuildContext context) {
    final budget = form.pricingUnit == PricingUnit.negotiable
        ? 'Teklif alınır'
        : '${form.budgetController.text.trim()} ₺ • ${_pricingUnitLabel(form.pricingUnit)}';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.aqua,
            foregroundColor: AppColors.turquoiseDeep,
            child: Text('${index + 1}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.label} • ${form.titleController.text.trim()}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  form.hasSpecificDate && form.neededAt != null
                      ? _dateLabel(form.neededAt!)
                      : 'Genel ilan • Hizmeti bulana kadar aktif',
                ),
                const SizedBox(height: 4),
                Text(budget),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestItemFormData {
  _RequestItemFormData(ServiceCategory category)
    : titleController = TextEditingController(
        text: '${category.label} arıyorum',
      );

  final TextEditingController titleController;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  PricingUnit pricingUnit = PricingUnit.fixed;
  bool priceIncludesVat = false;
  bool isUrgent = false;
  bool hasSpecificDate = false;
  DateTime? neededAt;
  String? preferredProviderKind;
  String? preferredProviderGender;

  ServiceRequestItemDraft toDraft(ServiceCategory category) {
    final parsedBudget = pricingUnit == PricingUnit.negotiable
        ? 0.0
        : double.parse(budgetController.text.trim().replaceAll(',', '.'));
    return ServiceRequestItemDraft(
      category: category,
      title: titleController.text,
      description: descriptionController.text,
      priceAmount: parsedBudget,
      pricingUnit: pricingUnit,
      priceIncludesVat: priceIncludesVat,
      scheduleNote: hasSpecificDate && neededAt != null
          ? _dateLabel(neededAt!)
          : '',
      isUrgent: isUrgent,
      expiresAt: hasSpecificDate && neededAt != null
          ? DateTime(neededAt!.year, neededAt!.month, neededAt!.day, 23, 59, 59)
          : null,
      preferredProviderKind: preferredProviderKind,
      preferredProviderGender: preferredProviderGender,
    );
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    budgetController.dispose();
  }
}

String _pricingUnitLabel(PricingUnit unit) => switch (unit) {
  PricingUnit.fixed => 'Toplam ücret',
  PricingUnit.hourly => 'Saatlik',
  PricingUnit.daily => 'Günlük',
  PricingUnit.perSession => 'Seans başına',
  PricingUnit.startingAt => 'Başlangıç fiyatı',
  PricingUnit.negotiable => 'Teklif alınır',
  PricingUnit.free => 'Ücretsiz',
};

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

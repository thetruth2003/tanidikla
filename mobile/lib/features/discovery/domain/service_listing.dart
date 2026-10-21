enum ListingType { serviceOffer, serviceRequest }

enum PricingUnit {
  fixed,
  hourly,
  daily,
  perSession,
  startingAt,
  negotiable,
  free,
}

extension PricingUnitApiValue on PricingUnit {
  String get apiValue => switch (this) {
    PricingUnit.fixed => 'fixed',
    PricingUnit.hourly => 'hourly',
    PricingUnit.daily => 'daily',
    PricingUnit.perSession => 'per_session',
    PricingUnit.startingAt => 'starting_at',
    PricingUnit.negotiable => 'negotiable',
    PricingUnit.free => 'free',
  };
}

enum LocationPrecision { exact, neighborhood }

enum ServiceCategoryGroup {
  homeTechnical,
  vehicleRoad,
  cleaningCare,
  education,
  foodRetail,
  courierTransport,
  computerIt,
}

extension ServiceCategoryGroupDetails on ServiceCategoryGroup {
  String get id => switch (this) {
    ServiceCategoryGroup.homeTechnical => 'home_technical',
    ServiceCategoryGroup.vehicleRoad => 'vehicle_road',
    ServiceCategoryGroup.cleaningCare => 'cleaning_care',
    ServiceCategoryGroup.education => 'education_private_lesson',
    ServiceCategoryGroup.foodRetail => 'food_retail',
    ServiceCategoryGroup.courierTransport => 'courier_transport',
    ServiceCategoryGroup.computerIt => 'computer_it',
  };

  String get label => switch (this) {
    ServiceCategoryGroup.homeTechnical => 'Ev ve Teknik',
    ServiceCategoryGroup.vehicleRoad => 'Araç ve Yol',
    ServiceCategoryGroup.cleaningCare => 'Temizlik ve Bakım',
    ServiceCategoryGroup.education => 'Eğitim ve Özel Ders',
    ServiceCategoryGroup.foodRetail => 'Yeme-İçme ve Mağaza',
    ServiceCategoryGroup.courierTransport => 'Kurye ve Taşıma',
    ServiceCategoryGroup.computerIt => 'Bilgisayar ve IT',
  };

  List<ServiceCategory> get categories => ServiceCategory.values
      .where((category) => category.group == this)
      .toList(growable: false);
}

enum ServiceCategory {
  electrician,
  plumbing,
  painter,
  furnitureAssembly,
  applianceRepair,
  hvacService,
  otherHomeTechnical,
  tireRepair,
  roadAssistance,
  batteryJumpStart,
  carCleaning,
  otherVehicleRoad,
  cleaning,
  officeCleaning,
  postConstructionCleaning,
  childCare,
  elderCare,
  otherCleaningCare,
  schoolTutoring,
  foreignLanguage,
  drivingInstructor,
  musicTeacher,
  fitnessCoach,
  computerTraining,
  otherEducation,
  waiter,
  bartender,
  kitchenStaff,
  shopAssistant,
  barista,
  otherFoodRetail,
  courier,
  vehicleCourier,
  movingHelper,
  deliveryDriver,
  otherCourierTransport,
  computerTechnicalSupport,
  operatingSystemInstallation,
  networkModemSetup,
  softwareItSupport,
  otherComputerIt,
}

extension ServiceCategoryLabel on ServiceCategory {
  String get label => switch (this) {
    ServiceCategory.electrician => 'Elektrikçi',
    ServiceCategory.plumbing => 'Tesisatçı',
    ServiceCategory.painter => 'Boyacı',
    ServiceCategory.furnitureAssembly => 'Mobilya ve Montaj Ustası',
    ServiceCategory.applianceRepair => 'Beyaz Eşya Tamircisi',
    ServiceCategory.hvacService => 'Klima ve Kombi Ustası',
    ServiceCategory.otherHomeTechnical => 'Diğer Ev ve Teknik Hizmeti',
    ServiceCategory.tireRepair => 'Lastikçi',
    ServiceCategory.roadAssistance => 'Yol Yardımı',
    ServiceCategory.batteryJumpStart => 'Akü Takviyesi',
    ServiceCategory.carCleaning => 'Araç Temizliği',
    ServiceCategory.otherVehicleRoad => 'Diğer Araç ve Yol Hizmeti',
    ServiceCategory.cleaning => 'Ev Temizliği',
    ServiceCategory.officeCleaning => 'Ofis Temizliği',
    ServiceCategory.postConstructionCleaning => 'İnşaat Sonrası Temizlik',
    ServiceCategory.childCare => 'Çocuk Bakıcısı',
    ServiceCategory.elderCare => 'Yaşlı/Hasta Bakıcısı',
    ServiceCategory.otherCleaningCare => 'Diğer Temizlik veya Bakım Hizmeti',
    ServiceCategory.schoolTutoring => 'Okul Dersleri Öğretmeni',
    ServiceCategory.foreignLanguage => 'Yabancı Dil Öğretmeni',
    ServiceCategory.drivingInstructor => 'Sürücü Eğitmeni',
    ServiceCategory.musicTeacher => 'Gitar/Müzik Öğretmeni',
    ServiceCategory.fitnessCoach => 'Spor Eğitmeni',
    ServiceCategory.computerTraining => 'Bilgisayar/Yazılım Eğitmeni',
    ServiceCategory.otherEducation => 'Diğer Özel Ders / Eğitim',
    ServiceCategory.waiter => 'Garson',
    ServiceCategory.bartender => 'Barmen',
    ServiceCategory.kitchenStaff => 'Aşçı/Mutfak Elemanı',
    ServiceCategory.shopAssistant => 'Tezgahtar',
    ServiceCategory.barista => 'Barista',
    ServiceCategory.otherFoodRetail => 'Diğer Gastronomi / İşletme Hizmeti',
    ServiceCategory.courier => 'Motorlu Kurye',
    ServiceCategory.vehicleCourier => 'Araçlı Kurye',
    ServiceCategory.movingHelper => 'Taşıma/Hamaliye Elemanı',
    ServiceCategory.deliveryDriver => 'Teslimat Şoförü',
    ServiceCategory.otherCourierTransport => 'Diğer Taşıma / Lojistik Hizmeti',
    ServiceCategory.computerTechnicalSupport => 'Bilgisayar Teknik Destek',
    ServiceCategory.operatingSystemInstallation =>
      'Format ve İşletim Sistemi Kurulumu',
    ServiceCategory.networkModemSetup => 'Modem ve Ağ Kurulumu',
    ServiceCategory.softwareItSupport => 'Yazılım ve IT Desteği',
    ServiceCategory.otherComputerIt => 'Diğer Bilgisayar ve IT Hizmeti',
  };

  String get dbValue => switch (this) {
    ServiceCategory.electrician => 'electrician',
    ServiceCategory.plumbing => 'plumbing',
    ServiceCategory.painter => 'painter',
    ServiceCategory.furnitureAssembly => 'furniture_assembly',
    ServiceCategory.applianceRepair => 'appliance_repair',
    ServiceCategory.hvacService => 'hvac_service',
    ServiceCategory.otherHomeTechnical => 'other_home_technical',
    ServiceCategory.tireRepair => 'tire_repair',
    ServiceCategory.roadAssistance => 'road_assistance',
    ServiceCategory.batteryJumpStart => 'battery_jump_start',
    ServiceCategory.carCleaning => 'car_cleaning',
    ServiceCategory.otherVehicleRoad => 'other_vehicle_road',
    ServiceCategory.cleaning => 'cleaning',
    ServiceCategory.officeCleaning => 'office_cleaning',
    ServiceCategory.postConstructionCleaning => 'post_construction_cleaning',
    ServiceCategory.childCare => 'child_care',
    ServiceCategory.elderCare => 'elder_care',
    ServiceCategory.otherCleaningCare => 'other_cleaning_care',
    ServiceCategory.schoolTutoring => 'school_tutoring',
    ServiceCategory.foreignLanguage => 'foreign_language',
    ServiceCategory.drivingInstructor => 'driving_instructor',
    ServiceCategory.musicTeacher => 'music_teacher',
    ServiceCategory.fitnessCoach => 'fitness_coach',
    ServiceCategory.computerTraining => 'computer_training',
    ServiceCategory.otherEducation => 'other_education',
    ServiceCategory.waiter => 'waiter',
    ServiceCategory.bartender => 'bartender',
    ServiceCategory.kitchenStaff => 'kitchen_staff',
    ServiceCategory.shopAssistant => 'shop_assistant',
    ServiceCategory.barista => 'barista',
    ServiceCategory.otherFoodRetail => 'other_food_retail',
    ServiceCategory.courier => 'courier',
    ServiceCategory.vehicleCourier => 'vehicle_courier',
    ServiceCategory.movingHelper => 'moving_helper',
    ServiceCategory.deliveryDriver => 'delivery_driver',
    ServiceCategory.otherCourierTransport => 'other_courier_transport',
    ServiceCategory.computerTechnicalSupport => 'computer_technical_support',
    ServiceCategory.operatingSystemInstallation =>
      'operating_system_installation',
    ServiceCategory.networkModemSetup => 'network_modem_setup',
    ServiceCategory.softwareItSupport => 'software_it_support',
    ServiceCategory.otherComputerIt => 'other_computer_it',
  };

  ServiceCategoryGroup get group => switch (this) {
    ServiceCategory.electrician ||
    ServiceCategory.plumbing ||
    ServiceCategory.painter ||
    ServiceCategory.furnitureAssembly ||
    ServiceCategory.applianceRepair ||
    ServiceCategory.hvacService ||
    ServiceCategory.otherHomeTechnical => ServiceCategoryGroup.homeTechnical,
    ServiceCategory.tireRepair ||
    ServiceCategory.roadAssistance ||
    ServiceCategory.batteryJumpStart ||
    ServiceCategory.carCleaning ||
    ServiceCategory.otherVehicleRoad => ServiceCategoryGroup.vehicleRoad,
    ServiceCategory.cleaning ||
    ServiceCategory.officeCleaning ||
    ServiceCategory.postConstructionCleaning ||
    ServiceCategory.childCare ||
    ServiceCategory.elderCare ||
    ServiceCategory.otherCleaningCare => ServiceCategoryGroup.cleaningCare,
    ServiceCategory.schoolTutoring ||
    ServiceCategory.foreignLanguage ||
    ServiceCategory.drivingInstructor ||
    ServiceCategory.musicTeacher ||
    ServiceCategory.fitnessCoach ||
    ServiceCategory.computerTraining ||
    ServiceCategory.otherEducation => ServiceCategoryGroup.education,
    ServiceCategory.waiter ||
    ServiceCategory.bartender ||
    ServiceCategory.kitchenStaff ||
    ServiceCategory.shopAssistant ||
    ServiceCategory.barista ||
    ServiceCategory.otherFoodRetail => ServiceCategoryGroup.foodRetail,
    ServiceCategory.courier ||
    ServiceCategory.vehicleCourier ||
    ServiceCategory.movingHelper ||
    ServiceCategory.deliveryDriver ||
    ServiceCategory.otherCourierTransport =>
      ServiceCategoryGroup.courierTransport,
    ServiceCategory.computerTechnicalSupport ||
    ServiceCategory.operatingSystemInstallation ||
    ServiceCategory.networkModemSetup ||
    ServiceCategory.softwareItSupport ||
    ServiceCategory.otherComputerIt => ServiceCategoryGroup.computerIt,
  };

  bool get isOpenEnded => switch (this) {
    ServiceCategory.otherHomeTechnical ||
    ServiceCategory.otherVehicleRoad ||
    ServiceCategory.otherCleaningCare ||
    ServiceCategory.otherEducation ||
    ServiceCategory.otherFoodRetail ||
    ServiceCategory.otherCourierTransport => true,
    ServiceCategory.otherComputerIt => true,
    _ => false,
  };

  String get fullLabel => '${group.label} • $label';
}

ServiceCategory serviceCategoryFromDbValue(String? value) {
  for (final category in ServiceCategory.values) {
    if (category.dbValue == value) return category;
  }
  throw FormatException('Bilinmeyen kategori: $value');
}

class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.ownerName,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.priceAmount,
    required this.pricingUnit,
    required this.priceIncludesVat,
    required this.district,
    required this.neighborhood,
    required this.latitude,
    required this.longitude,
    required this.locationPrecision,
    required this.distanceKm,
    required this.availableNow,
    this.ownerId = 'provider-demo',
    this.availabilityLabel = 'Saat bilgisi belirtilmedi',
    this.ownerRating = 0,
    this.ownerReviewCount = 0,
    this.bundleId,
    this.bundleItemIndex = 0,
    this.bundleItemCount = 1,
    this.expiresAt,
    this.privateDistrict = '',
    this.privateNeighborhood = '',
    this.privateStreet = '',
    this.privateBuildingNumber = '',
    this.city = '',
    this.serviceRadiusKm,
    this.preferredProviderKind,
    this.preferredProviderGender,
    this.imageUrls = const [],
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String description;
  final ListingType type;
  final ServiceCategory category;
  final double priceAmount;
  final PricingUnit pricingUnit;
  final bool priceIncludesVat;
  final String district;
  final String neighborhood;
  final double latitude;
  final double longitude;
  final LocationPrecision locationPrecision;
  final double distanceKm;
  final bool availableNow;
  final String availabilityLabel;
  final double ownerRating;
  final int ownerReviewCount;
  final String? bundleId;
  final int bundleItemIndex;
  final int bundleItemCount;
  final DateTime? expiresAt;
  final String privateDistrict;
  final String privateNeighborhood;
  final String privateStreet;
  final String privateBuildingNumber;
  final String city;
  final int? serviceRadiusKm;
  final String? preferredProviderKind;
  final String? preferredProviderGender;
  final List<String> imageUrls;

  ServiceListing copyWith({
    String? title,
    String? description,
    ServiceCategory? category,
    double? priceAmount,
    PricingUnit? pricingUnit,
    bool? priceIncludesVat,
    String? district,
    String? neighborhood,
    bool? availableNow,
    String? availabilityLabel,
    String? city,
    int? serviceRadiusKm,
    bool clearServiceRadius = false,
    String? preferredProviderKind,
    String? preferredProviderGender,
    List<String>? imageUrls,
  }) {
    return ServiceListing(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type,
      category: category ?? this.category,
      priceAmount: priceAmount ?? this.priceAmount,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      priceIncludesVat: priceIncludesVat ?? this.priceIncludesVat,
      district: district ?? this.district,
      neighborhood: neighborhood ?? this.neighborhood,
      latitude: latitude,
      longitude: longitude,
      locationPrecision: locationPrecision,
      distanceKm: distanceKm,
      availableNow: availableNow ?? this.availableNow,
      availabilityLabel: availabilityLabel ?? this.availabilityLabel,
      ownerRating: ownerRating,
      ownerReviewCount: ownerReviewCount,
      bundleId: bundleId,
      bundleItemIndex: bundleItemIndex,
      bundleItemCount: bundleItemCount,
      expiresAt: expiresAt,
      privateDistrict: privateDistrict,
      privateNeighborhood: privateNeighborhood,
      privateStreet: privateStreet,
      privateBuildingNumber: privateBuildingNumber,
      city: city ?? this.city,
      serviceRadiusKm: clearServiceRadius
          ? null
          : serviceRadiusKm ?? this.serviceRadiusKm,
      preferredProviderKind:
          preferredProviderKind ?? this.preferredProviderKind,
      preferredProviderGender:
          preferredProviderGender ?? this.preferredProviderGender,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  String get locationLabel => '$neighborhood, $district';

  String get priceLabel {
    if (pricingUnit == PricingUnit.negotiable) return 'Teklif alınır';
    if (pricingUnit == PricingUnit.free) return 'Ücretsiz';

    final amount = priceAmount.toStringAsFixed(
      priceAmount.truncateToDouble() == priceAmount ? 0 : 2,
    );
    final suffix = switch (pricingUnit) {
      PricingUnit.fixed => ' · sabit',
      PricingUnit.hourly => ' / saat',
      PricingUnit.daily => ' / gün',
      PricingUnit.perSession => ' / seans',
      PricingUnit.startingAt => "'den başlayan",
      PricingUnit.negotiable => '',
      PricingUnit.free => '',
    };
    final vat = priceIncludesVat ? ' • KDV dahil' : '';
    return '$amount ₺$suffix$vat';
  }
}

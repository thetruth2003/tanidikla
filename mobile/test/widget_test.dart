import 'package:ankara_proje/app/app.dart';
import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/data/fake_listing_repository.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/map_preview.dart';
import 'package:ankara_proje/features/listing/data/reverse_geocoding_service.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/category_group_selector.dart';
import 'package:ankara_proje/features/listing/presentation/widgets/request_location_picker.dart';
import 'package:ankara_proje/features/messages/application/message_controller.dart';
import 'package:ankara_proje/features/messages/domain/conversation.dart';
import 'package:ankara_proje/features/messages/domain/message_repository.dart';
import 'package:ankara_proje/features/messages/presentation/chat_screen.dart';
import 'package:ankara_proje/features/messages/presentation/messages_screen.dart';
import 'package:ankara_proje/features/profile/presentation/provider_profile_setup_screen.dart';
import 'package:ankara_proje/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  setUp(() => appRouter.go(AppRoutes.discovery));

  test('listeyi haritanın görünen koordinat sınırına göre filtreler', () async {
    final listings = await FakeListingRepository().fetchActiveListings();
    final visible = listingsWithinBounds(
      listings,
      LatLngBounds(const LatLng(39.89, 32.80), const LatLng(39.95, 32.88)),
    );

    expect(visible.map((item) => item.id), contains('offer-tire-1'));
    expect(visible.map((item) => item.id), contains('offer-courier-1'));
    expect(visible.map((item) => item.id), isNot(contains('offer-cleaning-1')));
    expect(
      visible.every(
        (item) =>
            item.latitude >= 39.89 &&
            item.latitude <= 39.95 &&
            item.longitude >= 32.80 &&
            item.longitude <= 32.88,
      ),
      isTrue,
    );
  });

  test(
    'gelişmiş filtreleri fiyat saat mesafe puan ve konuma uygular',
    () async {
      final container = ProviderContainer(
        overrides: [
          listingRepositoryProvider.overrideWithValue(FakeListingRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeListingsProvider.future);

      container
          .read(discoveryControllerProvider.notifier)
          .applyFilters(
            group: ServiceCategoryGroup.vehicleRoad,
            category: ServiceCategory.tireRepair,
            onlyAvailableNow: true,
            onlyWithWorkingHours: true,
            onlyVatIncluded: true,
            minPrice: 800,
            maxPrice: 900,
            maxDistanceKm: 5,
            minRating: 4.5,
            pricingUnit: PricingUnit.fixed,
            locationPrecision: LocationPrecision.exact,
            providerKind: null,
            gender: null,
          );

      final filtered = container.read(visibleListingsProvider).requireValue;
      expect(filtered.map((item) => item.id), ['offer-tire-1']);

      container.read(discoveryControllerProvider.notifier).resetFilters();
      final reset = container.read(visibleListingsProvider).requireValue;
      expect(reset.length, 4);
    },
  );

  test('profil yenilenirken eski eksik sonucuyla yönlendirme yapmaz', () {
    expect(shouldOpenProfileCompletion(const AsyncLoading<bool>()), isFalse);
    expect(shouldOpenProfileCompletion(const AsyncData<bool>(false)), isTrue);
    expect(shouldOpenProfileCompletion(const AsyncData<bool>(true)), isFalse);
  });

  testWidgets('hizmet ve iş keşif modları arasında geçiş yapar', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tanıdıkla'), findsOneWidget);
    expect(find.text('Hizmet Bul'), findsOneWidget);
    expect(find.text('İş Bul'), findsOneWidget);
    expect(find.byType(MapPreview), findsOneWidget);
    expect(find.text('Araç ve Yol'), findsOneWidget);
    expect(find.text('Temizlik ve Bakım'), findsOneWidget);

    await tester.tap(find.text('İş Bul'));
    await tester.pumpAndSettle();

    expect(find.text('Yakındaki iş taleplerinde ara'), findsOneWidget);
  });

  testWidgets('harita ve liste görünümü arasında geçiş yapar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MapPreview), findsOneWidget);

    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    expect(find.text('Yerinde lastik tamiri'), findsOneWidget);
    expect(find.byType(MapPreview), findsNothing);
  });

  testWidgets('filtreler daralan başlıklar altında açılır', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtreler'));
    await tester.pumpAndSettle();

    expect(find.text('İlan türü ve kategori'), findsOneWidget);
    expect(find.text('Fiyat'), findsOneWidget);
    expect(find.text('Müsaitlik ve çalışma saatleri'), findsOneWidget);
    expect(find.text('Mesafe ve konum'), findsOneWidget);
    expect(find.text('Puan ve diğer seçenekler'), findsOneWidget);

    await tester.tap(find.text('Fiyat'));
    await tester.pumpAndSettle();
    expect(find.text('En düşük'), findsOneWidget);
    expect(find.text('En yüksek'), findsOneWidget);
    expect(find.text('Saatlik'), findsOneWidget);
  });

  testWidgets('arama başlık ve kategoriye bakar, açıklamayı karıştırmaz', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'kurye');
    await tester.pumpAndSettle();

    expect(find.text('Motorlu kurye hizmeti'), findsOneWidget);
    expect(find.text('Yerinde lastik tamiri'), findsNothing);

    await tester.enterText(searchField, 'geniş çantam');
    await tester.pump();

    expect(find.text('Motorlu kurye hizmeti'), findsNothing);
  });

  testWidgets('boş harita uyarısı iki saniye sonra kaybolur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPreview(listings: const [], onListingTap: (_) {}),
        ),
      ),
    );

    expect(find.text('Bu filtrelerde aktif ilan bulunamadı.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Bu filtrelerde aktif ilan bulunamadı.'), findsNothing);
  });

  testWidgets('harita kartı yalnız işaret seçiliyken görünür', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final listings = await FakeListingRepository().fetchActiveListings();
    final listing = listings.firstWhere((item) => item.id == 'offer-courier-1');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPreview(listings: [listing], onListingTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(ValueKey('map-listing-card-${listing.id}'));
    expect(card, findsNothing);
    final clusterLayer = tester.widget<MarkerClusterLayerWidget>(
      find.byType(MarkerClusterLayerWidget),
    );
    expect(clusterLayer.options.zoomToBoundsOnClick, isTrue);
    expect(clusterLayer.options.spiderfyCluster, isTrue);
    expect(clusterLayer.options.disableClusteringAtZoom, 15);

    await tester.tap(find.byKey(ValueKey('map-pin-${listing.id}')));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    final mapRect = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(Offset(mapRect.left + 70, mapRect.top + 300));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('boş liste uyarısı iki saniye sonra kaybolur', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeListingsProvider.overrideWith((ref) async => const []),
        ],
        child: const AnkaraServicesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Liste'));
    await tester.pump();

    expect(find.text('Henüz aktif hizmet yok'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Henüz aktif hizmet yok'), findsNothing);
  });

  testWidgets('kendi ilanlarını oturum kimliğine göre ayırır', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Motorlu kurye hizmeti'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Senin ilanın'), findsOneWidget);

    await tester.tap(find.text('Harita'));
    await tester.pumpAndSettle();

    final map = tester.widget<MapPreview>(find.byType(MapPreview));
    expect(map.currentUserId, 'current-user');
  });

  testWidgets('ilan verme ekranını alt menü sekmesinden açar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reverseGeocodingServiceProvider.overrideWithValue(
            const _FakeReverseGeocodingService(),
          ),
        ],
        child: const AnkaraServicesApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlan Ver'));
    await tester.pumpAndSettle();

    expect(find.text('İlan Oluştur'), findsOneWidget);
    expect(find.text('Mesajlar'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('hizmet talebi konum ve adres seçimiyle başlar', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlan Ver'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hizmet Alıyorum'));
    await tester.tap(find.text('Hizmet Alıyorum'));
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('Hizmet nerede yapılacak?'), findsOneWidget);
    expect(find.text('Net adres'), findsOneWidget);
    expect(find.text('Yakın konum'), findsOneWidget);
    expect(
      find.text('Devam etmek için haritayı taşı ve bulunan konumu doğrula.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Net adres'));
    await tester.pumpAndSettle();

    expect(find.text('İlçe *'), findsOneWidget);
    expect(find.text('Mahalle *'), findsOneWidget);
    expect(find.text('Cadde / Sokak *'), findsOneWidget);
  });

  testWidgets('ilan oluştururken yalnız son seçilen hizmeti kullanır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reverseGeocodingServiceProvider.overrideWithValue(
            const _FakeReverseGeocodingService(),
          ),
        ],
        child: const AnkaraServicesApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlan Ver'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hizmet Alıyorum'));
    await tester.tap(find.text('Hizmet Alıyorum'));
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    final picker = tester.widget<RequestLocationPicker>(
      find.byType(RequestLocationPicker),
    );
    picker.onChanged(const LatLng(39.92, 32.85));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu konumu doğrula'));
    await tester.pump();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    final categorySelector = tester.widget<CategoryGroupSelector>(
      find.byType(CategoryGroupSelector),
    );
    categorySelector.onChanged(ServiceCategory.waiter);
    categorySelector.onChanged(ServiceCategory.courier);
    await tester.pump();

    expect(find.textContaining('Kurye'), findsWidgets);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    expect(find.text('Motorlu Kurye ihtiyacı'), findsOneWidget);
    expect(find.text('Tek hizmet ilanı'), findsOneWidget);
  });

  testWidgets('ilan detayında saat fiyat ve profil bağlantısı görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yerinde lastik tamiri'));
    await tester.pumpAndSettle();

    expect(find.text('Açıklama'), findsOneWidget);
    expect(find.text('Çalışma saatleri'), findsOneWidget);
    expect(find.text('Her gün 08.00–23.00'), findsOneWidget);
    expect(find.text('Profili görüntüle'), findsOneWidget);
  });

  testWidgets('ilan detayından mesaj ekranına çakışmasız geçer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yerinde lastik tamiri'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mesaj gönder'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Mesaj gönder'));
    await tester.pumpAndSettle();

    expect(find.text('İlan Görüşmesi'), findsOneWidget);
    expect(find.text('İlk mesajı gönder.'), findsOneWidget);
  });

  testWidgets('sohbette yeni mesaj eskilerin altında görünür', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            const _OrderedMessageRepository(),
          ),
        ],
        child: const MaterialApp(
          home: ChatScreen(conversationId: 'conversation-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final oldTop = tester.getTopLeft(find.text('Eski mesaj')).dy;
    final newTop = tester.getTopLeft(find.text('Yeni mesaj')).dy;
    expect(oldTop, lessThan(newTop));
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('03.08.2020'), findsOneWidget);
  });

  testWidgets('mesajlar hizmet alma ve verme bölümlerine ayrılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(
            const _SplitConversationRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MessagesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Lastik hizmeti alacağım'), findsOneWidget);
    expect(find.textContaining('Garson hizmeti vereceğim'), findsNothing);

    await tester.tap(find.text('Hizmet Ver'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lastik hizmeti alacağım'), findsNothing);
    expect(find.textContaining('Garson hizmeti vereceğim'), findsOneWidget);
  });

  testWidgets('profil hizmetleri ihtiyaçları puan ve yorumları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profilimi Düzenle'), findsOneWidget);
    expect(find.text('İlgi ve Bildirim Alanlarım'), findsOneWidget);
    expect(find.text('Aktif İlanlarım'), findsOneWidget);
  });

  testWidgets('profil düzenleme Türkçe karakterleri destekler', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProviderProfileSetupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, 'Çağrı Şen');
    expect(
      tester.widget<TextFormField>(nameField).controller?.text,
      'Çağrı Şen',
    );
    final bioField = find.byType(TextFormField).last;
    await tester.enterText(
      bioField,
      'Çözüm odaklıyım; ağ, modem ve yazılım desteği sağlıyorum.',
    );
    expect(
      tester.widget<TextFormField>(bioField).controller?.text,
      contains('Çözüm'),
    );

    expect(find.text('Aktif İlanlarım'), findsNothing);
  });
}

class _FakeReverseGeocodingService implements ReverseGeocodingService {
  const _FakeReverseGeocodingService();

  @override
  Future<ResolvedAddress> resolve(LatLng point) async {
    return const ResolvedAddress(
      city: 'Ankara',
      displayName: 'Kızılay, Çankaya, Ankara',
      district: 'Çankaya',
      neighborhood: 'Kızılay',
      street: 'Atatürk Bulvarı',
      buildingNumber: '10',
    );
  }
}

class _OrderedMessageRepository implements MessageRepository {
  const _OrderedMessageRepository();

  @override
  Future<List<ConversationSummary>> fetchConversations() async => const [];

  @override
  Future<void> sendMessage(
    String conversationId,
    String body, {
    List<MessageImageUpload> attachments = const [],
  }) async {}

  @override
  Future<String> startListingConversation(String listingId) async =>
      'conversation-1';

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return Stream.value([
      ChatMessage(
        id: 2,
        conversationId: conversationId,
        senderId: 'current-user',
        body: 'Yeni mesaj',
        createdAt: DateTime(2020, 8, 3, 12),
      ),
      ChatMessage(
        id: 1,
        conversationId: conversationId,
        senderId: 'other-user',
        body: 'Eski mesaj',
        createdAt: DateTime(2020, 8, 3, 11),
      ),
    ]);
  }
}

class _SplitConversationRepository implements MessageRepository {
  const _SplitConversationRepository();

  @override
  Future<List<ConversationSummary>> fetchConversations() async => [
    ConversationSummary(
      id: 'receiving',
      listingId: 'listing-1',
      listingTitle: 'Lastik hizmeti alacağım',
      otherUserName: 'Lastikçi',
      lastMessage: 'Yola çıkıyorum',
      updatedAt: DateTime(2026, 8, 3, 12),
      section: ConversationSection.receivingService,
    ),
    ConversationSummary(
      id: 'providing',
      listingId: 'listing-2',
      listingTitle: 'Garson hizmeti vereceğim',
      otherUserName: 'Restoran',
      lastMessage: 'Saat 18 uygun',
      updatedAt: DateTime(2026, 8, 3, 11),
      section: ConversationSection.providingService,
    ),
  ];

  @override
  Future<void> sendMessage(
    String conversationId,
    String body, {
    List<MessageImageUpload> attachments = const [],
  }) async {}

  @override
  Future<String> startListingConversation(String listingId) async =>
      'receiving';

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      Stream.value(const []);
}

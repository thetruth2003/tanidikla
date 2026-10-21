import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/discovery/application/discovery_controller.dart';
import 'package:ankara_proje/features/discovery/data/fake_listing_repository.dart';
import 'package:ankara_proje/features/listing/presentation/edit_listing_screen.dart';
import 'package:ankara_proje/features/profile/application/profile_controller.dart';
import 'package:ankara_proje/features/profile/data/fake_profile_repository.dart';
import 'package:ankara_proje/features/profile/presentation/my_listings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('kullanıcı aktif ilanının bilgilerini düzenler', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final testRouter = GoRouter(
      initialLocation: AppRoutes.myListings,
      routes: [
        GoRoute(
          path: AppRoutes.myListings,
          builder: (context, state) => const MyListingsScreen(),
        ),
        GoRoute(
          path: '/listing/:listingId/edit',
          builder: (context, state) =>
              EditListingScreen(listingId: state.pathParameters['listingId']!),
        ),
      ],
    );
    addTearDown(testRouter.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('current-user'),
          listingRepositoryProvider.overrideWithValue(FakeListingRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: MaterialApp.router(routerConfig: testRouter),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Düzenle').first,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Düzenle').first);
    await tester.pumpAndSettle();

    expect(find.text('İlanı Düzenle'), findsOneWidget);
    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          widget.controller?.text == 'Motorlu kurye hizmeti',
    );
    expect(titleField, findsOneWidget);
    await tester.enterText(titleField, 'Güncel motorlu kurye hizmeti');
    await tester.scrollUntilVisible(
      find.text('Değişiklikleri kaydet'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Değişiklikleri kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Aktif İlanlarım'), findsOneWidget);
  });
}

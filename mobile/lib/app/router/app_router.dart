import 'package:ankara_proje/core/widgets/main_shell.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:ankara_proje/features/auth/presentation/auth_screen.dart';
import 'package:ankara_proje/features/auth/presentation/account_security_screen.dart';
import 'package:ankara_proje/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:ankara_proje/features/engagements/presentation/engagements_screen.dart';
import 'package:ankara_proje/features/listing/presentation/create_listing_screen.dart';
import 'package:ankara_proje/features/listing/presentation/edit_listing_screen.dart';
import 'package:ankara_proje/features/listing/presentation/listing_detail_screen.dart';
import 'package:ankara_proje/features/listing/presentation/service_offer_wizard_screen.dart';
import 'package:ankara_proje/features/listing/presentation/service_request_wizard_screen.dart';
import 'package:ankara_proje/features/marketplace/presentation/favorites_screen.dart';
import 'package:ankara_proje/features/messages/presentation/messages_screen.dart';
import 'package:ankara_proje/features/messages/presentation/chat_screen.dart';
import 'package:ankara_proje/features/notifications/presentation/notifications_screen.dart';
import 'package:ankara_proje/features/profile/presentation/profile_completion_screen.dart';
import 'package:ankara_proje/features/privacy/presentation/privacy_screen.dart';
import 'package:ankara_proje/features/profile/presentation/profile_required_gate.dart';
import 'package:ankara_proje/features/profile/presentation/profile_screen.dart';
import 'package:ankara_proje/features/profile/presentation/provider_profile_screen.dart';
import 'package:ankara_proje/features/profile/presentation/provider_profile_setup_screen.dart';
import 'package:ankara_proje/features/profile/presentation/profile_preferences_screen.dart';
import 'package:ankara_proje/features/profile/presentation/my_listings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const auth = '/auth';
  static const discovery = '/';
  static const messages = '/messages';
  static const profile = '/profile';
  static const favorites = '/favorites';
  static const notifications = '/notifications';
  static const privacy = '/privacy';
  static const profileCompletion = '/profile/complete';
  static const createListing = '/listing/create';
  static const createServiceOffer = '/listing/create/offer';
  static const createServiceRequest = '/listing/create/request';
  static const providerProfileSetup = '/profile/provider/setup';
  static const accountSecurity = '/profile/security';
  static const profilePreferences = '/profile/preferences';
  static const myListings = '/profile/listings';
  static const engagements = '/profile/jobs';

  static String authFor(String returnTo) =>
      Uri(path: auth, queryParameters: {'returnTo': returnTo}).toString();

  static String listingDetail(String listingId) => '/listing/$listingId';
  static String editListing(String listingId) => '/listing/$listingId/edit';
  static String providerProfile(String providerId) => '/provider/$providerId';
  static String chat(String conversationId) => '/messages/$conversationId';
  static String profileCompletionFor(String returnTo) => Uri(
    path: profileCompletion,
    queryParameters: {'returnTo': returnTo},
  ).toString();
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.discovery,
  refreshListenable: apiAuthSession,
  redirect: (context, state) {
    // Widget testleri uygulamanın main() başlangıcını çalıştırmadan ekranları
    // kurar. Gerçek uygulamada main() bu noktadan önce oturumu hazırlar.
    if (!apiAuthSession.initialized) return null;
    final signedIn = apiAuthSession.isAuthenticated;
    final onAuthScreen = state.uri.path == AppRoutes.auth;
    final path = state.uri.path;
    final protected =
        path == AppRoutes.messages ||
        path.startsWith('${AppRoutes.messages}/') ||
        path == AppRoutes.profile ||
        path == AppRoutes.favorites ||
        path == AppRoutes.notifications ||
        path == AppRoutes.privacy ||
        path.startsWith('${AppRoutes.profile}/') ||
        path.startsWith('/listing/create') ||
        path.endsWith('/edit');
    if (!signedIn && protected) {
      return AppRoutes.authFor(state.uri.toString());
    }
    if (signedIn && onAuthScreen) {
      return _safeReturnTo(state.uri.queryParameters['returnTo']);
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.auth,
      builder: (context, state) => AuthScreen(
        returnTo: _safeReturnTo(state.uri.queryParameters['returnTo']),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileCompletion,
      builder: (context, state) => ProfileCompletionScreen(
        returnTo: state.uri.queryParameters['returnTo'],
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.discovery,
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: AppRoutes.createListing,
          builder: (context, state) => const ProfileRequiredGate(
            returnTo: AppRoutes.createListing,
            child: CreateListingScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.createServiceOffer,
          builder: (context, state) => const ProfileRequiredGate(
            returnTo: AppRoutes.createServiceOffer,
            child: ServiceOfferWizardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.createServiceRequest,
          builder: (context, state) => const ProfileRequiredGate(
            returnTo: AppRoutes.createServiceRequest,
            child: ServiceRequestWizardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.messages,
          builder: (context, state) => const MessagesScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.favorites,
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: AppRoutes.providerProfileSetup,
          builder: (context, state) => const ProviderProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.accountSecurity,
          builder: (context, state) => const AccountSecurityScreen(),
        ),
        GoRoute(
          path: AppRoutes.profilePreferences,
          builder: (context, state) => const ProfilePreferencesScreen(),
        ),
        GoRoute(
          path: AppRoutes.myListings,
          builder: (context, state) => const MyListingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.engagements,
          builder: (context, state) => const EngagementsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/messages/:conversationId',
      builder: (context, state) =>
          ChatScreen(conversationId: state.pathParameters['conversationId']!),
    ),
    GoRoute(
      path: '/listing/:listingId/edit',
      builder: (context, state) =>
          EditListingScreen(listingId: state.pathParameters['listingId']!),
    ),
    GoRoute(
      path: '/listing/:listingId',
      builder: (context, state) =>
          ListingDetailScreen(listingId: state.pathParameters['listingId']!),
    ),
    GoRoute(
      path: '/provider/:providerId',
      builder: (context, state) => ProviderProfileScreen(
        providerId: state.pathParameters['providerId']!,
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Sayfa bulunamadı')),
    body: Center(child: Text(state.error.toString())),
  ),
);

String _safeReturnTo(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//')) {
    return AppRoutes.discovery;
  }
  if (Uri.tryParse(value)?.path == AppRoutes.auth) {
    return AppRoutes.discovery;
  }
  return value;
}

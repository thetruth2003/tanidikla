import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteListing {
  const FavoriteListing({
    required this.id,
    required this.slug,
    required this.title,
    required this.ownerName,
    required this.district,
    required this.priceLabel,
  });

  factory FavoriteListing.fromJson(Map<String, dynamic> json) {
    final pricingUnit = json['pricing_unit']?.toString() ?? 'negotiable';
    final price = double.tryParse(json['price_amount']?.toString() ?? '');
    return FavoriteListing(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? 'İlan',
      ownerName: json['owner_name']?.toString() ?? '',
      district: json['public_district']?.toString() ?? 'Ankara',
      priceLabel: pricingUnit == 'negotiable' || price == null
          ? 'Teklif alınır'
          : '${price.toStringAsFixed(0)} ₺',
    );
  }

  final String id;
  final String slug;
  final String title;
  final String ownerName;
  final String district;
  final String priceLabel;
}

class MarketplaceClient {
  const MarketplaceClient(this._client);

  final ApiClient _client;

  Future<List<FavoriteListing>> favorites() async {
    final data = await _client.get('/favorites', query: const {'limit': 50});
    final items = data['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          FavoriteListing.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> favorite(String listingId) async {
    await _client.post('/favorites/$listingId');
  }

  Future<void> unfavorite(String listingId) async {
    await _client.delete('/favorites/$listingId');
  }

  Future<void> reportListing({
    required String listingId,
    required String reason,
    required String details,
  }) async {
    await _client.post(
      '/reports',
      body: {'listing_id': listingId, 'reason': reason, 'details': details},
    );
  }

  Future<void> blockUser(String userId) async {
    await _client.post('/blocks/$userId');
  }

  Future<void> review({
    String? reviewId,
    required String listingId,
    required double rating,
    required String comment,
  }) async {
    final body = {
      'listing_id': listingId,
      'rating': rating,
      'comment': comment,
    };
    if (reviewId == null) {
      await _client.post('/reviews', body: body);
    } else {
      await _client.put('/reviews/$reviewId', body: body);
    }
  }

  Future<Map<String, dynamic>?> ownReview({
    required String ownerId,
    required String listingId,
  }) async {
    final userId = apiAuthSession.currentUser?.id;
    if (userId == null) return null;
    final data = await _client.get(
      '/users/$ownerId/reviews',
      query: const {'limit': 50},
    );
    final items = data['items'];
    if (items is! List) return null;
    for (final item in items) {
      if (item is Map &&
          item['author_id']?.toString() == userId &&
          item['listing_id']?.toString() == listingId) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }
}

final marketplaceClientProvider = Provider<MarketplaceClient>(
  (_) => MarketplaceClient(apiClient),
);

final favoriteListingsProvider = FutureProvider<List<FavoriteListing>>((ref) {
  ref.watch(authStateChangesProvider);
  if (!apiAuthSession.initialized || !apiAuthSession.isAuthenticated) {
    return Future.value(const []);
  }
  return ref.watch(marketplaceClientProvider).favorites();
});

final favoriteListingIdsProvider = Provider<Set<String>>((ref) {
  return ref
      .watch(favoriteListingsProvider)
      .maybeWhen(
        data: (items) => items.map((item) => item.id).toSet(),
        orElse: () => const <String>{},
      );
});

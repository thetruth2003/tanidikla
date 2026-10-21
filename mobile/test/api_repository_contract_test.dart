import 'dart:async';
import 'dart:convert';

import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/features/discovery/data/api_listing_repository.dart';
import 'package:ankara_proje/features/messages/data/api_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('yanıt vermeyen API isteği zaman aşımında serbest bırakılır', () async {
    final pendingResponse = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((_) => pendingResponse.future),
    );

    await expectLater(
      client.get('/slow', timeout: const Duration(milliseconds: 20)),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 408)
            .having((error) => error.code, 'code', 'request_timeout'),
      ),
    );
  });

  test('ilan detayı parent kimliğiyle bütün paket kalemlerini okur', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/listings/parent-id');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'parent-id',
              'owner_id': 'owner-id',
              'owner_name': 'Test Kullanıcı',
              'listing_type': 'service_request',
              'public_district': 'Çankaya',
              'public_neighborhood': 'Bahçelievler',
              'latitude': 39.92,
              'longitude': 32.84,
              'location_precision': 'neighborhood',
              'owner_rating': 4.8,
              'owner_review_count': 5,
              'items': [
                {
                  'id': 'item-1',
                  'page_index': 0,
                  'category_id': 'waiter',
                  'title': 'Garson aranıyor',
                  'description': 'Akşam vardiyası için garson aranıyor.',
                  'price_amount': 1000,
                  'pricing_unit': 'daily',
                  'price_includes_vat': false,
                  'urgent': true,
                  'schedule_label': '18:00–23:00',
                },
                {
                  'id': 'item-2',
                  'page_index': 1,
                  'category_id': 'courier',
                  'title': 'Kurye aranıyor',
                  'description': 'Akşam vardiyası için kurye aranıyor.',
                  'price_amount': 1200,
                  'pricing_unit': 'daily',
                  'price_includes_vat': false,
                  'urgent': true,
                  'schedule_label': '18:00–23:00',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiListingRepository(client);

    final first = await repository.findById('parent-id');
    final bundle = await repository.findBundleItems('parent-id');

    expect(first?.bundleId, 'parent-id');
    expect(first?.bundleItemCount, 2);
    expect(bundle.map((item) => item.id), ['item-1', 'item-2']);
  });

  test('mesaj polling after_id ile bütün sayfaları birleştirir', () async {
    var requestCount = 0;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((request) async {
        requestCount += 1;
        final afterId = request.url.queryParameters['after_id'];
        if (requestCount == 1) {
          expect(afterId, '0');
          return _messageResponse([
            _message(1, 'Bir'),
            _message(2, 'İki'),
          ], hasMore: true);
        }
        expect(afterId, '2');
        return _messageResponse([_message(3, 'Üç')], hasMore: false);
      }),
    );
    final repository = ApiMessageRepository(
      client,
      pollInterval: Duration.zero,
    );

    final messages = await repository.watchMessages('conversation-id').first;

    expect(messages.map((message) => message.id), [1, 2, 3]);
    expect(requestCount, 2);
  });
}

Map<String, Object?> _message(int id, String body) => {
  'id': id,
  'conversation_id': 'conversation-id',
  'sender_id': 'sender-id',
  'body': body,
  'created_at': '2026-08-09T00:00:0${id}Z',
};

http.Response _messageResponse(
  List<Map<String, Object?>> items, {
  required bool hasMore,
}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {'items': items, 'has_more': hasMore},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

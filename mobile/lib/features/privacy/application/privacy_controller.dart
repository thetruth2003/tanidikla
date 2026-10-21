import 'package:ankara_proje/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PolicyDocument {
  const PolicyDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.title,
    required this.content,
    required this.configurationComplete,
  });

  final String id;
  final String type;
  final String version;
  final String title;
  final String content;
  final bool configurationComplete;
}

class PrivacyClient {
  const PrivacyClient(this._client);
  final ApiClient _client;

  Future<List<PolicyDocument>> policies() async {
    final data = await _client.get('/policies');
    final items = data['items'];
    if (items is! List) return const [];
    return [
      for (final raw in items)
        if (raw is Map)
          PolicyDocument(
            id: raw['id']?.toString() ?? '',
            type: raw['document_type']?.toString() ?? '',
            version: raw['version']?.toString() ?? '',
            title: raw['title']?.toString() ?? 'Yasal metin',
            content: raw['content']?.toString() ?? '',
            configurationComplete: raw['configuration_complete'] == true,
          ),
    ];
  }

  Future<Map<String, dynamic>> exportData() => _client.get('/privacy/export');

  Future<void> recordConsents(List<String> policyIds) => _client
      .post('/privacy/consents', body: {'policy_ids': policyIds})
      .then((_) {});

  Future<void> request({required String type, required String details}) =>
      _client
          .post(
            '/privacy/requests',
            body: {'request_type': type, 'details': details},
          )
          .then((_) {});
}

final privacyClientProvider = Provider<PrivacyClient>(
  (_) => PrivacyClient(apiClient),
);
final policiesProvider = FutureProvider<List<PolicyDocument>>(
  (ref) => ref.watch(privacyClientProvider).policies(),
);

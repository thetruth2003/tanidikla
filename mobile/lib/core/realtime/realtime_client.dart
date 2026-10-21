import 'dart:async';
import 'dart:convert';

import 'package:ankara_proje/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeEvent {
  const RealtimeEvent({
    required this.channel,
    required this.event,
    required this.payload,
  });

  final String channel;
  final String event;
  final Map<String, dynamic> payload;
}

class RealtimeClient {
  RealtimeClient(this._client);

  final ApiClient _client;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  Timer? _refreshTimer;
  bool _connecting = false;
  bool _shouldConnect = false;
  bool? _enabled;
  int _retrySeconds = 1;

  Stream<RealtimeEvent> get events {
    unawaited(ensureConnected());
    return _events.stream;
  }

  Future<void> ensureConnected() async {
    _shouldConnect = true;
    if (_enabled == false) return;
    if (_connecting || _channel != null || _client.bearerToken == null) return;
    _connecting = true;
    try {
      final config = await _client.get('/realtime/connection');
      if (config['enabled'] != true) {
        _enabled = false;
        _shouldConnect = false;
        return;
      }
      _enabled = true;
      final url = config['url']?.toString() ?? '';
      final token = config['token']?.toString() ?? '';
      if (url.isEmpty || token.isEmpty) return;

      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready;
      if (!_shouldConnect) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _retrySeconds = 1;
      channel.sink.add(
        jsonEncode({
          'id': 1,
          'connect': {
            'token': token,
            'name': 'ankara-flutter',
            'version': '1.0.0',
          },
        }),
      );
      _subscription = channel.stream.listen(
        _handleFrame,
        onError: (_) => _disconnectAndRetry(),
        onDone: _disconnectAndRetry,
        cancelOnError: true,
      );

      final expiresAt = DateTime.tryParse(
        config['expires_at']?.toString() ?? '',
      );
      if (expiresAt != null) {
        final delayMilliseconds =
            expiresAt.difference(DateTime.now().toUtc()).inMilliseconds -
            const Duration(seconds: 30).inMilliseconds;
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          Duration(milliseconds: delayMilliseconds.clamp(1000, 1 << 31)),
          _disconnectAndRetry,
        );
      }
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> waitForConversation(
    String conversationId,
    Duration timeout,
  ) async {
    await ensureConnected();
    try {
      await _events.stream
          .firstWhere(
            (item) =>
                item.channel == 'conversation:$conversationId' ||
                item.payload['conversation_id']?.toString() == conversationId,
          )
          .timeout(timeout);
    } on TimeoutException {
      // Polling interval elapsed; the caller will request incremental updates.
    }
  }

  void reset() {
    _shouldConnect = false;
    _reconnectTimer?.cancel();
    _refreshTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _retrySeconds = 1;
    _enabled = null;
  }

  void _handleFrame(Object? raw) {
    final value = raw is List<int> ? utf8.decode(raw) : raw?.toString() ?? '';
    for (final line in const LineSplitter().convert(value)) {
      dynamic decoded;
      try {
        decoded = jsonDecode(line);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final frame = Map<String, dynamic>.from(decoded);
      if (frame.isEmpty) {
        _channel?.sink.add('{}');
        continue;
      }
      if (frame['id'] == 1 && frame['error'] != null) {
        _disconnectAndRetry();
        continue;
      }
      final push = frame['push'];
      if (push is! Map || push['pub'] is! Map) continue;
      final publication = Map<String, dynamic>.from(push['pub'] as Map);
      if (publication['data'] is! Map) continue;
      final data = Map<String, dynamic>.from(publication['data'] as Map);
      final payload = data['payload'] is Map
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : const <String, dynamic>{};
      _events.add(
        RealtimeEvent(
          channel: push['channel']?.toString() ?? '',
          event: data['event']?.toString() ?? '',
          payload: payload,
        ),
      );
    }
  }

  void _disconnectAndRetry() {
    _refreshTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldConnect || _reconnectTimer != null) return;
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), () {
      _reconnectTimer = null;
      unawaited(ensureConnected());
    });
    _retrySeconds = (_retrySeconds * 2).clamp(1, 30).toInt();
  }
}

final realtimeClient = RealtimeClient(apiClient);
final realtimeEventsProvider = StreamProvider<RealtimeEvent>(
  (_) => realtimeClient.events,
);

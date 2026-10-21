import 'dart:async';
import 'dart:convert';

import 'package:ankara_proje/core/network/api_client.dart';
import 'package:ankara_proje/core/realtime/realtime_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiUser {
  const ApiUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.bio,
    required this.city,
    required this.district,
    required this.isProvider,
    required this.phoneE164,
    required this.phoneVisible,
    required this.phoneVerified,
    required this.emailVerified,
    required this.messageEmailNotifications,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
    id: json['id']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    displayName: json['display_name']?.toString() ?? '',
    role: json['role']?.toString() ?? 'user',
    bio: json['bio']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    district: json['district']?.toString() ?? '',
    isProvider: json['is_provider'] == true,
    phoneE164: json['phone_e164']?.toString() ?? '',
    phoneVisible: json['phone_visible'] == true,
    phoneVerified: json['phone_verified_at'] != null,
    emailVerified: json['email_verified_at'] != null,
    messageEmailNotifications: json['message_email_notifications'] == true,
  );

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String bio;
  final String city;
  final String district;
  final bool isProvider;
  final String phoneE164;
  final bool phoneVisible;
  final bool phoneVerified;
  final bool emailVerified;
  final bool messageEmailNotifications;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role,
    'bio': bio,
    'city': city,
    'district': district,
    'is_provider': isProvider,
    'phone_e164': phoneE164,
    'phone_visible': phoneVisible,
    'phone_verified_at': phoneVerified ? true : null,
    'email_verified_at': emailVerified ? true : null,
    'message_email_notifications': messageEmailNotifications,
  };
}

class ApiAuthSession extends ChangeNotifier {
  ApiAuthSession(
    this._client, {
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage {
    _client.onUnauthorized = _refreshAccessToken;
  }

  static const _legacyTokenKey = 'ankara_api_session_token';
  static const _accessTokenKey = 'ankara_api_access_token';
  static const _refreshTokenKey = 'ankara_api_refresh_token';
  static const _cachedUserKey = 'ankara_api_cached_user';
  final ApiClient _client;
  final FlutterSecureStorage _storage;
  final StreamController<ApiUser?> _changes =
      StreamController<ApiUser?>.broadcast();

  ApiUser? currentUser;
  bool initialized = false;
  String? _refreshToken;
  Future<bool>? _refreshing;

  bool get isAuthenticated => currentUser != null;
  Stream<ApiUser?> get changes => _changes.stream;

  Future<void> initialize() async {
    if (initialized) return;
    // Mark initialization as started synchronously. main() intentionally does
    // not await this method, so production repositories are selected from the
    // first frame while secure storage is restored in the background.
    initialized = true;
    var shouldVerifySession = false;
    try {
      // Secure-storage reads are independent. Reading them together keeps the
      // native splash short, especially on a cold Android start.
      final storedValues = await Future.wait<String?>([
        _storage.read(key: _accessTokenKey),
        _storage.read(key: _legacyTokenKey),
        _storage.read(key: _refreshTokenKey),
        _storage.read(key: _cachedUserKey),
      ]);
      final token = storedValues[0] ?? storedValues[1];
      _refreshToken = storedValues[2];
      if (token != null && token.isNotEmpty) {
        _client.bearerToken = token;
        currentUser = _decodeCachedUser(storedValues[3]);
        shouldVerifySession = true;
      }
    } catch (_) {
      // A temporary secure-storage error must not keep the launch screen open.
      currentUser = null;
      _client.bearerToken = null;
      _refreshToken = null;
    } finally {
      if (currentUser != null) unawaited(realtimeClient.ensureConnected());
      notifyListeners();
      _changes.add(currentUser);
    }
    if (shouldVerifySession) unawaited(_verifyRestoredSession());
  }

  Future<void> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    required String displayName,
    required bool messageEmailNotifications,
  }) async {
    final data = await _client.post(
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'display_name': displayName.trim(),
        'message_email_notifications': messageEmailNotifications,
      },
    );
    await _acceptSession(data);
  }

  Future<void> login({required String email, required String password}) async {
    final data = await _client.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    await _acceptSession(data);
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.post('/auth/password/forgot', body: {'email': email.trim()});
  }

  Future<void> logout() async {
    try {
      if (_client.bearerToken != null) await _client.post('/auth/logout');
    } finally {
      realtimeClient.reset();
      _client.bearerToken = null;
      currentUser = null;
      await _clearStoredSession();
      notifyListeners();
      _changes.add(null);
    }
  }

  Future<void> refreshUser() async {
    if (_client.bearerToken == null) return;
    final data = await _client.get('/auth/me');
    currentUser = ApiUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    await _cacheCurrentUser();
    unawaited(realtimeClient.ensureConnected());
    notifyListeners();
    _changes.add(currentUser);
  }

  Future<void> _acceptSession(Map<String, dynamic> data) async {
    final session = Map<String, dynamic>.from(data['session'] as Map);
    final token =
        session['access_token']?.toString() ??
        session['token']?.toString() ??
        '';
    if (token.isEmpty) {
      throw const ApiException(
        statusCode: 500,
        code: 'session_missing',
        message: 'Oturum başlatılamadı.',
      );
    }
    _client.bearerToken = token;
    final refreshToken = session['refresh_token']?.toString() ?? '';
    _refreshToken = refreshToken.isEmpty ? null : refreshToken;
    currentUser = ApiUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    await Future.wait<void>([
      _storage.write(key: _accessTokenKey, value: token),
      _storage.delete(key: _legacyTokenKey),
      if (refreshToken.isNotEmpty)
        _storage.write(key: _refreshTokenKey, value: refreshToken)
      else
        _storage.delete(key: _refreshTokenKey),
      _cacheCurrentUser(),
    ]);
    unawaited(realtimeClient.ensureConnected());
    notifyListeners();
    _changes.add(currentUser);
  }

  ApiUser? _decodeCachedUser(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return ApiUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      unawaited(_storage.delete(key: _cachedUserKey));
      return null;
    }
  }

  Future<void> _cacheCurrentUser() async {
    final user = currentUser;
    if (user == null) {
      await _storage.delete(key: _cachedUserKey);
      return;
    }
    await _storage.write(key: _cachedUserKey, value: jsonEncode(user.toJson()));
  }

  Future<void> _verifyRestoredSession() async {
    final restoredToken = _client.bearerToken;
    if (restoredToken == null) return;
    try {
      final data = await _client.get(
        '/auth/me',
        timeout: const Duration(seconds: 5),
      );
      // Ignore a stale response if the user logged in/out while this request
      // was running.
      if (_client.bearerToken != restoredToken) return;
      currentUser = ApiUser.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      await _cacheCurrentUser();
      unawaited(realtimeClient.ensureConnected());
      notifyListeners();
      _changes.add(currentUser);
    } on ApiException catch (error) {
      // Network/server problems keep the cached session usable. Only an
      // explicit authorization rejection removes it.
      if (_client.bearerToken == restoredToken &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        currentUser = null;
        await _clearStoredSession();
        notifyListeners();
        _changes.add(null);
      }
    } catch (_) {
      // Startup verification is best effort and never blocks the first frame.
    }
  }

  Future<bool> _refreshAccessToken() async {
    final existing = _refreshing;
    if (existing != null) return existing;
    final operation = _performRefresh();
    _refreshing = operation;
    try {
      return await operation;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final data = await _client.post(
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
      );
      await _acceptSession(data);
      return true;
    } catch (_) {
      currentUser = null;
      await _clearStoredSession();
      notifyListeners();
      _changes.add(null);
      return false;
    }
  }

  Future<void> _clearStoredSession() async {
    realtimeClient.reset();
    _client.bearerToken = null;
    _refreshToken = null;
    await Future.wait([
      _storage.delete(key: _legacyTokenKey),
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _cachedUserKey),
    ]);
  }
}

final apiAuthSession = ApiAuthSession(apiClient);
final apiAuthSessionProvider = Provider<ApiAuthSession>(
  (ref) => apiAuthSession,
);

final authStateChangesProvider = StreamProvider<ApiUser?>((ref) async* {
  yield apiAuthSession.currentUser;
  yield* apiAuthSession.changes;
});

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateChangesProvider);
  if (!apiAuthSession.initialized) return 'current-user';
  return apiAuthSession.currentUser?.id;
});

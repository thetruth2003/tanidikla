import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.isFallback,
  });

  static const turkeyCenter = UserLocation(
    latitude: 39.0,
    longitude: 35.0,
    isFallback: true,
  );

  final double latitude;
  final double longitude;
  final bool isFallback;
}

class UserLocationService {
  UserLocationService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _explanationKey = 'location_explanation_seen_v1';
  final FlutterSecureStorage _storage;

  Future<bool> shouldExplain() async =>
      await _storage.read(key: _explanationKey) != 'true';

  Future<void> markExplanationSeen() =>
      _storage.write(key: _explanationKey, value: 'true');

  Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return UserLocation.turkeyCenter;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return UserLocation.turkeyCenter;
      }

      // A cached device position is enough for the first listing request and
      // avoids waiting for a fresh GPS fix on every application launch.
      return await _lastKnown() ?? _resolvePosition();
    } catch (_) {
      return _lastKnownOrFallback();
    }
  }

  Future<UserLocation> requestCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return UserLocation.turkeyCenter;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return UserLocation.turkeyCenter;
      }

      return _resolvePosition();
    } catch (_) {
      return _lastKnownOrFallback();
    }
  }

  Future<UserLocation> _resolvePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        isFallback: false,
      );
    } catch (_) {
      return _lastKnownOrFallback();
    }
  }

  Future<UserLocation> _lastKnownOrFallback() async {
    return await _lastKnown() ?? UserLocation.turkeyCenter;
  }

  Future<UserLocation?> _lastKnown() async {
    try {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition == null) return null;
      return UserLocation(
        latitude: lastPosition.latitude,
        longitude: lastPosition.longitude,
        isFallback: false,
      );
    } catch (_) {
      return null;
    }
  }
}

final userLocationServiceProvider = Provider<UserLocationService>(
  (_) => UserLocationService(),
);

final userLocationProvider = FutureProvider<UserLocation>(
  (ref) => ref.watch(userLocationServiceProvider).current(),
);

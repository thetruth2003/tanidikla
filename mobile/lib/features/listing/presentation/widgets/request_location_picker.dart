import 'dart:async';

import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RequestLocationPicker extends StatefulWidget {
  const RequestLocationPicker({
    required this.selectedPoint,
    required this.onChanged,
    this.onMoving,
    super.key,
  });

  final LatLng selectedPoint;
  final ValueChanged<LatLng> onChanged;
  final VoidCallback? onMoving;

  @override
  State<RequestLocationPicker> createState() => _RequestLocationPickerState();
}

class _RequestLocationPickerState extends State<RequestLocationPicker> {
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgentPackageName = 'com.example.ankara_proje';

  final MapController _controller = MapController();
  bool _mapReady = false;
  bool _locating = false;
  Timer? _settleTimer;
  late LatLng _cameraCenter;

  @override
  void initState() {
    super.initState();
    _cameraCenter = widget.selectedPoint;
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    _cameraCenter = camera.center;
    widget.onMoving?.call();
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) widget.onChanged(_cameraCenter);
    });
  }

  void _changeZoom(double amount) {
    if (!_mapReady) return;
    final nextZoom = (_controller.camera.zoom + amount).clamp(5.0, 17.0);
    _controller.move(_controller.camera.center, nextZoom);
  }

  Future<void> _useCurrentLocation() async {
    if (!_mapReady || _locating) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulunduğun konumu kullan'),
        content: const Text(
          'Konumun ilan iğnesini yerleştirmek için kullanılır. Yayında tam adres yerine seçtiğin yaklaşık konum gösterilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konumumu kullan'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Telefonun konum servisi kapalı. Ayarlardan açıp tekrar dene.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Konum izni verilmedi. Haritayı elle hareket ettirebilirsin.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      widget.onMoving?.call();
      _controller.move(point, 15.5);
      widget.onChanged(point);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 270,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.selectedPoint,
            initialZoom: 13.5,
            minZoom: 5,
            maxZoom: 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: _handlePositionChanged,
            onMapReady: () {
              if (mounted) setState(() => _mapReady = true);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: _userAgentPackageName,
              maxNativeZoom: 17,
              tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .66,
                  .24,
                  .10,
                  0,
                  18,
                  .20,
                  .70,
                  .10,
                  0,
                  18,
                  .18,
                  .25,
                  .57,
                  0,
                  18,
                  0,
                  0,
                  0,
                  .78,
                  0,
                ]),
                child: tileWidget,
              ),
            ),
            const _Attribution(),
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -27),
                  child: Icon(
                    Icons.location_on,
                    size: 58,
                    color: colorScheme.primary,
                    shadows: const [
                      Shadow(
                        color: Color(0x55000000),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'request-map-zoom-in',
                    tooltip: 'Yakınlaştır',
                    onPressed: _mapReady ? () => _changeZoom(1) : null,
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'request-map-zoom-out',
                    tooltip: 'Uzaklaştır',
                    onPressed: _mapReady ? () => _changeZoom(-1) : null,
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'request-map-focus-pin',
                    tooltip: 'Bulunduğum konumu işaretle',
                    onPressed: _mapReady && !_locating
                        ? _useCurrentLocation
                        : null,
                    child: _locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(6),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

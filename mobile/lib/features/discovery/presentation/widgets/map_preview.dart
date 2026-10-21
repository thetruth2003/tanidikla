import 'dart:async';

import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:ankara_proje/features/discovery/domain/service_listing.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/category_icon.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/listing_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

Widget _cachedTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) => RepaintBoundary(
  child: ColorFiltered(
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
);

class MapViewportSnapshot {
  const MapViewportSnapshot({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

class MapPreview extends StatefulWidget {
  const MapPreview({
    required this.listings,
    required this.onListingTap,
    this.currentUserId,
    this.onViewportListingsChanged,
    this.initialViewport,
    this.onViewportChanged,
    super.key,
  });

  final List<ServiceListing> listings;
  final ValueChanged<ServiceListing> onListingTap;
  final String? currentUserId;
  final ValueChanged<List<ServiceListing>>? onViewportListingsChanged;
  final MapViewportSnapshot? initialViewport;
  final ValueChanged<MapViewportSnapshot>? onViewportChanged;

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  static const _ankaraCenter = LatLng(39.9208, 32.8541);
  static const _initialZoom = 12.5;
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgentPackageName = 'com.example.ankara_proje';
  static final TileUpdateTransformer _tileUpdateTransformer =
      TileUpdateTransformers.debounce(const Duration(milliseconds: 140));

  final MapController _mapController = MapController();
  final PageController _cardController = PageController(viewportFraction: .88);
  late List<Marker> _markers;
  List<ServiceListing> _viewportListings = const [];
  String? _selectedListingId;
  Timer? _emptyMessageTimer;
  Timer? _viewportTimer;
  bool _mapReady = false;
  bool _showEmptyMessage = false;

  bool get _supportsInteractiveMap {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _rebuildMarkers() {
    _markers = widget.listings
        .map(
          (listing) => Marker(
            point: LatLng(listing.latitude, listing.longitude),
            width: 52,
            height: 62,
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              child: Tooltip(
                message:
                    '${listing.title}\n${listing.locationLabel} • ${listing.priceLabel}',
                child: _MapPin(
                  key: ValueKey('map-pin-${listing.id}'),
                  color: _markerColor(listing),
                  icon: categoryIcon(listing.category),
                  selected: listing.id == _selectedListingId,
                  onTap: () => _focusListing(listing),
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
    _syncEmptyMessage();
  }

  @override
  void didUpdateWidget(covariant MapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listings != widget.listings ||
        oldWidget.currentUserId != widget.currentUserId) {
      _rebuildMarkers();
      if (_mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleViewportUpdate(_mapController.camera, immediate: true);
          }
        });
      }
    }
    if (oldWidget.listings.isEmpty != widget.listings.isEmpty) {
      _syncEmptyMessage();
    }
  }

  void _syncEmptyMessage() {
    _emptyMessageTimer?.cancel();
    if (widget.listings.isNotEmpty) {
      _showEmptyMessage = false;
      return;
    }

    _showEmptyMessage = true;
    _emptyMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showEmptyMessage = false);
    });
  }

  Color _markerColor(ServiceListing listing) {
    if (listing.ownerId == widget.currentUserId) {
      return const Color(0xFF2E7DB6);
    }
    return listing.availableNow ? AppColors.turquoise : AppColors.turquoiseDark;
  }

  void _scheduleViewportUpdate(MapCamera camera, {bool immediate = false}) {
    _viewportTimer?.cancel();
    if (immediate) {
      _applyViewport(camera);
      return;
    }
    _viewportTimer = Timer(
      const Duration(milliseconds: 300),
      () => _applyViewport(camera),
    );
  }

  void _applyViewport(MapCamera camera) {
    if (!mounted) return;
    final visible = listingsWithinBounds(widget.listings, camera.visibleBounds);
    final changed = !_sameListings(_viewportListings, visible);
    final selectionIsVisible = visible.any(
      (item) => item.id == _selectedListingId,
    );
    if (changed || (_selectedListingId != null && !selectionIsVisible)) {
      setState(() {
        _viewportListings = visible;
        if (!selectionIsVisible) _selectedListingId = null;
        _rebuildMarkers();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_cardController.hasClients) return;
        final selectedIndex = _viewportListings.indexWhere(
          (item) => item.id == _selectedListingId,
        );
        if (selectedIndex >= 0) _cardController.jumpToPage(selectedIndex);
      });
    }
    widget.onViewportListingsChanged?.call(
      List<ServiceListing>.unmodifiable(visible),
    );
  }

  void _clearSelection() {
    if (_selectedListingId == null) return;
    setState(() {
      _selectedListingId = null;
      _rebuildMarkers();
    });
  }

  void _focusListing(ServiceListing listing) {
    final index = _viewportListings.indexWhere((item) => item.id == listing.id);
    setState(() {
      _selectedListingId = listing.id;
      _rebuildMarkers();
    });
    if (index >= 0 && _cardController.hasClients) {
      _cardController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectCard(int index) {
    if (index < 0 || index >= _viewportListings.length) return;
    final listing = _viewportListings[index];
    if (listing.id == _selectedListingId) return;
    setState(() {
      _selectedListingId = listing.id;
      _rebuildMarkers();
    });
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(5.0, 17.0);
    _mapController.move(camera.center, zoom);
  }

  @override
  void dispose() {
    _emptyMessageTimer?.cancel();
    _viewportTimer?.cancel();
    _cardController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _supportsInteractiveMap
                ? Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _clearSelection(),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            widget.initialViewport?.center ?? _ankaraCenter,
                        initialZoom:
                            widget.initialViewport?.zoom ?? _initialZoom,
                        minZoom: 5,
                        maxZoom: 17,
                        onMapReady: () {
                          _mapReady = true;
                          widget.onViewportChanged?.call(
                            MapViewportSnapshot(
                              center: _mapController.camera.center,
                              zoom: _mapController.camera.zoom,
                            ),
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _scheduleViewportUpdate(
                                _mapController.camera,
                                immediate: true,
                              );
                            }
                          });
                        },
                        onPositionChanged: (camera, _) {
                          widget.onViewportChanged?.call(
                            MapViewportSnapshot(
                              center: camera.center,
                              zoom: camera.zoom,
                            ),
                          );
                          _scheduleViewportUpdate(camera);
                        },
                        onTap: (_, _) => _clearSelection(),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _tileUrl,
                          userAgentPackageName: _userAgentPackageName,
                          maxNativeZoom: 17,
                          tileDimension: 512,
                          zoomOffset: -1,
                          keepBuffer: 1,
                          panBuffer: 0,
                          tileDisplay: const TileDisplay.instantaneous(),
                          tileBuilder: _cachedTileBuilder,
                          tileUpdateTransformer: _tileUpdateTransformer,
                        ),
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: _markers,
                            size: const Size(52, 52),
                            maxClusterRadius: 56,
                            disableClusteringAtZoom: 15,
                            maxZoom: 17,
                            showPolygon: false,
                            zoomToBoundsOnClick: true,
                            centerMarkerOnClick: false,
                            spiderfyCluster: true,
                            forceIntegerZoomLevel: true,
                            onClusterTap: (_) => _clearSelection(),
                            markerChildBehavior: true,
                            builder: (context, markers) =>
                                _ClusterBubble(count: markers.length),
                          ),
                        ),
                      ],
                    ),
                  )
                : const _UnsupportedPlatformMap(),
          ),
          if (_showEmptyMessage)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Bu filtrelerde aktif ilan bulunamadı.'),
                ),
              ),
            ),
          if (_supportsInteractiveMap) ...[
            Positioned(
              top: 12,
              left: 12,
              child: _AreaCount(count: _viewportListings.length),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _ZoomControls(
                onZoomIn: () => _changeZoom(1),
                onZoomOut: () => _changeZoom(-1),
              ),
            ),
            if (_selectedListingId != null && _viewportListings.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                height: 166,
                child: PageView.builder(
                  controller: _cardController,
                  itemCount: _viewportListings.length,
                  onPageChanged: _selectCard,
                  itemBuilder: (context, index) {
                    final listing = _viewportListings[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: ListingCard(
                        key: ValueKey('map-listing-card-${listing.id}'),
                        listing: listing,
                        compact: true,
                        isOwnListing: listing.ownerId == widget.currentUserId,
                        onTap: () => widget.onListingTap(listing),
                      ),
                    );
                  },
                ),
              ),
          ],
          if (_supportsInteractiveMap)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _MapAttribution(
                    bottomInset:
                        _selectedListingId == null || _viewportListings.isEmpty
                        ? 0
                        : 174,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<ServiceListing> listingsWithinBounds(
  List<ServiceListing> listings,
  LatLngBounds bounds,
) => listings
    .where(
      (listing) => bounds.contains(LatLng(listing.latitude, listing.longitude)),
    )
    .toList(growable: false);

bool _sameListings(List<ServiceListing> first, List<ServiceListing> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index].id != second[index].id) return false;
  }
  return true;
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.color,
    required this.icon,
    required this.selected,
    this.onTap,
    super.key,
  });

  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: const Alignment(0, -0.25),
          children: [
            Icon(
              Icons.location_on,
              color: color,
              size: selected ? 58 : 52,
              shadows: const [
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            Container(
              width: selected ? 27 : 24,
              height: selected ? 27 : 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: selected ? Border.all(color: color, width: 2) : null,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.turquoise,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 999 ? '999+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _AreaCount extends StatelessWidget {
  const _AreaCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .94),
      elevation: 2,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Bu bölgede $count ilan',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .96),
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yakınlaştır',
          ),
          const SizedBox(width: 42, child: Divider(height: 1)),
          IconButton(
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
            tooltip: 'Uzaklaştır',
          ),
        ],
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottomInset),
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
              style: TextStyle(fontSize: 7, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedPlatformMap extends StatelessWidget {
  const _UnsupportedPlatformMap();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'OpenStreetMap haritası Android ve iOS uygulamasında gösterilir.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/google_geocoding_service.dart';
import 'package:koyden_sehire/models/selected_location.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';

class SelectLocationScreen extends StatefulWidget {
  final SelectedLocation? initial;
  const SelectLocationScreen({super.key, this.initial});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen>
    with SingleTickerProviderStateMixin {
  static const _turkeyCenter = LatLng(39.9334, 32.8597);

  late final MapController _mapController;
  late final AnimationController _pinAnimCtrl;
  late final Animation<double> _pinOffset;

  final _geocoding = GoogleGeocodingService();

  Timer? _debounce;
  LatLng _center = _turkeyCenter;
  bool _isGeocodingLoading = false;
  bool _isLocating = false;

  String _city = '';
  String _district = '';
  String _village = '';
  String _addressLine1 = '';
  String _addressLine2 = '';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pinAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pinOffset = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _pinAnimCtrl, curve: Curves.easeInOut),
    );

    final loc = widget.initial;
    if (loc != null && loc.lat != 0) {
      _center = LatLng(loc.lat, loc.lng);
      _city = loc.city;
      _district = loc.district;
      _village = loc.village;
      _addressLine1 = loc.formattedAddress;
      _addressLine2 = [loc.district, loc.city]
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pinAnimCtrl.dispose();
    super.dispose();
  }

  void _onMapMoved(LatLng center) {
    _center = center;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _reverseGeocode(center),
    );
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isGeocodingLoading = true);
    try {
      final addr = await _geocoding.reverseGeocode(pos.latitude, pos.longitude);
      if (addr == null || !mounted) return;
      setState(() {
        _city = addr.city;
        _district = addr.district;
        _village = addr.village;
        _addressLine1 = addr.streetAddress.isNotEmpty
            ? addr.streetAddress
            : addr.formattedAddress;
        _addressLine2 = [addr.district, addr.city]
            .where((s) => s.isNotEmpty)
            .join(', ');
      });
    } catch (_) {
      // Geocoding failed
    } finally {
      if (mounted) setState(() => _isGeocodingLoading = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Konum izni verilmedi. Ayarlardan izin verebilirsiniz.'),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newCenter = LatLng(pos.latitude, pos.longitude);
      _mapController.move(newCenter, 15);
      _onMapMoved(newCenter);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum alÄ±namadÄ±')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      SelectedLocation(
        city: _city,
        district: _district,
        village: _village,
        formattedAddress: _addressLine1.isNotEmpty ? _addressLine1 : _addressLine2,
        lat: _center.latitude,
        lng: _center.longitude,
      ),
    );
  }

  bool get _hasAddress => _addressLine1.isNotEmpty || _addressLine2.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final initialZoom = widget.initial != null && widget.initial!.lat != 0 ? 15.0 : 6.0;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: initialZoom,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _onMapMoved(camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.koydensehire.app',
              ),
            ],
          ),

          // Top overlay
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopBar(onBack: () => Navigator.pop(context)),
                const SizedBox(height: 8),
                _SearchCard(
                  isLocating: _isLocating,
                  onLocate: _goToCurrentLocation,
                ),
              ],
            ),
          ),

          // Center bouncing pin
          _CenterPin(animation: _pinOffset),

          // Bottom address card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCard(
              addressLine1: _addressLine1,
              addressLine2: _addressLine2,
              isLoading: _isGeocodingLoading,
              hasAddress: _hasAddress,
              onConfirm: _hasAddress ? _confirm : null,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Sub-widgets ---

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.arrow_back, color: AppColors.onSurface, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.soft,
            ),
            child: const Text(
              'Ã‡iftlik Konumu',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onLocate;
  const _SearchCard({required this.isLocating, required this.onLocate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.soft,
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'HaritayÄ± sÃ¼rÃ¼kleyerek konum seÃ§in',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.outline,
                ),
              ),
            ),
            isLocating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: onLocate,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.onSecondaryContainer,
                        size: 18,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  final Animation<double> animation;
  const _CenterPin({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, animation.value - 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.onPrimary,
                  size: 26,
                ),
              ),
              Container(
                width: 10,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  final String addressLine1;
  final String addressLine2;
  final bool isLoading;
  final bool hasAddress;
  final VoidCallback? onConfirm;

  const _BottomCard({
    required this.addressLine1,
    required this.addressLine2,
    required this.isLoading,
    required this.hasAddress,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SeÃ§ilen Konum',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: isLoading
                                ? const Text(
                                    'Adres belirleniyor...',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasAddress
                                            ? (addressLine1.isNotEmpty
                                                ? addressLine1
                                                : addressLine2)
                                            : 'HaritayÄ± sÃ¼rÃ¼kleyerek konum seÃ§in',
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: hasAddress
                                              ? AppColors.onSurface
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      if (addressLine1.isNotEmpty &&
                                          addressLine2.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          addressLine2,
                                          style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 12,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Konumu Onayla',
                      onPressed: onConfirm,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.onPrimary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

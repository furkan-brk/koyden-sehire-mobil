import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/data/turkey_locations.dart';

class LocationFilterResult {
  final String? city;
  final String? district;
  const LocationFilterResult({this.city, this.district});
}

Future<LocationFilterResult?> showLocationFilterSheet(
  BuildContext context, {
  String? initialCity,
  String? initialDistrict,
}) {
  return showModalBottomSheet<LocationFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationFilterSheet(
      initialCity: initialCity,
      initialDistrict: initialDistrict,
    ),
  );
}

class _LocationFilterSheet extends StatefulWidget {
  final String? initialCity;
  final String? initialDistrict;

  const _LocationFilterSheet({this.initialCity, this.initialDistrict});

  @override
  State<_LocationFilterSheet> createState() => _LocationFilterSheetState();
}

class _LocationFilterSheetState extends State<_LocationFilterSheet> {
  late final PageController _pageCtrl;
  final _searchCtrl = TextEditingController();

  String? _city;
  String? _district;
  bool _onDistrictPage = false;

  static const _kDuration = Duration(milliseconds: 280);
  static const _kCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _district = widget.initialDistrict;
    _onDistrictPage = _city != null;
    _pageCtrl = PageController(initialPage: _onDistrictPage ? 1 : 0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectCity(String city) {
    // Set _onDistrictPage synchronously — avoids 280ms header flicker
    setState(() {
      _city = city;
      _district = null;
      _onDistrictPage = true;
      _searchCtrl.clear();
    });
    _pageCtrl.animateToPage(1, duration: _kDuration, curve: _kCurve);
  }

  void _backToCity() {
    setState(() => _onDistrictPage = false);
    _searchCtrl.clear();
    _pageCtrl.animateToPage(0, duration: _kDuration, curve: _kCurve);
  }

  void _apply() {
    Navigator.pop(
      context,
      LocationFilterResult(city: _city, district: _district),
    );
  }

  // Resets in-place — does NOT close the sheet
  void _clear() {
    setState(() {
      _city = null;
      _district = null;
      _onDistrictPage = false;
      _searchCtrl.clear();
    });
    _pageCtrl.animateToPage(0, duration: _kDuration, curve: _kCurve);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    // Subtract keyboard height so sheet never overflows
    final sheetHeight =
        (mq.size.height * 0.78 - bottomInset).clamp(280.0, mq.size.height * 0.9);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  // Fixed-width slot — AnimatedOpacity avoids layout shift
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: AnimatedOpacity(
                      opacity: _onDistrictPage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_onDistrictPage,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _backToCity,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Breadcrumb(
                          city: _city,
                          onDistrictPage: _onDistrictPage,
                          onCityTap: _onDistrictPage ? _backToCity : null,
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            _onDistrictPage ? 'İlçe Seç' : 'İl Seç',
                            key: ValueKey(_onDistrictPage),
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_city != null)
                    TextButton(
                      onPressed: _clear,
                      child: const Text(
                        'Temizle',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Search bar — visible on both pages, hint reflects current step
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: _onDistrictPage ? 'İlçe ara...' : 'İl ara...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // PageView — always 2 stable children; avoids child-count change bugs
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 0: İl listesi
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (_, val, __) => _CityPage(
                      selected: _city,
                      search: val.text,
                      onSelect: _selectCity,
                    ),
                  ),
                  // Page 1: İlçe listesi — empty placeholder until city is chosen
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (_, val, __) {
                      if (_city == null) return const SizedBox.shrink();
                      return _DistrictPage(
                        city: _city!,
                        selected: _district,
                        search: val.text,
                        onSelect: (d) => setState(() => _district = d),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Apply button — no AnimatedSwitcher key churn
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _city == null ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surfaceContainerLow,
                      disabledForegroundColor: AppColors.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _city == null
                          ? 'İl Seçin'
                          : _district == null
                              ? '$_city — Tüm İlçeler'
                              : '$_city / $_district',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Breadcrumb ──────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final String? city;
  final bool onDistrictPage;
  final VoidCallback? onCityTap;

  const _Breadcrumb({
    required this.city,
    required this.onDistrictPage,
    this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onDistrictPage ? onCityTap : null,
          child: Text(
            'Türkiye',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              color: !onDistrictPage
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              fontWeight:
                  !onDistrictPage ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (city != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 12,
              color: AppColors.outlineVariant,
            ),
          ),
          Text(
            city!,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              color: onDistrictPage
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              fontWeight:
                  onDistrictPage ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Sayfa: İl Listesi ───────────────────────────────────────────────────────

class _CityPage extends StatelessWidget {
  final String? selected;
  final String search;
  final ValueChanged<String> onSelect;

  const _CityPage({
    required this.selected,
    required this.search,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cities = TurkeyLocations.cities
        .where((c) =>
            search.isEmpty ||
            c.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: cities.length,
      itemBuilder: (_, i) {
        final city = cities[i];
        return _LocationTile(
          label: city,
          isSelected: city == selected,
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.outlineVariant,
          ),
          onTap: () => onSelect(city),
        );
      },
    );
  }
}

// ─── Sayfa: İlçe Listesi ─────────────────────────────────────────────────────

class _DistrictPage extends StatelessWidget {
  final String city;
  final String? selected;
  final String search;
  final ValueChanged<String?> onSelect;

  const _DistrictPage({
    required this.city,
    required this.selected,
    required this.search,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final allDistricts = TurkeyLocations.districtsOf(city);
    final isFiltered = search.isNotEmpty;
    final districts = isFiltered
        ? allDistricts
            .where((d) => d.toLowerCase().contains(search.toLowerCase()))
            .toList()
        : allDistricts;

    // "Tüm İlçeler" is hidden while searching to avoid confusion
    final extraRow = isFiltered ? 0 : 1;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: districts.length + extraRow,
      itemBuilder: (_, i) {
        if (!isFiltered && i == 0) {
          return _LocationTile(
            label: 'Tüm İlçeler',
            sublabel: city,
            isSelected: selected == null,
            onTap: () => onSelect(null),
          );
        }
        final d = districts[i - extraRow];
        return _LocationTile(
          label: d,
          isSelected: d == selected,
          onTap: () => onSelect(d),
        );
      },
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _LocationTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _LocationTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.sublabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryFixed : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.onSurface,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

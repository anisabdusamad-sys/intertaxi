import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/driver_ride_model.dart';
import '../widgets/city_selection_modal.dart';
import 'route_screen.dart';

/// InterTaxi Home Screen — the passenger dashboard.
///
/// Premium gradient header with the user avatar / greeting, an elevated
/// route search card (From, To, Date, Passengers) pinned to the Home tab,
/// and the matching driver trips rendered INLINE directly below the form —
/// no navigation to a separate route screen.
///
/// Performance: all data fetching flows through
/// [DriverRideRepository.fetchMatchingRides], which reads SharedPreferences through
/// the async platform channel and decodes / filters on a background
/// isolate ([compute]). The UI thread never blocks.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Car-color name → swatch mapping (mirrors DriverRideCard).
  static const Map<String, Color> _carColorMap = {
    'сафед': Color(0xFFE8EDF5),
    'сиёҳ': Color(0xFF2B2F3A),
    'нуқрагӣ': Color(0xFFB8C0CC),
    'кабуд': Color(0xFF0066FF),
    'сурх': Color(0xFFE53935),
    'ҳафтранг': Color(0xFFF5A623),
  };

  // ---- Header (user) state ----
  bool _isLoading = true;
  String _userName = '';
  String _avatarPath = '';
  bool _avatarExists = false;

  // ---- Route search state ----
  String? _fromCity;
  String? _toCity;
  DateTime _departureDate = DateTime.now();
  int _passengers = 1;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  List<DriverRide> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Defer all initial data loading to prevent startup ANR.
    // Use Future.delayed to let the screen paint before heavy I/O.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _loadUserHeader();
    });
  }

  Future<void> _loadUserHeader() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('user_avatar_path') ?? '';
      // Async file-existence check — no sync disk I/O on the UI thread.
      final exists = path.isNotEmpty && await File(path).exists();
      if (!mounted) return;
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Мусофир';
        _avatarPath = path;
        _avatarExists = exists;
        _isLoading = false;
      });
    } catch (_) {
      // Silent failure — use defaults
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 'dd.MM.yyyy' for the date field (no intl dependency needed).
  String get _dateLabel {
    final d = _departureDate;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day.$month.${d.year}';
  }

  /// Deterministic pseudo-rating in the 4.2–5.0 range derived from the
  /// driver name. The [DriverRide] model has no rating field yet, so this
  /// keeps a stable, non-flickering value without changing the model.
  double _ratingFor(String driverName) {
    if (driverName.isEmpty) return 4.5;
    var hash = 0;
    for (final code in driverName.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return 4.2 + (hash % 9) / 10.0;
  }

  /// Driver initials for the photo avatar (e.g. 'Файзали Карим' → 'ФК').
  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  Color _driverColorFor(DriverRide ride) =>
      _carColorMap[ride.carColor] ?? AppColors.primaryBlue;

  // ==================== HANDLERS ====================

  Future<void> _pickCity({required bool isFrom}) async {
    final selected = await showCitySelectionSheet(
      context: context,
      title: isFrom ? 'Аз куҷо' : 'Ба куҷо',
      selectedCity: isFrom ? _fromCity : _toCity,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromCity = selected;
      } else {
        _toCity = selected;
      }
      // Previous results refer to the old route — invalidate them.
      _hasSearched = false;
      _searchResults = [];
      _searchError = null;
    });
  }

  void _swapCities() {
    if (_fromCity == null && _toCity == null) return;
    setState(() {
      final tmp = _fromCity;
      _fromCity = _toCity;
      _toCity = tmp;
      _hasSearched = false;
      _searchResults = [];
      _searchError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    setState(() => _departureDate = picked);
  }

  /// Runs the inline route search. Fully asynchronous: SharedPreferences is
  /// read through the async platform channel and JSON decoding / filtering
  /// happens on a background isolate inside
  /// [DriverRideRepository.fetchMatchingRides].
  Future<void> _handleSearch() async {
    final from = _fromCity?.trim();
    final to = _toCity?.trim();
    if (from == null || from.isEmpty || to == null || to.isEmpty) {
      _showSnack('Аввал шаҳрҳои рафтан ва омаданро интихоб кунед');
      return;
    }
    if (from == to) {
      _showSnack('Шаҳрҳо бояд фарқ кунанд');
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final rides = await DriverRideRepository.fetchMatchingRides(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _searchResults = rides
            .where((r) => r.availableSeats >= _passengers)
            .toList(growable: false);
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Хато ҳангоми ҷустуҷӯ рух дод. Дубора кӯшиш кунед';
        _isSearching = false;
      });
    }
  }

  /// Opens the Route Screen with the interactive OpenStreetMap for the
  /// currently searched segment. Pure navigation — no blocking work.
  void _openRouteMap() {
    final from = _fromCity?.trim();
    final to = _toCity?.trim();
    if (from == null || from.isEmpty || to == null || to.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteScreen(fromCity: from, toCity: to),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.gray900,
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    // No sync disk/network calls in build — all I/O deferred via Future.delayed
    // Show lightweight UI immediately while async data loads in background
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.splashBackground,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryBlue.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            // Search card floats over the header's rounded bottom edge.
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchCard(),
                    const SizedBox(height: 24),
                    _buildResultsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gradient top header: greeting + user avatar with a white ring, a
  /// notification button and decorative translucent circles. The rounded
  /// bottom edge lets the search card overlap it for a layered look.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPadding,
        MediaQuery.of(context).padding.top + 16,
        AppConstants.screenPadding,
        56,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkBlue,
            AppColors.primaryBlue,
            AppColors.accentBlue,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Decorative translucent circles for depth.
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            right: 60,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            children: [
              _buildHeaderAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Салом, $_userName!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ба куҷо меравем имрӯз?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// User avatar in the header: the picked photo inside a white-ringed
  /// [CircleAvatar], or the user's initials when no photo was chosen.
  Widget _buildHeaderAvatar() {
    final hasAvatar = _avatarExists && _avatarPath.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        backgroundImage: hasAvatar ? FileImage(File(_avatarPath)) : null,
        onBackgroundImageError: hasAvatar ? (_, __) {} : null,
        child: hasAvatar
            ? null
            : Text(
                _initialsFor(_userName),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ==================== SEARCH CARD ====================

  /// Elevated route search card: From / To with a swap button, departure
  /// date, passenger count and a gradient search button.
  Widget _buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _cityField(isFrom: true)),
              _swapButton(),
              Expanded(child: _cityField(isFrom: false)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateField()),
              const SizedBox(width: 12),
              Expanded(child: _passengerStepper()),
            ],
          ),
          const SizedBox(height: 16),
          _searchButton(),
        ],
      ),
    );
  }

  /// Tappable From/To field that opens the async city selection sheet.
  Widget _cityField({required bool isFrom}) {
    final value = isFrom ? _fromCity : _toCity;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickCity(isFrom: isFrom),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryBlue.withValues(alpha: 0.06),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value != null
                  ? AppColors.primaryBlue.withValues(alpha: 0.4)
                  : AppColors.inputBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isFrom ? Icons.trip_origin_rounded : Icons.location_on_rounded,
                size: 18,
                color: isFrom ? AppColors.success : AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value ?? (isFrom ? 'Аз куҷо' : 'Ба куҷо'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: value != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Round swap button between the From / To fields.
  Widget _swapButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _swapCities,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
            ),
            child: const Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  /// Departure date field — opens the async material date picker.
  Widget _dateField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryBlue.withValues(alpha: 0.06),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Passenger count stepper (1–4 seats) with + / − round buttons.
  Widget _passengerStepper() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_rounded,
            size: 18,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$_passengers нафар',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _stepperButton(
            icon: Icons.remove_rounded,
            onTap: _passengers > 1 ? () => setState(() => _passengers--) : null,
          ),
          const SizedBox(width: 4),
          _stepperButton(
            icon: Icons.add_rounded,
            onTap: _passengers < 4 ? () => setState(() => _passengers++) : null,
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap != null
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : AppColors.gray100,
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? AppColors.primaryBlue : AppColors.gray300,
          ),
        ),
      ),
    );
  }

  /// Gradient search button with an inline loading spinner while the async
  /// search is in flight.
  Widget _searchButton() {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primaryBlue, AppColors.accentBlue],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSearching ? null : _handleSearch,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isSearching
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Ҷустуҷӯи сафар',
                          style: TextStyle(
                            fontSize: AppConstants.buttonTextSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== RESULTS (INLINE) ====================

  /// Results rendered directly under the search card on the same page:
  /// hint before the first search, spinner while loading, error / empty
  /// states, then the matching driver trips.
  Widget _buildResultsSection() {
    if (!_hasSearched) return _buildHintCard();
    if (_isSearching) {
      return _resultsWrapper(
        child: Column(
          children: const [
            SizedBox(height: 24),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Ҷустуҷӯи ронандаҳо...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      );
    }
    if (_searchError != null) return _buildErrorCard();
    if (_searchResults.isEmpty) return _buildEmptyCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultsHeader(_searchResults.length),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildRideCard(_searchResults[index]),
        ),
      ],
    );
  }

  Widget _resultsHeader(int count) {
    return Row(
      children: [
        const Text(
          'Ёфташудагон',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const Spacer(),
        // Opens the interactive OpenStreetMap Route Screen for this trip.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openRouteMap,
            borderRadius: BorderRadius.circular(10),
            splashColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 15,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Харита',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Soft white wrapper used for hint / loading / error / empty states.
  Widget _resultsWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildHintCard() {
    return _resultsWrapper(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
            ),
            child: const Icon(
              Icons.route_rounded,
              size: 28,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Масирро интихоб кунед',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Шаҳрҳои рафтан ва омадан, сана ва шумораи ҷойҳоро интихоб кунед — натиҷаҳо дар ҳамин ҷо нишон дода мешаванд.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return _resultsWrapper(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(Icons.directions_car_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'Ҳоло дар ин масир ронандае нест',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Кӯшиш кунед, ки масир ё санаи дигарро интихоб кунед',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return _resultsWrapper(
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppColors.error,
          ),
          const SizedBox(height: 10),
          Text(
            _searchError ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Premium trip card: driver photo (initials avatar with car-color
  /// tint), name, rating, car model + plate, gradient price tag in
  /// Somoni, and a footer with departure time and seats left.
  Widget _buildRideCard(DriverRide ride) {
    final from = _fromCity?.trim() ?? '';
    final to = _toCity?.trim() ?? '';
    final rating = _ratingFor(ride.driverName);
    final avatarColor = _driverColorFor(ride);
    final price = ride.priceForSegment(from, to);
    final isDirect = ride.isExactMatch(from, to);

    return Container(
      key: ValueKey('ride_${ride.id}'),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: open booking / details screen for this ride.
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Driver photo avatar (initials + car-color tint).
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: avatarColor.withValues(alpha: 0.18),
                      child: Text(
                        _initialsFor(ride.driverName),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: avatarColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${ride.carModel} • ${ride.carColor} • ${ride.carPlate}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Price tag in Somoni.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryBlue, AppColors.accentBlue],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$price',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'сомонӣ',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.gray100),
                const SizedBox(height: 10),
                // Footer: departure time + countdown, seats left, badge.
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${ride.departureLabel} (${ride.countdownLabel})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.event_seat_rounded,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${ride.availableSeats} ҷой',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!isDirect)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ба воситаи дигар шаҳр',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

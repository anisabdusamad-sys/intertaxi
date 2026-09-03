import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/intertaxi_models.dart';
import '../screens/server_settings_screen.dart';
import '../widgets/about_app_sheet.dart';
import '../widgets/city_selection_modal.dart';
import '../widgets/profile_edit_sheet.dart';

/// InterTaxi Profile Screen
/// Self-contained profile tab: a tappable user card (edit name & phone via
/// SharedPreferences) and menu entries that open lightweight bottom sheets
/// for trip history, favorite locations, settings and app info.
class ProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;

  const ProfileScreen({
    super.key,
    this.initialName = '',
    this.initialPhone = '',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  String _displayPhone = '';
  String _gender = '';
  String _birthYear = '';
  String _role = '';
  String _avatarPath = '';

  /// Whether the file at [_avatarPath] actually exists — checked
  /// asynchronously so the UI thread never blocks on disk I/O.
  bool _avatarExists = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.initialName;
    _displayPhone = widget.initialPhone;
    // Defer the storage read until after the first frame so the screen
    // renders instantly instead of waiting on the plugin channel round-trip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(kUserAvatarPathKey) ?? '';
    // Asynchronous file-existence check — never touches the UI thread.
    final exists = path.isNotEmpty && await File(path).exists();
    if (!mounted) return;
    setState(() {
      _displayName = prefs.getString('user_name') ?? widget.initialName;
      _displayPhone = prefs.getString('user_phone') ?? widget.initialPhone;
      _gender = prefs.getString('user_gender') ?? '';
      _birthYear = prefs.getString('user_birth_year') ?? '';
      _role = prefs.getString('user_role') ?? '';
      _avatarPath = path;
      _avatarExists = exists;
    });
  }

  /// Human-readable role label for the stored `user_role` value.
  String get _roleLabel {
    switch (_role) {
      case 'driver':
        return 'Ронанда';
      case 'passenger':
        return 'Мусофир';
      default:
        return _role.isEmpty ? 'Мусофир' : _role;
    }
  }

  // ==================== HANDLERS ====================

  /// 1. Edit Profile — full name, phone, gender and birth year persisted
  /// to SharedPreferences.
  Future<void> _openEditProfile() async {
    final result = await showProfileEditSheet(
      context: context,
      currentName: _displayName,
      currentPhone: _displayPhone,
      currentGender: _gender,
      currentBirthYear: _birthYear,
      currentAvatarPath: _avatarPath,
    );
    if (result == null || !mounted) return;
    setState(() {
      _displayName = result.fullName;
      _displayPhone = result.phone;
      _gender = result.gender;
      _birthYear = result.birthYear;
      _avatarPath = result.avatarPath;
      _avatarExists = result.avatarPath.isNotEmpty;
    });
  }

  /// Lets the user pick a new avatar (gallery or camera). The picked file
  /// path is persisted by [pickAndSaveAvatar] and the UI updates via a
  /// single setState — all work stays asynchronous, nothing blocks.
  Future<void> _changeAvatar() async {
    final source = await showAvatarSourcePicker(context);
    if (source == null || !mounted) return;
    final path = await pickAndSaveAvatar(context: context, source: source);
    if (path == null || !mounted) return;
    setState(() {
      _avatarPath = path;
      _avatarExists = true;
    });
  }

  /// 2. Trip History — saved trips from local storage.
  Future<void> _openTripHistory() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _TripHistorySheet(),
    );
  }

  /// 3. Favorite Locations — add / remove favorite cities.
  Future<void> _openFavorites() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _FavoritesSheet(),
    );
  }

  /// 4. Settings — notifications toggle, language selector, log out.
  Future<void> _openSettings() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );
  }

  /// 5. About App — logo, version (v1.0.0) and description.
  Future<void> _openAbout() => showAboutAppSheet(context: context);

  /// 6. Server — point the app at the Flask backend (needed on physical
  /// phones where `localhost` refers to the phone itself, not the PC).
  Future<void> _openServerSettings() {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
    );
  }

  /// Registration details sheet — read-only view of all stored fields.
  Future<void> _openDetails() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailsSheet(
        fullName: _displayName,
        phone: _displayPhone,
        gender: _gender,
        birthYear: _birthYear,
        role: _roleLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Профил',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildUserCard(),
          const SizedBox(height: 24),
          _buildMenuCard(
            children: [
              _buildMenuTile(
                icon: Icons.badge_rounded,
                label: 'Маълумоти профил',
                onTap: _openDetails,
              ),
              _buildMenuDivider(),
              _buildMenuTile(
                icon: Icons.history_rounded,
                label: 'Таърихи сафарҳо',
                onTap: _openTripHistory,
              ),
              _buildMenuDivider(),
              _buildMenuTile(
                icon: Icons.favorite_rounded,
                label: 'Манзалҳои дӯстдошта',
                onTap: _openFavorites,
              ),
              _buildMenuDivider(),
              _buildMenuTile(
                icon: Icons.settings_rounded,
                label: 'Танзимот',
                onTap: _openSettings,
              ),
              _buildMenuDivider(),
              _buildMenuTile(
                icon: Icons.dns_rounded,
                label: 'Сервер',
                onTap: _openServerSettings,
              ),
              _buildMenuDivider(),
              _buildMenuTile(
                icon: Icons.info_rounded,
                label: 'Дар бораи барнома',
                onTap: _openAbout,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Premium gradient header card: user avatar, name, phone and detail
  /// chips on a primary-blue gradient with a soft glow shadow. Tapping it
  /// opens the async profile edit sheet.
  Widget _buildUserCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0052CC),
            Color(0xFF0066FF),
            Color(0xFF4D94FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066FF).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative translucent circles for depth.
            Positioned(
              top: -48,
              right: -36,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: 56,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openEditProfile,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name — strongest hierarchy level.
                            Text(
                              _displayName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Role — quiet supporting label.
                            Text(
                              _roleLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Phone — clearly readable secondary info.
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _displayPhone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildDetailChip(
                                  icon: _gender == 'Мард'
                                      ? Icons.male_rounded
                                      : _gender == 'Зан'
                                          ? Icons.female_rounded
                                          : Icons.person_outline_rounded,
                                  label: _gender.isEmpty ? 'Ҷинс —' : _gender,
                                ),
                                _buildDetailChip(
                                  icon: Icons.cake_rounded,
                                  label: _birthYear.isEmpty
                                      ? 'Соли таваллуд —'
                                      : _birthYear,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit affordance as a soft circular glass button.
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Profile avatar: shows the picked photo inside a [CircleAvatar] with a
  /// default person-icon fallback. A clean white ring and glassy camera
  /// badge make it pop on the gradient card. Tapping it opens the async
  /// gallery / camera picker; the change is persisted under
  /// `user_avatar_path`.
  Widget _buildAvatar() {
    final hasAvatar = _avatarExists && _avatarPath.isNotEmpty;
    return GestureDetector(
      onTap: _changeAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White ring around the avatar for contrast on the gradient.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              backgroundImage: hasAvatar ? FileImage(File(_avatarPath)) : null,
              // Graceful fallback to the icon if the file vanished.
              onBackgroundImageError: hasAvatar ? (_, __) {} : null,
              child: hasAvatar
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0066FF),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                size: 14,
                color: Color(0xFF0066FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Translucent white chip shown under the phone (gender, birth year) —
  /// styled for the gradient header card.
  Widget _buildDetailChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Premium grouped menu card: all navigation entries live in a single
  /// rounded white container with soft shadow and inset dividers.
  Widget _buildMenuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// Hairline divider between menu tiles, inset past the icon tile so it
  /// aligns with the labels.
  Widget _buildMenuDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 16,
      color: Colors.grey[100],
    );
  }

  /// One tappable menu row: rounded tinted icon tile, clear label and a
  /// modern chevron trailing icon. Wrapped in [Material] so the ripple
  /// splash stays inside the card's rounded corners.
  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF0066FF).withValues(alpha: 0.06),
        highlightColor: const Color(0xFF0066FF).withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: const Color(0xFF0066FF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Bottom sheet: read-only view of all stored registration details
/// (name, phone, gender, birth year and role).
class _DetailsSheet extends StatelessWidget {
  final String fullName;
  final String phone;
  final String gender;
  final String birthYear;
  final String role;

  const _DetailsSheet({
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.birthYear,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppConstants.screenPadding),
            child: Text(
              'Маълумоти профил',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                AppConstants.screenPadding,
                0,
                AppConstants.screenPadding,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              children: [
                _buildDetailRow(
                    Icons.person_rounded, 'Ному насаб', fullName),
                _buildDetailRow(Icons.phone_rounded, 'Раками телефон', phone),
                _buildDetailRow(
                    Icons.wc_rounded, 'Ҷинс', gender.isEmpty ? '—' : gender),
                _buildDetailRow(Icons.cake_rounded, 'Соли таваллуд',
                    birthYear.isEmpty ? '—' : birthYear),
                _buildDetailRow(Icons.work_rounded, 'Нақш', role),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: trip history read from local storage (real persisted data
/// via [loadOrders]). Shows an empty state when no trips exist yet.
class _TripHistorySheet extends StatefulWidget {
  const _TripHistorySheet();

  @override
  State<_TripHistorySheet> createState() => _TripHistorySheetState();
}

class _TripHistorySheetState extends State<_TripHistorySheet> {
  List<Order> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final orders = await loadOrders();
      if (!mounted) return;
      setState(() {
        _trips = orders.reversed.toList(); // newest first
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} • ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppConstants.screenPadding),
            child: Text(
              'Таърихи сафарҳо',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }
    if (_trips.isEmpty) {
      return ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.screenPadding),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'Ҳоло сафарҳо вуҷуд надоранд',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Таърихи сафарҳои шумо дар ин ҷо нишон дода мешавад',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPadding,
        0,
        AppConstants.screenPadding,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: _trips.length,
      itemBuilder: (context, index) => _buildTripCard(_trips[index]),
    );
  }

  Widget _buildTripCard(Order trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.fromLocation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trip.toLocation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                trip.price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${trip.seats} ҷой',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(trip.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


}


/// Bottom sheet: favorite cities persisted under `favorite_locations`.
/// Cities are added via the existing city picker (10 Tajik cities) and
/// removed with the delete icon.
class _FavoritesSheet extends StatefulWidget {
  const _FavoritesSheet();

  @override
  State<_FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<_FavoritesSheet> {
  static const String _favoritesKey = 'favorite_locations';

  List<String> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (!mounted) return;
    setState(() {
      _favorites = _decodeFavorites(raw);
      _isLoading = false;
    });
  }

  List<String> _decodeFavorites(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return []; // corrupted storage — start fresh
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, jsonEncode(_favorites));
  }

  Future<void> _addFavorite() async {
    final available =
        tajikCities.where((c) => !_favorites.contains(c)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ҳамаи шаҳрҳо аллакай илова шудаанд'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final city = await showCitySelectionSheet(
      context: context,
      title: 'Илова кардани шаҳр',
      cities: available,
    );
    if (city == null || !mounted) return;
    setState(() => _favorites.add(city));
    await _persist();
  }

  Future<void> _removeFavorite(String city) async {
    setState(() => _favorites.remove(city));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppConstants.screenPadding),
            child: Text(
              'Манзалҳои дӯстдошта',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Flexible(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPadding,
        0,
        AppConstants.screenPadding,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      children: [
        _buildAddTile(),
        if (_favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.favorite_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Ҳанӯз шаҳре илова нашудааст',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ..._favorites.map(_buildFavoriteTile),
      ],
    );
  }

  Widget _buildAddTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: _addFavorite,
        leading: const Icon(Icons.add_circle_rounded, color: AppColors.primaryBlue),
        title: const Text(
          'Илова кардани шаҳр',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteTile(String city) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.location_on_rounded,
          size: 20,
          color: AppColors.primaryBlue,
        ),
        title: Text(
          city,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: IconButton(
          onPressed: () => _removeFavorite(city),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: AppColors.error,
          ),
          tooltip: 'Тоза кардан',
        ),
      ),
    );
  }

}


/// Bottom sheet: notifications toggle, app language selection (Tajik /
/// Russian) and log out. Log out clears the persisted session and returns
/// the app to the splash / registration flow.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _languageKey = 'app_language';

  bool _notificationsEnabled = true;
  String _language = 'tg'; // 'tg' = Tajik, 'ru' = Russian

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
      _language = prefs.getString(_languageKey) ?? 'tg';
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _language = code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Баромадан'),
        content: const Text('Шумо дар ҳақиқат аз аккаунт баромадан мехоҳед?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Баромадан',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Clear ALL persisted app data — the entire SharedPreferences store —
    // so the app starts completely fresh on the next launch with no cached
    // user info, routes, orders, favorites, or settings.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    // Dismiss the settings sheet first, then fully close the app.
    // SystemNavigator.pop() finishes the root activity on Android, so
    // unlike pushing the SplashScreen the application process is
    // terminated and it does not stay in the background.
    Navigator.pop(context); // close the settings sheet
    SystemNavigator.pop(); // close the app entirely
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppConstants.screenPadding),
              child: Text(
                'Танзимот',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Хабарномаҳо',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              secondary: const Icon(
                Icons.notifications_rounded,
                color: AppColors.primaryBlue,
              ),
              title: const Text(
                'Хабарномаҳо',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 24, indent: 16, endIndent: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Забони барнома',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: _language,
              onChanged: (value) => _selectLanguage(value!),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'tg',
                    title: const Text(
                      'Тоҷикӣ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'ru',
                    title: const Text(
                      'Русский',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, indent: 16, endIndent: 16),
            ListTile(
              onTap: _logout,
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Баромадан',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'InterTaxi • v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
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


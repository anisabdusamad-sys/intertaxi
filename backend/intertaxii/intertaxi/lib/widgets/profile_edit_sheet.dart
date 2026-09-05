import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// SharedPreferences key under which the picked avatar image file path is
/// stored. Shared by the profile screen and the edit sheet.
const String kUserAvatarPathKey = 'user_avatar_path';

/// Lightweight bottom sheet letting the user choose the avatar source:
/// gallery or camera. Resolves with the chosen [ImageSource], or null when
/// the sheet is dismissed.
Future<ImageSource?> showAvatarSourcePicker(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                'Расми профил',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primaryBlue,
              ),
              title: const Text(
                'Галерея',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primaryBlue,
              ),
              title: const Text(
                'Камера',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Picks an image from [source] via `image_picker` and persists the file
/// path to SharedPreferences under `user_avatar_path`. Everything runs
/// asynchronously — no UI-thread blocking. Resolves with the saved path,
/// or null when the user cancelled or an error occurred.
Future<String?> pickAndSaveAvatar({
  required BuildContext context,
  required ImageSource source,
}) async {
  try {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserAvatarPathKey, picked.path);
    return picked.path;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Расм интихоб нашуд'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
}

/// Result returned after a successful profile edit.
class ProfileEditResult {
  final String fullName;
  final String phone;

  /// 'Мард' / 'Зан' (same values the registration flow stores).
  final String gender;

  /// Birth year as a string, e.g. '1995'.
  final String birthYear;

  /// Local file path of the picked avatar, empty when none was chosen.
  final String avatarPath;

  const ProfileEditResult({
    required this.fullName,
    required this.phone,
    this.gender = '',
    this.birthYear = '',
    this.avatarPath = '',
  });
}

/// Shows a Modal Bottom Sheet for editing the user's registration details:
/// full name, phone, gender (Мард/Зан) and birth year. Persists everything
/// to SharedPreferences and resolves with a [ProfileEditResult], or null
/// when the sheet is dismissed.
Future<ProfileEditResult?> showProfileEditSheet({
  required BuildContext context,
  required String currentName,
  required String currentPhone,
  String currentGender = '',
  String currentBirthYear = '',
  String currentAvatarPath = '',
}) {
  return showModalBottomSheet<ProfileEditResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ProfileEditSheet(
      currentName: currentName,
      currentPhone: currentPhone,
      currentGender: currentGender,
      currentBirthYear: currentBirthYear,
      currentAvatarPath: currentAvatarPath,
    ),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentGender;
  final String currentBirthYear;
  final String currentAvatarPath;

  const _ProfileEditSheet({
    required this.currentName,
    required this.currentPhone,
    required this.currentGender,
    required this.currentBirthYear,
    required this.currentAvatarPath,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _birthYearController;
  String? _selectedGender;
  bool _isSaving = false;
  String _avatarPath = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _birthYearController =
        TextEditingController(text: widget.currentBirthYear);
    _selectedGender = widget.currentGender.isEmpty ? null : widget.currentGender;
    _avatarPath = widget.currentAvatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  /// Opens the gallery / camera picker and persists the picked image path
  /// immediately (asynchronously — the UI never blocks).
  Future<void> _pickAvatar() async {
    final source = await showAvatarSourcePicker(context);
    if (source == null || !mounted) return;
    final path = await pickAndSaveAvatar(context: context, source: source);
    if (path == null || !mounted) return;
    setState(() => _avatarPath = path);
  }

  /// Tappable avatar shown at the top of the form: the picked photo inside
  /// a [CircleAvatar], or a default person icon when none was chosen yet.
  Widget _buildAvatarHeader() {
    final hasAvatar = _avatarPath.isNotEmpty;
    return Center(
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              backgroundImage:
                  hasAvatar ? FileImage(File(_avatarPath)) : null,
              // Graceful fallback to the icon if the file vanished.
              onBackgroundImageError: hasAvatar ? (_, __) {} : null,
              child: hasAvatar
                  ? null
                  : const Icon(
                      Icons.person_rounded,
                      size: 44,
                      color: AppColors.primaryBlue,
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final birthYear = _birthYearController.text.trim();
      final gender = _selectedGender ?? '';
      final parts = name.split(' ');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_first_name', parts.first);
      await prefs.setString(
        'user_last_name',
        parts.length > 1 ? parts.sublist(1).join(' ') : '',
      );
      await prefs.setString('user_gender', gender);
      await prefs.setString('user_birth_year', birthYear);

      if (!mounted) return;
      Navigator.of(context).pop(
        ProfileEditResult(
          fullName: name,
          phone: phone,
          gender: gender,
          birthYear: birthYear,
          avatarPath: _avatarPath,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хатогӣ — маълумот нигоҳ дошта нашуд'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(AppConstants.screenPadding),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              const SizedBox(height: 16),
              const Text(
                'Таҳрир кардани профил',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildAvatarHeader(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ному насаб',
                  prefixIcon: Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < AppConstants.minNameLength)
                        ? 'Ном хеле кӯтоҳ аст'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Раками телефон',
                  prefixIcon: Icon(
                    Icons.phone_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null ||
                        v.trim().length < AppConstants.minPhoneLength)
                    ? 'Раками телефон нодуруст аст'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Ҷинс',
                  prefixIcon: Icon(
                    Icons.wc_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Мард', child: Text('Мард')),
                  DropdownMenuItem(value: 'Зан', child: Text('Зан')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ҷинсро интихоб кунед' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Соли таваллуд',
                  prefixIcon: Icon(
                    Icons.cake_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final raw = v?.trim() ?? '';
                  if (raw.isEmpty) return 'Соли таваллудро ворид кунед';
                  final year = int.tryParse(raw);
                  if (year == null) return 'Соли таваллуд бояд рақам бошад';
                  final currentYear = DateTime.now().year;
                  if (year < 1900 || year > currentYear) {
                    return 'Соли таваллуд нодуруст аст';
                  }
                  if (currentYear - year < 18) {
                    return 'Шумо бояд на камтар аз 18 сол дошта бошед';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.buttonBorderRadius,
                      ),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'Нигоҳ доштан',
                          style: TextStyle(
                            fontSize: AppConstants.buttonTextSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
            ),
          ),
        ),
      ),
    );
  }

}

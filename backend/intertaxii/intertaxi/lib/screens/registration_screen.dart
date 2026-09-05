import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'role_selection_screen.dart';

/// InterTaxi Welcome Registration Screen
/// Premium dark theme registration in Tajik language
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _phoneController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _avatarBytes;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthYearController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Номро ворид кунед';
    }
    if (value.length < AppConstants.minNameLength) {
      return 'Ном бояд на камтар аз 2 ҳарф бошад';
    }
    if (value.length > AppConstants.maxNameLength) {
      return 'Ном бояд на зиёда аз 50 ҳарф бошад';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Насабро ворид кунед';
    }
    if (value.length < AppConstants.minNameLength) {
      return 'Насаб бояд на камтар аз 2 ҳарф бошад';
    }
    if (value.length > AppConstants.maxNameLength) {
      return 'Насаб бояд на зиёда аз 50 ҳарф бошад';
    }
    return null;
  }

  String? _validateBirthYear(String? value) {
    if (value == null || value.isEmpty) {
      return 'Соли таваллудро ворид кунед';
    }

    final year = int.tryParse(value);
    if (year == null) {
      return 'Соли таваллуд бояд рақам бошад';
    }

    final currentYear = DateTime.now().year;
    if (year < AppConstants.minBirthYear || year > currentYear) {
      return 'Соли таваллуд бояд миёни ${AppConstants.minBirthYear} ва $currentYear бошад';
    }

    final age = currentYear - year;
    if (age < 18) {
      return 'Шумо бояд на камтар аз 18 сол дошта бошед';
    }
    if (age > 120) {
      return 'Соли таваллуд нодуруст ворид шудааст';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Рақами телефонро ворид кунед';
    }
    if (value.length < AppConstants.minPhoneLength) {
      return 'Рақами телефон бояд на камтар аз 9 рақам бошад';
    }
    if (value.length > AppConstants.maxPhoneLength) {
      return 'Рақами телефон бояд на зиёда аз 15 рақам бошад';
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        // Read image bytes for web compatibility
        final bytes = await image.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
        });
      }
    } catch (e) {
      // Handle error
      print('Error picking image: $e');
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Navigate to role selection screen with passenger info
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              final passengerName =
                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
              final passengerPhone = _phoneController.text.trim();

              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RoleSelectionScreen(
                        passengerName: passengerName,
                        passengerPhone: passengerPhone,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.screenPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                              image: _avatarBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_avatarBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _avatarBytes == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: AppColors.primaryBlue,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Avatar hint text
                  Center(
                    child: Text(
                      'Акси худро илова кунед',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Welcome Title
                  Text(
                    'Хуш омадед ба InterTaxi',
                    style: TextStyle(
                      fontSize: AppConstants.welcomeTitleSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Subtitle
                  Text(
                    'Барои истифодаи хизматрасониҳо, маълумоти худро ворид кунед',
                    style: TextStyle(
                      fontSize: AppConstants.welcomeSubtitleSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // First Name Field
                  CustomTextField(
                    label: 'Ном',
                    hintText: 'Номи худро ворид кунед',
                    controller: _firstNameController,
                    validator: _validateFirstName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppConstants.fieldSpacing),
                  // Last Name Field
                  CustomTextField(
                    label: 'Насаб',
                    hintText: 'Насаби худро ворид кунед',
                    controller: _lastNameController,
                    validator: _validateLastName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppConstants.fieldSpacing),
                  // Birth Year Field
                  CustomTextField(
                    label: 'Соли таваллуд',
                    hintText: 'Масалан: 1995',
                    controller: _birthYearController,
                    keyboardType: TextInputType.number,
                    validator: _validateBirthYear,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppConstants.fieldSpacing),
                  // Phone Field
                  CustomTextField(
                    label: 'Рақами телефон',
                    hintText: 'Масалан: +992 90 123 45 67',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 40),
                  // Submit Button
                  CustomButton(
                    text: 'Идома додан',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  // Terms Text
                  Center(
                    child: Text(
                      'Ба давом додан, шумо қабул мекунед',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // TODO: Show terms and conditions
                      },
                      child: Text(
                        'Шартҳои истифода',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryBlue,
                          letterSpacing: 0.2,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
}

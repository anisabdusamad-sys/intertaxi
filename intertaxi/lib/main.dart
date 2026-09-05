import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'screens/passenger_home_screen.dart';
import 'screens/server_settings_screen.dart';
import 'services/api_service.dart';

const String _appSessionVersion = 'intertaxi_session_v2';

class CarBrand {
  final String name;
  final String logoAsset;

  const CarBrand(this.name, this.logoAsset);
}

/// The only vehicle makes supported by InterTaxi driver profiles.
const List<CarBrand> supportedCarBrands = [
  CarBrand('Mercedes', 'assets/logos/1.jpg'),
  CarBrand('Toyota', 'assets/logos/2.jpg'),
  CarBrand('Honda', 'assets/logos/3.jpg'),
  CarBrand('Hyundai', 'assets/logos/4.jpg'),
  CarBrand('Opel', 'assets/logos/5.jpg'),
  CarBrand('BYD', 'assets/logos/6.jpg'),
  CarBrand('KIA', 'assets/logos/7.jpg'),
  CarBrand('Lexus', 'assets/logos/8.jpg'),
  CarBrand('Nissan', 'assets/logos/9.jpg'),
  CarBrand('Audi', 'assets/logos/10.jpg'),
  CarBrand('Ford', 'assets/logos/11.jpg'),
  CarBrand('BMW', 'assets/logos/12.jpg'),
];

const Map<String, LatLng> taxiLocationCoordinates = {
  'Кӯлоб': LatLng(37.9146, 69.7845),
  'Душанбе': LatLng(38.5598, 68.7870),
  'Восеъ': LatLng(37.8031, 69.6453),
  'Хуҷанд': LatLng(40.2833, 69.6333),
  'Бухоро': LatLng(39.7681, 64.4556),
  'Самарқанд': LatLng(39.6542, 66.9597),
  'Файзобод': LatLng(38.5481, 69.3167),
  'Турсунзода': LatLng(38.5111, 68.2317),
  'Панҷакент': LatLng(39.4952, 67.6093),
  'Истаравшан': LatLng(39.9142, 69.0033),
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InterTaxiApp());
}

class InterTaxiApp extends StatelessWidget {
  const InterTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InterTaxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToHome();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString('app_session_version');
    final savedName = prefs.getString('user_name');
    final savedPhone = prefs.getString('user_phone');
    final savedRole = prefs.getString('user_role');

    if (savedVersion != _appSessionVersion) {
      await prefs.clear();
      await prefs.setString('app_session_version', _appSessionVersion);
    }

    final finalName = prefs.getString('user_name');
    final finalPhone = prefs.getString('user_phone');
    final finalRole = prefs.getString('user_role');

    if (finalName != null && finalName.isNotEmpty && finalPhone != null) {
      if (finalRole == 'driver') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DriverHomeScreen(
              driverName: finalName,
              driverPhone: finalPhone,
            ),
          ),
        );
        return;
      }

      if (finalRole == 'passenger') {
        // Computed ONCE here (not inside the builder) so the key is stable
        // for the lifetime of this route while still being unique per entry.
        final passengerSessionKey = ValueKey(
          'passenger-home-$finalPhone-'
          '${DateTime.now().millisecondsSinceEpoch}',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PassengerHomeScreen(
              // Session-scoped key: every entry into the passenger section
              // mounts a brand-new State (route cache, search results, map),
              // so no stale UI can be carried over from a previous session.
              key: passengerSessionKey,
              passengerName: finalName,
              passengerPhone: finalPhone,
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RoleSelectionScreen(
            passengerName: finalName,
            passengerPhone: finalPhone,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_taxi_rounded,
                      size: 80,
                      color: const Color(0xFF0066FF),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'InterTaxi',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your ride, your way',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0066FF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

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
  String? _passengerName;
  String? _selectedGender;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthYearController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) return 'Номро ворид кунед';
    if (value.length < 2) return 'Ном бояд на камтар аз 2 ҳарф бошад';
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) return 'Насабро ворид кунед';
    if (value.length < 2) return 'Насаб бояд на камтар аз 2 ҳарф бошад';
    return null;
  }

  String? _validateBirthYear(String? value) {
    if (value == null || value.isEmpty) return 'Соли таваллудро ворид кунед';
    final year = int.tryParse(value);
    if (year == null) return 'Соли таваллуд бояд рақам бошад';
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear) return 'Соли таваллуд нодуруст аст';
    final age = currentYear - year;
    if (age < 18) return 'Шумо бояд на камтар аз 18 сол дошта бошед';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Рақами телефонро ворид кунед';
    if (value.length < 9) {
      return 'Рақами телефон бояд на камтар аз 9 рақам бошад';
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
        final bytes = await image.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _saveUserBasicInfo(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final birthYear = _birthYearController.text.trim();

    await prefs.setString('app_session_version', _appSessionVersion);
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_first_name', firstName);
    await prefs.setString('user_last_name', lastName);
    await prefs.setString('user_birth_year', birthYear);
    await prefs.setString('user_gender', _selectedGender!);
  }

  void _handleSubmit() {
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ҷинсро интихоб кунед')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _passengerName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      });
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted) {
          setState(() => _isLoading = false);
          await _saveUserBasicInfo(_passengerName!, _phoneController.text);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RoleSelectionScreen(
                passengerName: _passengerName!,
                passengerPhone: _phoneController.text,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0066FF),
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
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey[400],
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
                              color: const Color(0xFF0066FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Акси худро илова кунед',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Хуш омадед ба InterTaxi',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Барои истифодаи хизматрасониҳо, маълумоти худро ворид кунед',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _firstNameController,
                  validator: _validateFirstName,
                  decoration: const InputDecoration(
                    labelText: 'Ном',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  validator: _validateLastName,
                  decoration: const InputDecoration(
                    labelText: 'Насаб',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Ҷинс',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Мард', child: Text('Мард')),
                    DropdownMenuItem(value: 'Зан', child: Text('Зан')),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _birthYearController,
                  validator: _validateBirthYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Соли таваллуд',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Рақами телефон',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Идома додан'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const RoleSelectionScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  void _handleRoleSelection(String role) {
    setState(() => _selectedRole = role);
  }

  void _handleContinue() async {
    if (_selectedRole == null) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final fullName = widget.passengerName.trim();
      final nameParts = fullName.split(RegExp(r'\s+'));
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      await prefs.setString('app_session_version', _appSessionVersion);
      await prefs.setString('user_role', _selectedRole!);
      await prefs.setString('user_name', widget.passengerName);
      await prefs.setString('user_phone', widget.passengerPhone);
      await prefs.setString('user_first_name', firstName);
      await prefs.setString('user_last_name', lastName);

      setState(() => _isLoading = false);
      if (_selectedRole == 'passenger') {
        // Computed ONCE here (not inside the builder) so the key is stable
        // for the lifetime of this route while still being unique per entry.
        final passengerSessionKey = ValueKey(
          'passenger-home-${widget.passengerPhone}-'
          '${DateTime.now().millisecondsSinceEpoch}',
        );
        // Remove the whole previous stack (registration, role selection, any
        // leftover screens) so the passenger home screen is always the root
        // of a fresh session — nothing stale can sit below or around it.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PassengerHomeScreen(
              // Session-scoped key: guarantees a brand-new State on every
              // entry into the passenger section (no route/search caches
              // carried over from a previous session).
              key: passengerSessionKey,
              passengerName: widget.passengerName,
              passengerPhone: widget.passengerPhone,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DriverRegistrationScreen(
              passengerName: widget.passengerName,
              passengerPhone: widget.passengerPhone,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Шумо кӣ ҳастед?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildRoleCard(
                      title: 'Мусофир',
                      description: 'Ман мехоҳам бо таксӣ сафар кунам',
                      icon: Icons.person,
                      isSelected: _selectedRole == 'passenger',
                      onTap: () => _handleRoleSelection('passenger'),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      title: 'Ронанда',
                      description: 'Ман мехоҳам ҳамчун ронанда кор кунам',
                      icon: Icons.directions_car,
                      isSelected: _selectedRole == 'driver',
                      onTap: () => _handleRoleSelection('driver'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || _selectedRole == null
                      ? null
                      : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Идома додан'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.white : const Color(0xFF0066FF),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                    ),
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

class PassengerTripScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const PassengerTripScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<PassengerTripScreen> createState() => _PassengerTripScreenState();
}

class _PassengerTripScreenState extends State<PassengerTripScreen> {
  String? _selectedStartLocation;
  String? _selectedDestination;
  bool _isLoading = false;

  final List<String> _locations = ['Кӯлоб', 'Душанбе', 'Восеъ'];

  void _handleSearch() async {
    if (_selectedStartLocation == null || _selectedDestination == null) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isLoading = false);
      // Navigate to order details with passenger info
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(
            fromLocation: _selectedStartLocation!,
            toLocation: _selectedDestination!,
            price: '150 сомонӣ',
            duration: '2 соат 30 дақиқа',
            seats: 3,
            passengerPhone: widget.passengerPhone,
            passengerName: widget.passengerName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Мусофир'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Хуш омадед, мусофир!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Биёед саёҳати худро оғоз кунем',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              _buildLocationCard(
                title: 'Аз куҷо меравед?',
                placeholder: 'Ҷойи оғозро интихоб кунед',
                selectedLocation: _selectedStartLocation,
                icon: Icons.trip_origin,
                onTap: () async {
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationSelectionScreen(
                        title: 'Аз куҷо меравед?',
                        locations: _locations,
                        selectedLocation: _selectedStartLocation,
                      ),
                    ),
                  );
                  if (selected != null) {
                    setState(() => _selectedStartLocation = selected);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildLocationCard(
                title: 'Ба куҷо рафтан мехоҳед?',
                placeholder: 'Макони таъинотро интихоб кунед',
                selectedLocation: _selectedDestination,
                icon: Icons.location_on,
                onTap: () async {
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationSelectionScreen(
                        title: 'Ба куҷо рафтан мехоҳед?',
                        locations: _locations,
                        selectedLocation: _selectedDestination,
                      ),
                    ),
                  );
                  if (selected != null) {
                    setState(() => _selectedDestination = selected);
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ||
                          _selectedStartLocation == null ||
                          _selectedDestination == null
                      ? null
                      : _handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Ҷустуҷӯи мошин'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String placeholder,
    required String? selectedLocation,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedLocation != null
                ? const Color(0xFF0066FF)
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: selectedLocation != null
                  ? const Color(0xFF0066FF)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedLocation ?? placeholder,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selectedLocation != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selectedLocation != null
                          ? Colors.black87
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

class LocationSelectionScreen extends StatelessWidget {
  final String title;
  final List<String> locations;
  final String? selectedLocation;

  const LocationSelectionScreen({
    super.key,
    required this.title,
    required this.locations,
    this.selectedLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          final isSelected = selectedLocation == location;

          return GestureDetector(
            onTap: () => Navigator.pop(context, location),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0066FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0066FF)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 24,
                    color: isSelected ? Colors.white : const Color(0xFF0066FF),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Colors.white, size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CarBrandSelectionScreen extends StatelessWidget {
  final List<CarBrand> brands;
  final String? selectedBrand;

  const CarBrandSelectionScreen({
    super.key,
    required this.brands,
    this.selectedBrand,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Маркаи мошин'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: brands.length,
        itemBuilder: (context, index) {
          final brand = brands[index];
          final isSelected = selectedBrand == brand.name;

          return GestureDetector(
            onTap: () => Navigator.pop(context, brand.name),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0066FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0066FF)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      brand.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.directions_car,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      brand.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Colors.white, size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CarColorSelectionScreen extends StatelessWidget {
  final List<String> colors;
  final String? selectedColor;

  const CarColorSelectionScreen({
    super.key,
    required this.colors,
    this.selectedColor,
  });

  Color _getColorFromName(String colorName) {
    switch (colorName) {
      case 'Сабз':
        return Colors.green;
      case 'Сафед':
        return Colors.white;
      case 'Сиёҳ':
        return Colors.black;
      case 'Сурх':
        return Colors.red;
      case 'Кабуд':
        return Colors.blue;
      case 'Зард':
        return Colors.yellow;
      case 'Нилӯфар':
        return Colors.purple;
      case 'Беж':
        return Colors.brown;
      case 'Кул':
        return Colors.grey;
      case 'Тилоӣ':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ранги мошин'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = selectedColor == color;
          final colorValue = _getColorFromName(color);

          return GestureDetector(
            onTap: () => Navigator.pop(context, color),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0066FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0066FF)
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  // Actual color circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorValue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      color,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Colors.white, size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DriverRegistrationScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const DriverRegistrationScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class CreateOrderScreen extends StatefulWidget {
  final String driverName;
  final String driverPhone;

  const CreateOrderScreen({
    super.key,
    required this.driverName,
    required this.driverPhone,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  int _seats = 3;
  bool _isLoading = false;
  String? _selectedFromLocation;
  String? _selectedToLocation;

  String get _driverName => widget.driverName;
  String get _driverPhone => widget.driverPhone;

  final List<String> _allLocations = [
    'Кӯлоб',
    'Душанбе',
    'Восеъ',
    'Хуҷанд',
    'Бухоро',
    'Самарқанд',
    'Файзобод',
    'Турсунзода',
    'Панҷакент',
    'Истаравшан',
  ];

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateOrder() async {
    if (_selectedFromLocation == null || _selectedToLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Лутфан макони оғоз ва таъинро интихоб кунед'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_route_from', _selectedFromLocation!);
      await prefs.setString('active_route_to', _selectedToLocation!);

      final now = DateTime.now();

      // Publish to the server FIRST and capture the REAL server id (UUID).
      // Storing that id locally is what lets the delete button remove the
      // SAME announcement from the server afterwards (and from passengers).
      final serverTrip = await ApiService.createTrip({
        'driver_id': _driverPhone,
        'driver_name': _driverName,
        'driver_phone': _driverPhone,
        'from_location': _selectedFromLocation!,
        'to_location': _selectedToLocation!,
        'departure_time': now.toIso8601String(),
        'price':
            int.tryParse(_priceController.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ??
                0,
        'available_seats': _seats,
      });

      // Save the announcement so it appears on the driver home screen AND in
      // the passenger route search (real data — no mock). Car info comes from
      // the driver registration data stored earlier.
      final order = Order(
        id: serverTrip?['id']?.toString() ?? now.millisecondsSinceEpoch.toString(),
        fromLocation: _selectedFromLocation!,
        toLocation: _selectedToLocation!,
        price: _priceController.text.trim(),
        duration: _durationController.text.trim(),
        seats: _seats,
        notes: '',
        createdAt: now.toIso8601String(),
        departureTime: now.toIso8601String(),
        driverName: _driverName,
        driverPhone: _driverPhone,
        carBrand: prefs.getString('driver_car_brand') ?? '',
        carModel: prefs.getString('driver_car_model') ?? '',
        carColor: prefs.getString('driver_car_color') ?? '',
        carPlate: prefs.getString('driver_plate_number') ?? '',
      );

      // Plain async I/O (SharedPreferences) — never blocks the UI thread.
      // Keeps the announcement on THIS device (driver home screen list).
      await saveOrder(order);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хатогӣ — эълон нигоҳ дошта нашуд'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Создани заказ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // From Location Selection
              GestureDetector(
                onTap: () async {
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationSelectionScreen(
                        title: 'Аз куҷо меравед?',
                        locations: _allLocations,
                        selectedLocation: _selectedFromLocation,
                      ),
                    ),
                  );
                  if (selected != null) {
                    setState(() => _selectedFromLocation = selected);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedFromLocation != null
                          ? const Color(0xFF0066FF)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trip_origin, size: 24, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFromLocation ?? 'Аз куҷо меравед?',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedFromLocation != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // To Location Selection
              GestureDetector(
                onTap: () async {
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationSelectionScreen(
                        title: 'Ба куҷо рафтан мехоҳед?',
                        locations: _allLocations,
                        selectedLocation: _selectedToLocation,
                      ),
                    ),
                  );
                  if (selected != null) {
                    setState(() => _selectedToLocation = selected);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedToLocation != null
                          ? const Color(0xFF0066FF)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 24, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedToLocation ?? 'Ба куҷо рафтан мехоҳед?',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedToLocation != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Price input
              TextFormField(
                controller: _priceController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Нархро ворид кунед';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Нарх (сомонӣ)',
                  border: OutlineInputBorder(),
                  hintText: 'Масалан: 150',
                ),
              ),
              const SizedBox(height: 16),
              // Duration input
              TextFormField(
                controller: _durationController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Вақтро ворид кунед';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Вақт (дақиқа)',
                  border: OutlineInputBorder(),
                  hintText: 'Масалан: 30',
                ),
              ),
              const SizedBox(height: 16),
              // Seats selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ҷойҳои холӣ: $_seats',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Minus button
                      GestureDetector(
                        onTap: () {
                          if (_seats > 1) {
                            setState(() => _seats--);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 24,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Seats display
                      Container(
                        width: 80,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '$_seats',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Plus button
                      GestureDetector(
                        onTap: () {
                          if (_seats < 8) {
                            setState(() => _seats++);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 24,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Create order button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Эълон кардан',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final String fromLocation;
  final String toLocation;
  final String price;
  final String duration;
  final int seats;
  final String passengerPhone;
  final String passengerName;

  const OrderDetailsScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.price,
    required this.duration,
    required this.seats,
    required this.passengerPhone,
    this.passengerName = 'Мусофир',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Тафсилоти заказ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Харита',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Route information
            Row(
              children: [
                // From location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Аз',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fromLocation,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 24,
                  color: Colors.grey[400],
                ),
                // To location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Ба',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        toLocation,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Divider
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 24),
            // Price
            _buildInfoRow(
              icon: Icons.attach_money_rounded,
              label: 'Нарх',
              value: price,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 16),
            // Duration
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Вақт',
              value: duration,
              iconColor: Colors.blue,
            ),
            const SizedBox(height: 16),
            // Seats
            _buildInfoRow(
              icon: Icons.airline_seat_recline_normal_rounded,
              label: 'Ҷойҳои холӣ',
              value: '$seats ҷой',
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 24),
            // Divider
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 24),
            // Passenger info
            Text(
              'Маълумоти мусофир',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 24,
                        color: const Color(0xFF0066FF),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ном:',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      passengerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 24,
                        color: const Color(0xFF0066FF),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Телефон:',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Text(
                      passengerPhone,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Accept button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Заказ қабул шуд!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Navigate back to driver home after delay
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const DriverHomeScreen(
                            driverName: 'Ронанда',
                            driverPhone: '',
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Заказро қабул кардан',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Order model — represents a driver's ride announcement (эълон)
class Order {
  final String id;
  final String fromLocation;
  final String toLocation;
  final String price;
  final String duration;
  final int seats;
  final String notes;
  final String createdAt;
  final String departureTime;
  final String driverName;
  final String driverPhone;
  final String carBrand;
  final String carModel;
  final String carColor;
  final String carPlate;

  Order({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.price,
    required this.duration,
    required this.seats,
    required this.notes,
    required this.createdAt,
    this.departureTime = '',
    this.driverName = '',
    this.driverPhone = '',
    this.carBrand = '',
    this.carModel = '',
    this.carColor = '',
    this.carPlate = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
    'price': price,
    'duration': duration,
    'seats': seats,
    'notes': notes,
    'createdAt': createdAt,
    'departureTime': departureTime,
    'driverName': driverName,
    'driverPhone': driverPhone,
    'carBrand': carBrand,
    'carModel': carModel,
    'carColor': carColor,
    'carPlate': carPlate,
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String? ?? '',
    fromLocation: json['fromLocation'] as String? ?? '',
    toLocation: json['toLocation'] as String? ?? '',
    price: json['price'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    seats: json['seats'] as int? ?? 0,
    notes: json['notes'] as String? ?? '',
    createdAt: json['createdAt'] as String? ?? '',
    departureTime: json['departureTime'] as String? ?? '',
    driverName: json['driverName'] as String? ?? '',
    driverPhone: json['driverPhone'] as String? ?? '',
    carBrand: json['carBrand'] as String? ?? '',
    carModel: json['carModel'] as String? ?? '',
    carColor: json['carColor'] as String? ?? '',
    carPlate: json['carPlate'] as String? ?? '',
  );
}

/// Persists an order to SharedPreferences so it survives app restarts / refresh
Future<void> saveOrder(Order order) async {
  final prefs = await SharedPreferences.getInstance();
  final orders = await loadOrders();
  orders.add(order);
  await prefs.setString(
    'saved_orders',
    jsonEncode(orders.map((o) => o.toJson()).toList()),
  );
}

/// Loads all saved orders from SharedPreferences
Future<List<Order>> loadOrders() async {
  final prefs = await SharedPreferences.getInstance();
  final ordersJson = prefs.getString('saved_orders');
  if (ordersJson == null || ordersJson.isEmpty) return [];
  final List<dynamic> decoded = jsonDecode(ordersJson);
  return decoded
      .map((item) => Order.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Deletes a single order by id — from the SERVER (which also broadcasts
/// `trip_deleted` to every passenger device, so the announcement disappears
/// from the мусофир app too) AND from local storage.
Future<void> deleteOrder(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final orders = await loadOrders();
  Order? order;
  for (final o in orders) {
    if (o.id == id) {
      order = o;
      break;
    }
  }

  // 1) Delete on the server. New announcements store the server UUID as
  //    their local id, so a direct call works. Older saved announcements
  //    have a local timestamp id, so we fall back to matching the server
  //    trip by its route/driver/price and delete that exact row.
  final serverId = _looksLikeUuid(id) ? id : await _resolveServerTripId(order);
  if (serverId != null && serverId.isNotEmpty) {
    // deleteTrip returns true when the server confirmed the delete OR the
    // trip was already gone (404). It returns false only when unreachable —
    // in that case we still remove the local copy so the app keeps working.
    await ApiService.deleteTrip(serverId);
  }

  // 2) Always remove the local copy.
  orders.removeWhere((o) => o.id == id);
  await prefs.setString(
    'saved_orders',
    jsonEncode(orders.map((o) => o.toJson()).toList()),
  );
}

bool _looksLikeUuid(String id) => RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);

/// Finds the server trip matching the given local order by its content
/// (route + driver + price) so old announcements that only carry a local
/// timestamp id can still be removed from the server.
Future<String?> _resolveServerTripId(Order? order) async {
  if (order == null) return null;
  final trips = await ApiService.fetchTrips();
  final norm = (String? s) => (s ?? '').trim().toLowerCase();
  final priceNum = int.tryParse(order.price.replaceAll(RegExp(r'[^0-9]'), ''));
  final candidates = <Map<String, dynamic>>[];
  for (final t in trips) {
    if (norm(t['from_location']) != norm(order.fromLocation)) continue;
    if (norm(t['to_location']) != norm(order.toLocation)) continue;
    if (order.driverPhone.isNotEmpty &&
        norm(t['driver_phone']) != norm(order.driverPhone) &&
        norm(t['driver_id']) != norm(order.driverPhone)) {
      continue;
    }
    if (priceNum != null &&
        t['price'] is num &&
        (t['price'] as num) != priceNum) {
      continue;
    }
    candidates.add(t);
  }
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first['id']?.toString();
  final depart = order.departureTime.trim();
  if (depart.isNotEmpty) {
    for (final t in candidates) {
      if (norm(t['departure_time']) == norm(depart)) {
        return t['id']?.toString();
      }
    }
  }
  return candidates.first['id']?.toString();
}

class DriverHomeScreen extends StatefulWidget {
  final String driverName;
  final String driverPhone;

  const DriverHomeScreen({
    super.key,
    required this.driverName,
    required this.driverPhone,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _profileImage;
  int _currentIndex = 0;
  bool _isOnline = true;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await loadOrders();
    if (!mounted) return;
    setState(() => _orders = orders.reversed.toList());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isOnline = state == AppLifecycleState.resumed;
    if (mounted && _isOnline != isOnline) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImage = bytes;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _resetProfileAndRestart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
      (route) => false,
    );
  }

  void _openSettingsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCurrentTab()),
            _buildBottomNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Салом, Ронанда!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Барои кор омодаед?',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openSettingsScreen,
                tooltip: 'Танзимот',
                icon: Icon(
                  Icons.settings_rounded,
                  size: 28,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // "Закази нав" button — compact card
          GestureDetector(
            onTap: () async {
              final wasCreated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateOrderScreen(
                    driverName: widget.driverName,
                    driverPhone: widget.driverPhone,
                  ),
                ),
              );
              if (wasCreated == true && mounted) {
                _loadOrders();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0066FF), Color(0xFF3399FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0066FF).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Закази нав',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Барои эълон кардан зер кунед',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section title: Эълонҳо
          Row(
            children: [
              const Icon(
                Icons.campaign_rounded,
                size: 20,
                color: Color(0xFF0066FF),
              ),
              const SizedBox(width: 8),
              Text(
                'Эълонҳои ман',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_orders.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Orders list
          Expanded(
            child: _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ҳанӯз эълон вуҷуд надорад',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Аввалин эълони худро созед',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(_orders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route row: from → to
          Row(
            children: [
              // Route icons
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 28, color: Colors.grey[300]),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Locations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.fromLocation,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      order.toLocation,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Price badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.attach_money_rounded,
                      size: 18,
                      color: Color(0xFF0066FF),
                    ),
                    Text(
                      '${order.price} сом',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Bottom info row
          Row(
            children: [
              _buildOrderInfoChip(
                icon: Icons.access_time_rounded,
                label: order.duration.isNotEmpty
                    ? '${order.duration} дақ'
                    : '—',
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildOrderInfoChip(
                icon: Icons.airline_seat_recline_normal_rounded,
                label: '${order.seats} ҷой',
                color: Colors.orange,
              ),
              const Spacer(),
              // Delete button
              GestureDetector(
                onTap: () async {
                  await deleteOrder(order.id);
                  _loadOrders();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Start trip button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                // Save active route and navigate to map tab
                _startTrip(order);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Оғози сафар',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrip(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_route_from', order.fromLocation);
    await prefs.setString('active_route_to', order.toLocation);
    await prefs.setBool('trip_started', true);
    if (!mounted) return;
    setState(() => _currentIndex = 1);
  }

  Widget _buildOrderInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTab() {
    return const _RouteMapTab();
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildRouteTab();
      case 2:
        return _buildMessagesTab();
      default:
        return _buildProfileTab();
    }
  }

  Widget _buildMessagesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Сообщения',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _cleanDebugText(String value) {
    if (value.contains('TextEditingController') ||
        value.contains('TextEditingValue')) {
      var match = RegExp(r'text:\s*-\|\s*([^|]+?)\s*\|').firstMatch(value);
      if (match != null) {
        final extracted = match.group(1)?.trim() ?? '';
        if (extracted.isNotEmpty && !extracted.contains('selection')) {
          return extracted;
        }
      }

      match = RegExp(r"'([^']+)'").firstMatch(value);
      if (match != null) {
        final extracted = match.group(1)?.trim() ?? '';
        if (extracted.isNotEmpty &&
            !extracted.contains('TextEditing') &&
            !extracted.contains('selection') &&
            extracted.length < 50) {
          return extracted;
        }
      }
    }
    return value;
  }

  Future<Map<String, String>> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    var firstName = prefs.getString('user_first_name') ?? '';
    var lastName = prefs.getString('user_last_name') ?? '';
    final phone = prefs.getString('user_phone') ?? widget.driverPhone;
    final birthYear = prefs.getString('user_birth_year') ?? '';
    final gender = prefs.getString('user_gender') ?? '—';
    final carBrand = prefs.getString('driver_car_brand') ?? '—';
    final carColor = prefs.getString('driver_car_color') ?? '—';
    final carModel = prefs.getString('driver_car_model') ?? '—';
    final plateNumber = prefs.getString('driver_plate_number') ?? '—';

    firstName = _cleanDebugText(firstName);
    lastName = _cleanDebugText(lastName);

    final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? [firstName, lastName].where((item) => item.isNotEmpty).join(' ')
        : (prefs.getString('user_name') ?? '—');

    return {
      'full_name': fullName,
      'phone': phone,
      'role': 'Ронанда',
      'birth_year': birthYear,
      'gender': gender,
      'car_brand': carBrand,
      'car_color': carColor,
      'car_model': carModel,
      'plate_number': plateNumber,
    };
  }

  Future<void> _showProfileEditor() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneController = TextEditingController(
      text: prefs.getString('user_phone') ?? widget.driverPhone,
    );
    final carModelController = TextEditingController(
      text: prefs.getString('driver_car_model') ?? '',
    );
    final plateController = TextEditingController(
      text: prefs.getString('driver_plate_number') ?? '',
    );
    String selectedBrand = prefs.getString('driver_car_brand') ?? '';
    String selectedColor = prefs.getString('driver_car_color') ?? '';

    final changed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Редактировать профиль'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Рақами телефон',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarBrandSelectionScreen(
                              brands: supportedCarBrands,
                              selectedBrand: selectedBrand.isNotEmpty
                                  ? selectedBrand
                                  : null,
                            ),
                          ),
                        );
                        if (result != null) {
                          setDialogState(() => selectedBrand = result);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_car,
                              color: Color(0xFF0066FF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedBrand.isNotEmpty
                                    ? selectedBrand
                                    : 'Маркаи мошин',
                                style: TextStyle(
                                  color: selectedBrand.isNotEmpty
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: carModelController,
                      decoration: const InputDecoration(
                        labelText: 'Модели мошин',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarColorSelectionScreen(
                              colors: const [
                                'Сабз',
                                'Сафед',
                                'Сиёҳ',
                                'Сурх',
                                'Кабуд',
                                'Зард',
                                'Нилӯфар',
                                'Беж',
                                'Кул',
                                'Тилоӣ',
                              ],
                              selectedColor: selectedColor.isNotEmpty
                                  ? selectedColor
                                  : null,
                            ),
                          ),
                        );
                        if (result != null) {
                          setDialogState(() => selectedColor = result);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: selectedColor.isNotEmpty
                                    ? {
                                            'Сабз': Colors.green,
                                            'Сафед': Colors.white,
                                            'Сиёҳ': Colors.black,
                                            'Сурх': Colors.red,
                                            'Кабуд': Colors.blue,
                                            'Зард': Colors.yellow,
                                            'Нилӯфар': Colors.purple,
                                            'Беж': Colors.brown,
                                            'Кул': Colors.grey,
                                            'Тилоӣ': Colors.amber,
                                          }[selectedColor] ??
                                          Colors.grey
                                    : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                selectedColor.isNotEmpty
                                    ? selectedColor
                                    : 'Ранги мошин',
                                style: TextStyle(
                                  color: selectedColor.isNotEmpty
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: plateController,
                      decoration: const InputDecoration(
                        labelText: 'Рақами давлатӣ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Бекор'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final phoneValue = phoneController.text.trim();
                    final brandValue = selectedBrand.trim();
                    final modelValue = carModelController.text.trim();
                    final colorValue = selectedColor.trim();
                    final plateValue = plateController.text.trim();

                    if (phoneValue.isNotEmpty) {
                      await prefs.setString('user_phone', phoneValue);
                    }
                    if (brandValue.isNotEmpty) {
                      await prefs.setString('driver_car_brand', brandValue);
                    }
                    if (modelValue.isNotEmpty) {
                      await prefs.setString('driver_car_model', modelValue);
                    }
                    if (colorValue.isNotEmpty) {
                      await prefs.setString('driver_car_color', colorValue);
                    }
                    if (plateValue.isNotEmpty) {
                      await prefs.setString('driver_plate_number', plateValue);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (changed == true) {
      setState(() {});
    }
  }

  Widget _buildProfileTab() {
    return FutureBuilder<Map<String, String>>(
      future: _loadProfileData(),
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            {
              'full_name': widget.driverName,
              'phone': widget.driverPhone,
              'role': 'Ронанда',
              'birth_year': '—',
              'gender': '—',
              'car_brand': '—',
              'car_color': '—',
              'car_model': '—',
              'plate_number': '—',
            };

        final topProfileRows = [
          _buildProfileRow(
            'Ном ва насаб',
            data['full_name'] ?? '—',
            compact: true,
          ),
          _buildProfileRow(
            'Рақами телефон',
            data['phone'] ?? '—',
            compact: true,
          ),
          _buildProfileRow('Рол', data['role'] ?? 'Ронанда'),
        ];

        final vehicleRows = [
          _buildProfileRow('Соли таваллуд', data['birth_year'] ?? '—'),
          _buildProfileRow('Ҷинс', data['gender'] ?? '—'),
          _buildProfileRow('Маркаи мошин', data['car_brand'] ?? '—'),
          _buildProfileRow('Ранги мошин', data['car_color'] ?? '—'),
          _buildProfileRow('Модели мошин', data['car_model'] ?? '—'),
          _buildProfileRow('Рақами давлатӣ', data['plate_number'] ?? '—'),
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isOnline
                                    ? const Color(0xFF22C55E)
                                    : Colors.grey,
                                width: 3,
                              ),
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: MemoryImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 36,
                                    color: Color(0xFF0066FF),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0066FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['full_name'] ?? 'Ронанда',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ронанда',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openSettingsScreen,
                        tooltip: 'Танзимот',
                        icon: const Icon(
                          Icons.settings_rounded,
                          size: 28,
                          color: Color(0xFF0066FF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 13, child: Column(children: topProfileRows)),
                    const SizedBox(width: 12),
                    const Expanded(flex: 7, child: _ProfileRatingCard()),
                  ],
                ),
                ...vehicleRows,
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showProfileEditor,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Редактировать'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0066FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value, {bool compact = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: compact
          ? Row(
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0066FF),
        unselectedItemColor: Colors.grey[400],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded, size: 28),
            label: 'Асосӣ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_rounded),
            activeIcon: Icon(Icons.route_rounded, size: 28),
            label: 'Масир',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            activeIcon: Icon(Icons.message_rounded, size: 28),
            label: 'Сообщения',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded, size: 28),
            label: 'Профил',
          ),
        ],
      ),
    );
  }
}

class _RouteMapTab extends StatefulWidget {
  const _RouteMapTab();

  @override
  State<_RouteMapTab> createState() => _RouteMapTabState();
}

class _RouteMapTabState extends State<_RouteMapTab> {
  static const _initialLocation = LatLng(38.5598, 68.7870);
  final _mapController = MapController();
  final _searchController = TextEditingController();
  double _zoom = 13;
  LatLng _selectedLocation = _initialLocation;
  LatLng? _routeStart;
  LatLng? _routeEnd;
  String? _routeStartName;
  String? _routeEndName;
  List<_PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  List<LatLng> _routePoints = [];
  String? _routeDistance;
  String? _routeDuration;
  bool _tripStarted = false;
  LatLng? _carPosition;
  double _traveledDistance = 0;
  int _currentRouteIndex = 0;
  Timer? _carTimer;

  @override
  void initState() {
    super.initState();
    _loadActiveRoute();
    _checkTripStarted();
  }

  Future<void> _checkTripStarted() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getBool('trip_started') ?? false;
    if (started && mounted) {
      setState(() => _tripStarted = true);
    }
  }

  Future<void> _loadActiveRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final fromName = prefs.getString('active_route_from');
    final toName = prefs.getString('active_route_to');
    final from = fromName == null ? null : taxiLocationCoordinates[fromName];
    final to = toName == null ? null : taxiLocationCoordinates[toName];

    if (!mounted) return;
    setState(() {
      _routeStartName = fromName;
      _routeEndName = toName;
      _routeStart = from;
      _routeEnd = to;
      _routePoints = [];
    });

    if (from != null && to != null) {
      // Fetch real road route from OSRM API
      await _fetchRoute(from, to);

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final distance = const Distance().as(LengthUnit.Kilometer, from, to);
        _zoom = distance < 20
            ? 12
            : distance < 100
            ? 9
            : 6;
        _mapController.move(
          LatLng(
            (from.latitude + to.latitude) / 2,
            (from.longitude + to.longitude) / 2,
          ),
          _zoom,
        );
      });
    }
  }

  /// Fetches real road route points from OSRM (Open Source Routing Machine)
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Роҳ дастнорас аст');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) return;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List? ?? [];

      final points = coordinates
          .map(
            (coord) => LatLng((coord as List)[1] as double, coord[0] as double),
          )
          .toList();

      // Extract distance (meters) and duration (seconds) from OSRM
      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

      final distanceKm = distanceMeters / 1000;
      final distanceText = distanceKm >= 100
          ? '${distanceKm.toStringAsFixed(0)} км'
          : '${distanceKm.toStringAsFixed(1)} км';

      final hours = (durationSeconds / 3600).floor();
      final minutes = ((durationSeconds % 3600) / 60).round();
      final durationText = hours > 0
          ? '$hours соат $minutes дақ'
          : '$minutes дақ';

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeDistance = distanceText;
        _routeDuration = durationText;
        if (_tripStarted && points.isNotEmpty) {
          _carPosition = points.first;
          _currentRouteIndex = 0;
          _traveledDistance = 0;
          _startCarMovement();
        }
      });
    } catch (_) {
      // If OSRM fails, fall back to a straight line
      if (!mounted) return;
      setState(() {
        _routePoints = [from, to];
        _routeDistance = null;
        _routeDuration = null;
        if (_tripStarted) {
          _carPosition = from;
          _currentRouteIndex = 0;
          _traveledDistance = 0;
          _startCarMovement();
        }
      });
    }
  }

  void _startCarMovement() {
    _carTimer?.cancel();
    _carTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _routePoints.isEmpty) {
        timer.cancel();
        return;
      }
      if (_currentRouteIndex >= _routePoints.length - 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentRouteIndex++;
        _carPosition = _routePoints[_currentRouteIndex];
        // Calculate traveled distance
        if (_currentRouteIndex > 0) {
          final prev = _routePoints[_currentRouteIndex - 1];
          final curr = _routePoints[_currentRouteIndex];
          _traveledDistance += const Distance().as(
            LengthUnit.Kilometer,
            prev,
            curr,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeZoom(double difference) {
    _zoom = (_zoom + difference).clamp(3, 18).toDouble();
    _mapController.move(_mapController.camera.center, _zoom);
  }

  void _goToInitialLocation() {
    _zoom = 13;
    setState(() => _selectedLocation = _initialLocation);
    _mapController.move(_initialLocation, _zoom);
  }

  Future<void> _searchPlace([String? value]) async {
    final query = (value ?? _searchController.text).trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'tj',
        'q': query,
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'InterTaxi/1.0 (com.intertaxi.intertaxi)',
          'Accept-Language': 'tg,ru;q=0.9,en;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ҷустуҷӯ дастнорас аст');
      }

      final places = (jsonDecode(response.body) as List)
          .map(
            (item) => _PlaceSearchResult.fromJson(item as Map<String, dynamic>),
          )
          .where((item) => item.location != null)
          .toList();

      if (!mounted) return;
      setState(() => _searchResults = places);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchError = 'Ҷой ёфт нашуд. Аз нав кӯшиш кунед.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_PlaceSearchResult result) {
    final location = result.location!;
    _searchController.text = result.name;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = location;
      _searchResults = [];
    });
    _zoom = 15;
    _mapController.move(location, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialLocation,
            initialZoom: 13,
            maxZoom: 18,
            minZoom: 3,
            onTap: (_, point) => setState(() => _selectedLocation = point),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.intertaxi.intertaxi',
              maxNativeZoom: 19,
            ),
            if (_routePoints.isNotEmpty && !_tripStarted)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF0066FF),
                    strokeWidth: 6,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: _routeStart != null && _routeEnd != null
                  ? [
                      if (!_tripStarted)
                        _routeMarker(_routeStart!, Colors.green, 'А'),
                      if (!_tripStarted)
                        _routeMarker(_routeEnd!, Colors.red, 'Б'),
                      if (_tripStarted && _carPosition != null)
                        Marker(
                          point: _carPosition!,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 5),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_taxi_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ]
                  : [
                      Marker(
                        point: _selectedLocation,
                        width: 54,
                        height: 54,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 54,
                          color: Color(0xFF0066FF),
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 5),
                          ],
                        ),
                      ),
                    ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
                TextSourceAttribution('CARTO'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 18,
          left: 16,
          right: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onSubmitted: _searchPlace,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Номи шаҳр ё ноҳияро нависед',
                hintStyle: const TextStyle(color: Colors.black54, fontSize: 15),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF0066FF),
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        color: const Color(0xFF0066FF),
                        onPressed: _searchPlace,
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty || _searchError != null)
          Positioned(
            top: 82,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 5,
              child: _searchError != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _searchError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF0066FF),
                          ),
                          title: Text(
                            result.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
            ),
          ),

        // Route info card: distance & duration
        if (_routeDistance != null && _routeDuration != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Distance
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.straighten_rounded,
                                size: 20,
                                color: Color(0xFF0066FF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Масофа',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _routeDistance!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(width: 1, height: 32, color: Colors.grey[300]),
                      const SizedBox(width: 12),
                      // Duration
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 20,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Вақт',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _routeDuration!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Traveled distance (only when trip started)
                  if (_tripStarted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.route_rounded,
                              size: 20,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Масофаи тайкарда',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${_traveledDistance.toStringAsFixed(1)} км',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_routeStartName != null && _routeEndName != null)
          Positioned(
            left: 16,
            right: 84,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.trip_origin, size: 16, color: Colors.green),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _routeStartName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _routeEndName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 28,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.add,
                onPressed: () => _changeZoom(1),
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove,
                onPressed: () => _changeZoom(-1),
              ),
              const SizedBox(height: 12),
              _MapControlButton(
                icon: Icons.my_location_rounded,
                onPressed: _goToInitialLocation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Marker _routeMarker(LatLng point, Color color, String label) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PlaceSearchResult {
  final String name;
  final LatLng? location;

  const _PlaceSearchResult({required this.name, required this.location});

  factory _PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    return _PlaceSearchResult(
      name: json['display_name'] as String? ?? 'Ҷойи номаълум',
      location:
          double.tryParse(json['lat']?.toString() ?? '') != null &&
              double.tryParse(json['lon']?.toString() ?? '') != null
          ? LatLng(
              double.parse(json['lat'].toString()),
              double.parse(json['lon'].toString()),
            )
          : null,
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFF0066FF)),
        ),
      ),
    );
  }
}

class _ProfileRatingCard extends StatelessWidget {
  const _ProfileRatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 159,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7E2), Color(0xFFFFE9AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC857)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 27),
          SizedBox(height: 4),
          Text(
            '0.0',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A5A00),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Рейтинг',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF8A5A00)),
          ),
          SizedBox(height: 3),
          Text(
            'Ба зудӣ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Color(0xFF9A6B10)),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetProfileAndRestart(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Танзимот'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Танзимоти ҳисоби корбар',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Бо зер кардани тугмаи зерин, ҳамаи маълумоти профил аз нав оғоз карда мешавад.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _resetProfileAndRestart(context),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Аз нав оғоз кардан'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ServerSettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.dns_rounded),
                label: const Text('Сервер'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0066FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF0066FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _carModelController = TextEditingController();
  final _licensePlateController = TextEditingController();
  String? _selectedCarBrand;
  String? _selectedCarColor;
  bool _isLoading = false;

  final List<String> _carColors = [
    'Сабз',
    'Сафед',
    'Сиёҳ',
    'Сурх',
    'Кабуд',
    'Зард',
    'Нилӯфар',
    'Беж',
    'Кул',
    'Тилоӣ',
  ];

  @override
  void dispose() {
    _carModelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Widget _buildLicensePlateBox({
    required TextEditingController controller,
    required int startIndex,
    required int length,
    required bool isNumber,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLength: length,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            // Only allow numbers for first and last sections
            if (isNumber) {
              final filtered = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
              return TextEditingValue(
                text: filtered.substring(0, min(filtered.length, length)),
                selection: newValue.selection,
              );
            } else {
              // Only allow letters for middle section
              final filtered = newValue.text.replaceAll(
                RegExp(r'[^A-Za-z]'),
                '',
              );
              return TextEditingValue(
                text: filtered
                    .substring(0, min(filtered.length, length))
                    .toUpperCase(),
                selection: newValue.selection,
              );
            }
          }),
        ],
      ),
    );
  }

  Future<void> _saveDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final originalFirstName = prefs.getString('user_first_name') ?? '';
    final originalLastName = prefs.getString('user_last_name') ?? '';
    final originalBirthYear = prefs.getString('user_birth_year') ?? '';

    await prefs.setString('app_session_version', _appSessionVersion);
    await prefs.setString('user_name', widget.passengerName);
    await prefs.setString('user_phone', widget.passengerPhone);
    await prefs.setString('user_role', 'driver');
    await prefs.setString(
      'user_first_name',
      originalFirstName.isNotEmpty
          ? originalFirstName
          : widget.passengerName.split(RegExp(r'\s+')).first,
    );
    await prefs.setString(
      'user_last_name',
      originalLastName.isNotEmpty
          ? originalLastName
          : widget.passengerName.split(RegExp(r'\s+')).skip(1).join(' '),
    );
    await prefs.setString('user_birth_year', originalBirthYear);

    if (_selectedCarBrand != null) {
      await prefs.setString('driver_car_brand', _selectedCarBrand!);
    }
    if (_selectedCarColor != null) {
      await prefs.setString('driver_car_color', _selectedCarColor!);
    }
    if (_carModelController.text.trim().isNotEmpty) {
      await prefs.setString(
        'driver_car_model',
        _carModelController.text.trim(),
      );
    }
    if (_licensePlateController.text.trim().isNotEmpty) {
      await prefs.setString(
        'driver_plate_number',
        _licensePlateController.text.trim(),
      );
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted) {
          setState(() => _isLoading = false);
          await _saveDriverProfile();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DriverHomeScreen(
                driverName: widget.passengerName,
                driverPhone: widget.passengerPhone,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Маълумоти мошин',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Маълумоти мошини худро ворид кунед',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                // Car Brand Selection
                GestureDetector(
                  onTap: () async {
                    final selected = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CarBrandSelectionScreen(
                          brands: supportedCarBrands,
                          selectedBrand: _selectedCarBrand,
                        ),
                      ),
                    );
                    if (selected != null) {
                      setState(() => _selectedCarBrand = selected);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedCarBrand != null
                            ? const Color(0xFF0066FF)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedCarBrand ?? 'Маркаи мошинро интихоб кунед',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedCarBrand != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Car Model Input
                TextFormField(
                  controller: _carModelController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Модели мошинро ворид кунед';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Модели мошин',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // License Plate Number (Format: 4 digits + 2 letters + 2 digits)
                TextFormField(
                  controller: _licensePlateController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Рақами давлатиро ворид кунед';
                    }
                    if (value.length != 8) {
                      return 'Рақам бояд 8 аломат бошад (масалан: 1111AA01)';
                    }
                    // Format: 4 digits + 2 letters + 2 digits
                    final regex = RegExp(r'^\d{4}[A-Z]{2}\d{2}$');
                    if (!regex.hasMatch(value.toUpperCase())) {
                      return 'Формат: 4 рақам + 2 ҳарф + 2 рақам (масалан: 1111AA01)';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Рақами давлатӣ',
                    border: OutlineInputBorder(),
                    hintText: 'Масалан: 1111AA01',
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      // Remove all non-alphanumeric characters
                      String filtered = newValue.text.replaceAll(
                        RegExp(r'[^A-Za-z0-9]'),
                        '',
                      );

                      // Convert to uppercase
                      filtered = filtered.toUpperCase();

                      // Smart formatting: automatically format as user types
                      if (filtered.isNotEmpty) {
                        // First 4 characters: numbers only
                        if (filtered.length <= 4) {
                          // Keep only numbers for first section
                          filtered = filtered.replaceAll(RegExp(r'[^0-9]'), '');
                        } else if (filtered.length <= 6) {
                          // First 4 are numbers, next 2 are letters
                          final numbers = filtered
                              .substring(0, 4)
                              .replaceAll(RegExp(r'[^0-9]'), '');
                          final letters = filtered
                              .substring(4)
                              .replaceAll(RegExp(r'[^A-Z]'), '');
                          filtered = numbers + letters;
                        } else {
                          // 4 numbers + 2 letters + remaining numbers
                          final numbers1 = filtered
                              .substring(0, 4)
                              .replaceAll(RegExp(r'[^0-9]'), '');
                          final letters = filtered
                              .substring(4, min(6, filtered.length))
                              .replaceAll(RegExp(r'[^A-Z]'), '');
                          final numbers2 = filtered
                              .substring(6)
                              .replaceAll(RegExp(r'[^0-9]'), '');
                          filtered = numbers1 + letters + numbers2;
                        }
                      }

                      // Limit to 8 characters
                      final limited = filtered.substring(
                        0,
                        min(filtered.length, 8),
                      );

                      return TextEditingValue(
                        text: limited,
                        selection: newValue.selection,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                // Car Color Selection
                GestureDetector(
                  onTap: () async {
                    final selected = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CarColorSelectionScreen(
                          colors: _carColors,
                          selectedColor: _selectedCarColor,
                        ),
                      ),
                    );
                    if (selected != null) {
                      setState(() => _selectedCarColor = selected);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedCarColor != null
                            ? const Color(0xFF0066FF)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedCarColor ?? 'Ранги мошинро интихоб кунед',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedCarColor != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Идома додан'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

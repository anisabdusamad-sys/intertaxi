import 'package:flutter/material.dart';
import '../models/intertaxi_models.dart' as models;
import '../services/api_service.dart';
import 'location_selection_screen.dart';

/// InterTaxi Create Order Screen
/// Allows drivers to create new ride orders
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
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  int _seats = 3;
  DateTime? _departureTime;
  bool _isLoading = false;

  final List<String> _locations = [
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
    _pickupController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0066FF),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0066FF),
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _departureTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

    Future<void> _handleCreateOrder() async {
    if (_pickupController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лутфан макони оғозро ворид кунед'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лутфан макони таъинотро ворид кунед'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лутфан нархро ворид кунед'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лутфан вақти рафтанро интихоб кунед'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Publish the announcement to the server FIRST and capture the REAL
      //    server id (UUID). Storing that same id locally is what makes the
      //    delete button able to remove the row on the server too (and
      //    broadcast `trip_deleted` to every passenger device).
      final serverTrip = await ApiService.createTrip({
        'driver_id': widget.driverPhone,
        'driver_name': widget.driverName,
        'driver_phone': widget.driverPhone,
        'from_location': _pickupController.text.trim(),
        'to_location': _destinationController.text.trim(),
        'departure_time': _departureTime!.toIso8601String(),
        'price':
            int.tryParse(_priceController.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ??
                0,
        'available_seats': _seats,
      });

      // 2) Build the local order using the server id when available
      //    (offline fallback keeps a local timestamp id).
      final order = models.Order(
        id: serverTrip?['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        fromLocation: _pickupController.text,
        toLocation: _destinationController.text,
        price: _priceController.text,
        duration: '',
        seats: _seats,
        notes: _notesController.text,
        createdAt: DateTime.now().toIso8601String(),
        departureTime: _departureTime!.toIso8601String(),
        driverName: widget.driverName,
        driverPhone: widget.driverPhone,
        carBrand: '',
        carModel: '',
        carColor: '',
        carPlate: '',
      );

      // 3) Persist the order locally (SharedPreferences) so it appears in
      //    "Эълонҳои ман" and survives app restarts.
      await models.saveOrder(order);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Заказ эълон шуд!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Мусофирон метавонанд заказ диҳанд',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF0066FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Хатогӣ дар эълон кардни заказ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Заказ эълон кардан',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup Location
                _buildSectionTitle('Аз куҷо меравед?', Icons.trip_origin),
                const SizedBox(height: 12),
                _buildLocationField(
                  controller: _pickupController,
                  hintText: 'Макони оғозро ворид кунед',
                  icon: Icons.trip_origin,
                  locations: _locations,
                ),

                const SizedBox(height: 20),

                // Destination
                _buildSectionTitle(
                  'Ба куҷо рафтан мехоҳед?',
                  Icons.location_on,
                ),
                const SizedBox(height: 12),
                _buildLocationField(
                  controller: _destinationController,
                  hintText: 'Макони таъинотро ворид кунед',
                  icon: Icons.location_on,
                  locations: _locations,
                ),

                const SizedBox(height: 20),

                // Seats and Price Row
                Row(
                  children: [
                    // Seats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Ҷойҳои холӣ',
                            Icons.airline_seat_recline_normal,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.airline_seat_recline_normal_rounded,
                                  color: const Color(0xFF0066FF),
                                  size: 24,
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: _seats > 1
                                          ? () => setState(() => _seats--)
                                          : null,
                                      icon: Icon(
                                        Icons.remove_circle_rounded,
                                        color: _seats > 1
                                            ? const Color(0xFF0066FF)
                                            : Colors.grey,
                                        size: 28,
                                      ),
                                    ),
                                    Text(
                                      '$_seats',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _seats < 8
                                          ? () => setState(() => _seats++)
                                          : null,
                                      icon: Icon(
                                        Icons.add_circle_rounded,
                                        color: _seats < 8
                                            ? const Color(0xFF0066FF)
                                            : Colors.grey,
                                        size: 28,
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

                    const SizedBox(width: 12),

                    // Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Нарх (сомонӣ)',
                            Icons.attach_money,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Масалан: 150',
                              prefixIcon: const Icon(
                                Icons.attach_money_rounded,
                                color: Color(0xFF0066FF),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0066FF),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Departure Time
                _buildSectionTitle('Вақти рафтан', Icons.access_time),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDepartureTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF0066FF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _departureTime == null
                                ? 'Вақтро интихоб кунед'
                                : '${_departureTime!.day}/${_departureTime!.month}/${_departureTime!.year} - ${_departureTime!.hour}:${_departureTime!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 15,
                              color: _departureTime == null
                                  ? Colors.grey[600]
                                  : Colors.black87,
                              fontWeight: _departureTime == null
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Notes
                _buildSectionTitle('Эзоҳот (ихтиёрӣ)', Icons.note),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Маълумоти иловагӣ...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0066FF),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Create Order Button
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0066FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required List<String> locations,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (newContext) => LocationSelectionScreen(
              title: 'Ҷойро интихоб кунед',
              locations: locations,
              selectedLocation: controller.text.isEmpty
                  ? null
                  : controller.text,
              onSelect: (location) {
                setState(() {
                  controller.text = location;
                });
                Navigator.pop(newContext);
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0066FF), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text.isEmpty ? hintText : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  color: controller.text.isEmpty
                      ? Colors.grey[600]
                      : Colors.black87,
                  fontWeight: controller.text.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

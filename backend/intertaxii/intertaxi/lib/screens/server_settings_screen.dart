import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

/// Lets the user point the app at the InterTaxi Flask backend.
///
/// The backend is deployed on Render at `https://intertaxi.onrender.com` and
/// that is the default address for every REST and Socket.IO call. This screen
/// only exists as an override for local development (e.g. pointing the app at
/// a Flask instance running on a PC: `http://192.168.1.20:5000`). The address
/// is stored in SharedPreferences (key `backend_url`) and used by every REST
/// and Socket.IO call through [ApiService.resolveBaseUrl].
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  static const String _baseUrlPrefsKey = 'backend_url';

  final TextEditingController _urlCtrl = TextEditingController();
  String _currentUrl = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final effective = await ApiService.resolveBaseUrl();
    if (!mounted) return;
    setState(() {
      _currentUrl = effective;
      // The field shows the saved override only (empty = platform default).
      _urlCtrl.text = prefs.getString(_baseUrlPrefsKey) ?? '';
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ApiService.setCustomBaseUrl(_urlCtrl.text);
    final effective = await ApiService.resolveBaseUrl();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _currentUrl = effective;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Суроғаи сервер нигоҳ дошта шуд: $effective'),
        backgroundColor: const Color(0xFF0066FF),
      ),
    );
  }

  Future<void> _reset() async {
    await ApiService.setCustomBaseUrl('');
    final effective = await ApiService.resolveBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlCtrl.clear();
      _currentUrl = effective;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ба пешфарз баргашт: $effective')),
    );
  }

  /// Pings the backend by fetching the trips list.
  Future<void> _testConnection() async {
    setState(() => _busy = true);
    final trips = await ApiService.fetchTrips();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trips.isNotEmpty
              ? 'Пайваст шуд! Эълонҳои фаъол: ${trips.length}'
              : 'Пайвастшавӣ нагузашт ё эълонҳо нестанд. IP-и компютерро санҷед.',
        ),
        backgroundColor: trips.isNotEmpty ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Сервер'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentCard(),
            const SizedBox(height: 16),
            const Text(
              'Суроғаи нав',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://intertaxi.onrender.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Пешфарз — сервери Render: https://intertaxi.onrender.com. '
              'Агар хоҳед барои санҷиш сервери локалӣ истифода баред, '
              'суроғаи онро ворид кунед (мисол: http://192.168.1.20:5000). '
              'Барои бозгашт ба сервери асосӣ, майдонро холӣ гузоред.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Нигоҳ доштан'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_rounded),
                    label: const Text('Санҷиш'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : _reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Ба пешфарз баргардонидан'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Суроғаи ҷорӣ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentUrl.isEmpty ? '…' : _currentUrl,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0066FF),
            ),
          ),
        ],
      ),
    );
  }
}
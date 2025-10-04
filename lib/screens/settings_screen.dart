import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../models/user_settings.dart';
import 'offline_map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final TextEditingController _weightController = TextEditingController();
  
  UserSettings _settings = UserSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final settings = await _preferencesService.loadUserSettings();
      setState(() {
        _settings = settings;
        _weightController.text = settings.weightKg.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar configuración');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final weight = double.tryParse(_weightController.text) ?? _settings.weightKg;
      
      final updatedSettings = _settings.copyWith(weightKg: weight);
      
      final success = await _preferencesService.saveUserSettings(updatedSettings);
      
      if (success) {
        setState(() => _settings = updatedSettings);
        _showSuccess('Configuración guardada');
      } else {
        _showError('Error al guardar configuración');
      }
    } catch (e) {
      _showError('Error al guardar configuración');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Configuración de usuario
                  _buildUserSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Configuración de unidades
                  _buildUnitsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Configuración de GPS
                  _buildGpsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Configuración de notificaciones
                  _buildNotificationsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Configuración de mapas offline
                  _buildOfflineMapsSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text(
                        'Guardar Configuración',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Personal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
                helperText: 'Necesario para calcular calorías',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unidades',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Unidad de distancia
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Unidad de Distancia'),
              subtitle: Text(_settings.distanceUnit == 'km' ? 'Kilómetros' : 'Millas'),
              trailing: DropdownButton<String>(
                value: _settings.distanceUnit,
                items: const [
                  DropdownMenuItem(value: 'km', child: Text('Kilómetros')),
                  DropdownMenuItem(value: 'miles', child: Text('Millas')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings.copyWith(distanceUnit: value);
                    });
                  }
                },
              ),
            ),
            
            // Unidad de velocidad
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Unidad de Velocidad'),
              subtitle: Text(_settings.speedUnit == 'kmh' ? 'km/h' : 'mph'),
              trailing: DropdownButton<String>(
                value: _settings.speedUnit,
                items: const [
                  DropdownMenuItem(value: 'kmh', child: Text('km/h')),
                  DropdownMenuItem(value: 'mph', child: Text('mph')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings.copyWith(speedUnit: value);
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración GPS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.gps_fixed),
              title: const Text('Intervalo de Actualización GPS'),
              subtitle: Text('Cada ${_settings.gpsUpdateInterval} segundos'),
              trailing: DropdownButton<int>(
                value: _settings.gpsUpdateInterval,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 seg')),
                  DropdownMenuItem(value: 2, child: Text('2 seg')),
                  DropdownMenuItem(value: 3, child: Text('3 seg')),
                  DropdownMenuItem(value: 5, child: Text('5 seg')),
                  DropdownMenuItem(value: 10, child: Text('10 seg')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings.copyWith(gpsUpdateInterval: value);
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('Alertas por Voz'),
              subtitle: const Text('Notificaciones habladas durante el recorrido'),
              value: _settings.enableVoiceAlerts,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(enableVoiceAlerts: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineMapsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mapas Offline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Gestionar Mapas Offline'),
              subtitle: const Text('Descargar mapas para usar sin datos móviles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OfflineMapScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Información'),
              subtitle: const Text(
                'Los mapas descargados se almacenan en tu dispositivo y no consumen datos móviles durante el uso.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
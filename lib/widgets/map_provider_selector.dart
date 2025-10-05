import 'package:flutter/material.dart';
import '../models/map_tile_provider.dart';

class MapProviderSelector extends StatelessWidget {
  final MapTileProvider currentProvider;
  final Function(MapTileProvider) onProviderChanged;
  final bool isCompact;

  const MapProviderSelector({
    super.key,
    required this.currentProvider,
    required this.onProviderChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactSelector(context);
    } else {
      return _buildFullSelector(context);
    }
  }

  Widget _buildCompactSelector(BuildContext context) {
    return PopupMenuButton<MapTileProvider>(
      icon: Icon(currentProvider.icon),
      tooltip: 'Cambiar tipo de mapa',
      onSelected: onProviderChanged,
      itemBuilder: (context) => MapTileProvider.values.map((provider) {
        return PopupMenuItem<MapTileProvider>(
          value: provider,
          child: Row(
            children: [
              Icon(
                provider.icon,
                color: provider == currentProvider ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.name,
                      style: TextStyle(
                        fontWeight: provider == currentProvider 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                        color: provider == currentProvider ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      provider.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (provider == currentProvider)
                Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFullSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tipo de Mapa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...MapTileProvider.values.map((provider) => _buildProviderTile(context, provider)),
      ],
    );
  }

  Widget _buildProviderTile(BuildContext context, MapTileProvider provider) {
    final isSelected = provider == currentProvider;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300],
        child: Icon(
          provider.icon,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
      title: Text(
        provider.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(provider.description),
      trailing: isSelected 
        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
        : null,
      selected: isSelected,
      onTap: () => onProviderChanged(provider),
    );
  }
}

// Widget para mostrar en configuraciones
class MapProviderSettingsScreen extends StatefulWidget {
  const MapProviderSettingsScreen({super.key});

  @override
  State<MapProviderSettingsScreen> createState() => _MapProviderSettingsScreenState();
}

class _MapProviderSettingsScreenState extends State<MapProviderSettingsScreen> {
  MapTileProvider _selectedProvider = MapTileProvider.openStreetMap;

  @override
  void initState() {
    super.initState();
    _loadCurrentProvider();
  }

  Future<void> _loadCurrentProvider() async {
    // Aquí cargarías desde SharedPreferences
    // Por ahora usamos el valor por defecto
  }

  Future<void> _saveProvider(MapTileProvider provider) async {
    // Aquí guardarías en SharedPreferences
    setState(() {
      _selectedProvider = provider;
    });
    
    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tipo de mapa cambiado a ${provider.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipo de Mapa'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Información sobre los tipos de mapa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary.withAlpha((0.08 * 255).round()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tipos de Mapas Disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona el tipo de mapa que prefieras para el tracking. '
                  'Los mapas descargados funcionarán sin conexión.',
                  style: TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          // Preview del mapa actual
          Container(
            height: 120,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: _getPreviewColor(context, _selectedProvider),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedProvider.icon,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vista previa: ${_selectedProvider.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Selector
          Expanded(
            child: MapProviderSelector(
              currentProvider: _selectedProvider,
              onProviderChanged: _saveProvider,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPreviewColor(BuildContext context, MapTileProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    switch (provider) {
      case MapTileProvider.openStreetMap:
  return scheme.primary.withAlpha((0.9 * 255).round());
      case MapTileProvider.cartoDark:
        return Colors.grey[800]!;
      case MapTileProvider.esriSatellite:
        return Colors.black87;
    }
  }
}
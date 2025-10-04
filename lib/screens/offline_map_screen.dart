import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/map_cache_service.dart';
import '../services/location_service.dart';
import '../models/map_area.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final MapCacheService _cacheService = MapCacheService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  
  List<MapArea> _areas = [];
  bool _isLoading = true;
  double _totalCacheMB = 0.0;
  LatLng? _currentLocation;
  LatLng? _selectionStart;
  LatLng? _selectionEnd;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _cacheService.initialize();
    await _loadAreas();
    await _getCurrentLocation();
    _listenToDownloadProgress();
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoading = true);
    
    try {
      final areas = await _cacheService.getAllAreas();
      final totalSize = await _cacheService.getTotalCacheSizeMB();
      
      setState(() {
        _areas = areas;
        _totalCacheMB = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar áreas: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      setState(() => _currentLocation = location);
      _mapController.move(location, 12.0);
    }
  }

  void _listenToDownloadProgress() {
    _cacheService.downloadProgress.listen((area) {
      setState(() {
        final index = _areas.indexWhere((a) => a.id == area.id);
        if (index != -1) {
          _areas[index] = area;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺️ Mapas Offline'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAreas,
          ),
          IconButton(
            icon: Icon(_isSelecting ? Icons.close : Icons.add_location_alt),
            onPressed: () {
              setState(() {
                _isSelecting = !_isSelecting;
                _selectionStart = null;
                _selectionEnd = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de información
          _buildInfoPanel(),
          
          // Mapa para selección
          Expanded(
            flex: 3,
            child: _buildMap(),
          ),
          
          // Lista de áreas descargadas
          Expanded(
            flex: 2,
            child: _buildAreasList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.storage, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cache: ${_totalCacheMB.toStringAsFixed(1)} MB / ${MapCacheService.maxCacheSizeMB} MB',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${_areas.length} áreas',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _totalCacheMB / MapCacheService.maxCacheSizeMB,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _totalCacheMB > MapCacheService.maxCacheSizeMB * 0.8 
                  ? Colors.red 
                  : Colors.blue,
            ),
          ),
          if (_isSelecting) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '📌 Selecciona dos puntos en el mapa para definir el área a descargar',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? const LatLng(40.7128, -74.0060),
        initialZoom: 12.0,
        onTap: _isSelecting ? _onMapTap : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.cicle_app',
        ),
        
        // Áreas descargadas
        PolylineLayer(
          polylines: _areas.map((area) => Polyline(
            points: [
              area.southWest,
              LatLng(area.southWest.latitude, area.northEast.longitude),
              area.northEast,
              LatLng(area.northEast.latitude, area.southWest.longitude),
              area.southWest,
            ],
            strokeWidth: 2.0,
            color: area.isFullyDownloaded ? Colors.green : Colors.orange,
          )).toList(),
        ),
        
        // Área en selección
        if (_selectionStart != null && _selectionEnd != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(_selectionStart!.latitude, _selectionStart!.longitude),
                  LatLng(_selectionStart!.latitude, _selectionEnd!.longitude),
                  LatLng(_selectionEnd!.latitude, _selectionEnd!.longitude),
                  LatLng(_selectionEnd!.latitude, _selectionStart!.longitude),
                  LatLng(_selectionStart!.latitude, _selectionStart!.longitude),
                ],
                strokeWidth: 3.0,
                color: Colors.red,
              ),
            ],
          ),
        
        // Marcadores
        MarkerLayer(
          markers: [
            // Ubicación actual
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
                width: 20,
                height: 20,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            
            // Puntos de selección
            if (_selectionStart != null)
              Marker(
                point: _selectionStart!,
                width: 30,
                height: 30,
                child: const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            if (_selectionEnd != null)
              Marker(
                point: _selectionEnd!,
                width: 30,
                height: 30,
                child: const Icon(
                  Icons.flag,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreasList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Áreas Descargadas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_areas.isNotEmpty)
                  TextButton(
                    onPressed: _showClearCacheDialog,
                    child: const Text('Limpiar Todo'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _areas.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay áreas descargadas\nSelecciona un área en el mapa',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _areas.length,
                        itemBuilder: (context, index) {
                          final area = _areas[index];
                          return _buildAreaCard(area);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(MapArea area) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: area.isFullyDownloaded 
              ? Colors.green 
              : area.isDownloading 
                  ? Colors.orange 
                  : Colors.grey,
          child: Icon(
            area.isFullyDownloaded 
                ? Icons.check 
                : area.isDownloading 
                    ? Icons.download 
                    : Icons.cloud_download,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          area.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (area.isDownloading) ...[
              LinearProgressIndicator(
                value: area.downloadProgress,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 4),
              Text('Descargando: ${(area.downloadProgress * 100).toStringAsFixed(1)}%'),
            ] else ...[
              Text('${area.sizeInMB.toStringAsFixed(1)} MB'),
              Text('Zoom ${area.minZoom}-${area.maxZoom}'),
            ],
          ],
        ),
        trailing: area.isDownloading 
            ? null
            : PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'center',
                    child: const Row(
                      children: [
                        Icon(Icons.center_focus_strong),
                        SizedBox(width: 8),
                        Text('Centrar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: const Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _onAreaMenuAction(value, area),
              ),
      ),
    );
  }

  void _onMapTap(_, LatLng point) {
    if (!_isSelecting) return;

    setState(() {
      if (_selectionStart == null) {
        _selectionStart = point;
      } else if (_selectionEnd == null) {
        _selectionEnd = point;
        _showCreateAreaDialog();
      } else {
        _selectionStart = point;
        _selectionEnd = null;
      }
    });
  }

  void _showCreateAreaDialog() {
    if (_selectionStart == null || _selectionEnd == null) return;

    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar Área'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nombre del área',
                hintText: 'Ej: Mi zona de entrenamiento',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta área se descargará para uso offline. Puede tardar varios minutos.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _createAndDownloadArea(controller.text.trim()),
            child: const Text('Descargar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAndDownloadArea(String name) async {
    if (name.isEmpty) name = 'Área ${DateTime.now().day}/${DateTime.now().month}';
    
    Navigator.pop(context);

    try {
      final northEast = LatLng(
        [_selectionStart!.latitude, _selectionEnd!.latitude].reduce((a, b) => a > b ? a : b),
        [_selectionStart!.longitude, _selectionEnd!.longitude].reduce((a, b) => a > b ? a : b),
      );
      
      final southWest = LatLng(
        [_selectionStart!.latitude, _selectionEnd!.latitude].reduce((a, b) => a < b ? a : b),
        [_selectionStart!.longitude, _selectionEnd!.longitude].reduce((a, b) => a < b ? a : b),
      );

      final area = await _cacheService.createArea(
        name: name,
        northEast: northEast,
        southWest: southWest,
      );

      setState(() {
        _areas.add(area);
        _isSelecting = false;
        _selectionStart = null;
        _selectionEnd = null;
      });

      // Iniciar descarga en background
      _cacheService.downloadArea(area.id).catchError((e) {
        _showError('Error al descargar: $e');
      });

      _showSuccess('Descarga iniciada: $name');
    } catch (e) {
      _showError('Error al crear área: $e');
    }
  }

  void _onAreaMenuAction(String action, MapArea area) {
    switch (action) {
      case 'center':
        final center = LatLng(
          (area.northEast.latitude + area.southWest.latitude) / 2,
          (area.northEast.longitude + area.southWest.longitude) / 2,
        );
        _mapController.move(center, 14.0);
        break;
      case 'delete':
        _showDeleteAreaDialog(area);
        break;
    }
  }

  void _showDeleteAreaDialog(MapArea area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Área'),
        content: Text('¿Eliminar "${area.name}"?\nSe liberarán ${area.sizeInMB.toStringAsFixed(1)} MB'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _deleteArea(area),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArea(MapArea area) async {
    Navigator.pop(context);
    
    try {
      await _cacheService.deleteArea(area.id);
      await _loadAreas();
      _showSuccess('Área eliminada: ${area.name}');
    } catch (e) {
      _showError('Error al eliminar: $e');
    }
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Cache'),
        content: Text('¿Eliminar todas las áreas descargadas?\nSe liberarán ${_totalCacheMB.toStringAsFixed(1)} MB'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _clearAllCache,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpiar Todo'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllCache() async {
    Navigator.pop(context);
    
    try {
      for (final area in _areas) {
        await _cacheService.deleteArea(area.id);
      }
      await _loadAreas();
      _showSuccess('Cache limpiado completamente');
    } catch (e) {
      _showError('Error al limpiar cache: $e');
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
}
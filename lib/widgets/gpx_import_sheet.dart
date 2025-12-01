import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/gpx_import_service.dart';
import '../services/database_service.dart';
import '../models/imported_route.dart';
import 'cached_tile_layer.dart';

class GpxImportSheet extends StatefulWidget {
  final Function(ImportedRoute) onLoad;
  const GpxImportSheet({super.key, required this.onLoad});

  @override
  State<GpxImportSheet> createState() => _GpxImportSheetState();
}

class _GpxImportSheetState extends State<GpxImportSheet> {
  final GpxImportService _service = GpxImportService();
  final TextEditingController _nameController = TextEditingController();
  ImportedRoute? _previewRoute;
  bool _loading = false;

  Future<void> _pickAndParse() async {
    setState(() => _loading = true);
    final f = await _service.pickGpxFile();
    if (f == null) {
      setState(() => _loading = false);
      return;
    }
    final route = await _service.parseGpxFile(f);
    setState(() {
      _previewRoute = route;
      _nameController.text = route?.name ?? '';
      _loading = false;
    });
    // we compute center/zoom later when building the map
  }

  Future<void> _saveAndLoad() async {
    if (_previewRoute == null) return;
    final db = DatabaseService();
    // allow renaming before save
    final renamed = ImportedRoute(
      id: _previewRoute!.id,
      name: _nameController.text.isNotEmpty ? _nameController.text : _previewRoute!.name,
      description: _previewRoute!.description,
      gpxText: _previewRoute!.gpxText,
      points: _previewRoute!.points,
      distanceKm: _previewRoute!.distanceKm,
      createdAt: _previewRoute!.createdAt,
    );
    final id = await db.insertImportedRoute(renamed);
    final list = await db.getAllImportedRoutes();
    ImportedRoute? inserted;
    try {
      inserted = list.firstWhere((r) => r.id == id);
    } catch (_) {
      inserted = null;
    }
    widget.onLoad(inserted ?? _previewRoute!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  LatLng _computeCenter(List<LatLng> pts) {
    final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final lon = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lon);
  }

  double _approxZoomForPoints(List<LatLng> pts) {
    // crude approximation: more spread -> lower zoom
    try {
      final lats = pts.map((p) => p.latitude);
      final lons = pts.map((p) => p.longitude);
      final latDiff = lats.reduce((a, b) => a > b ? a : b) - lats.reduce((a, b) => a < b ? a : b);
      final lonDiff = lons.reduce((a, b) => a > b ? a : b) - lons.reduce((a, b) => a < b ? a : b);
      final span = latDiff > lonDiff ? latDiff : lonDiff;
      if (span < 0.002) return 15.0;
      if (span < 0.01) return 14.0;
      if (span < 0.05) return 13.0;
      if (span < 0.2) return 12.0;
      return 10.0;
    } catch (_) {
      return 13.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Importar GPX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_previewRoute == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecciona un archivo GPX para previsualizar.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Seleccionar GPX'),
                        onPressed: _loading ? null : _pickAndParse,
                      ),
                    ],
                  ),
                ],
              )
                else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Nombre de la ruta', hintText: _previewRoute!.name ?? 'Sin nombre'),
                  ),
                  Text('Distancia: ${_previewRoute!.distanceKm.toStringAsFixed(2)} km'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AbsorbPointer(
                        absorbing: true,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _previewRoute!.points.isNotEmpty ? _computeCenter(_previewRoute!.points) : LatLng(0, 0),
                            initialZoom: _previewRoute!.points.isNotEmpty ? _approxZoomForPoints(_previewRoute!.points) : 13.0,
                          ),
                          children: [
                            CachedTileLayer(userAgentPackageName: 'com.example.cicle_app'),
                            PolylineLayer(
                              polylines: [
                                Polyline(points: _previewRoute!.points, color: Colors.blue, strokeWidth: 3.0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (_previewRoute != null) widget.onLoad(_previewRoute!);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cargar en mapa'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveAndLoad,
                        child: const Text('Guardar y Cargar'),
                      ),
                    ],
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}

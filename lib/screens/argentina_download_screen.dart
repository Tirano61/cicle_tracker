import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/argentina_regions.dart';
import '../services/map_cache_service.dart';
import 'package:latlong2/latlong.dart';

class ArgentinaDownloadScreen extends StatefulWidget {
  const ArgentinaDownloadScreen({super.key});

  @override
  State<ArgentinaDownloadScreen> createState() => _ArgentinaDownloadScreenState();
}

class _ArgentinaDownloadScreenState extends State<ArgentinaDownloadScreen> {
  final Set<String> _selectedProvinces = <String>{};
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentProvince = '';
  bool _forceRedownload = false;
  final MapCacheService _mapCacheService = MapCacheService();
  // Contadores de tiles para mostrar progreso real
  int _currentProvinceTilesDownloaded = 0;
  int _currentProvinceTilesTotal = 0;
  // Estado de progreso por provincia (cached)
  final Map<String, double> _provinceProgress = {};
  bool _loadingProvinceProgress = false;

  @override
  void initState() {
    super.initState();
    // Cargar el progreso de provincias al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProvinceProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargar Mapas de Argentina'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Información de descarga
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descarga Completa de Argentina',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ),
                const SizedBox(height: 8),
                _buildDownloadSummary(),
              ],
            ),
          ),

          // Progress bar cuando está descargando
          if (_isDownloading) _buildDownloadProgress(),

          // Lista de provincias por región
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: _buildRegionSections(),
            ),
          ),

          // Botones de acción
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDownloadSummary() {
    final selectedProvincesData = ArgentinaRegions.provinces
        .where((province) => _selectedProvinces.contains(province.code))
        .toList();
    
    final totals = ArgentinaRegions.calculateTotals(selectedProvincesData);
    final allTotals = ArgentinaRegions.calculateTotals(ArgentinaRegions.provinces);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Provincias seleccionadas: ${_selectedProvinces.length}/24'),
            Text('Área: ${(totals['areaKm2'] as double).toStringAsFixed(0)} km²'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tiles estimados: ${totals['tiles']}'),
            Text('Tamaño: ${(totals['sizeMB'] as double).toStringAsFixed(1)} MB'),
          ],
        ),
        const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Argentina: ${allTotals['tiles']} tiles (~${(allTotals['sizeMB'] as double).toStringAsFixed(0)} MB)',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.7 * 255).round())),
                      ),
                    ),
                    IconButton(
                      icon: _loadingProvinceProgress ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.refresh),
                      tooltip: 'Actualizar estado de provincias',
                      onPressed: _loadingProvinceProgress ? null : _refreshProvinceProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
          'Total Argentina: ${allTotals['tiles']} tiles (~${(allTotals['sizeMB'] as double).toStringAsFixed(0)} MB)',
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.7 * 255).round())),
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      padding: const EdgeInsets.all(16.0),
  color: Theme.of(context).colorScheme.primary.withAlpha((0.06 * 255).round()),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Descargando: $_currentProvince',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _cancelDownload,
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          if (_currentProvinceTilesTotal > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tiles: $_currentProvinceTilesDownloaded / $_currentProvinceTilesTotal'),
                const SizedBox(width: 8),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mostrar porcentaje por provincia para que sea más visible en descargas grandes
              Builder(builder: (context) {
                final provincePercent = _currentProvinceTilesTotal > 0
                    ? (_currentProvinceTilesDownloaded / _currentProvinceTilesTotal) * 100
                    : (_downloadProgress * 100);
                return Text('${provincePercent.toStringAsFixed(1)}% (provincia)');
              }),
              Text(
                '${_selectedProvinces.length} ${_selectedProvinces.length == 1 ? "provincia" : "provincias"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.8 * 255).round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRegionSections() {
    final regions = ArgentinaRegions.provincesByRegion;
    final List<Widget> sections = [];

    regions.forEach((regionName, provinces) {
      sections.add(_buildRegionSection(regionName, provinces));
      sections.add(const SizedBox(height: 16));
    });

    return sections;
  }

  Widget _buildRegionSection(String regionName, List<ArgentinaProvince> provinces) {
    final regionSelected = provinces.every((province) => _selectedProvinces.contains(province.code));
    final regionPartiallySelected = provinces.any((province) => _selectedProvinces.contains(province.code));

    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Checkbox(
              value: regionSelected,
              tristate: true,
              onChanged: _isDownloading ? null : (value) => _toggleRegion(provinces, value),
            ),
            Expanded(
              child: Text(
                regionName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: regionPartiallySelected ? scheme.primary : null,
                ),
              ),
            ),
          ],
        ),
        children: provinces.map((province) => _buildProvinceItem(province)).toList(),
      ),
    );
  }

  Widget _buildProvinceItem(ArgentinaProvince province) {
    final isSelected = _selectedProvinces.contains(province.code);
    final prog = _provinceProgress[province.code];
    // Determinar etiqueta de estado
    final String statusLabel;
    final Color? statusColor;
    if (prog == null) {
      statusLabel = 'No calculado';
      statusColor = null;
    } else if (prog >= 0.95) {
      statusLabel = 'Descargada';
      statusColor = Colors.green;
    } else if (prog > 0) {
      statusLabel = '${(prog * 100).toStringAsFixed(0)}%';
      statusColor = Colors.orange;
    } else {
      statusLabel = 'No descargada';
      statusColor = null;
    }

    return CheckboxListTile(
      title: Text(province.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${province.estimatedTileCount.toString()} tiles • ${province.estimatedSizeMB.toStringAsFixed(1)} MB'),
          if (prog != null)
            Text('Descargado: ${ (prog * 100).toStringAsFixed(1) }%'),
          const SizedBox(height: 6),
          Row(children: [
            Chip(
              label: Text(statusLabel),
              backgroundColor: statusColor == null ? null : statusColor.withOpacity(0.12),
              labelStyle: TextStyle(color: statusColor ?? Theme.of(context).textTheme.bodySmall?.color),
            ),
          ]),
          Text(
            'Área: ${province.areaKm2.toStringAsFixed(0)} km²',
            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.7 * 255).round())),
          ),
        ],
      ),
      value: isSelected,
      onChanged: _isDownloading ? null : (value) => _toggleProvince(province.code, value ?? false),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // Refrescar el progreso por provincia (no bloqueante, carga en serie para no saturar)
  Future<void> _refreshProvinceProgress() async {
    setState(() { _loadingProvinceProgress = true; _provinceProgress.clear(); });
    final provinces = ArgentinaRegions.provinces;
    for (final p in provinces) {
      final counts = _mapCacheService.getTileCountsForRegion(p.minLat, p.maxLat, p.minLng, p.maxLng, minZoom:9, maxZoom:12);
      final total = counts['total'] as int;
      if (total == 0) {
        setState(() { _provinceProgress[p.code] = 0.0; });
        continue;
      }
      final existing = await _mapCacheService.countExistingTilesForRegion(p.minLat, p.maxLat, p.minLng, p.maxLng, minZoom:9, maxZoom:12);
      final exist = existing['existing'] as int;
      setState(() {
        _provinceProgress[p.code] = exist / total;
      });
      // Pequeña pausa para evitar saturar IO
      await Future.delayed(const Duration(milliseconds: 50));
    }
    setState(() { _loadingProvinceProgress = false; });
  }

  Widget _buildActionButtons() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha((0.08 * 255).round()),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _selectAllProvinces,
              style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
              ),
              child: const Text('Seleccionar Todo'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _clearSelection,
              style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
              ),
              child: const Text('Limpiar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _selectedProvinces.isEmpty || _isDownloading ? null : _startDownload,
              style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              child: _isDownloading 
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                    ),
                  )
                : const Text('Descargar'),
            ),
          ),
        ],
      ),
      
      // Checkbox para forzar re-descarga
      if (_selectedProvinces.isNotEmpty && !_isDownloading)
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            children: [
              Checkbox(
                value: _forceRedownload,
                onChanged: (bool? value) {
                  setState(() {
                    _forceRedownload = value ?? false;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Forzar re-descarga (incluso si ya existe)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.85 * 255).round()),
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  void _toggleProvince(String provinceCode, bool selected) {
    setState(() {
      if (selected) {
        _selectedProvinces.add(provinceCode);
      } else {
        _selectedProvinces.remove(provinceCode);
      }
    });
  }

  void _toggleRegion(List<ArgentinaProvince> provinces, bool? selected) {
    setState(() {
      if (selected == true) {
        // Seleccionar toda la región
        for (final province in provinces) {
          _selectedProvinces.add(province.code);
        }
      } else {
        // Deseleccionar toda la región
        for (final province in provinces) {
          _selectedProvinces.remove(province.code);
        }
      }
    });
  }

  void _selectAllProvinces() {
    setState(() {
      _selectedProvinces.clear();
      _selectedProvinces.addAll(
        ArgentinaRegions.provinces.map((province) => province.code),
      );
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProvinces.clear();
    });
  }

  Future<void> _startDownload() async {
    if (_selectedProvinces.isEmpty) return;

    if (kDebugMode) debugPrint('CICLE-UI: _startDownload invoked selected=${_selectedProvinces.length} force=$_forceRedownload');

    // Asegurar que el servicio de cache esté inicializado (DB, directorios)
    try {
      await _mapCacheService.initialize();
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inicializando servicio de mapas: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final selectedProvincesData = ArgentinaRegions.provinces
          .where((province) => _selectedProvinces.contains(province.code))
          .toList();

    if (kDebugMode) debugPrint('CICLE-UI: selectedProvincesData length=${selectedProvincesData.length}');

      // Calcular total real usando el servicio de cache para obtener conteos por zoom
      // (usamos los mismos zooms que usará la descarga: 8..15)
      final boundsMinLat = selectedProvincesData.map((p) => p.minLat).reduce((a, b) => a < b ? a : b);
      final boundsMaxLat = selectedProvincesData.map((p) => p.maxLat).reduce((a, b) => a > b ? a : b);
      final boundsMinLng = selectedProvincesData.map((p) => p.minLng).reduce((a, b) => a < b ? a : b);
      final boundsMaxLng = selectedProvincesData.map((p) => p.maxLng).reduce((a, b) => a > b ? a : b);

      final counts = _mapCacheService.getTileCountsForRegion(
        boundsMinLat,
        boundsMaxLat,
        boundsMinLng,
        boundsMaxLng,
        minZoom: 10,
  maxZoom: 14,
      );

  if (kDebugMode) debugPrint('CICLE-UI: estimatedTiles for selection=${counts['total']}');

      final estimatedTiles = counts['total'] as int;
      // Contador asíncrono para saber cuántos tiles ya existen en caché
      // Lanzar conteo de existing en background para no bloquear la UI
      Future<int> existingCountFuture = _mapCacheService.countExistingTilesForRegion(
        boundsMinLat,
        boundsMaxLat,
        boundsMinLng,
        boundsMaxLng,
        minZoom: 10,
  maxZoom: 14,
      ).then((m) => m['existing'] as int).catchError((e) {
        if (kDebugMode) debugPrint('Error contando tiles existentes: $e');
        return 0;
      });

  const int largeThreshold = 10000; // umbral para advertir
      bool dialogForceDownload = false;
      if (estimatedTiles > largeThreshold) {
        if (kDebugMode) debugPrint('CICLE-UI: large download dialog triggered estimated=$estimatedTiles');
        // Mostrar diálogo inmediatamente y actualizarlo cuando termine el conteo (no bloqueante)
        final bool? downloadOnlyMissing = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
            bool _downloadOnlyMissingLocal = true;

            return AlertDialog(
              title: const Text('Descarga muy grande'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total tiles en la selección: $estimatedTiles'),
                  const SizedBox(height: 6),
                  // Usar FutureBuilder para evitar llamar setState sobre un StatefulBuilder ya disposado
                  FutureBuilder<int>(
                    future: existingCountFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(children: [const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)), const SizedBox(width:8), const Text('Calculando cuántos ya están en caché...')]);
                      }

                      final int displayedExisting = snapshot.hasData ? snapshot.data! : 0;
                      final int displayedMissing = estimatedTiles - displayedExisting;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ya en caché: $displayedExisting'),
                          Text('Faltantes a descargar: $displayedMissing'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _downloadOnlyMissingLocal,
                        onChanged: (v) => setStateDialog(() => _downloadOnlyMissingLocal = v ?? true),
                      ),
                      const Expanded(child: Text('Descargar solo los tiles faltantes (recomendado)')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Esto puede tardar mucho y consumir espacio.'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.pop(context, _downloadOnlyMissingLocal), child: const Text('Continuar')),
              ],
            );
          }),
        );

        if (!mounted) return;

        if (downloadOnlyMissing == null) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0.0;
          });
          return;
        }

        // Si el usuario eligió descargar solo faltantes, no forzamos; de lo contrario forzamos re-descarga
        dialogForceDownload = !(downloadOnlyMissing);
      }

      // Determinar el flag final para forzar re-descarga: si el usuario marcó el checkbox global o via diálogo
      final bool forceForAll = _forceRedownload || dialogForceDownload;

      int completedProvinces = 0;
      final totalProvinces = selectedProvincesData.length;

      for (final province in selectedProvincesData) {
        // Verificar si el usuario canceló la descarga (usar flag local)
        if (!_isDownloading) {
          break;
        }
        debugPrint('CICLE-UI: Starting download for province: ${province.name} (${province.code})');
        setState(() {
          _currentProvince = province.name;
          _downloadProgress = completedProvinces / totalProvinces;
        });

        // Log del total estimado de tiles para esta provincia (diagnóstico)
        final provinceTilesEstimate = province.estimatedTileCount;
        debugPrint('Province ${province.name} estimated tiles: $provinceTilesEstimate');

        // Reset counters para esta provincia
        _currentProvinceTilesDownloaded = 0;
        _currentProvinceTilesTotal = 0;

          try {
          // Verificar si la provincia ya está completa
          // Usar el mismo rango de zoom que usaremos para descargar (10..14)
          final isComplete = await _mapCacheService.isRegionComplete(
            province.minLat,
            province.maxLat,
            province.minLng,
            province.maxLng,
            minZoom: 10,
            maxZoom: 14,
          );

          if (kDebugMode) debugPrint('CICLE-UI: isRegionComplete(${province.name}) => $isComplete');

          if (isComplete && !forceForAll) {
            if (kDebugMode) debugPrint('${province.name} ya está descargada completamente');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${province.name} ya está descargada (salteando)'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            // Actualizar progreso visual inmediatamente para no quedar en 0
            if (mounted) {
              setState(() {
                _currentProvinceTilesDownloaded = 1;
                _currentProvinceTilesTotal = 1;
                final provinceProgress = 1.0;
                _downloadProgress = (completedProvinces + provinceProgress) / totalProvinces;
              });
            }
          } else {
            if (isComplete && _forceRedownload) {
              if (kDebugMode) debugPrint('Re-descargando ${province.name} por solicitud del usuario');
            }
            // Crear/obtener un MapArea persistente para esta provincia y usar su id
            if (kDebugMode) debugPrint('CICLE-UI: creating MapArea for ${province.name}');
            final area = await _mapCacheService.createArea(
              name: province.name,
              northEast: LatLng(province.maxLat, province.maxLng),
              southWest: LatLng(province.minLat, province.minLng),
              minZoom: 10,
              maxZoom: 14,
            );

            if (kDebugMode) debugPrint('CICLE-UI: created area id=${area.id} for ${province.name}');

            // Descargar tiles para esta provincia usando el areaId persistente
            if (kDebugMode) debugPrint('CICLE-UI: calling downloadRegion for ${province.name} areaId=${area.id}');
            await _mapCacheService.downloadRegion(
              province.minLat,
              province.maxLat,
              province.minLng,
              province.maxLng,
              areaId: area.id,
              minZoom: 10,
              maxZoom: 14,
              forceDownload: forceForAll,
              onProgress: (processed, total, newDownloaded) {
                  // Debug: registrar progreso en logs para verificar llamadas
                  debugPrint('CICLE-PROV: province ${province.name} onProgress processed=$processed total=$total new=$newDownloaded');
                  if (mounted) {
                    setState(() {
                      _currentProvinceTilesDownloaded = processed;
                      _currentProvinceTilesTotal = total;
                      final provinceProgress = total > 0 ? (processed / total) : 0.0;
                      _downloadProgress = (completedProvinces + provinceProgress) / totalProvinces;
                    });
                  }
                },
            );
            // Tras una descarga exitosa de la provincia, limitar la sesión al maxZoom del area creada
            // 'area' está en alcance aquí porque fue creado arriba en este bloque.
            _mapCacheService.setSessionMaxZoom(area.maxZoom);
            if (kDebugMode) debugPrint('CICLE-UI: session max zoom set to ${area.maxZoom} for ${province.name}');
          }
          
          completedProvinces++;
          if (kDebugMode) debugPrint('Completed province: ${province.name}');
        } catch (e) {
          if (kDebugMode) debugPrint('Error descargando provincia ${province.name}: $e');
          // Mostrar error pero continuar con la siguiente provincia
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error descargando ${province.name}: $e. Continuando...'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          completedProvinces++; // Contar como completada para continuar
        }
      }

      setState(() {
        _downloadProgress = 1.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Descarga completada: ${selectedProvincesData.length} provincias'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la descarga: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _currentProvince = '';
        _downloadProgress = 0.0;
      });
    }
  }

  void _cancelDownload() {
    _mapCacheService.cancelDownload();
    setState(() {
      _isDownloading = false;
      _currentProvince = 'Cancelado';
      _downloadProgress = 0.0;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Descarga cancelada por el usuario'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }
}
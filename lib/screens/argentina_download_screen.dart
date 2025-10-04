import 'package:flutter/material.dart';
import '../models/argentina_regions.dart';
import '../services/map_cache_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargar Mapas de Argentina'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Información de descarga
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descarga Completa de Argentina',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
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
        Text(
          'Total Argentina: ${allTotals['tiles']} tiles (~${(allTotals['sizeMB'] as double).toStringAsFixed(0)} MB)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.blue[50],
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
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(_downloadProgress * 100).toStringAsFixed(1)}% completado'),
              Text(
                '${_selectedProvinces.length} ${_selectedProvinces.length == 1 ? "provincia" : "provincias"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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
                  color: regionPartiallySelected ? Colors.green[700] : null,
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
    
    return CheckboxListTile(
      title: Text(province.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${province.estimatedTileCount.toString()} tiles • ${province.estimatedSizeMB.toStringAsFixed(1)} MB'),
          Text(
            'Área: ${province.areaKm2.toStringAsFixed(0)} km²',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      value: isSelected,
      onChanged: _isDownloading ? null : (value) => _toggleProvince(province.code, value ?? false),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
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
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Seleccionar Todo'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _clearSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
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
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isDownloading 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    color: Colors.grey[700],
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

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final selectedProvincesData = ArgentinaRegions.provinces
          .where((province) => _selectedProvinces.contains(province.code))
          .toList();

      int completedProvinces = 0;
      final totalProvinces = selectedProvincesData.length;

      for (final province in selectedProvincesData) {
        // Verificar si el usuario canceló la descarga
        if (!_mapCacheService.isDownloading) {
          break;
        }
        
        setState(() {
          _currentProvince = province.name;
          _downloadProgress = completedProvinces / totalProvinces;
        });

        try {
          // Verificar si la provincia ya está completa
          final isComplete = await _mapCacheService.isRegionComplete(
            province.minLat,
            province.maxLat,
            province.minLng,
            province.maxLng,
            minZoom: 8,
            maxZoom: 15,
          );

          if (isComplete && !_forceRedownload) {
            print('${province.name} ya está descargada completamente');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${province.name} ya está descargada (salteando)'),
                  backgroundColor: Colors.blue[600],
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          } else {
            if (isComplete && _forceRedownload) {
              print('Re-descargando ${province.name} por solicitud del usuario');
            }
            // Descargar tiles para esta provincia
            await _mapCacheService.downloadRegion(
              province.minLat,
              province.maxLat,
              province.minLng,
              province.maxLng,
              minZoom: 8,
              maxZoom: 15,
              onProgress: (downloaded, total) {
                if (mounted) {
                  setState(() {
                    final provinceProgress = downloaded / total;
                    _downloadProgress = (completedProvinces + provinceProgress) / totalProvinces;
                  });
                }
              },
            );
          }
          
          completedProvinces++;
        } catch (e) {
          print('Error descargando provincia ${province.name}: $e');
          // Mostrar error pero continuar con la siguiente provincia
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error descargando ${province.name}. Continuando...'),
                backgroundColor: Colors.orange,
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
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la descarga: $e'),
            backgroundColor: Colors.red[600],
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
        const SnackBar(
          content: Text('Descarga cancelada por el usuario'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
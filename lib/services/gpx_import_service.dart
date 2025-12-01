import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import '../models/imported_route.dart';

class GpxImportService {
  Future<File?> pickGpxFile() async {
    final typeGroup = XTypeGroup(
      label: 'gpx',
      mimeTypes: ['application/gpx+xml'],
      extensions: ['gpx'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty) return null;
    final file = files.first;
    return File(file.path);
  }

  Future<ImportedRoute?> parseGpxFile(File file) async {
    final xml = await file.readAsString();
    final reader = GpxReader();
    final gpx = reader.fromString(xml);
    final points = <LatLng>[];

    // Collect track points
    for (final trk in gpx.trks) {
      for (final seg in trk.trksegs) {
        for (final p in seg.trkpts) {
          if (p.lat != null && p.lon != null) {
            points.add(LatLng(p.lat!, p.lon!));
          }
        }
      }
    }

    // If no track points, try route points
    if (points.isEmpty) {
      for (final rte in gpx.rtes) {
        for (final p in rte.rtepts) {
          if (p.lat != null && p.lon != null) {
            points.add(LatLng(p.lat!, p.lon!));
          }
        }
      }
    }

    if (points.isEmpty) return null;

    final distanceKm = _calcDistanceKm(points);

    // gpx package may store metadata differently; try common fields
    String? name;
    String? desc;
    try {
      name = gpx.metadata?.name ?? gpx.trks.first.name;
    } catch (_) {}
    try {
      desc = gpx.metadata?.desc ?? gpx.trks.first.desc;
    } catch (_) {}

    return ImportedRoute(
      name: name ?? file.uri.pathSegments.last,
      description: desc,
      gpxText: xml,
      points: points,
      distanceKm: distanceKm,
    );
  }

  double _calcDistanceKm(List<LatLng> points) {
    final Distance distance = Distance();
    double meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters / 1000.0;
  }
}

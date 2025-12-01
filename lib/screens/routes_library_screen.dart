import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/imported_route.dart';
import '../controllers/tracking_controller.dart';
import 'package:provider/provider.dart';

class RoutesLibraryScreen extends StatefulWidget {
  const RoutesLibraryScreen({super.key});

  @override
  State<RoutesLibraryScreen> createState() => _RoutesLibraryScreenState();
}

class _RoutesLibraryScreenState extends State<RoutesLibraryScreen> {
  final DatabaseService _db = DatabaseService();
  List<ImportedRoute> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getAllImportedRoutes();
    setState(() {
      _routes = list;
      _loading = false;
    });
  }

  Future<void> _delete(int id) async {
    await _db.deleteImportedRoute(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<TrackingController>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas guardadas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (_, i) {
                final r = _routes[i];
                return ListTile(
                  title: Text(r.name ?? 'Sin nombre'),
                  subtitle: Text('${r.distanceKm.toStringAsFixed(2)} km'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          controller.loadImportedRoute(r.points);
                          Navigator.of(context).pop();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _delete(r.id!),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

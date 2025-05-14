// lib/pages/overview_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/database_service.dart';
import '../models/brain_entry.dart';
import 'alarmes_ativos_page.dart';
import 'device_details_page.dart';

/// Modelo de dados para visão geral de um dispositivo
class DeviceOverviewData {
  final String deviceId;
  final String cliente;
  final double? latitude;
  final double? longitude;
  final String lastUpdate;
  final bool alarmActive;
  final double batteryVoltage;

  DeviceOverviewData({
    required this.deviceId,
    required this.cliente,
    this.latitude,
    this.longitude,
    required this.lastUpdate,
    required this.alarmActive,
    required this.batteryVoltage,
  });
}

/// Visão geral de todos os dispositivos com mapa e tabela expansível
class OverviewPage extends StatefulWidget {
  const OverviewPage({Key? key}) : super(key: key);

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final DatabaseService _db;
  final List<String> _deviceIds = [];
  final Map<String, DeviceOverviewData> _dataMap = {};
  bool _loading = true;
  bool _hasAlarm = false;
  String? _errorMessage;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _db = DatabaseService.forUserDevices(uid);
    _loadAll(uid);
  }

  Future<DeviceOverviewData> _fetchData(String uid, String id) async {
    // Busca informações estáticas
    final infoMap = await _db.getDeviceInfo(id) as Map<String, dynamic>? ?? {};
    final cliente = infoMap['cliente']?.toString() ?? '';

    // Inicializa variáveis de log
    DateTime? dt;
    double? lat;
    double? lng;
    bool hasAlarm = false;
    double vb = 0;
    try {
      // Busca último log
      final logs = await DatabaseService.forDevice(uid, id).fetchRecentLogs(1);
      if (logs.isNotEmpty) {
        final entry = logs.first;
        dt = entry.timestamp;
        lat = entry.data.latitude;
        lng = entry.data.longitude;
        hasAlarm = entry.data.alarmes.values.any((v) => v);
        vb = entry.data.vBateria;
      }
    } catch (_) {}

    // Formata data
    String lastUpdate = '';
    if (dt != null) {
      lastUpdate =
          '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:''${dt.minute.toString().padLeft(2, '0')}';
    }

    return DeviceOverviewData(
      deviceId: id,
      cliente: cliente,
      latitude: lat,
      longitude: lng,
      lastUpdate: lastUpdate,
      alarmActive: hasAlarm,
      batteryVoltage: vb,
    );
  }

  Future<void> _loadAll(String uid) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _hasAlarm = false;
    });
    try {
      final ids = await _db.permittedDeviceIds();
      final results = await Future.wait(ids.map((id) => _fetchData(uid, id)));
      _dataMap.clear();
      _deviceIds.clear();
      for (var data in results) {
        _dataMap[data.deviceId] = data;
        _deviceIds.add(data.deviceId);
        if (data.alarmActive) _hasAlarm = true;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Erro ao carregar dados: \$e';
      });
    }
  }

  /// Ajusta câmera para exibir todos os marcadores
  void _fitMarkers() {
    if (_dataMap.isEmpty || _mapController == null) return;
    final coords = _dataMap.values
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) => LatLng(d.latitude!, d.longitude!));
    if (coords.isEmpty) return;
    double minLat = coords.first.latitude;
    double maxLat = coords.first.latitude;
    double minLng = coords.first.longitude;
    double maxLng = coords.first.longitude;
    for (var c in coords) {
      minLat = c.latitude < minLat ? c.latitude : minLat;
      maxLat = c.latitude > maxLat ? c.latitude : maxLat;
      minLng = c.longitude < minLng ? c.longitude : minLng;
      maxLng = c.longitude > maxLng ? c.longitude : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  Widget build(BuildContext context) {
    // Cria marcadores
    final initial = const LatLng(0, 0);
    final markers = _dataMap.values
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) => Marker(
              markerId: MarkerId(d.deviceId),
              position: LatLng(d.latitude!, d.longitude!),
              infoWindow: InfoWindow(
                title: d.deviceId,
                snippet: 'Cliente: ${d.cliente}\nÚltima: ${d.lastUpdate}',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DeviceDetailsPage(deviceId: d.deviceId))),
              ),
            ))
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral'),
        actions: [
          IconButton(
            icon: Icon(Icons.warning, color: _hasAlarm ? Colors.red : Colors.white),
            onPressed: _hasAlarm
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AlarmesAtivosPage()),
                    )
                : null,
          )
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 400,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 1),
              markers: markers,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                _fitMarkers();
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          ExpansionTile(
            title: const Text('Detalhes dos Dispositivos'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Última Atualização')),
                    DataColumn(label: Text('Tensão (VB)')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _deviceIds.map((id) {
                    final d = _dataMap[id]!;
                    return DataRow(cells: [
                      DataCell(Text(d.deviceId)),
                      DataCell(Text(d.cliente)),
                      DataCell(Text(d.lastUpdate)),
                      DataCell(Text('${d.batteryVoltage} V')),
                      DataCell(Icon(
                        d.alarmActive ? Icons.error : Icons.check,
                        color: d.alarmActive ? Colors.red : Colors.green,
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

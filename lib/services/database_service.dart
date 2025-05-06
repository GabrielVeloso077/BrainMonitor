// lib/services/database_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/brain_data.dart';
import '../models/brain_entry.dart';

class DatabaseService {
  final String _uid;
  final String? _deviceId;
  final DatabaseReference _baseRef;

  DatabaseService._(this._uid, [this._deviceId])
    : _baseRef =
          FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://piloto-minas-laser.firebaseio.com',
          ).ref();

  /// Cria instância para listar dispositivos que o usuário pode acessar
  factory DatabaseService.forUserDevices(String uid) =>
      DatabaseService._(uid, null);

  /// Cria instância para operar sobre um dispositivo específico
  factory DatabaseService.forDevice(String uid, String deviceId) =>
      DatabaseService._(uid, deviceId);

  /// Caminho users/{uid}/devices → lista de deviceIds
  Future<List<String>> permittedDeviceIds() async {
    final snap = await _baseRef.child('users/$_uid/devices').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.keys.toList();
  }

  /// Referência para logs do device
  DatabaseReference get logsRef {
    if (_deviceId == null) {
      throw StateError('Use forDevice antes de chamar logsRef');
    }
    return _baseRef.child('dispositivos/$_deviceId/logs');
  }

  /// Stream do último entry do device
  Stream<BrainEntry> get entryStream {
    return logsRef.orderByKey().limitToLast(1).onValue.map((event) {
      final logs = event.snapshot.value as Map<dynamic, dynamic>?;
      if (logs == null || logs.isEmpty) {
        throw StateError('No logs for device $_deviceId');
      }
      final e = logs.entries.first;
      final dt = DateTime.parse(e.key.replaceFirst('_', 'T'));
      final general = (e.value as Map)['general'] as Map;
      return BrainEntry(timestamp: dt, data: BrainData.fromMap(general));
    });
  }

  /// Stream que lê o nó /dispositivos/{deviceId}/info
  Stream<Map<String, dynamic>> get infoStream {
    if (_deviceId == null) {
      throw StateError('Use forDevice antes de chamar infoStream');
    }
    return _baseRef
        .child('dispositivos/$_deviceId/info')
        .onValue
        .map((e) => Map<String, dynamic>.from(e.snapshot.value as Map));
  }

  /// Busca todos os logs (HistoryPage)
  Future<List<BrainEntry>> fetchAllLogs() async {
    final snap = await logsRef.orderByKey().get();
    final list =
        snap.children.map((s) {
            final dt = DateTime.parse(s.key!.replaceFirst('_', 'T'));
            final gen = (s.value as Map)['general'] as Map;
            return BrainEntry(timestamp: dt, data: BrainData.fromMap(gen));
          }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Busca últimos N logs (GraphsPage)
  Future<List<BrainEntry>> fetchRecentLogs(int count) async {
    final snap = await logsRef.orderByKey().limitToLast(count).get();
    final list =
        snap.children.map((s) {
            final dt = DateTime.parse(s.key!.replaceFirst('_', 'T'));
            final gen = (s.value as Map)['general'] as Map;
            return BrainEntry(timestamp: dt, data: BrainData.fromMap(gen));
          }).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }
}

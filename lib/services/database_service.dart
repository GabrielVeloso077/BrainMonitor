// lib/services/database_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/brain_data.dart';
import '../models/brain_entry.dart';
import '../models/models.dart';

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

  /// Para operações de usuários (sem deviceId)
  factory DatabaseService.forUserDevices(String uid) =>
      DatabaseService._(uid, null);

  /// Para um dispositivo específico
  factory DatabaseService.forDevice(String uid, String deviceId) =>
      DatabaseService._(uid, deviceId);

  // ==================== CLIENTES CRUD ====================

  Future<List<Cliente>> listClientes() async {
    final snap = await _baseRef.child('clientes').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.entries
        .map(
          (e) =>
              Cliente.fromMap(e.key, (e.value as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<Cliente> getCliente(String clienteId) async {
    final snap = await _baseRef.child('clientes/$clienteId').get();
    final map = (snap.value as Map).cast<String, dynamic>();
    return Cliente.fromMap(clienteId, map);
  }

  Future<void> createCliente(Cliente cliente) async {
    await _baseRef.child('clientes/${cliente.id}').set(cliente.toMap());
  }

  Future<void> updateCliente(Cliente cliente) async {
    await _baseRef.child('clientes/${cliente.id}').update(cliente.toMap());
  }

  Future<void> deleteCliente(String clienteId) async {
    await _baseRef.child('clientes/$clienteId').remove();
  }

  // ==================== USUÁRIOS CRUD ====================

  /// Lista usuários, opcionalmente filtrando por cliente
  Future<List<Usuario>> listUsuarios({String? clienteId}) async {
    final snap = await _baseRef.child('users').get();
    final uids =
        (snap.value as Map?)?.cast<String, dynamic>().keys.toList() ?? [];
    final users = <Usuario>[];
    for (var uid in uids) {
      users.add(await getUsuario(uid));
    }
    if (clienteId != null) {
      return users.where((u) => u.clienteId == clienteId).toList();
    }
    return users;
  }

  /// Lê usuário de acordo com estrutura antiga (/regsiter e /devices)
  Future<Usuario> getUsuario(String uid) async {
    final regSnap = await _baseRef.child('users/$uid/regsiter').get();
    final regMap = (regSnap.value as Map?)?.cast<String, dynamic>() ?? {};
    final devSnap = await _baseRef.child('users/$uid/devices').get();
    final devMap = (devSnap.value as Map?)?.cast<String, dynamic>() ?? {};

    // PerfilId a partir de 'class'
    final classVal = regMap['class'];
    int perfilId;
    if (classVal is int) {
      perfilId = classVal;
    } else if (classVal is String && int.tryParse(classVal) != null) {
      perfilId = int.parse(classVal);
    } else {
      final str = classVal?.toString().toLowerCase() ?? '';
      final idx = PerfilTipo.values.indexWhere(
        (e) => e.toString().split('.').last.toLowerCase() == str,
      );
      perfilId = idx != -1 ? idx + 1 : PerfilTipo.usuarioComum.id;
    }
    late PerfilTipo perfilTipo;
    try {
      perfilTipo = PerfilTipoExtension.fromId(perfilId);
    } catch (_) {
      perfilTipo = PerfilTipo.usuarioComum;
    }

    return Usuario(
      id: uid,
      name: regMap['name'] as String? ?? '',
      email: regMap['Email'] as String? ?? '',
      perfil: perfilTipo,
      clienteId: regMap['company']?.toString(),
      dispositivosPermitidos:
          devMap.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList(),
    );
  }

  /// Cria novo usuário em /users/{uid}/regsiter e /users/{uid}/devices
  Future<void> createUsuario(Usuario usuario) async {
    final regMap = {
      'name': usuario.name,
      'Email': usuario.email,
      'class': usuario.perfil.id,
      if (usuario.clienteId != null) 'company': usuario.clienteId!,
    };
    final devicesMap = {for (var d in usuario.dispositivosPermitidos) d: true};
    await _baseRef.child('users/${usuario.id}/regsiter').set(regMap);
    await _baseRef.child('users/${usuario.id}/devices').set(devicesMap);
  }

  /// Atualiza usuário em /users/{uid}/regsiter e /users/{uid}/devices
  Future<void> updateUsuario(Usuario usuario) async {
    final regMap = {
      'name': usuario.name,
      'Email': usuario.email,
      'class': usuario.perfil.id,
      if (usuario.clienteId != null) 'company': usuario.clienteId!,
    };
    final devicesMap = {for (var d in usuario.dispositivosPermitidos) d: true};
    await _baseRef.child('users/${usuario.id}/regsiter').update(regMap);
    await _baseRef.child('users/${usuario.id}/devices').set(devicesMap);
  }

  /// Remove usuário inteiro em /users/{uid}
  Future<void> deleteUsuario(String uid) async {
    await _baseRef.child('users/$uid').remove();
  }

  // ==================== DISPOSITIVOS & LOGS ====================

  Future<List<String>> permittedDeviceIds() async {
    final snap = await _baseRef.child('users/$_uid/devices').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.keys.toList();
  }

  Future<List<String>> listAllDeviceIds() async {
    final snap = await _baseRef.child('dispositivos').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.keys.cast<String>().toList();
  }

  Future<Map<String, dynamic>?> getDeviceInfo(String deviceId) async {
    final snap = await _baseRef.child('dispositivos/$deviceId/info').get();
    return (snap.value as Map?)?.cast<String, dynamic>();
  }

  Future<void> setDeviceInfo(String deviceId, Map<String, dynamic> info) async {
    await _baseRef.child('dispositivos/$deviceId/info').set(info);
  }

  DatabaseReference get logsRef {
    if (_deviceId == null) throw StateError('Use forDevice antes');
    return _baseRef.child('dispositivos/$_deviceId/logs');
  }

  Stream<BrainEntry> get entryStream =>
      logsRef.orderByKey().limitToLast(1).onValue.map((event) {
        final logs = event.snapshot.value as Map<dynamic, dynamic>?;
        if (logs == null || logs.isEmpty) {
          throw StateError('No logs for device $_deviceId');
        }
        final e = logs.entries.first;
        final dt = DateTime.parse(e.key.replaceFirst('_', 'T'));
        final general = (e.value as Map)['general'] as Map;
        return BrainEntry(timestamp: dt, data: BrainData.fromMap(general));
      });

  Stream<Map<String, dynamic>> get infoStream {
    if (_deviceId == null) throw StateError('Use forDevice antes');
    return _baseRef
        .child('dispositivos/$_deviceId/info')
        .onValue
        .map((e) => Map<String, dynamic>.from(e.snapshot.value as Map));
  }

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

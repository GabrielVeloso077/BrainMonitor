// lib/services/database_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/brain_data.dart';
import '../models/brain_entry.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

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

  /// Instância para operações de usuário (sem deviceId)
  factory DatabaseService.forUserDevices(String uid) =>
      DatabaseService._(uid, null);

  /// Instância para operações de dispositivo específico
  factory DatabaseService.forDevice(String uid, String deviceId) =>
      DatabaseService._(uid, deviceId);

  // ==================== CLIENTES CRUD ====================

  Future<List<Cliente>> listClientes() async {
    final snap = await _baseRef.child('clientes').get();
    print('>>> listClientes snapshot.value = ${snap.value}');
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

  /// Lista usuários, carregando dados de cada subnó 'regsiter' e 'devices'
  Future<List<Usuario>> listUsuarios({String? clienteId}) async {
    final snap = await _baseRef.child('users').get();
    final uids =
        (snap.value as Map?)?.cast<String, dynamic>().keys.toList() ?? [];
    final users = <Usuario>[];
    for (var uid in uids) {
      final u = await getUsuario(uid);
      users.add(u);
    }
    if (clienteId != null) {
      return users.where((u) => u.clienteId == clienteId).toList();
    }
    return users;
  }

  /// Busca usuário a partir da estrutura antiga (/users/{uid}/regsiter e /users/{uid}/devices)
  Future<Usuario> getUsuario(String uid) async {
    final regSnap = await _baseRef.child('users/$uid/regsiter').get();
    final regMap = (regSnap.value as Map?)?.cast<String, dynamic>() ?? {};
    final devSnap = await _baseRef.child('users/$uid/devices').get();
    final devMap = (devSnap.value as Map?)?.cast<String, dynamic>() ?? {};

    // Determina perfilId a partir do campo 'class'
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

    // Converte para PerfilTipo, default para usuarioComum se inválido
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
      clienteId: regMap['company'] as String?,
      dispositivosPermitidos:
          devMap.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList(),
    );
    (
      id: uid,
      name: regMap['name'] as String? ?? '',
      email: regMap['Email'] as String? ?? '',
      perfil: PerfilTipoExtension.fromId(perfilId),
      clienteId: regMap['company'] as String?,
      dispositivosPermitidos:
          devMap.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList(),
    );
  }

  /// Cria novo usuário
  Future<void> createUsuario(Usuario usuario) async {
    await _baseRef.child('users/${usuario.id}').set(usuario.toMap());
  }

  /// Atualiza usuário existente
  Future<void> updateUsuario(Usuario usuario) async {
    await _baseRef.child('users/${usuario.id}').update(usuario.toMap());
  }

  /// Remove usuário
  Future<void> deleteUsuario(String uid) async {
    await _baseRef.child('users/$uid').remove();
  }

  // ==================== DISPOSITIVOS ====================

  /// Dispositivos permitidos para o usuário atual
  Future<List<String>> permittedDeviceIds() async {
    final snap = await _baseRef.child('users/$_uid/devices').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.keys.toList();
  }

  /// Lista todos dispositivos no sistema
  Future<List<String>> listAllDeviceIds() async {
    final snap = await _baseRef.child('dispositivos').get();
    final map = (snap.value as Map?)?.cast<String, dynamic>() ?? {};
    return map.keys.toList();
  }

  // ==================== LOGS ====================

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

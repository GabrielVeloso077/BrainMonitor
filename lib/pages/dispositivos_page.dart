// lib/pages/dispositivos_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class DispositivosPage extends StatefulWidget {
  const DispositivosPage({Key? key}) : super(key: key);

  @override
  State<DispositivosPage> createState() => _DispositivosPageState();
}

class _DispositivosPageState extends State<DispositivosPage> {
  late final DatabaseService _db;
  List<String> _deviceIds = [];
  bool _loading = true;
  String? _errorMessage;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Usuário não autenticado';
      });
    } else {
      _db = DatabaseService.forUserDevices(uid);
      _initialize(uid);
    }
  }

  Future<void> _initialize(String uid) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final user = await _db.getUsuario(uid);
      _isAllowed =
          user.perfil == PerfilTipo.admin ||
          user.perfil == PerfilTipo.representante;
      _deviceIds = await _db.listAllDeviceIds();
    } catch (e, stack) {
      debugPrint('Erro DispositivosPage: $e');
      debugPrintStack(stackTrace: stack);
      setState(() {
        _errorMessage = 'Erro ao carregar: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onAdd() {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/dispositivoForm').then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  void _onEdit(String id) {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/dispositivoForm', arguments: id).then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      body: Builder(
        builder: (_) {
          if (_loading) return const Center(child: CircularProgressIndicator());
          if (_errorMessage != null)
            return Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          return ListView.builder(
            itemCount: _deviceIds.length,
            itemBuilder: (ctx, i) {
              final id = _deviceIds[i];
              return ListTile(
                title: Text('Dispositivo $id'),
                trailing:
                    _isAllowed
                        ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _onEdit(id),
                        )
                        : null,
              );
            },
          );
        },
      ),
      floatingActionButton:
          _isAllowed
              ? FloatingActionButton(
                onPressed: _onAdd,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

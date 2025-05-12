// lib/pages/usuarios_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({Key? key}) : super(key: key);

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late final DatabaseService _db;
  List<Usuario> _usuarios = [];
  Map<String, Cliente> _clientesMap = {};
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
      final currentUser = await _db.getUsuario(uid);
      _isAllowed =
          currentUser.perfil == PerfilTipo.admin ||
          currentUser.perfil == PerfilTipo.moderador;
      final usuarios = await _db.listUsuarios();
      final clientes = await _db.listClientes();
      _usuarios = usuarios;
      _clientesMap = {for (var c in clientes) c.id: c};
    } catch (e, stack) {
      debugPrint('❌ Erro ao inicializar UsuariosPage: $e');
      debugPrintStack(stackTrace: stack);
      setState(() {
        _errorMessage = 'Erro ao inicializar: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onAddUsuario() {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/usuarioForm').then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  void _onEditUsuario(Usuario u) {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/usuarioForm', arguments: u).then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  Future<void> _onDeleteUsuario(Usuario u) async {
    if (!_isAllowed) return;
    try {
      await _db.deleteUsuario(u.id);
      setState(() => _usuarios.remove(u));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir usuário: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      _initialize(uid);
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          if (_usuarios.isEmpty) {
            return Center(
              child: Text(
                'Nenhum usuário encontrado',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await _initialize(uid);
            },
            child: ListView.builder(
              itemCount: _usuarios.length,
              itemBuilder: (context, index) {
                final u = _usuarios[index];
                final perfilName = u.perfil.toString().split('.').last;
                final cliente =
                    u.clienteId != null ? _clientesMap[u.clienteId!] : null;
                final clienteText =
                    cliente != null ? cliente.nome : (u.clienteId ?? '—');
                return ListTile(
                  title: Text(u.name),
                  subtitle: Text(
                    '${u.email} • Perfil: $perfilName • Cliente: $clienteText',
                  ),
                  trailing:
                      _isAllowed
                          ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _onEditUsuario(u);
                              if (value == 'delete') _onDeleteUsuario(u);
                            },
                            itemBuilder:
                                (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Excluir'),
                                  ),
                                ],
                          )
                          : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton:
          _isAllowed
              ? FloatingActionButton(
                onPressed: _onAddUsuario,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

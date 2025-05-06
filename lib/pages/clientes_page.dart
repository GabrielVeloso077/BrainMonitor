// lib/pages/clientes_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({Key? key}) : super(key: key);

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  late final DatabaseService _db;
  List<Cliente> _clientes = [];
  Map<String, Usuario> _usersMap = {};
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
      // Verifica o perfil do usuário para permissões
      final currentUser = await _db.getUsuario(uid);
      _isAllowed =
          currentUser.perfil == PerfilTipo.admin ||
          currentUser.perfil == PerfilTipo.moderador;

      // Carrega todos usuários para lookup de representantes
      final allUsers = await _db.listUsuarios();
      _usersMap = {for (var u in allUsers) u.id: u};

      // Carrega clientes
      _clientes = await _db.listClientes();
    } catch (e, stack) {
      debugPrint('❌ Erro ao inicializar ClientesPage: $e');
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

  void _onAddCliente() {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/clienteForm').then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  void _onEditCliente(Cliente cliente) {
    if (!_isAllowed) return;
    Navigator.pushNamed(context, '/clienteForm', arguments: cliente).then((_) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      _initialize(uid);
    });
  }

  Future<void> _onDeleteCliente(Cliente cliente) async {
    if (!_isAllowed) return;
    try {
      await _db.deleteCliente(cliente.id);
      setState(() => _clientes.remove(cliente));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir cliente: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
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
          if (_clientes.isEmpty) {
            return Center(
              child: Text(
                'Nenhum cliente encontrado',
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
              itemCount: _clientes.length,
              itemBuilder: (context, index) {
                final c = _clientes[index];
                final rep = _usersMap[c.representanteId];
                final repText =
                    rep != null
                        ? '${rep.name} (${rep.email})'
                        : c.representanteId;
                return ListTile(
                  title: Text(c.nome),
                  subtitle: Text('Representante: $repText'),
                  trailing:
                      _isAllowed
                          ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _onEditCliente(c);
                              if (value == 'delete') _onDeleteCliente(c);
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
                onPressed: _onAddCliente,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

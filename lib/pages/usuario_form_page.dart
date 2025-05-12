// lib/pages/usuario_form_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ← aqui
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class UsuarioFormPage extends StatefulWidget {
  const UsuarioFormPage({Key? key}) : super(key: key);

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  PerfilTipo? _selectedPerfil;
  String? _selectedClienteId;
  Set<String> _selectedDevices = {};

  late final DatabaseService _db;
  List<Cliente> _clientes = [];
  List<String> _devices = [];
  bool _loading = true;
  bool _saving = false;
  bool _isAllowed = false;

  Usuario? _editingUsuario;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _db = DatabaseService.forUserDevices(uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(uid);
    });
  }

  Future<void> _loadData(String uid) async {
    setState(() => _loading = true);
    try {
      // Permissão
      final currentUser = await _db.getUsuario(uid);
      _isAllowed =
          currentUser.perfil == PerfilTipo.admin ||
          currentUser.perfil == PerfilTipo.moderador;
      if (!_isAllowed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Acesso negado')));
        Navigator.of(context).pop();
        return;
      }

      // Carrega clientes e dispositivos
      _clientes = await _db.listClientes();
      _devices = await _db.listAllDeviceIds();

      // Se edição
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is Usuario) {
        _editingUsuario = arg;
        _nameCtl.text = arg.name;
        _emailCtl.text = arg.email;
        _selectedPerfil = arg.perfil;
        _selectedClienteId = arg.clienteId;
        _selectedDevices = Set.from(arg.dispositivosPermitidos);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}')),
      );
      Navigator.of(context).pop();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_isAllowed) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtl.text.trim();
      final email = _emailCtl.text.trim();
      final perfil = _selectedPerfil!;
      final clienteId = _selectedClienteId;
      final devices = _selectedDevices.toList();

      String id;
      if (_editingUsuario != null) {
        id = _editingUsuario!.id;
      } else {
        // para novos usuários, usamos UID do auth? Por enquanto, gera push
        id =
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: 'https://piloto-minas-laser.firebaseio.com',
            ).ref().child('users').push().key!;
      }

      final usuario = Usuario(
        id: id,
        name: name,
        email: email,
        perfil: perfil,
        clienteId: clienteId,
        dispositivosPermitidos: devices,
      );

      if (_editingUsuario != null) {
        await _db.updateUsuario(usuario);
      } else {
        await _db.createUsuario(usuario);
      }
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar usuário: ${e.toString()}')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _editingUsuario != null ? 'Editar Usuário' : 'Novo Usuário',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso negado')),
        body: const Center(child: Text('Você não tem permissão.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingUsuario != null ? 'Editar Usuário' : 'Novo Usuário',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PerfilTipo>(
                value: _selectedPerfil,
                decoration: const InputDecoration(labelText: 'Perfil'),
                items:
                    PerfilTipo.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.toString().split('.').last),
                          ),
                        )
                        .toList(),
                onChanged: (p) => setState(() => _selectedPerfil = p),
                validator: (v) => v == null ? 'Escolha um perfil' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // só atribui value se ele estiver na lista de IDs válidos
                value:
                    _clientes.any((c) => c.id == _selectedClienteId)
                        ? _selectedClienteId
                        : null,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items:
                    _clientes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nome),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedClienteId = v),
                validator: (v) => v == null ? 'Escolha um cliente' : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Dispositivos permitidos:'),
              ),
              ..._devices.map(
                (d) => CheckboxListTile(
                  title: Text(d),
                  value: _selectedDevices.contains(d),
                  onChanged: (sel) {
                    setState(() {
                      if (sel == true)
                        _selectedDevices.add(d);
                      else
                        _selectedDevices.remove(d);
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando...' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ignore_for_file: use_build_context_synchronously 
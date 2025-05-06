// lib/pages/cliente_form_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class ClienteFormPage extends StatefulWidget {
  const ClienteFormPage({Key? key}) : super(key: key);

  @override
  State<ClienteFormPage> createState() => _ClienteFormPageState();
}

class _ClienteFormPageState extends State<ClienteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtl = TextEditingController();
  final _maxCtl = TextEditingController();
  String? _selectedRepId;
  Set<String> _selectedDevices = {};

  late final DatabaseService _db;
  List<Usuario> _representantes = [];
  List<String> _devices = [];
  bool _loading = true;
  bool _saving = false;
  bool _isAllowed = false;

  Cliente? _editingCliente;

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
      // Verifica permissão
      final currentUser = await _db.getUsuario(uid);
      _isAllowed =
          currentUser.perfil == PerfilTipo.admin ||
          currentUser.perfil == PerfilTipo.moderador;

      // Carrega representantes
      final allUsers = await _db.listUsuarios();
      _representantes =
          allUsers.where((u) => u.perfil == PerfilTipo.representante).toList();

      // Carrega dispositivos
      _devices =
          _isAllowed
              ? await _db.listAllDeviceIds()
              : await _db.permittedDeviceIds();

      // Pré-carrega edição
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is Cliente) {
        _editingCliente = arg;
        _nomeCtl.text = arg.nome;
        _maxCtl.text = arg.maxUsuariosPorRepresentante.toString();
        _selectedRepId = arg.representanteId;
        _selectedDevices = Set.from(arg.dispositivos);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_isAllowed) return;
    setState(() => _saving = true);
    try {
      final nome = _nomeCtl.text.trim();
      final maxUsers = int.parse(_maxCtl.text.trim());
      final repId = _selectedRepId!;
      final dispositivos = _selectedDevices.toList();

      // Geração de ID
      String id;
      if (_editingCliente != null) {
        id = _editingCliente!.id;
      } else {
        id =
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: 'https://piloto-minas-laser.firebaseio.com',
            ).ref().child('clientes').push().key!;
      }

      // Monta objeto Cliente
      final cliente = Cliente(
        id: id,
        nome: nome,
        representanteId: repId,
        maxUsuariosPorRepresentante: maxUsers,
        dispositivos: dispositivos,
      );

      // Persiste
      if (_editingCliente != null) {
        await _db.updateCliente(cliente);
      } else {
        await _db.createCliente(cliente);
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar cliente: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _editingCliente != null ? 'Editar Cliente' : 'Novo Cliente',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso Negado')),
        body: const Center(
          child: Text('Você não tem permissão para acessar este recurso.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingCliente != null ? 'Editar Cliente' : 'Novo Cliente',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeCtl,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRepId,
                decoration: const InputDecoration(labelText: 'Representante'),
                items:
                    _representantes
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedRepId = v),
                validator:
                    (v) => v == null ? 'Selecione um representante' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxCtl,
                decoration: const InputDecoration(
                  labelText: 'Max Usuários por Representante',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Obrigatório';
                  if (int.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Dispositivos disponíveis:'),
              ..._devices.map(
                (d) => CheckboxListTile(
                  title: Text(d),
                  value: _selectedDevices.contains(d),
                  onChanged: (sel) {
                    setState(() {
                      if (sel == true) {
                        _selectedDevices.add(d);
                      } else {
                        _selectedDevices.remove(d);
                      }
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

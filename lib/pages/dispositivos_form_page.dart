// lib/pages/dispositivo_form_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class DispositivoFormPage extends StatefulWidget {
  const DispositivoFormPage({Key? key}) : super(key: key);
  @override
  State<DispositivoFormPage> createState() => _DispositivoFormPageState();
}

class _DispositivoFormPageState extends State<DispositivoFormPage> {
  final _formKey = GlobalKey<FormState>();
  String? _deviceId;
  final _clienteCtl = TextEditingController();
  final _dataProdCtl = TextEditingController();
  final _dataExpCtl = TextEditingController();
  final _bateriasCtl = TextEditingController();
  final _holofotesCtl = TextEditingController();
  final _tensaoCtl = TextEditingController();
  final _tipoCtl = TextEditingController();
  final _obsCtl = TextEditingController();

  late final DatabaseService _db;
  List<String> _deviceIds = [];
  bool _loading = true;
  bool _saving = false;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _db = DatabaseService.forUserDevices(uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(uid);
    });
  }

  Future<void> _load(String uid) async {
    setState(() => _loading = true);
    try {
      final user = await _db.getUsuario(uid);
      _isAllowed =
          user.perfil == PerfilTipo.admin ||
          user.perfil == PerfilTipo.representante;
      _deviceIds = await _db.listAllDeviceIds();
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is String) {
        _deviceId = arg;
        final info = await _db.getDeviceInfo(arg);
        if (info != null) {
          _clienteCtl.text = info['cliente']?.toString() ?? '';
          _dataProdCtl.text = info['dataproducao']?.toString() ?? '';
          _dataExpCtl.text = info['dataexpedicao']?.toString() ?? '';
          _bateriasCtl.text = info['numerodebaterias']?.toString() ?? '';
          _holofotesCtl.text = info['quantidadeholofotes']?.toString() ?? '';
          _tensaoCtl.text = info['tensaonominal']?.toString() ?? '';
          _tipoCtl.text = info['tipo']?.toString() ?? '';
          _obsCtl.text = info['observacao']?.toString() ?? '';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      Navigator.of(context).pop();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_isAllowed) return;
    setState(() => _saving = true);
    final id = _deviceId!;
    final info = <String, dynamic>{
      'cliente': _clienteCtl.text.trim(),
      'dataproducao': _dataProdCtl.text.trim(),
      if (_dataExpCtl.text.trim().isNotEmpty)
        'dataexpedicao': _dataExpCtl.text.trim(),
      'numerodebaterias': int.parse(_bateriasCtl.text),
      'quantidadeholofotes': int.parse(_holofotesCtl.text),
      'tensaonominal': int.parse(_tensaoCtl.text),
      'tipo': _tipoCtl.text.trim(),
      if (_obsCtl.text.trim().isNotEmpty) 'observacao': _obsCtl.text.trim(),
    };
    try {
      await _db.setDeviceInfo(id, info);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro salvar: ${e.toString()}')));
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
            _deviceId != null ? 'Editar Dispositivo' : 'Novo Dispositivo',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso negado')),
        body: const Center(child: Text('Sem permissão')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _deviceId != null ? 'Editar Dispositivo' : 'Novo Dispositivo',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _deviceIds.contains(_deviceId) ? _deviceId : null,
                decoration: const InputDecoration(
                  labelText: 'ID do Dispositivo',
                ),
                items:
                    _deviceIds
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                onChanged: (v) => setState(() => _deviceId = v),
                validator: (v) => v == null ? 'Escolha o ID' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clienteCtl,
                decoration: const InputDecoration(labelText: 'Cliente'),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataProdCtl,
                decoration: const InputDecoration(labelText: 'Data Produção'),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataExpCtl,
                decoration: const InputDecoration(
                  labelText: 'Data Expedição (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bateriasCtl,
                decoration: const InputDecoration(
                  labelText: 'Número de Baterias',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _holofotesCtl,
                decoration: const InputDecoration(
                  labelText: 'Quantidade Holofotes',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tensaoCtl,
                decoration: const InputDecoration(labelText: 'Tensão Nominal'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tipoCtl,
                decoration: const InputDecoration(labelText: 'Tipo'),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _obsCtl,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
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

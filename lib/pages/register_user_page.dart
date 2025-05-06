// lib/pages/register_user_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({Key? key}) : super(key: key);

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  // Controllers para formulário
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _classController = TextEditingController();
  final _permissionController = TextEditingController();

  // Listas de dados
  List<String> _uids = [];
  Map<String, String> _uidToEmail = {};
  List<String> _devices = [];

  // Seleções
  String? _selectedUid;
  Set<String> _selectedDevices = {};

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Carrega UIDs via Cloud Function e lista de dispositivos do RDB correto
  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1) Chama a Function pública listAllUsers
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final res = await functions.httpsCallable('listAllUsers').call();
      final rawList = res.data as List;
      final usersList =
          rawList
              .cast<Map>() // Map<dynamic,dynamic>
              .map((m) => m.cast<String, String>()) // Map<String,String>
              .toList();

      final fetchedUids = usersList.map((e) => e['uid']!).toList();
      final fetchedMap = {for (var u in usersList) u['uid']!: u['email']!};

      // 2) Busca dispositivos no piloto-minas-laser
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://piloto-minas-laser.firebaseio.com',
      );
      final devSnap = await db.ref('dispositivos').get();
      final fetchedDevices =
          devSnap.value != null
              ? (devSnap.value as Map).keys.cast<String>().toList()
              : <String>[];

      setState(() {
        _uids = fetchedUids;
        _uidToEmail = fetchedMap;
        _devices = fetchedDevices;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() {
        _errorMessage = 'Falha ao carregar dados. Verifique sua conexão.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _classController.dispose();
    _permissionController.dispose();
    super.dispose();
  }

  /// Carrega registro e dispositivos de um UID selecionado
  Future<void> _loadUserData(String uid) async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://piloto-minas-laser.firebaseio.com',
    );
    final regSnap = await db.ref('users/$uid/regsiter').get();
    final devSnap = await db.ref('users/$uid/devices').get();
    final regMap = (regSnap.value as Map?)?.cast<String, dynamic>() ?? {};
    final devMap = (devSnap.value as Map?)?.cast<String, dynamic>() ?? {};

    setState(() {
      _nameController.text = regMap['name'] ?? '';
      _emailController.text = regMap['Email'] ?? '';
      _companyController.text = regMap['company'] ?? '';
      _classController.text = regMap['class'] ?? '';
      _permissionController.text = regMap['permission'] ?? '';
      _selectedDevices =
          devMap.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toSet();
    });
  }

  /// Salva alterações no RDB
  Future<void> _save() async {
    if (_selectedUid == null) return;

    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://piloto-minas-laser.firebaseio.com',
      );
      await db.ref('users/$_selectedUid/regsiter').set({
        'Email': _emailController.text,
        'class': _classController.text,
        'company': _companyController.text,
        'name': _nameController.text,
        'permission': _permissionController.text,
      });
      await db.ref('users/$_selectedUid/devices').set({
        for (var d in _selectedDevices) d: true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuário $_selectedUid atualizado com sucesso')),
      );
    } catch (e) {
      debugPrint('Error saving user: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar usuário: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cadastrar Usuário')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cadastrar Usuário')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Usuário')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Selecione UID'),
              value: _selectedUid,
              items:
                  _uids
                      .map(
                        (uid) => DropdownMenuItem(
                          value: uid,
                          child: Text('$uid – ${_uidToEmail[uid] ?? ''}'),
                        ),
                      )
                      .toList(),
              onChanged: (uid) {
                setState(() {
                  _selectedUid = uid;
                  _selectedDevices.clear();
                });
                if (uid != null) _loadUserData(uid);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Empresa'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _classController,
              decoration: const InputDecoration(labelText: 'Classe'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _permissionController,
              decoration: const InputDecoration(labelText: 'Permissão'),
            ),
            const SizedBox(height: 16),
            Text(
              'Dispositivos disponíveis:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            ..._devices.map(
              (d) => CheckboxListTile(
                title: Text(d),
                value: _selectedDevices.contains(d),
                onChanged: (sel) {
                  setState(() {
                    sel == true
                        ? _selectedDevices.add(d)
                        : _selectedDevices.remove(d);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}

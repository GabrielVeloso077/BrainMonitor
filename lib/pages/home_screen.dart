// lib/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/models.dart';
import 'overview_page.dart';
import 'history_page.dart';
import 'graphs_page.dart';
import 'settings_page.dart';
import 'clientes_page.dart';
import 'cliente_form_page.dart';
import 'usuarios_page.dart';
import 'usuario_form_page.dart';
import 'dispositivos_page.dart';
import 'dispositivos_form_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _devices = [];
  String? _selectedDevice;
  Widget _page = const Center(child: CircularProgressIndicator());
  bool _loadingDevices = true;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    _loadDevicesAndPermissions();
  }

  Future<void> _loadDevicesAndPermissions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      // Permissões do usuário
      final user = await DatabaseService.forUserDevices(uid).getUsuario(uid);
      _isAllowed =
          user.perfil == PerfilTipo.admin ||
          user.perfil == PerfilTipo.moderador;
      // Dispositivos permitidos
      final devices =
          await DatabaseService.forUserDevices(uid).permittedDeviceIds();
      setState(() {
        _devices = devices;
        _loadingDevices = false;
        if (_devices.isNotEmpty) {
          _selectedDevice = _devices.first;
          _page = OverviewPage(deviceId: _selectedDevice!);
        }
      });
    } catch (e) {
      // Tratar erros
      setState(() {
        _devices = [];
        _loadingDevices = false;
      });
      debugPrint('Erro ao carregar dados iniciais: $e');
    }
  }

  void _switchPage(Widget page) {
    setState(() => _page = page);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDevices) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_devices.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Nenhum dispositivo disponível')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<String>(
          value: _selectedDevice,
          dropdownColor: Theme.of(context).canvasColor,
          underline: const SizedBox(),
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _selectedDevice = id;
              _page = OverviewPage(deviceId: id);
            });
          },
          items:
              _devices
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text('Dispositivo $d'),
                    ),
                  )
                  .toList(),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text('Menu')),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Visão Geral'),
              onTap:
                  () => _switchPage(OverviewPage(deviceId: _selectedDevice!)),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico'),
              onTap: () => _switchPage(HistoryPage(deviceId: _selectedDevice!)),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Gráficos'),
              onTap: () => _switchPage(GraphsPage(deviceId: _selectedDevice!)),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configurações'),
              onTap: () => _switchPage(SettingsPage()),
            ),
            // Botão CRUD Clientes somente para Admin/Moderador
            if (_isAllowed) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Clientes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/clientes');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Usuários'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/usuarios');
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb),
                title: const Text('Dispositivos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/dispositivos');
                },
              ),
            ],
          ],
        ),
      ),
      body: _page,
    );
  }
}

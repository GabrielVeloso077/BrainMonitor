// lib/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/database_service.dart';
import '../models/models.dart';

import 'overview_page.dart'; // visão geral global (sem deviceId)
import 'device_details_page.dart'; // detalhes unitários (com deviceId)
import 'history_page.dart';
import 'graphs_page.dart';
import 'settings_page.dart';
import 'clientes_page.dart';
import 'usuarios_page.dart';

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
          // Página inicial: detalhes do primeiro device
          _page = const OverviewPage();
        }
      });
    } catch (e) {
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
              _page = DeviceDetailsPage(deviceId: id);
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
            // Visão Geral Global
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Visão Geral'),
              onTap: () => _switchPage(const OverviewPage()),
            ),
            // Visão Detalhada do Device Selecionado
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Detalhes do Dispositivo'),
              onTap:
                  () => _switchPage(
                    DeviceDetailsPage(deviceId: _selectedDevice!),
                  ),
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
              onTap: () => _switchPage(const SettingsPage()),
            ),
            if (_isAllowed) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Clientes'),
                onTap: () => Navigator.pushNamed(context, '/clientes'),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Usuários'),
                onTap: () => Navigator.pushNamed(context, '/usuarios'),
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

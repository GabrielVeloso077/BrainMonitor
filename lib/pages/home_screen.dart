// Importações necessárias para o funcionamento do aplicativo
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'overview_page.dart';
import 'history_page.dart';
import 'graphs_page.dart';
import 'settings_page.dart';

// Define o widget principal da tela inicial como um StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Estado associado ao HomeScreen
class _HomeScreenState extends State<HomeScreen> {
  // Lista de dispositivos disponíveis para o usuário
  List<String> _devices = [];
  // Dispositivo atualmente selecionado
  String? _selectedDevice;
  // Página atualmente exibida
  Widget _page = const Center(child: CircularProgressIndicator());
  // Indicador de carregamento dos dispositivos
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    // Carrega os dispositivos ao inicializar o estado
    _loadDevices();
  }

  // Método assíncrono para carregar os dispositivos do usuário
  Future<void> _loadDevices() async {
    final uid =
        FirebaseAuth
            .instance
            .currentUser!
            .uid; // Obtém o UID do usuário autenticado
    // Obtém a lista de IDs de dispositivos permitidos para o usuário
    final devices =
        await DatabaseService.forUserDevices(uid).permittedDeviceIds();
    setState(() {
      _devices = devices; // Atualiza a lista de dispositivos
      _loadingDevices = false; // Indica que o carregamento terminou
      if (_devices.isNotEmpty) {
        _selectedDevice =
            _devices.first; // Seleciona o primeiro dispositivo por padrão
        _page = OverviewPage(
          deviceId: _selectedDevice!,
        ); // Define a página inicial como "Visão Geral"
      }
    });
  }

  // Método para alternar entre páginas
  void _switchPage(Widget page) {
    setState(() => _page = page); // Atualiza a página exibida
    Navigator.pop(context); // Fecha o menu lateral (drawer)
  }

  @override
  Widget build(BuildContext context) {
    // Exibe um indicador de carregamento enquanto os dispositivos estão sendo carregados
    if (_loadingDevices) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Exibe uma mensagem caso não haja dispositivos disponíveis
    if (_devices.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Nenhum dispositivo disponível')),
      );
    }

    // Estrutura principal da tela
    return Scaffold(
      appBar: AppBar(
        // Dropdown para selecionar o dispositivo
        title: DropdownButton<String>(
          value: _selectedDevice, // Dispositivo atualmente selecionado
          dropdownColor: Theme.of(context).canvasColor, // Cor do dropdown
          underline: const SizedBox(), // Remove a linha sublinhada
          onChanged: (id) {
            if (id == null) return;
            setState(() {
              _selectedDevice = id; // Atualiza o dispositivo selecionado
              _page = OverviewPage(deviceId: id); // Atualiza a página exibida
            });
          },
          // Lista de dispositivos como itens do dropdown
          items:
              _devices
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(
                        'Dispositivo $d',
                      ), // Exibe o nome do dispositivo
                    ),
                  )
                  .toList(),
        ),
      ),
      // Menu lateral (drawer) com opções de navegação
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text('Menu')), // Cabeçalho do menu
            ListTile(
              leading: const Icon(Icons.home), // Ícone
              title: const Text('Visão Geral'), // Texto
              onTap:
                  () => _switchPage(
                    OverviewPage(deviceId: _selectedDevice!),
                  ), // Navega para a página "Visão Geral"
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico'),
              onTap:
                  () => _switchPage(
                    HistoryPage(deviceId: _selectedDevice!),
                  ), // Navega para a página "Histórico"
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Gráficos'),
              onTap:
                  () => _switchPage(
                    GraphsPage(deviceId: _selectedDevice!),
                  ), // Navega para a página "Gráficos"
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configurações'),
              onTap:
                  () => _switchPage(
                    SettingsPage(),
                  ), // Navega para a página "Configurações"
            ),
          ],
        ),
      ),
      body: _page, // Exibe a página selecionada
    );
  }
}
// O código acima define a tela inicial de um aplicativo Flutter que exibe uma lista de dispositivos disponíveis para o usuário autenticado. O usuário pode selecionar um dispositivo e navegar entre diferentes páginas, como Visão Geral, Histórico, Gráficos e Configurações. A tela também inclui um menu lateral (drawer) para facilitar a navegação entre as páginas.,
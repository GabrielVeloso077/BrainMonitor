// lib/pages/alarmes_ativos_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/brain_entry.dart';

/// Página que exibe apenas alarmes ativos dos dispositivos permitidos
class AlarmesAtivosPage extends StatefulWidget {
  const AlarmesAtivosPage({Key? key}) : super(key: key);

  @override
  State<AlarmesAtivosPage> createState() => _AlarmesAtivosPageState();
}

class _AlarmesAtivosPageState extends State<AlarmesAtivosPage> {
  late final DatabaseService _db;
  List<AlarmeAtivo> _alarmes = [];
  bool _loading = true;
  String? _errorMessage;

  // Nomes de alarmes do sistema
  static const Map<String, String> alarmNames = {
    'A10': 'Sem Comunicação com Placa de Acionamento',
    'A12': 'Sem Comunicação com Controlador de Carga',
    'A15': 'SdCard Desconectado',
    'A4': 'Sensor de Norte não Reconhecido',
    'A8': 'Fora de Operação + 30 dias',
  };

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _db = DatabaseService.forUserDevices(uid);
    _loadAlarmes(uid);
  }

  Future<void> _loadAlarmes(String uid) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _alarmes = [];
    });
    try {
      // Dispositivos permitidos
      final deviceIds = await _db.permittedDeviceIds();
      for (final id in deviceIds) {
        // Lê info de cliente e número de baterias
        final infoMap = (await _db.getDeviceInfo(id)) ?? {};
        final clienteName = infoMap['cliente']?.toString() ?? '';
        final numBaterias = infoMap['numerodebaterias'] is num
            ? (infoMap['numerodebaterias'] as num).toInt()
            : int.tryParse(infoMap['numerodebaterias']?.toString() ?? '') ?? 0;

        // Busca apenas o último log
        BrainEntry entry;
        try {
          final logs = await DatabaseService.forDevice(uid, id).fetchRecentLogs(1);
          if (logs.isEmpty) continue;
          entry = logs.first;
        } catch (_) {
          continue; // pula dispositivo se falhar
        }

        final dt = entry.timestamp;
        final formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:''${dt.minute.toString().padLeft(2, '0')}';

        // Alarmes do sistema
        entry.data.alarmes.forEach((code, active) {
          if (active && alarmNames.containsKey(code)) {
            _alarmes.add(AlarmeAtivo(
              timestamp: entry.timestamp,
              nome: alarmNames[code]!,
              cliente: clienteName,
              serie: id,
            ));
          }
        });

        // Alarmes manuais
        final hora = dt.hour;
        final vp = entry.data.vPainel;
        final vb = entry.data.vBateria;
        if (hora >= 8 && hora <= 17 && vp < 36) {
          _alarmes.add(AlarmeAtivo(
            timestamp: entry.timestamp,
            nome: 'Baixa Geração dos Módulos Solares',
            cliente: clienteName,
            serie: id,
          ));
        }
        if (numBaterias > 0 && vb >= 11.1 * numBaterias && vb <= 11.5 * numBaterias) {
          _alarmes.add(AlarmeAtivo(
            timestamp: entry.timestamp,
            nome: 'Pré- Baixa tensão no Banco de Baterias',
            cliente: clienteName,
            serie: id,
          ));
        }
        if (numBaterias > 0 && vb < 11.1 * numBaterias) {
          _alarmes.add(AlarmeAtivo(
            timestamp: entry.timestamp,
            nome: 'LVD - Nível Crítico de Tensão no Banco de Baterias',
            cliente: clienteName,
            serie: id,
          ));
        }
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar alarmes: ${e.toString()}';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alarmes Ativos')),
        body: Center(
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alarmes Ativos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data/Hora')),
            DataColumn(label: Text('Alarme')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Série')),
          ],
          rows: _alarmes.map((a) {
            final dt = a.timestamp;
            final formatted =
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year} '
                '${dt.hour.toString().padLeft(2, '0')}:''${dt.minute.toString().padLeft(2, '0')}';
            return DataRow(cells: [
              DataCell(Text(formatted)),
              DataCell(Text(a.nome)),
              DataCell(Text(a.cliente)),
              DataCell(Text(a.serie)),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

/// Modelo de alarme ativo para exibição
class AlarmeAtivo {
  final DateTime timestamp;
  final String nome;
  final String cliente;
  final String serie;

  AlarmeAtivo({
    required this.timestamp,
    required this.nome,
    required this.cliente,
    required this.serie,
  });
}

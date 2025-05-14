// lib/pages/device_details_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/brain_entry.dart';

class DeviceDetailsPage extends StatelessWidget {
  final String deviceId;
  const DeviceDetailsPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, deviceId);

    return Scaffold(
      appBar: AppBar(title: const Text('Visão Detalhada')),
      body: StreamBuilder<BrainEntry>(
        stream: svc.entryStream,
        builder: (ctx, snapEntry) {
          if (!snapEntry.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entry = snapEntry.data!;
          final dt = entry.timestamp;
          final formattedDate =
              '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/'
              '${dt.year} '
              '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Visão Detalhada',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Última atualização: $formattedDate',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric(context, 'VBateria', '${entry.data.vBateria} V'),
                      _metric(context, 'VPainel', '${entry.data.vPainel} V'),
                      _metric(context, 'IBateria', '${entry.data.iBateria} A'),
                      _metric(context, 'IPainel', '${entry.data.iPainel} A'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    height: 300,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          entry.data.latitude,
                          entry.data.longitude,
                        ),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('pos'),
                          position: LatLng(
                            entry.data.latitude,
                            entry.data.longitude,
                          ),
                        ),
                      },
                    ),
                  ),
                ),
                // Card de Alarmes
                StreamBuilder<Map<String, dynamic>>(
                  stream: svc.infoStream,
                  builder: (ctx2, snapInfo) {
                    final info = snapInfo.data ?? {};
                    final numBaterias =
                        info['numerodebaterias'] is num
                            ? (info['numerodebaterias'] as num)
                            : 0;
                    final hora = entry.timestamp.hour;
                    final vp = entry.data.vPainel;
                    final vb = entry.data.vBateria;

                    // Alarmes do sistema
                    final sistemaAtivos =
                        entry.data.alarmes.entries
                            .where((e) => e.value)
                            .map((e) => e.key)
                            .toList();

                    // Gerar alarmes manuais
                    final manualList = <String>[];
                    if (hora >= 8 && hora <= 17 && vp < 36) {
                      manualList.add('Baixa Geração dos Módulos Solares');
                    }
                    if (numBaterias > 0 &&
                        vb >= 11.1 * numBaterias &&
                        vb <= 11.5 * numBaterias) {
                      manualList.add('Pré- Baixa tensão no Banco de Baterias');
                    }
                    if (numBaterias > 0 && vb < 11.1 * numBaterias) {
                      manualList.add(
                        'LVD - Nível Crítico de Tensão no Banco de Baterias',
                      );
                    }

                    final allAlarms = <String>[];
                    // Mapear nomes
                    final alarmNames = <String, String>{
                      'A10': 'Sem Comunicação com Placa de Acionamento',
                      'A12': 'Sem Comunicação com Controlador de Carga',
                      'A15': 'SdCard Desconectado',
                      'A4': 'Sensor de Norte não Reconhecido',
                      'A8': 'Fora de Operação + 30 dias',
                    };
                    for (var code in sistemaAtivos) {
                      allAlarms.add(alarmNames[code] ?? code);
                    }
                    allAlarms.addAll(manualList);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarmes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (allAlarms.isEmpty)
                              Text(
                                'Nenhum alarme ativo',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ...allAlarms.map(
                              (nome) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      sistemaAtivos.contains(nome)
                                          ? Icons.warning
                                          : Icons.bolt,
                                      color:
                                          sistemaAtivos.contains(nome)
                                              ? Colors.red
                                              : Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        nome,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metric(BuildContext ctx, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(ctx).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(ctx).textTheme.titleLarge),
      ],
    );
  }
}

// lib/pages/overview_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/database_service.dart';
import '../models/brain_entry.dart';

class OverviewPage extends StatelessWidget {
  final String deviceId;

  const OverviewPage({Key? key, required this.deviceId}) : super(key: key);

  // Só os alarmes que queremos e seus nomes
  static const Map<String, String> alarmNames = {
    'A10': 'Sem Comunicação com Placa de Acionamento',
    'A12': 'Sem Comunicação com Controlador de Carga',
    'A15': 'SdCard Desconectado',
    'A4': 'Sensor de Norte não Reconhecido',
    'A8': 'Fora de Operação + 30 dias',
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, deviceId);

    return StreamBuilder<BrainEntry>(
      stream: svc.entryStream,
      builder: (ctx, snapEntry) {
        if (!snapEntry.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entry = snapEntry.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ——————————————————————————
              // TÍTULO DO APP
              Center(
                child: Text(
                  'Brain Monitor',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),

              const SizedBox(height: 8),

              // ——————————————————————————
              // ÚLTIMA ATUALIZAÇÃO
              Center(
                child: Text(
                  'Última atualização: '
                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${entry.timestamp.minute.toString().padLeft(2, '0')}  '
                  '${entry.timestamp.day.toString().padLeft(2, '0')}/'
                  '${entry.timestamp.month.toString().padLeft(2, '0')}/'
                  '${entry.timestamp.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 16),

              // ——————————————————————————
              // Card de Métricas
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

              // ——————————————————————————
              // Card do Mapa
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(entry.data.latitude, entry.data.longitude),
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

              // ——————————————————————————
              // Card de Alarmes do Sistema (JSON)
              StreamBuilder<Map<String, dynamic>>(
                stream: svc.infoStream,
                builder: (ctx2, snapInfo) {
                  final info = snapInfo.data ?? {};
                  final numBaterias = (info['numerodebaterias'] ?? 0) as num;
                  final hora = entry.timestamp.hour;
                  final vp = entry.data.vPainel;
                  final vb = entry.data.vBateria;

                  // Filtrar alarmes do sistema ativos
                  final sistemaAtivos =
                      entry.data.alarmes.entries
                          .where(
                            (e) => alarmNames.containsKey(e.key) && e.value,
                          )
                          .map((e) => alarmNames[e.key]!)
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

                  // Combinar ambos
                  final todosAlarmes = [...sistemaAtivos, ...manualList];

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

                          if (todosAlarmes.isEmpty)
                            Text(
                              'Nenhum alarme ativo',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),

                          ...todosAlarmes.map(
                            (nome) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
                                          Theme.of(context).textTheme.bodyLarge,
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

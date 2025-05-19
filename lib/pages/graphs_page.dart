import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/database_service.dart';
import '../models/brain_entry.dart';
import '../utils/download_util.dart' as download_util;

class GraphsPage extends StatefulWidget {
  final String deviceId;
  const GraphsPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  final GlobalKey _chartKey = GlobalKey();
  List<BrainEntry> _entries = [];
  bool _loading = true;

  String _selectedVar = 'VB';
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFmt = DateFormat('dd/MM');
  final DateFormat _tooltipFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, widget.deviceId);
    final all = await svc.fetchAllLogs();
    final filtered = all.where((e) {
      final t = e.timestamp;
      if (_startDate != null && t.isBefore(_startDate!)) return false;
      if (_endDate != null && t.isAfter(_endDate!)) return false;
      return true;
    }).toList();
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() {
      _entries = filtered;
      _loading = false;
    });
  }

  List<FlSpot> _generateSpots() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final x = entry.timestamp.millisecondsSinceEpoch.toDouble();
      double y;
      switch (_selectedVar) {
        case 'VB':
          y = entry.data.vBateria;
          break;
        case 'IB':
          y = entry.data.iBateria;
          break;
        case 'VP':
          y = entry.data.vPainel;
          break;
        case 'IP':
          y = entry.data.iPainel;
          break;
        case 'IC':
          y = entry.data.iCarga;
          break;
        default:
          y = 0;
      }
      // ignora picos a zero entre leituras válidas
      if (y == 0 && i > 0 && i < _entries.length - 1) {
        double prevY, nextY;
        switch (_selectedVar) {
          case 'VB':
            prevY = _entries[i - 1].data.vBateria;
            nextY = _entries[i + 1].data.vBateria;
            break;
          case 'IB':
            prevY = _entries[i - 1].data.iBateria;
            nextY = _entries[i + 1].data.iBateria;
            break;
          case 'VP':
            prevY = _entries[i - 1].data.vPainel;
            nextY = _entries[i + 1].data.vPainel;
            break;
          case 'IP':
            prevY = _entries[i - 1].data.iPainel;
            nextY = _entries[i + 1].data.iPainel;
            break;
          case 'IC':
            prevY = _entries[i - 1].data.iCarga;
            nextY = _entries[i + 1].data.iCarga;
            break;
          default:
            prevY = 0;
            nextY = 0;
        }
        if (prevY != 0 && nextY != 0) continue;
      }
      spots.add(FlSpot(x, y));
    }
    return spots;
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = _dateFmt.format(date);
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : (_endDate ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date != null) {
      setState(() {
        if (isStart) _startDate = date;
        else _endDate = date;
      });
    }
  }

  Future<void> _captureAndDownload() async {
    try {
      final boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Falha ao gerar imagem');
      final bytes = byteData.buffer.asUint8List();
      final fileName = 'grafico_${_selectedVar}_${widget.deviceId}.png';

      await download_util.downloadFile(bytes, fileName, context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar gráfico: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = _generateSpots();
    final double minX = spots.isNotEmpty ? spots.first.x : 0.0;
    final double maxX = spots.isNotEmpty ? spots.last.x : 0.0;
    final double xInterval = spots.isNotEmpty ? (maxX - minX) / 4 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _captureAndDownload,
            tooltip: 'Download do gráfico',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedVar,
                  items: const [
                    DropdownMenuItem(value: 'VB', child: Text('Tensão de Bateria')),
                    DropdownMenuItem(value: 'IB', child: Text('Corrente de Bateria')),
                    DropdownMenuItem(value: 'VP', child: Text('Tensão de Painel')),
                    DropdownMenuItem(value: 'IP', child: Text('Corrente de Painel')),
                    DropdownMenuItem(value: 'IC', child: Text('Corrente de Carga')),
                  ],
                  onChanged: (v) => setState(() => _selectedVar = v!),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _pickDate(true),
                  child: Text(
                    _startDate != null
                        ? DateFormat('dd/MM/yyyy').format(_startDate!)
                        : 'Início',
                  ),
                ),
                const Text(' - '),
                TextButton(
                  onPressed: () => _pickDate(false),
                  child: Text(
                    _endDate != null
                        ? DateFormat('dd/MM/yyyy').format(_endDate!)
                        : 'Fim',
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(onPressed: _loadData, child: const Text('Atualizar')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RepaintBoundary(
                      key: _chartKey,
                      child: LineChart(
                        LineChartData(
                          minX: minX,
                          maxX: maxX,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => Colors.black87,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((touchedSpot) {
                                  final dt = DateTime.fromMillisecondsSinceEpoch(
                                      touchedSpot.x.toInt());
                                  final time = _tooltipFmt.format(dt);
                                  return LineTooltipItem(
                                    '$time\n${touchedSpot.y.toStringAsFixed(2)}',
                                    const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: xInterval,
                                getTitlesWidget: _bottomTitleWidgets,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 10,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

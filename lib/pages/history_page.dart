import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import '../services/database_service.dart';
import '../models/brain_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatefulWidget {
  final String deviceId;
  const HistoryPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<BrainEntry> _entries = [];
  bool _loading = true;

  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, bool> _variableFilters = {
    'VB': true,
    'IB': true,
    'VP': true,
    'IP': true,
    'IC': true,
    'lt': true,
    'lg': true,
    'Alarmes': true,
  };

  int _rowsPerPage = 10;

  final DateFormat _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, widget.deviceId);
    final entries = await svc.fetchAllLogs();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _exportCsv() async {
    final filtered = _entries.where((e) {
      final ts = e.timestamp;
      if (_startDate != null && ts.isBefore(_startDate!)) return false;
      if (_endDate != null && ts.isAfter(_endDate!)) return false;
      return true;
    }).toList();

    final headers = <String>[];
    if (_variableFilters['VB']!) headers.add('Tensão de Bateria (V)');
    if (_variableFilters['IB']!) headers.add('Corrente de Bateria (A)');
    if (_variableFilters['VP']!) headers.add('Tensão de Painel (V)');
    if (_variableFilters['IP']!) headers.add('Corrente de Painel (A)');
    if (_variableFilters['IC']!) headers.add('Corrente de Carga (A)');
    if (_variableFilters['lt']!) headers.add('Latitude');
    if (_variableFilters['lg']!) headers.add('Longitude');
    if (_variableFilters['Alarmes']!) headers.add('Alarmes');

    final rows = <List<dynamic>>[];
    rows.add(['Timestamp', ...headers]);
    for (var e in filtered) {
      final row = <dynamic>[];
      row.add(e.timestamp.toIso8601String());
      if (_variableFilters['VB']!) row.add(e.data.vBateria);
      if (_variableFilters['IB']!) row.add(e.data.iBateria);
      if (_variableFilters['VP']!) row.add(e.data.vPainel);
      if (_variableFilters['IP']!) row.add(e.data.iPainel);
      if (_variableFilters['IC']!) row.add(e.data.iCarga);
      if (_variableFilters['lt']!) row.add(e.data.latitude);
      if (_variableFilters['lg']!) row.add(e.data.longitude);
      if (_variableFilters['Alarmes']!) row.add(
        e.data.alarmes.entries.where((a) => a.value).map((a) => a.key).join(';'),
      );
      rows.add(row);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'dados_${widget.deviceId}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dados_${widget.deviceId}.csv');
      await file.writeAsString(csvString);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo salvo em: \${file.path}')),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Filtros de Exportação'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: const Text('Data Início'),
                    subtitle: Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : 'Não selecionado',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setStateDialog(() => _startDate = d);
                    },
                  ),
                  ListTile(
                    title: const Text('Data Fim'),
                    subtitle: Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : 'Não selecionado',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setStateDialog(() => _endDate = d);
                    },
                  ),
                  const Divider(),
                  const Text('Variáveis'),
                  ..._variableFilters.keys.map((key) {
                    return CheckboxListTile(
                      title: Text(_variableLabel(key)),
                      value: _variableFilters[key],
                      onChanged: (v) => setStateDialog(() => _variableFilters[key] = v!),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _exportCsv();
                },
                child: const Text('Exportar'),
              ),
            ],
          );
        });
      },
    );
  }

  String _variableLabel(String key) {
    switch (key) {
      case 'VB': return 'Tensão de Bateria';
      case 'IB': return 'Corrente de Bateria';
      case 'VP': return 'Tensão de Painel';
      case 'IP': return 'Corrente de Painel';
      case 'IC': return 'Corrente de Carga';
      case 'lt': return 'Latitude';
      case 'lg': return 'Longitude';
      case 'Alarmes': return 'Alarmes';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showFilterDialog,
            tooltip: 'Exportar CSV',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: PaginatedDataTable(
          columns: [
            DataColumn(label: Text('Horário')),
            DataColumn(label: Text('Tensão de Bateria (V)')),
            DataColumn(label: Text('Corrente de Bateria (A)')), 
            DataColumn(label: Text('Tensão de Painel (V)')),
            DataColumn(label: Text('Corrente de Painel (A)')),
            DataColumn(label: Text('Corrente de Carga (A)')),
            DataColumn(label: Text('Latitude')),
            DataColumn(label: Text('Longitude')),
            DataColumn(label: Text('Alarmes')),
          ],
          source: _BrainDataSource(_entries, _fmt),
          rowsPerPage: _rowsPerPage,
          availableRowsPerPage: const [10, 50, 100],
          onRowsPerPageChanged: (r) {
            if (r != null) setState(() => _rowsPerPage = r);
          },
        ),
      ),
    );
  }
}

class _BrainDataSource extends DataTableSource {
  final List<BrainEntry> _entries;
  final DateFormat _fmt;

  _BrainDataSource(this._entries, this._fmt);

  @override
  DataRow getRow(int index) {
    final e = _entries[index];
    return DataRow(cells: [
      DataCell(Text(_fmt.format(e.timestamp.toLocal()))),
      DataCell(Text(e.data.vBateria.toString())),
      DataCell(Text(e.data.iBateria.toString())),
      DataCell(Text(e.data.vPainel.toString())),
      DataCell(Text(e.data.iPainel.toString())),
      DataCell(Text(e.data.iCarga.toString())),
      DataCell(Text(e.data.latitude.toString())),
      DataCell(Text(e.data.longitude.toString())),
      DataCell(Text(e.data.alarmes.entries.where((a) => a.value).map((a) => a.key).join(', '))),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _entries.length;

  @override
  int get selectedRowCount => 0;
}

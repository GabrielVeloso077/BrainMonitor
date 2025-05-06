import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../models/brain_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GraphsPage extends StatefulWidget {
  final String deviceId;
  const GraphsPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  List<FlSpot> _vb = [], _vp = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, widget.deviceId);
    final list = await svc.fetchRecentLogs(50);
    for (int i = 0; i < list.length; i++) {
      _vb.add(FlSpot(i.toDouble(), list[i].data.vBateria));
      _vp.add(FlSpot(i.toDouble(), list[i].data.vPainel));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _vb,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _vp,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

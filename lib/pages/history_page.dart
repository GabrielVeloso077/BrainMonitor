import 'package:flutter/material.dart';
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
  List<BrainEntry> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = DatabaseService.forDevice(uid, widget.deviceId);
    final entries = await svc.fetchAllLogs();
    setState(() {
      _list = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (_, i) {
        final e = _list[i];
        return ListTile(
          title: Text(e.timestamp.toString()),
          subtitle: Text('VB: ${e.data.vBateria}  VP: ${e.data.vPainel}'),
        );
      },
    );
  }
}

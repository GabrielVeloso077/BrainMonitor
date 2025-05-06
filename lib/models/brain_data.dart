// lib/models/brain_data.dart
class BrainData {
  final double vBateria;
  final double vPainel;
  final double iPainel;
  final double iBateria;
  final double iCarga;
  final double latitude;
  final double longitude;
  final Map<String, bool> alarmes;

  BrainData({
    required this.vBateria,
    required this.vPainel,
    required this.iPainel,
    required this.iBateria,
    required this.iCarga,
    required this.latitude,
    required this.longitude,
    required this.alarmes,
  });

  factory BrainData.fromMap(Map<dynamic, dynamic> map) {
    final alarms = <String, bool>{};
    map.forEach((key, value) {
      if (key is String && key.startsWith('A')) {
        alarms[key] = (value ?? 0) == 1;
      }
    });
    return BrainData(
      vBateria: (map['VB'] ?? 0).toDouble(),
      vPainel: (map['VP'] ?? 0).toDouble(),
      iPainel: (map['IP'] ?? 0).toDouble(),
      iBateria: (map['IB'] ?? 0).toDouble(),
      iCarga: (map['IC'] ?? 0).toDouble(),
      latitude: (map['lt'] ?? 0).toDouble(),
      longitude: (map['lg'] ?? 0).toDouble(),
      alarmes: alarms,
    );
  }
}

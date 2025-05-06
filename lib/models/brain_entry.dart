// lib/models/brain_entry.dart
import 'brain_data.dart';

/// Represents a database entry with its timestamp and data
class BrainEntry {
  final DateTime timestamp;
  final BrainData data;

  BrainEntry({required this.timestamp, required this.data});
}

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

/// Salva bytes em arquivo no armazenamento local e mostra SnackBar
Future<void> downloadFile(
    Uint8List bytes, String fileName, BuildContext context) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Gráfico salvo em: ${file.path}')),
  );
}

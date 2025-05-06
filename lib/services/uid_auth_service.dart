import 'package:cloud_functions/cloud_functions.dart';

class Uid_AuthService {
  /// Chama a Cloud Function listAllUsers e retorna lista de {uid, email}
  static Future<List<Map<String, String>>> fetchAuthUsers() async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listAllUsers');
    final result = await callable();
    final List<dynamic> raw = result.data;
    return raw
        .map((u) => Map<String, String>.from(u as Map<String, dynamic>))
        .toList();
  }
}
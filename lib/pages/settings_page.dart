// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'register_user_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://piloto-minas-laser.firebaseio.com',
    );
    final registerRef = db.ref().child('users/$uid/regsiter');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<DatabaseEvent>(
        stream: registerRef.onValue,
        builder: (ctx, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final regMap = Map<String, dynamic>.from(
            snap.data!.snapshot.value as Map<dynamic, dynamic>,
          );
          final permission = regMap['permission'] as String? ?? '';
          final canRegister =
              permission == 'admin' || permission == 'QualidadeMTower';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cadastro',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text('Nome: ${regMap['name'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text('Email: ${regMap['Email'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text('Empresa: ${regMap['company'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text('Cargo: ${regMap['class'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text('Permissão: ${regMap['permission'] ?? ''}'),
                      ],
                    ),
                  ),
                ),

                ElevatedButton(
                  onPressed: () => _logout(context),
                  child: const Text('Logout'),
                ),
                const SizedBox(height: 12),

                if (canRegister)
                  ElevatedButton(
                    onPressed: () {
                      // 1) Debug: imprime usuário atual
                      final user = FirebaseAuth.instance.currentUser;
                      debugPrint(
                        '>> Usuário atual: UID=${user?.uid}, Email=${user?.email}',
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterUserPage(),
                        ),
                      );
                    },
                    child: const Text('Cadastrar'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

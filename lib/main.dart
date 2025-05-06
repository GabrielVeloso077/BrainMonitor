// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'pages/sign_in_page.dart';
import 'pages/sign_up_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Opcional: você pode criar uma instância com região específica quando chamar a Function,
  // mas não é possível atribuir diretamente a um setter.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brain Monitor',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        colorScheme: ColorScheme.dark(primary: Colors.amber),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),
        '/signin': (_) => const SignInPage(),
        '/signup': (_) => const SignUpPage(),
        '/forgot': (_) => const ForgotPasswordPage(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

/// Decide qual tela exibir baseado no estado de autenticação
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().userChanges,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.hasData ? const HomeScreen() : const SignInPage();
      },
    );
  }
}

// lib/pages/sign_in_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true; // <— controla a visibilidade

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().signIn(
        email: _emailCtl.text.trim(),
        pass: _passCtl.text.trim(),
      );
      // se sucesso, o StreamBuilder em main.dart vai levar pra HomeScreen
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/LOGO.png', height: 120),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailCtl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator:
                      (v) =>
                          v != null && v.contains('@')
                              ? null
                              : 'Email inválido',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtl,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator:
                      (v) =>
                          (v != null && v.length >= 6)
                              ? null
                              : 'Mínimo 6 caracteres',
                ),
                const SizedBox(height: 32),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: _submit,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 12,
                        ),
                        child: Text('Entrar'),
                      ),
                    ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot'),
                  child: const Text('Esqueci minha senha'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

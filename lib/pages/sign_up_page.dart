// lib/pages/sign_up_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().signUp(
        email: _emailCtl.text.trim(),
        pass: _passCtl.text.trim(),
      );
      Navigator.pop(context); // volta pro sign in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada! Faça login.')),
      );
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
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
                      child: const Text('Cadastrar'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

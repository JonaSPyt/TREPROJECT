import 'package:flutter/material.dart';

class BlankScreen extends StatelessWidget {
  const BlankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Outra Tela'),
      ),
      body: const Center(
        child: Text('Tela em branco - Adicionar funcionalidades aqui'),
      ),
    );
  }
}

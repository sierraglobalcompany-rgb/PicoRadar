import 'package:flutter/material.dart';

class ImmersivePlaceholderScreen extends StatelessWidget {
  const ImmersivePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ruta inmersiva'),
      ),
      body: const Center(
        child: Text('Fuera del shell', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

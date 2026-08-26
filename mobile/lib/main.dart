import 'package:flutter/material.dart';

void main() {
  runApp(const PicoRadarApp());
}

class PicoRadarApp extends StatelessWidget {
  const PicoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PicoRadar',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: const Color(0xFF146C94)),
      ),
      home: const PicoRadarSmokeScreen(),
    );
  }
}

class PicoRadarSmokeScreen extends StatelessWidget {
  const PicoRadarSmokeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('PicoRadar'),
      ),
      body: const Center(
        child: Text('PicoRadar scaffold', textAlign: TextAlign.center),
      ),
    );
  }
}

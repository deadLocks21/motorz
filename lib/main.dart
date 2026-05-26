import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motorz',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: const Color(0xFFFF5A1F)),
      ),
      home: Scaffold(body: const Center(child: Text('Hello, World!'))),
    );
  }
}

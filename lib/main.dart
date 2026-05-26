import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
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

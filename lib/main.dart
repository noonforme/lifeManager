import 'package:flutter/material.dart';

void main() {
  runApp(const LifeOsApp());
}

class LifeOsApp extends StatelessWidget {
  const LifeOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315e8a)),
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LifeOS'),
              Text('Native workspace foundation'),
            ],
          ),
        ),
      ),
    );
  }
}

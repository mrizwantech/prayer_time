import 'package:flutter/material.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla'),
      ),
      body: const Center(
        child: Text(
          'Qibla direction feature coming soon!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

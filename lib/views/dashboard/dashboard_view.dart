import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cold Storage Dashboard")),
      body: const Center(
        child: Text("Live Temperature & Humidity will appear here"),
      ),
    );
  }
}

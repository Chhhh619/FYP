import 'package:flutter/material.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text(
          'Subscriptions',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Manage your subscriptions here.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
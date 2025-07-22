
import 'package:flutter/material.dart';
import 'package:fyp/wc/Onboard/app_settings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check onboarding status after delay
    Future.delayed(const Duration(seconds: 2), () async {
      final isOnboardingCompleted = await AppSettings.isOnboardingCompleted();
      if (!mounted) return; // Check if widget is still mounted

      Navigator.pushReplacementNamed(
        context,
        isOnboardingCompleted ? '/login' : '/onboarding',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/light.png',
              height: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Crumbs',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
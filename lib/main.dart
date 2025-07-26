// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'wc/login.dart';
import 'wc/register.dart';
import 'wc/currencyconverter.dart';
import 'wc/splash.dart';
import 'wc/home.dart';
import 'ch/homepage.dart';
import 'wc/financia_planning_screen.dart';
import 'wc/financial_tips.dart';
import 'wc/bill/bill_payment_screen.dart';
import 'wc/Onboard/Onboarding.dart';
import 'wc/bill/payment_history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.safetyNet,
    appleProvider: AppleProvider.deviceCheck,
  );


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false, // Remove debug banner
      initialRoute: '/splash', // Set splash screen as initial route
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomePage(),
        '/converter': (context) => const CurrencyConverterScreen(),
        '/advisor': (context) => const FinancialPlanningScreen(),
        '/tips': (context) => const FinancialTipsScreen(),
        '/bill': (context) {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId == null) {
            return Scaffold(
              body: Center(child: Text('Please log in')),
            );
          }
          return BillPaymentScreen(userId: userId);
        },
        '/payment_history': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String?;
          if (userId == null) {
          return Scaffold(
          body: Center(child: Text('User ID not provided')),
          );
          }return PaymentHistoryScreen(userId: userId);
      },}
    );
  }
}
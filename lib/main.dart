
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/wc/gamification_page.dart';
import 'firebase_options.dart';
import 'wc/login.dart';
import 'wc/register.dart';
import 'wc/currencyconverter.dart';
import 'wc/splash.dart';
import 'wc/home.dart';
import 'ch/homepage.dart';
import 'wc/financial_plan.dart';
import 'wc/financial_tips.dart';
import 'wc/bill/bill_payment_screen.dart';
import 'wc/Onboard/Onboarding.dart';
import 'wc/bill/payment_history_screen.dart';
import 'wc/financial_plan.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fyp/wc/bill/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:fyp/wc/trending.dart';

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

  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await NotificationService().init();



  runApp(const MyApp());
}

//bill module
Future<void> _requestPermissions() async {
  var status = await Permission.scheduleExactAlarm.status;
  if (status.isDenied) {
    developer.log('Requesting SCHEDULE_EXACT_ALARM permission');
    status = await Permission.scheduleExactAlarm.request();
    developer.log('Permission status: ${status.isGranted}');
    if (!status.isGranted) {
      developer.log('Exact alarms not permitted, falling back to inexact alarms');
    }
  }
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
        '/financial_plan': (context) =>  FinancialPlanPage(),
        '/tips': (context) => const FinancialTipsScreen(),
        '/game': (context) => const GamificationPage(),
        '/trending': (context) => const TrendingPage(),
        '/settings': (context) => const SettingsPage(),
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
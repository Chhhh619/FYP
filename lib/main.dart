import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ch/homepage.dart';
import 'firebase_options.dart';
import 'wc/login.dart';
import 'wc/register.dart';
import 'wc/currencyconverter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      title: 'Financial App',
      initialRoute: '/login',
      // Start at login screen
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => HomePage(),
        '/currencyconverter': (context) => const CurrencyConverterScreen(),
      },
    );
  }
}

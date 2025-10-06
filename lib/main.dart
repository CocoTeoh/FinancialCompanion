import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'startup_page.dart';
import 'login_page.dart';
import 'register_page.dart';


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Financial Companion',
      theme: ThemeData(
        fontFamily: 'Poppins',
      ),

      home: const StartupPage(),


      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(); // add options if web
    runApp(const MyApp());
  }

}
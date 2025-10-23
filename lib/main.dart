import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'startup_page.dart';
import 'login_page.dart';
import 'register_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MOBILE-ONLY: This is enough if you added the GoogleService-Info.plist (iOS)
  // and google-services.json (Android) in the native folders.
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
      theme: ThemeData(fontFamily: 'Poppins'),
      home: const StartupPage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

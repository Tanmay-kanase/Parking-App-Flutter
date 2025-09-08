import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
Future<void> main() async {
   WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Initialize Firebase before running the app
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Park Ease",
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}

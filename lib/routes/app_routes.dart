import 'package:flutter/material.dart';
import '../views/auth/login_view.dart';
import '../views/auth/signup_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/splash/splash_view.dart';

class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const splash = '/splash';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginView(),
    signup: (context) => SignupScreen(),
    dashboard: (context) => Dashboard(),
    splash: (context) => const SplashView()
  };
}

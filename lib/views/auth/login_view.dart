import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../routes/app_routes.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final storage = const FlutterSecureStorage();

  bool isLoading = false;
  String errorMessage = "";

  final String backendUrl =
      "https://parking-app-zo8j.onrender.com"; // Your backend

  // Login function (similar to React login)
  Future<void> login(String email, String password) async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final res = await http.post(
        Uri.parse("$backendUrl/api/users/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Save token and user securely
        await storage.write(key: "token", value: data['token']);
        await storage.write(key: "user", value: jsonEncode(data['user']));

        // Navigate to dashboard
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Login successful!")));
          Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        }
      } else {
        final data = jsonDecode(res.body);
        setState(() {
          errorMessage = data['message'] ?? "Login failed";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Login failed: $e";
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Login user",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              CustomTextField(
                controller: emailController,
                hintText: "Email",
                icon: Icons.email,
              ),
              const SizedBox(height: 15),
              CustomTextField(
                controller: passwordController,
                hintText: "Password",
                icon: Icons.lock,
                obscureText: true,
              ),
              const SizedBox(height: 15),
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 15),
              isLoading
                  ? const CircularProgressIndicator()
                  : CustomButton(
                      text: "Login",
                      onPressed: () {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        if (email.isEmpty || password.isEmpty) {
                          setState(() {
                            errorMessage = "Please enter email and password";
                          });
                        } else {
                          login(email, password);
                        }
                      },
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.signup);
                },
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

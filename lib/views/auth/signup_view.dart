import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  String? role;

  // States
  bool otpVisible = false;
  bool otpVerified = false;
  bool isSendingOtp = false;
  bool isVerifyingOtp = false;
  bool isRegistering = false;
  bool isUploadingImage = false;
  double uploadProgress = 0;

  File? profileImage;

  // Backend URL
  final String backendUrl = 'https://parking-app-zo8j.onrender.com';

  // Pick Image
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  // Upload image to Firebase
  Future<String> uploadProfileImage() async {
    if (profileImage == null) return "";
    setState(() => isUploadingImage = true);
    String downloadUrl = "dome";

    setState(() {
      isUploadingImage = false;
    });

    return downloadUrl;
  }

  // Send OTP
  Future<void> sendOtp() async {
    if (emailController.text.isEmpty) return;
    setState(() => isSendingOtp = true);

    try {
      var res = await http.post(
        Uri.parse('$backendUrl/api/users/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': emailController.text}),
      );

      var data = jsonDecode(res.body);
      if (data['message'] != null) {
        setState(() {
          otpVisible = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to your email!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP.')),
      );
    } finally {
      setState(() => isSendingOtp = false);
    }
  }

  // Verify OTP
  Future<void> verifyOtp() async {
    if (otpController.text.isEmpty) return;
    setState(() => isVerifyingOtp = true);

    try {
      var res = await http.post(
        Uri.parse('$backendUrl/api/users/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'otp': otpController.text,
        }),
      );

      var data = jsonDecode(res.body);
      if (data['verified'] == true) {
        setState(() {
          otpVerified = true;
          otpVisible = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email verified successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed.')),
      );
    } finally {
      setState(() => isVerifyingOtp = false);
    }
  }

  // Register user
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please verify your email first.')),
      );
      return;
    }

    setState(() => isRegistering = true);
    String profileUrl = await uploadProfileImage();

    try {
      var res = await http.post(
        Uri.parse('$backendUrl/api/users/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': fullNameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'password': passwordController.text,
          'photo': profileUrl,
          'role': role,
        }),
      );

      var data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user', jsonEncode(data['user']));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created successfully!')),
        );
        Navigator.pop(context); // Or navigate to home
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Registration failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user.')),
      );
    } finally {
      setState(() => isRegistering = false);
    }
  }

  // Google Sign-In
  Future<void> googleSignIn() async {
    try {
      // Using Firebase Auth Google sign-in flow
      // You need google_sign_in package here
      // final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      // Implement backend verification if needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 50),
              Text(
                "Create Your Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Join us to get started on your journey!",
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: 30),

              // Full Name
              TextFormField(
                controller: fullNameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please enter your full name" : null,
              ),
              SizedBox(height: 15),

              // Profile Image Picker
              Row(
                children: [
                  ElevatedButton(
                    onPressed: pickImage,
                    child: Text("Pick Profile Image"),
                  ),
                  SizedBox(width: 10),
                  profileImage != null
                      ? Text(profileImage!.path.split('/').last)
                      : Text("No file chosen"),
                ],
              ),
              if (isUploadingImage)
                LinearProgressIndicator(value: uploadProgress / 100),
              SizedBox(height: 15),

              // Email + OTP
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                      ),
                      enabled: !otpVerified && !isSendingOtp && !isVerifyingOtp,
                      validator: (value) =>
                          value!.isEmpty ? "Please enter email" : null,
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: otpVerified || isSendingOtp || isVerifyingOtp
                        ? null
                        : sendOtp,
                    child: isSendingOtp
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(otpVerified ? "Verified" : "Send OTP"),
                  ),
                ],
              ),
              SizedBox(height: 10),

              if (otpVisible && !otpVerified)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: otpController,
                        decoration: InputDecoration(labelText: "Enter OTP"),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed:
                          isVerifyingOtp || isSendingOtp ? null : verifyOtp,
                      child: isVerifyingOtp
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("Verify OTP"),
                    ),
                  ],
                ),
              SizedBox(height: 15),

              // Password
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) => value!.length < 8
                    ? "Password must be at least 8 characters"
                    : null,
              ),
              SizedBox(height: 15),

              // Confirm Password
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) => value != passwordController.text
                    ? "Passwords do not match"
                    : null,
              ),
              SizedBox(height: 15),

              // Phone
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) => value!.length != 10
                    ? "Phone number must be 10 digits"
                    : null,
              ),
              SizedBox(height: 15),

              // Role dropdown
              DropdownButtonFormField<String>(
                value: role,
                hint: Text("Select Your Role"),
                items: [
                  DropdownMenuItem(value: "user", child: Text("User")),
                  DropdownMenuItem(
                      value: "parking_owner", child: Text("Parking Owner")),
                ],
                onChanged: (val) => setState(() => role = val),
                validator: (value) =>
                    value == null ? "Please select a role" : null,
              ),
              SizedBox(height: 15),

              // Terms checkbox
              Row(
                children: [
                  Checkbox(value: true, onChanged: (_) {}),
                  Expanded(
                    child: Text(
                      "I agree to the Terms of Service and Privacy Policy",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isRegistering || isUploadingImage ? null : registerUser,
                child: isRegistering
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Create Account"),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50)),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: googleSignIn,
                child: Text("Sign in with Google"),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

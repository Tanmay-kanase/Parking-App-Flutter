import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../routes/app_routes.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();
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
    print("📁 Uploading from path: ${profileImage!.path}");
    print("⚡ Firebase initialized? ${Firebase.apps.isNotEmpty}");
  }

  Future<String> uploadProfileImage() async {
    if (profileImage == null) {
      print("⚠️ No image selected. Skipping upload.");
      return "";
    }

    setState(() => isUploadingImage = true);
    print("🚀 Starting image upload...");

    try {
      // Unique file name
      final fileName = 'profiles/${DateTime.now().millisecondsSinceEpoch}.jpg';
      print("📂 File name: $fileName");

      // Reference to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      print("🔗 Storage ref created: ${storageRef.fullPath}");

      // ✅ Add metadata to avoid null crash
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      // Upload task
      print("⬆️ Upload task started...");
      UploadTask uploadTask = storageRef.putFile(profileImage!, metadata);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setState(() => uploadProgress = progress);
        print(
            "📊 Progress: ${progress.toStringAsFixed(2)}% | State: ${snapshot.state}");
      }, onError: (e) {
        print("❌ Upload error inside snapshotEvents: $e");
      });

      // Wait until upload completes
      TaskSnapshot snapshot = await uploadTask;
      print("✅ Upload finished. State: ${snapshot.state}");

      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("🌐 Download URL: $downloadUrl");

      setState(() => isUploadingImage = false);
      return downloadUrl;
    } catch (e, st) {
      print("❌ Exception during upload: $e");
      print("📜 StackTrace: $st");

      setState(() => isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
      return "";
    }
  }

  Future<void> debugUploadCheck() async {
    if (profileImage == null) {
      print("❌ No image selected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image first")),
      );
      return;
    }

    String url = await uploadProfileImage();

    if (url.isNotEmpty) {
      print("✅ Image uploaded successfully: $url");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image uploaded successfully ✅")),
      );
    } else {
      print("❌ Image upload failed");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image upload failed ❌")),
      );
    }
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

      print("📩 OTP Response status: ${res.statusCode}");
      print("📩 OTP Response body: ${res.body}");

      var data = jsonDecode(res.body);
      if (data['message'] != null) {
        setState(() {
          otpVisible = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to your email!')),
        );
      }
    } catch (e, stackTrace) {
      print("Google Sign-In Error: $e");
      print(stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
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

  /// Simple dialog for password input
  Future<String?> _askPasswordDialog(BuildContext context) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Set Password"),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter password"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
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

      print("📩 Response status: ${res.statusCode}");
      print("📩 Response body: ${res.body}");

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
    } catch (e, stackTrace) {
      print("❌ Error registering user: $e");
      print("Stack trace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
      );
    } finally {
      setState(() => isRegistering = false);
    }
  }

  // Google Sign-In

  Future<void> googleSignIn() async {
    try {
      final GoogleSignIn _googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      // Trigger Google sign-in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        return;
      }

      // ✅ Extract info
      String? email = googleUser.email;
      String? name = googleUser.displayName;
      String? photoUrl = googleUser.photoUrl;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Email: $email\nName: $name")),
      );

      // 🔹 Step 1: Check if user already exists
      final checkRes = await http.get(
        Uri.parse("$backendUrl/email/$email"),
      );

      bool isNewUser = true;
      if (checkRes.statusCode == 200) {
        isNewUser = false;
      }

      String? password;
      if (isNewUser) {
        // 🔹 Ask user for password if new
        password = await _askPasswordDialog(context);
        if (password == null || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Password is required to continue.")),
          );
          return;
        }
      }

      // 🔹 Step 2: Prepare user data
      final userData = {
        "name": name,
        "email": email,
        "photo": photoUrl,
        "password": password // only for new users
      };

      // 🔹 Step 3: Send to backend for login/signup
      final res = await http.post(
        Uri.parse("$backendUrl/google-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data["token"];
        final user = data["user"];

        // Save
        await storage.write(key: "token", value: token);
        await storage.write(key: "user", value: jsonEncode(user));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful ✅")),
        );

        // Navigate to home
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
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
                  // SizedBox(width: 10),
                  // profileImage != null
                  //     ? Text(profileImage!.path.split('/').last)
                  //     : Text("No file chosen"),
                ],
              ),
              if (isUploadingImage)
                LinearProgressIndicator(value: uploadProgress / 100),
              SizedBox(height: 15),
              ElevatedButton(
                onPressed: debugUploadCheck,
                child: Text("Test Upload"),
              ),

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

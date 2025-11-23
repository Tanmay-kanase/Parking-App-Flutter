import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
// Add this with your other state variables
  bool termsAccepted = false;
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
        Navigator.pushReplacementNamed(
            context, "/dashboard"); // Or navigate to home
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

// --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isDarkMode),
                const SizedBox(height: 32),
                _buildImageUploader(),
                const SizedBox(height: 32),
                _buildTextFormField(
                  controller: fullNameController,
                  labelText: "Full Name",
                  prefixIcon: Icons.person_outline,
                  validator: (value) =>
                      value!.isEmpty ? "Please enter your full name" : null,
                ),
                const SizedBox(height: 16),
                _buildEmailAndOtpSection(),
                if (otpVisible && !otpVerified) ...[
                  const SizedBox(height: 16),
                  _buildOtpVerificationSection(),
                ],
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: passwordController,
                  labelText: "Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => value!.length < 8
                      ? "Password must be at least 8 characters"
                      : null,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: confirmPasswordController,
                  labelText: "Confirm Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => value != passwordController.text
                      ? "Passwords do not match"
                      : null,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: phoneController,
                  labelText: "Phone Number",
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) => value!.length != 10
                      ? "Phone number must be 10 digits"
                      : null,
                ),
                const SizedBox(height: 16),
                _buildRoleDropdown(theme),
                const SizedBox(height: 20),
                _buildTermsAndConditions(theme),
                const SizedBox(height: 24),
                _buildCreateAccountButton(),
                const SizedBox(height: 16),
                _buildSocialSignIn(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  Widget _buildHeader(bool isDarkMode) {
    return Column(
      children: [
        Text(
          "Create Your Account",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join us to get started on your journey!",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildImageUploader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              // The progress indicator is only visible during upload
              child: isUploadingImage
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: uploadProgress / 100),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          color: Colors.green,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                        );
                      },
                    )
                  : null,
            ),
            CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              backgroundImage:
                  profileImage != null ? FileImage(profileImage!) : null,
              child: profileImage == null
                  ? Icon(
                      Icons.person,
                      size: 60,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: pickImage, // This calls your existing pickImage function
          icon: Icon(profileImage == null
              ? Icons.add_a_photo_outlined
              : Icons.edit_outlined),
          label: Text(profileImage == null ? "Upload Photo" : "Change Photo"),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withAlpha(150),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: validator,
    );
  }

  Widget _buildEmailAndOtpSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextFormField(
            controller: emailController,
            labelText: "Email",
            prefixIcon: Icons.email_outlined,
            enabled: !otpVerified && !isSendingOtp && !isVerifyingOtp,
            validator: (value) => value!.isEmpty ? "Please enter email" : null,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding:
              const EdgeInsets.only(top: 5.0), // Align with text field content
          child: ElevatedButton(
            onPressed: otpVerified || isSendingOtp || isVerifyingOtp
                ? null
                : sendOtp, // Calls your sendOtp function
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSendingOtp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(otpVerified ? "Verified ✓" : "Send OTP"),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpVerificationSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextFormField(
            controller: otpController,
            labelText: "Enter OTP",
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 5.0),
          child: ElevatedButton(
            onPressed: isVerifyingOtp || isSendingOtp
                ? null
                : verifyOtp, // Calls your verifyOtp function
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isVerifyingOtp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("Verify OTP"),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: role,
      hint: const Text("Select Your Role"),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.work_outline, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surface.withAlpha(150),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      items: const [
        DropdownMenuItem(value: "user", child: Text("User")),
        DropdownMenuItem(value: "parking_owner", child: Text("Parking Owner")),
      ],
      onChanged: (val) => setState(() => role = val),
      validator: (value) => value == null ? "Please select a role" : null,
    );
  }

  Widget _buildTermsAndConditions(ThemeData theme) {
    return FormField<bool>(
      validator: (value) {
        if (!termsAccepted) {
          return 'You must accept the terms and conditions.';
        }
        return null;
      },
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: termsAccepted,
                  onChanged: (val) => setState(() => termsAccepted = val!),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: "I agree to the ",
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: "Terms of Service",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                child: Text(
                  field.errorText!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              )
          ],
        );
      },
    );
  }

  Widget _buildCreateAccountButton() {
    return FilledButton(
      onPressed: isRegistering || isUploadingImage
          ? null
          : registerUser, // Calls your registerUser function
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isRegistering
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
            )
          : const Text("Create Account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSocialSignIn(bool isDarkMode) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text("OR"),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: googleSignIn, // Calls your googleSignIn function
          // NOTE: You must add a 'google_logo.png' to your assets folder
          // and declare it in your pubspec.yaml file.
          icon: Image.asset('assets/google_logo.png', height: 20),
          label: const Text("Sign in with Google"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side:
                BorderSide(color: isDarkMode ? Colors.white54 : Colors.black26),
          ),
        ),
      ],
    );
  }
}

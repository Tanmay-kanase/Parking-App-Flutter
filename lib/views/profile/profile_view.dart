import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

// A StatefulWidget is used because we need to manage the state of fetching user data.
class ProfileView extends StatefulWidget {
  final String userId;
  final String token;

  const ProfileView({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // State variables to hold the user data and loading status.
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Fetch user data when the widget is first created.
    _fetchUserData();
  }

  // Fetches user profile data from the API.
  Future<void> _fetchUserData() async {
    try {
      final url =
          "https://parking-app-zo8j.onrender.com/api/users/${widget.userId}";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              "Failed to load user data. Status code: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred: $e";
        _isLoading = false;
      });
    }
  }

  // Placeholder functions for button actions.
  void _onEditProfile() {
    // TODO: Implement navigation to an edit profile screen.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Edit Profile Tapped!")),
    );
  }

  Future<void> _onLogout() async {
    const storage = FlutterSecureStorage();

    // 🔹 Clear stored user and token
    await storage.delete(key: 'user');
    await storage.delete(key: 'token');

    if (!mounted) return;

    // 🔹 Navigate to Login (replace with your LoginView route)
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login', // 👈 use your actual login route
      (Route<dynamic> route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logout Tapped!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        // Handle the different UI states: loading, error, and success.
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _userData == null
                    ? const Center(child: Text("No user data available."))
                    : _buildProfileContent(),
      ),
    );
  }

  // Builds the main profile content once data is successfully loaded.
  Widget _buildProfileContent() {
    // Safely extract data from the _userData map.
    final user = _userData ?? {};
    final vehicles = List<Map<String, dynamic>>.from(user['vehicles'] ?? []);
    final parkings = List<Map<String, dynamic>>.from(user['parkings'] ?? []);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(user),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow("Phone", user["phone"] ?? "Not Provided"),
                _buildInfoRow(
                    "Role", (user["role"] ?? "user").toString().toUpperCase()),
                const SizedBox(height: 20),

                // Conditionally display the "My Vehicles" section.
                if (user["role"] == "user") _buildVehiclesSection(vehicles),

                // Conditionally display the "My Parkings" section.
                if (user["role"] == "parking host")
                  _buildParkingsSection(parkings),

                const SizedBox(height: 30),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable UI Component Widgets ---

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: NetworkImage(user["photo"] ?? ""),
            onBackgroundImageError: (_, __) {}, // Handle image load error
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            user["name"] ?? "Unknown User",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            user["email"] ?? "No email",
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesSection(List<Map<String, dynamic>> vehicles) {
    return Column(
      children: [
        _buildSectionTitle("My Vehicles", LucideIcons.car),
        const SizedBox(height: 10),
        vehicles.isNotEmpty
            ? Column(
                children: vehicles.map((v) {
                  return _buildCard(
                    title: v["vehicleType"] ?? "Unknown Vehicle",
                    subtitle:
                        "Plate: ${v["licensePlate"]}\nCompany: ${v["company"] ?? "N/A"}",
                    icon: LucideIcons.car,
                  );
                }).toList(),
              )
            : const Text("No vehicles added yet.",
                style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildParkingsSection(List<Map<String, dynamic>> parkings) {
    return Column(
      children: [
        _buildSectionTitle("My Parkings", LucideIcons.mapPin),
        const SizedBox(height: 10),
        parkings.isNotEmpty
            ? Column(
                children: parkings.map((p) {
                  return _buildCard(
                    title: p["name"] ?? "Unnamed Parking",
                    subtitle:
                        "Location: ${p["address"]}, ${p["city"]}\nTotal Slots: ${p["totalSlots"]}",
                    icon: LucideIcons.parkingCircle,
                    onTap: () {
                      // TODO: Navigate to parking details/management screen
                    },
                  );
                }).toList(),
              )
            : const Text("No parkings found.",
                style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildButton("Edit Profile", Colors.blue, _onEditProfile),
        const SizedBox(width: 20),
        _buildButton("Logout", Colors.red, _onLogout),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text("$label: ",
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 22),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: Icon(icon, color: Colors.deepOrange),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

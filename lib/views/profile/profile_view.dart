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
    // Define a modern color scheme
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFF7F8FC);
    final headerColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.indigo;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("My Profile",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Moved Edit Profile to the AppBar for a cleaner look
          if (!_isLoading && _error == null)
            IconButton(
              icon: const Icon(LucideIcons.edit),
              onPressed: _onEditProfile,
              tooltip: "Edit Profile",
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ))
                : _userData == null
                    ? const Center(child: Text("No user data available."))
                    // Stack the header color behind the scrollable content
                    : Stack(
                        children: [
                          Container(height: 100, color: headerColor),
                          _buildProfileContent(cardColor),
                        ],
                      ),
      ),
    );
  }

  Widget _buildProfileContent(Color cardColor) {
    final user = _userData ?? {};
    final vehicles = List<Map<String, dynamic>>.from(user['vehicles'] ?? []);
    final parkings = List<Map<String, dynamic>>.from(user['parkings'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(user, cardColor),
          const SizedBox(height: 24),
          _buildInfoTiles(user, cardColor),
          const SizedBox(height: 24),
          if (user["role"] == "user")
            _buildVehiclesSection(vehicles, cardColor),
          if (user["role"] == "parking host")
            _buildParkingsSection(parkings, cardColor),
          const SizedBox(height: 24),
          _buildLogoutButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- Re-styled UI Component Widgets ---

  Widget _buildProfileHeader(Map<String, dynamic> user, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.indigo.shade50,
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user["photo"] ?? ""),
              onBackgroundImageError: (_, __) {},
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user["name"] ?? "Unknown User",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            user["email"] ?? "No email",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTiles(Map<String, dynamic> user, Color cardColor) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: LucideIcons.phone,
            label: "Phone",
            value: user["phone"] ?? "Not Provided",
            color: Colors.blue,
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            icon: LucideIcons.userCircle2,
            label: "Role",
            value: (user["role"] ?? "user").toString().toUpperCase(),
            color: Colors.green,
            cardColor: cardColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVehiclesSection(
      List<Map<String, dynamic>> vehicles, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("My Vehicles"),
        vehicles.isNotEmpty
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final v = vehicles[index];
                  return _buildListCard(
                    title: v["vehicleType"] ?? "Unknown Vehicle",
                    subtitle:
                        "Plate: ${v["licensePlate"]}\nCompany: ${v["company"] ?? "N/A"}",
                    icon: LucideIcons.car,
                    cardColor: cardColor,
                  );
                },
              )
            : const Center(
                child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No vehicles added yet.",
                    style: TextStyle(color: Colors.grey)),
              )),
      ],
    );
  }

  Widget _buildParkingsSection(
      List<Map<String, dynamic>> parkings, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("My Parkings"),
        parkings.isNotEmpty
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: parkings.length,
                itemBuilder: (context, index) {
                  final p = parkings[index];
                  return _buildListCard(
                    title: p["name"] ?? "Unnamed Parking",
                    subtitle:
                        "Location: ${p["address"]}, ${p["city"]}\nTotal Slots: ${p["totalSlots"]}",
                    icon: LucideIcons.parkingCircle,
                    cardColor: cardColor,
                    onTap: () {
                      // Your navigation logic here
                    },
                  );
                },
              )
            : const Center(
                child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No parkings found.",
                    style: TextStyle(color: Colors.grey)),
              )),
      ],
    );
  }

  Widget _buildListCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color cardColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withOpacity(0.1),
          child: Icon(icon, color: Colors.indigo.shade600, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      icon: const Icon(LucideIcons.logOut, size: 20),
      label: const Text("Logout"),
      onPressed: _onLogout,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: Colors.red.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

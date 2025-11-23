import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// Removed: import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:parking_app_flutter/views/booking/do_booking_screen.dart';

// --- DATA MODEL ---
// A model to safely handle the parking data from the API
class Parking {
  final String locationId;
  final String name;
  final double lat;
  final double lng;
  final int totalSlots;
  final int bikeSlots;
  final int sedanSlots;
  final int truckSlots;
  final int busSlots;
  final bool evCharging;
  final bool cctvCamera;
  final bool washing;
  final String ownerName;
  final String ownerPhone;
  double distance; // This will be calculated locally

  Parking({
    required this.locationId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.totalSlots,
    required this.bikeSlots,
    required this.sedanSlots,
    required this.truckSlots,
    required this.busSlots,
    required this.evCharging,
    required this.cctvCamera,
    required this.washing,
    required this.ownerName,
    required this.ownerPhone,
    this.distance = 0.0,
  });

  factory Parking.fromJson(Map<String, dynamic> json) {
    return Parking(
      locationId: json['locationId'] ?? '',
      name: json['name'] ?? 'Unknown Parking',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      totalSlots: json['totalSlots'] ?? 0,
      bikeSlots: json['bikeSlots'] ?? 0,
      sedanSlots: json['sedanSlots'] ?? 0,
      truckSlots: json['truckSlots'] ?? 0,
      busSlots: json['busSlots'] ?? 0,
      evCharging: json['evCharging'] ?? false,
      cctvCamera: json['cctvCamera'] ?? false,
      washing: json['washing'] ?? false,
      ownerName: json['user'] != null ? json['user']['name'] : 'N/A',
      ownerPhone: json['user'] != null ? json['user']['phone'] : 'N/A',
    );
  }
}

// --- MAIN SCREEN WIDGET ---
class ShowNearbyParkingsScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String searchLocation;

  const ShowNearbyParkingsScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.searchLocation,
  });

  @override
  State<ShowNearbyParkingsScreen> createState() =>
      _ShowNearbyParkingsScreenState();
}

class _ShowNearbyParkingsScreenState extends State<ShowNearbyParkingsScreen> {
  bool _isLoading = true;
  List<Parking> _parkings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNearbyParkings();
  }

// --- LOGIC: Fetching and Processing Data ---
  Future<void> _fetchNearbyParkings() async {
    // Define the storage instance
    const storage = FlutterSecureStorage();
    final uri = Uri.parse(
        'https://parking-app-zo8j.onrender.com/api/parking-locations/nearby?lat=${widget.lat}&lng=${widget.lng}');

    try {
      // Read the token from secure storage
      final token = await storage.read(key: 'token');
      if (token == null) {
        throw Exception('Auth token not found. Please log in again.');
      }

      // Create the authorization headers
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Make the authenticated API call
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        List<Parking> parkingsWithDistance = data.map((json) {
          final parking = Parking.fromJson(json);
          parking.distance = _getDistanceFromLatLng(
            widget.lat,
            widget.lng,
            parking.lat,
            parking.lng,
          );
          return parking;
        }).toList();

        // Sort by distance
        parkingsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

        setState(() {
          _parkings = parkingsWithDistance;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load parkings: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  // Haversine formula to calculate distance
  double _getDistanceFromLatLng(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371; // Radius of the earth in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = R * c; // Distance in km
    return double.parse(distance.toStringAsFixed(2));
  }

  double _deg2rad(double deg) {
    return deg * (math.pi / 180);
  }

  void _handleBooking(String parkingId, String name) {
    // Navigate to your booking screen, passing the required data
    // Example:
    Navigator.push(context, MaterialPageRoute(builder: (_) => DoBookingScreen(locationId: parkingId, name: name)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Navigate to book for: $name (ID: $parkingId)")),
    );
  }

  // --- UI: Building the Screen ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827), // bg-gray-900
      appBar: AppBar(
        title: Text("Parkings near ${widget.searchLocation}"),
        backgroundColor: const Color(0xFF1F2937), // bg-gray-800
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_parkings.isEmpty) {
      return const Center(
        child: Text(
          "No parking slots available at this location.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200
            ? 3
            : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _parkings.length,
      itemBuilder: (context, index) {
        return _ParkingCard(
          parking: _parkings[index],
          onBook: () => _handleBooking(
              _parkings[index].locationId, _parkings[index].name),
        );
      },
    );
  }
}

// --- UI: Reusable Parking Card Widget ---
class _ParkingCard extends StatelessWidget {
  final Parking parking;
  final VoidCallback onBook;

  const _ParkingCard({required this.parking, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937), // bg-gray-800
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parking.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow(
              // Replaced FontAwesomeIcons.locationDot
              Icons.location_on,
              '${parking.distance} km away'),
          _buildInfoRow(
              // Replaced FontAwesomeIcons.squareParking
              Icons.local_parking,
              'Total Slots: ${parking.totalSlots}'),
          const Divider(color: Colors.grey, height: 24),
          const Text("Available Slots",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          _buildSlotsGrid(),
          const SizedBox(height: 16),
          const Text("Features",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          _buildFeaturesGrid(),
          const SizedBox(height: 8),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24), // bg-yellow-400
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Park Here",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSlotsGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      children: [
        _SlotInfo(
            // Replaced FontAwesomeIcons.motorcycle
            icon: Icons.motorcycle,
            label: "Bike",
            value: parking.bikeSlots,
            color: Colors.blue.shade300),
        _SlotInfo(
            // Replaced FontAwesomeIcons.car
            icon: Icons.directions_car,
            label: "Sedan",
            value: parking.sedanSlots,
            color: Colors.green.shade400),
        _SlotInfo(
            // Replaced FontAwesomeIcons.truck
            icon: Icons.local_shipping,
            label: "Truck",
            value: parking.truckSlots,
            color: Colors.red.shade400),
        _SlotInfo(
            // Replaced FontAwesomeIcons.bus
            icon: Icons.directions_bus,
            label: "Bus",
            value: parking.busSlots,
            color: Colors.yellow.shade600),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      children: [
        _FeatureInfo(
            label: "Charging",
            // Replaced FontAwesomeIcons.chargingStation
            icon: Icons.ev_station,
            available: parking.evCharging),
        _FeatureInfo(
            label: "CCTV",
            // Replaced FontAwesomeIcons.video
            icon: Icons.videocam,
            available: parking.cctvCamera),
        _FeatureInfo(
            label: "Washing",
            // Replaced FontAwesomeIcons.shower
            icon: Icons.local_car_wash,
            available: parking.washing),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 14),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SlotInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _SlotInfo(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text("$label:",
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 4),
          Text(value.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _FeatureInfo extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool available;
  const _FeatureInfo(
      {required this.label, required this.icon, required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue.shade300, size: 14),
          const SizedBox(width: 8),
          Text("$label:",
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(width: 4),
          Icon(
            available
                ? Icons.check_circle // Replaced FontAwesomeIcons.checkCircle
                : Icons.cancel, // Replaced FontAwesomeIcons.timesCircle
            color: available ? Colors.green.shade500 : Colors.red.shade400,
            size: 16,
          ),
        ],
      ),
    );
  }
}

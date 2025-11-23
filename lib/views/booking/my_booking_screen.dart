import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Data Model ---
class Booking {
  final String bookingId;
  final String licensePlate;
  final int slotNumber;
  final String location;
  final String vehicleType;
  final DateTime startTime;
  final DateTime endTime;
  final String paymentMethod;
  final String paymentStatus;
  final String status; // e.g., 'active', 'completed', 'cancelled'
  final double amountPaid;
  final double totalCost;

  Booking({
    required this.bookingId,
    required this.licensePlate,
    required this.slotNumber,
    required this.location,
    required this.vehicleType,
    required this.startTime,
    required this.endTime,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.amountPaid,
    required this.totalCost,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // The toLocal() is used to convert the UTC time (likely from the server) to the device's local time.
    return Booking(
      bookingId: json['bookingId'] as String,
      licensePlate: json['licensePlate'] as String,
      slotNumber: json['slotNumber'] as int,
      location: json['location'] as String,
      vehicleType: json['vehicleType'] as String,
      startTime: DateTime.parse(json['startTime'] as String).toLocal(),
      endTime: DateTime.parse(json['endTime'] as String).toLocal(),
      paymentMethod: json['paymentMethod'] as String,
      paymentStatus: json['paymentStatus'] as String,
      status: json['status'] as String,
      amountPaid: (json['amountPaid'] as num).toDouble(),
      totalCost: (json['totalCost'] as num).toDouble(),
    );
  }
}

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _userId;
  String? _token; // New state variable for the JWT token
  Map<String, dynamic>? _user;

  // Placeholder for the base URL
  static const String _backendUrl = 'https://parking-app-zo8j.onrender.com/api';
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Step 1: Load user data and token from secure storage
  Future<void> _loadAuthData() async {
    final token = await _storage.read(key: 'token');
    final userString = await _storage.read(key: 'user');

    if (userString != null && mounted) {
      try {
        final user = jsonDecode(userString);
        setState(() {
          _user = user;
          _userId = user['userId'];
          _token = token;
        });
      } catch (e) {
        debugPrint('Error decoding user JSON from storage: $e');
      }
    }
  }

  // Step 2: Orchestrate loading the auth data and then fetching bookings
  Future<void> _initializeData() async {
    // 1. Load authentication data first
    await _loadAuthData();

    // 2. Proceed to fetch bookings only if user ID and token are available
    if (_userId != null && _token != null) {
      await _fetchBookings();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint(
          'Authentication data (User ID or Token) missing. Cannot fetch bookings.');
    }
  }

  // Step 3: Fetch bookings using the loaded data
  Future<void> _fetchBookings() async {
    // Safeguard check, though the primary check is in _initializeData
    if (_userId == null || _token == null) {
      debugPrint(
          "Error: Authentication data is incomplete when trying to fetch.");
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      return;
    }

    // Use the loaded _userId and _token
    final url = Uri.parse('$_backendUrl/bookings/user/$_userId');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> jsonList = json.decode(response.body);
          final bookings =
              jsonList.map((json) => Booking.fromJson(json)).toList();
          setState(() {
            _bookings = bookings;
            _isLoading = false;
          });
        } else {
          // Handle API error response (e.g., 404, 500)
          debugPrint('Failed to load bookings. Status: ${response.statusCode}');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Optionally show a user-friendly error message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings History'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Container(
        color: const Color(0xFFF3F4F6), // bg-gray-100
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event_note, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No bookings found.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bookings History',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937), // text-gray-900
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View details of your past parking bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280), // text-gray-500
            ),
          ),
          const SizedBox(height: 24),
          // Responsive Grid Layout using GridView.builder
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 3; // lg:grid-cols-3
              } else if (constraints.maxWidth > 600) {
                crossAxisCount = 2; // md:grid-cols-2
              } else {
                crossAxisCount = 1; // Default to 1 for mobile
              }

              return GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(), // To allow main SingleChildScrollView to scroll
                itemCount: _bookings.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.8, // Adjust aspect ratio for card height
                ),
                itemBuilder: (context, index) {
                  return _buildBookingCard(_bookings[index]);
                },
              );
            },
          ),
          const SizedBox(height: 40),
          // View More Button
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Implement view more logic (e.g., pagination)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B), // bg-yellow-500
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
              child: const Text(
                'View More Bookings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    // Determine the status color based on the booking.status
    Color statusColor;
    String statusText;
    IconData statusIcon;

    final now = DateTime.now().toLocal();
    final isCompleted = now.isAfter(booking.endTime);
    final isUpcoming = now.isBefore(booking.startTime);

    if (booking.status == 'cancelled') {
      statusColor = Colors.red.shade600;
      statusText = 'Cancelled';
      statusIcon = Icons.cancel;
    } else if (isCompleted) {
      statusColor = Colors.blue.shade600;
      statusText = 'Parking Completed';
      statusIcon = Icons.check_circle;
    } else if (isUpcoming) {
      statusColor = Colors.amber.shade600;
      statusText = 'Upcoming';
      statusIcon = Icons.access_time;
    } else {
      statusColor = Colors.green.shade600;
      statusText = 'Ongoing';
      statusIcon = Icons.directions_car;
    }

    final DateFormat formatter = DateFormat('MM/dd/yyyy, hh:mm:ss a');

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // bg-white
          borderRadius: BorderRadius.circular(12.0),
          border: Border(
            left: BorderSide(
              color: statusColor, // Dynamic border color based on status
              width: 4.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title and License Plate
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.licensePlate,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Slot and Location
            _buildDetailRow(
                Icons.local_parking, 'Slot:', booking.slotNumber.toString()),
            _buildDetailRow(Icons.location_on, 'Location:', booking.location),
            _buildDetailRow(Icons.badge, 'Vehicle Type:', booking.vehicleType),

            const Divider(height: 20),

            // Times
            _buildDetailRow(Icons.access_time, 'Start Time:',
                formatter.format(booking.startTime)),
            _buildDetailRow(Icons.access_time_filled, 'End Time:',
                formatter.format(booking.endTime)),

            const Divider(height: 20),

            // Payment
            _buildDetailRow(
                Icons.credit_card, 'Payment Method:', booking.paymentMethod),
            _buildDetailRow(
                Icons.payment, 'Payment Status:', booking.paymentStatus,
                isGood: true),

            const SizedBox(height: 16),

            // Current Status
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Costs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCostText(
                    'Paid:', booking.amountPaid, Colors.green.shade600),
                _buildCostText(
                    'Total:', booking.totalCost, Colors.grey.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool isGood = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280), // text-gray-500
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isGood ? Colors.green.shade600 : Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostText(String label, double amount, Color color) {
    return Row(
      children: [
        Icon(Icons.attach_money, size: 18, color: color),
        Text(
          '$label \$ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Configuration ---
// Assuming you have a file that holds the base URL, similar to VITE_BACKEND_URL
const String _baseUrl =
    'https://parking-app-zo8j.onrender.com/api'; // Replace with your actual base URL
const String _merchantVPA = "yashsandipthorat@okaxis";
// --- Data Models (Simplified for example) ---

// Models for slot and vehicle
class ParkingSlot {
  final String slotId;
  final String locationId;
  final String slotNumber;
  final String vehicleType;
  final bool available;
  final double pricePerHour;
  // Add other necessary fields

  // Note: The location field used in React seems to be the parking location name,
  // which is passed via arguments in Flutter.

  ParkingSlot({
    required this.slotId,
    required this.locationId,
    required this.slotNumber,
    required this.vehicleType,
    required this.available,
    required this.pricePerHour,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      slotId: json['_id'] ?? '',
      locationId: json['parking_lot_id'] ?? '',
      slotNumber: json['slotNumber'] ?? 'N/A',
      vehicleType: json['vehicleType'] ?? 'N/A',
      available: json['available'] ?? false,
      pricePerHour: (json['pricePerHour'] ?? 0.0).toDouble(),
    );
  }
}

class Vehicle {
  final String id;
  final String licensePlate;
  final String type;

  Vehicle({required this.id, required this.licensePlate, required this.type});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['_id'] ?? '',
      licensePlate: json['licensePlate'] ?? 'N/A',
      type: json['vehicleType'] ?? 'car', // Assuming a vehicleType field exists
    );
  }
}

// --- Main Screen Widget ---

class DoBookingScreen extends StatefulWidget {
  final String locationId;
  final String name;

  const DoBookingScreen({
    super.key,
    required this.locationId,
    required this.name,
  });

  @override
  State<DoBookingScreen> createState() => _DoBookingScreenState();
}

class _DoBookingScreenState extends State<DoBookingScreen> {
  // --- State Variables ---
  bool _isLoading = true;
  bool _isBookingLoading = false;
  String _message = "Processing your booking...";
  String _error = "";

  Map<String, dynamic>? _user;
  final _storage = const FlutterSecureStorage();

  // Data
  List<Map<String, dynamic>> _groupedSpots = [];
  List<Vehicle> _vehicles = [];

  // Selected Data
  ParkingSlot? _selectedSpot;
  String _selectedVehicleLicense = "";
  String _transactionId = "";

  // Form Data
  Map<String, dynamic> _formData = {
    'time': 1, // hours (number)
    'paymentMethod': 'credit-card',
    'startTime': DateTime.now()
        .toIso8601String()
        .substring(0, 16), // datetime-local format
    'endTime': '',
    'vehicleNumber': '',
  };

  // --- Initialization ---

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // --- API Calls & Data Fetching ---

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> _fetchAuthData() async {
    try {
      final userString = await _storage.read(key: 'user');

      if (userString != null) {
        if (mounted) {
          setState(() {
            _user = jsonDecode(userString);
          });
        }
      }
    } catch (e) {
      print("Error retrieving auth data from storage: $e");
    }
  }

  Future<void> _fetchInitialData() async {
    // --- STEP 1: START and USER CHECK ---
    print("--- [DEBUG] _fetchInitialData started ---");
    try {
      await _fetchAuthData();
      print("[DEBUG] 1.fetching user data completed successfully.");
    } catch (e) {
      print("[DEBUG] 1. ERROR during _fetchParkingSlots: $e");
      // Continue execution to attempt vehicles fetch, but flag the error.
    }
    if (_user == null) {
      print("[DEBUG] ERROR: _user is null. Aborting initial data fetch.");
      if (mounted) {
        setState(() {
          _error = "User not logged in.";
          _isLoading = false; // Set loading to false so error screen displays
        });
      }
      return;
    }

    print("[DEBUG] User check passed. User ID: ${_user!['userId']}");

    // --- STEP 2: FETCH SLOTS ---
    print("[DEBUG] 1. Starting _fetchParkingSlots...");
    try {
      await _fetchParkingSlots();
      print("[DEBUG] 1. _fetchParkingSlots completed successfully.");
    } catch (e) {
      print("[DEBUG] 1. ERROR during _fetchParkingSlots: $e");
      // Continue execution to attempt vehicles fetch, but flag the error.
    }

    // --- STEP 3: FETCH VEHICLES ---
    print("[DEBUG] 2. Starting _fetchUserVehicles...");
    try {
      await _fetchUserVehicles();
      print("[DEBUG] 2. _fetchUserVehicles completed successfully.");
    } catch (e) {
      print("[DEBUG] 2. ERROR during _fetchUserVehicles: $e");
      // Continue execution.
    }

    // --- STEP 4: CALCULATE END TIME ---
    print("[DEBUG] 3. Starting _calculateEndTime...");
    try {
      _calculateEndTime();
      print(
          "[DEBUG] 3. _calculateEndTime completed. End Time: ${_formData['endTime']}");
    } catch (e) {
      print("[DEBUG] 3. ERROR during _calculateEndTime: $e");
    }

    // --- STEP 5: FINAL STATE UPDATE ---
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      print(
          "--- [DEBUG] _fetchInitialData finished. _isLoading set to false. ---");
    } else {
      print("[DEBUG] WARNING: Widget unmounted before final state update.");
    }
  }

  Future<String> _generateUpiLink(double amount) async {
    // Convert amount to two decimal places
    final String amountStr = amount.toStringAsFixed(2);

    // Note: The structure is specific to the BHIM UPI specification
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _merchantVPA, // Payee Address (VPA)
        'pn': 'SmartPark Solutions', // Payee Name (Merchant name)
        'mc':
            '5541', // Merchant Category Code (MCC) - for parking/services (optional)
        'tr': DateTime.now()
            .millisecondsSinceEpoch
            .toString(), // Transaction Reference ID (Unique ID for reconciliation)
        'am': amountStr, // Amount in Rupees
        'cu': 'INR', // Currency
        'tn':
            'Parking Slot Booking: ${widget.name}', // Transaction Note/Description
      },
    );

    return uri.toString();
  }

  Future<void> _fetchParkingSlots() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final uri =
          Uri.parse('$_baseUrl/parking-slots/parking/${widget.locationId}');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final grouped = data.fold<Map<String, dynamic>>({}, (acc, slotJson) {
          final slot = ParkingSlot.fromJson(slotJson);
          final type = slot.vehicleType;
          if (!acc.containsKey(type)) {
            acc[type] = {
              'vehicleType': type,
              'slots': <ParkingSlot>[],
            };
          }
          acc[type]['slots'].add(slot);
          return acc;
        });

        if (mounted) {
          setState(() {
            _groupedSpots =
                grouped.values.toList().cast<Map<String, dynamic>>();
          });
        }
      } else {
        throw Exception('Failed to load slots: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Error fetching slots: $e");
      print(e);
    }
  }

  Future<void> _fetchUserVehicles() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final userId = _user!['userId'];
      if (userId == null) {
        print("Error: User ID is missing in the stored user map.");
        return;
      }
      final uri = Uri.parse('$_baseUrl/vehicles/user/$userId');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final vehicles = data.map((json) => Vehicle.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _vehicles = vehicles;
            // Auto-select if only one vehicle exists
            if (vehicles.length == 1) {
              _selectedVehicleLicense = vehicles.first.licensePlate;
              _formData['vehicleNumber'] = vehicles.first.licensePlate;
            }
          });
        }
      } else {
        throw Exception('Failed to load vehicles: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching vehicles: $e");
    }
  }

  // --- Booking/Payment Logic ---

  void _showUpiPaymentFlow() async {
    if (_selectedSpot == null) return;

    final double amountPaidDouble =
        _selectedSpot!.pricePerHour * (_formData['time'] as int);
    final upiLink = await _generateUpiLink(amountPaidDouble);

    try {
      // 1. Launch UPI App
      if (await canLaunchUrl(Uri.parse(upiLink))) {
        await launchUrl(
          Uri.parse(upiLink),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Handle the case where no app can open the link
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Could not open UPI app. Please ensure a UPI app is installed.")),
        );
        return;
      }

      // 2. Show Confirmation Dialog (after the user attempts payment)
      _transactionId = "";
      _error = "";
      showDialog(
        context: context,
        barrierDismissible: false, // Prevents closing the dialog accidentally
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setStateInDialog) {
              // Use the original _buildPaymentDialog, which we will modify slightly
              return _buildPaymentDialog(setStateInDialog);
            },
          );
        },
      );
    } catch (e) {
      print("Error launching UPI link: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initiate payment: ${e.toString()}")),
      );
    }
  }

  Future<void> _handleDonePayment() async {
    // 1. Validate Transaction ID
    if (!_transactionId.contains(RegExp(r'^\d{8}$'))) {
      if (mounted) {
        setState(() => _error = "Transaction ID must be an 8-digit number.");
      }
      return;
    }

    Navigator.of(context).pop(); // Close the payment dialog

    if (_selectedSpot == null || _user == null) return;

    // Set global loading
    if (mounted) {
      setState(() {
        _isBookingLoading = true;
        _message = "Reserving your slot...";
      });
    }

    final token = await _getAuthToken();
    if (token == null) return;

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };
    final amountPaid = _selectedSpot!.pricePerHour * (_formData['time'] as int);

    try {
      // 2. Update Slot Availability (PUT)
      await http.put(
        Uri.parse('$_baseUrl/parking-slots/${_selectedSpot!.slotId}'),
        headers: headers,
        body: jsonEncode({'available': false}),
      );

      // 3. Post Payment History (POST)
      if (mounted) setState(() => _message = "Processing payment...");
      await http.post(
        Uri.parse('$_baseUrl/payments'),
        headers: headers,
        body: jsonEncode({
          'userId': _user!['userId'],
          'paymentMethod': _formData['paymentMethod'],
          'status': 'completed',
          'paymentTime': DateTime.now().toIso8601String(),
          'amount': amountPaid,
        }),
      );

      // 4. Post Parking History (POST)
      if (mounted) setState(() => _message = "Saving parking history...");
      await http.post(
        Uri.parse('$_baseUrl/parking-history'),
        headers: headers,
        body: jsonEncode({
          'userId': _user!['userId'],
          'vehicleId': _formData['vehicleNumber'],
          'parking_lot_id': widget.locationId,
          'slotId': _selectedSpot!.slotNumber,
          'paymentId': _transactionId,
          'entryTime': _formData['startTime'],
          'exitTime': _formData['endTime'],
          'amountPaid': amountPaid.toStringAsFixed(2),
        }),
      );

      // 5. Create Booking (POST)
      if (mounted) setState(() => _message = "Finalizing booking...");
      final bookingData = {
        'userId': _user!['userId'],
        'email': _user!['email'],
        'slotId': _selectedSpot!.slotId,
        'slotNumber': _selectedSpot!.slotNumber,
        'location': widget.name, // Using location name from widget
        'amountPaid': amountPaid,
        'startTime': _formData['startTime'],
        'endTime': _formData['endTime'],
        'licensePlate': _formData['vehicleNumber'],
        'vehicleType': _selectedSpot!.vehicleType,
        'paymentMethod': _formData['paymentMethod'],
        'paymentStatus': 'Completed',
        'transactionId': _transactionId,
      };

      await http.post(
        Uri.parse('$_baseUrl/bookings'),
        headers: headers,
        body: jsonEncode(bookingData),
      );

      // 6. Navigation/Cleanup
      if (mounted) {
        Navigator.of(context)
            .popUntil((route) => route.isFirst); // Go back to root
        // You would typically navigate to a Booking confirmation screen or the main dashboard
        // Navigator.of(context).pushReplacementNamed('/booking-success');

        // Simulating the React component's hard refresh (window.location.reload())
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking confirmed successfully!")),
        );
      }
    } catch (e) {
      print("Booking error: $e");
      if (mounted) {
        setState(() {
          _isBookingLoading = false;
          _message = "Error occurred while booking. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isBookingLoading = false);
    }
  }

  // --- Form Handlers ---

  void _calculateEndTime() {
    final startTime = DateTime.tryParse(_formData['startTime'] as String);
    final duration = (_formData['time'] as int).toDouble();

    if (startTime != null && duration > 0) {
      final endTime = startTime.add(Duration(hours: duration.toInt()));
      // Format as 'YYYY-MM-DDTHH:MM' for HTML input consistency
      final formattedEndTime = DateFormat('yyyy-MM-ddTHH:mm').format(endTime);

      if (mounted) {
        setState(() {
          _formData['endTime'] = formattedEndTime;
        });
      }
    }
  }

  void _handleTimeChange(String value) {
    int? time = int.tryParse(value);
    if (time != null && time > 0) {
      if (mounted) {
        setState(() {
          _formData['time'] = time;
        });
        _calculateEndTime();
      }
    }
  }

  void _handleStartTimeChange(String value) {
    if (mounted) {
      setState(() {
        _formData['startTime'] = value;
      });
      _calculateEndTime();
    }
  }

  void _handleVehicleManualChange(String input) {
    // Mimic React's manual vehicle formatting
    String cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String formatted = '';

    if (cleaned.isNotEmpty) formatted += cleaned.substring(0, 2);
    if (cleaned.length > 2) formatted += "-" + cleaned.substring(2, 4);
    if (cleaned.length > 4) formatted += "-" + cleaned.substring(4, 6);
    if (cleaned.length > 6) formatted += "-" + cleaned.substring(6, 10);

    // Simulate validation
    if (!formatted.contains(RegExp(r'^[A-Z]{2}-\d{2}-[A-Z]{2}-\d{4}$'))) {
      _error = "Invalid format! Use: MH-43-AR-0707";
    } else {
      _error = "";
    }

    if (mounted) {
      setState(() {
        _formData['vehicleNumber'] = formatted;
      });
    }
  }

  // --- UI Builder Methods ---

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF3B82F6)), // blue-400
          const SizedBox(height: 20),
          Text(
            _message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildParkingSpotCard(Map<String, dynamic> group) {
    final List<ParkingSlot> slots = group['slots'];
    final String vehicleType = group['vehicleType'];
    final int availableCount = slots.where((s) => s.available).length;
    final int totalCount = slots.length;
    final double avgPrice = slots.isNotEmpty
        ? slots.map((s) => s.pricePerHour).reduce((a, b) => a + b) / totalCount
        : 0.0;

    return Card(
      color: const Color(0xFF1F2937), // dark:bg-gray-800
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color(0xFF1E40AF), width: 1.5), // dark:border-blue-700
      ),
      child: InkWell(
        onTap: availableCount > 0
            ? () {
                final firstAvailable = slots.firstWhere((s) => s.available);
                if (mounted) {
                  setState(() {
                    _selectedSpot = firstAvailable;
                  });
                  _showBookingModal();
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicleType,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Total Slots: $totalCount',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                'Available: $availableCount',
                style: TextStyle(
                  color:
                      availableCount > 0 ? Colors.green[400] : Colors.red[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Avg. Price: \$${avgPrice.toStringAsFixed(2)} / hr',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: availableCount > 0
                    ? ElevatedButton(
                        onPressed: () {
                          final firstAvailable =
                              slots.firstWhere((s) => s.available);
                          if (mounted) {
                            setState(() {
                              _selectedSpot = firstAvailable;
                            });
                            _showBookingModal();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFBBF24), // yellow-500
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Book Now",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    : const Text(
                        "No Slots Available",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInModal) {
            return _buildBookingForm(setStateInModal);
          },
        );
      },
    ).then((_) {
      // Cleanup after modal is closed
      if (mounted) {
        setState(() {
          _selectedSpot = null;
        });
      }
    });
  }

  Widget _buildBookingForm(StateSetter setStateInModal) {
    if (_selectedSpot == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937), // dark:bg-gray-800
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking Slot ${_selectedSpot!.slotNumber}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.grey),

              // Form Fields
              Wrap(
                runSpacing: 16.0,
                spacing: 16.0,
                children: [
                  // Start Time
                  _buildFormField(
                    label: "Start Time",
                    child: TextFormField(
                      initialValue: _formData['startTime'] as String,
                      onChanged: (val) {
                        setStateInModal(() => _handleStartTimeChange(val));
                        if (mounted)
                          setState(() {}); // Trigger main build if necessary
                      },
                      decoration: InputDecoration(
                        hintText: 'YYYY-MM-DD HH:MM',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.datetime,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  // End Time
                  _buildFormField(
                    label: "End Time",
                    child: TextFormField(
                      enabled: false,
                      controller: TextEditingController(
                          text: _formData['endTime'] as String),
                      decoration: InputDecoration(
                        hintText: 'Calculated End Time',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  // Time (Hours)
                  _buildFormField(
                    label: "Time (Hours)",
                    child: TextFormField(
                      initialValue: _formData['time'].toString(),
                      onChanged: (val) {
                        setStateInModal(() => _handleTimeChange(val));
                        if (mounted) setState(() {});
                      },
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  // Vehicle Number
                  _buildFormField(
                    label: "Vehicle Number",
                    spanAll: true,
                    child: _buildVehicleInput(setStateInModal),
                  ),

                  // Payment Method
                  _buildFormField(
                    label: "Payment Method",
                    child: DropdownButtonFormField<String>(
                      value: _formData['paymentMethod'],
                      dropdownColor: const Color(0xFF374151),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                            value: 'credit-card', child: Text('Credit Card')),
                        DropdownMenuItem(
                            value: 'debit-card', child: Text('Debit Card')),
                        DropdownMenuItem(
                            value: 'paypal', child: Text('PayPal')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      ],
                      onChanged: (value) {
                        setStateInModal(
                            () => _formData['paymentMethod'] = value);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),

                  // Total Amount
                  _buildFormField(
                    label: "Total Amount",
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '\$${(_selectedSpot!.pricePerHour * (_formData['time'] as int)).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Check required fields before proceeding
                      if (_formData['startTime'] == null ||
                          (_formData['vehicleNumber'] as String).isEmpty ||
                          _error.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please fill all required fields and fix errors.")),
                        );
                        return;
                      }
                      _showUpiPaymentFlow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24), // yellow-500
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Proceed to Payment"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInput(StateSetter setStateInModal) {
    if (_vehicles.isEmpty) {
      // Manual input if no vehicles
      return TextFormField(
        initialValue: _formData['vehicleNumber'] as String,
        onChanged: (val) {
          setStateInModal(() => _handleVehicleManualChange(val));
        },
        decoration: InputDecoration(
          hintText: 'Enter your vehicle number',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          errorText: _error.isNotEmpty ? _error : null,
        ),
        style: const TextStyle(color: Colors.white),
      );
    }

    // Select dropdown if vehicles exist

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedVehicleLicense.isNotEmpty &&
                  _selectedVehicleLicense != "manual"
              ? _selectedVehicleLicense
              : (_selectedVehicleLicense == "manual" ? "manual" : null),
          hint: const Text("Select a vehicle",
              style: TextStyle(color: Colors.grey)),
          dropdownColor: const Color(0xFF374151),
          style: const TextStyle(color: Colors.white),
          items: [
            ..._vehicles.map((v) => DropdownMenuItem(
                  value: v.licensePlate,
                  child: Text(v.licensePlate),
                )),
            const DropdownMenuItem(
                value: "manual", child: Text("Enter manually")),
          ],
          onChanged: (value) {
            setStateInModal(() {
              _selectedVehicleLicense = value!;
              if (value != "manual") {
                _formData['vehicleNumber'] = value;
                _error = "";
              } else {
                _formData['vehicleNumber'] = "";
              }
            });
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_selectedVehicleLicense == "manual" || _vehicles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextFormField(
              initialValue: _formData['vehicleNumber'] as String,
              onChanged: (val) {
                setStateInModal(() => _handleVehicleManualChange(val));
              },
              decoration: InputDecoration(
                hintText: 'MH-43-AR-0707',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                errorText: _error.isNotEmpty ? _error : null,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildFormField(
      {required String label, required Widget child, bool spanAll = false}) {
    return SizedBox(
      width: spanAll ? double.infinity : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFD1D5DB), // gray-300
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildPaymentDialog(StateSetter setStateInDialog) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937), // dark:bg-gray-800
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        "Payment Successful?",
      ),
      // title: const Text(
      //   "Scan QR & Pay",
      //   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      //   textAlign: TextAlign.center,
      // ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder for QR Code image
            // Image.asset(
            //   'assets/qr_code_placeholder.png', // You need to add a placeholder image in your assets
            //   height: 180,
            //   width: 180,
            //   fit: BoxFit.contain,
            // ),
            // const SizedBox(height: 16),
            const Text(
              "Please complete the payment in the UPI app (GPay/PhonePe) you were redirected to. Once done, enter the Transaction ID below and click 'Confirm'.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Transaction ID Input
            TextField(
              onChanged: (value) {
                setStateInDialog(() {
                  _transactionId = value;
                  _error = value.contains(RegExp(r'^\d{8}$'))
                      ? ""
                      : "Transaction ID must be an 8-digit number.";
                });
              },
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '8-digit Transaction ID *',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF34D399)), // green-500
                ),
                errorText: _error.isNotEmpty ? _error : null,
              ),
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B5563), // gray-600
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleDonePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // green-500
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Done Payment"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    // Check for user loading state (React's initial loading check)
    if (_user == null && !_isLoading) {
      // In Flutter, you would use a Navigator to push a Login screen
      // or return an error widget.
      return const Center(
          child: Text("Please log in to continue.",
              style: TextStyle(color: Colors.white)));
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111827),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Main UI structure
    return Scaffold(
      appBar: AppBar(
        title: Text("Booking for Location: ${widget.name}"),
        backgroundColor: const Color(0xFF111827), // bg-gray-900
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF111827), // bg-gray-900

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text("Error: $_error",
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),

                // Parking Spot Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300, // Max width of a card
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Adjust as needed
                  ),
                  itemCount: _groupedSpots.length,
                  itemBuilder: (context, index) {
                    return _buildParkingSpotCard(_groupedSpots[index]);
                  },
                ),
              ],
            ),
          ),

          // Booking Loading Overlay (Mirrors the React Component)
          if (_isBookingLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }
}

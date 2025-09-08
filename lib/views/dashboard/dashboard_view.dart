import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Main dashboard widget
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  bool _darkMode = false;

  // --- MOCK DATA ---
  // Data for the bottom navigation bar
  final List<Map<String, dynamic>> _navItems = [
    {"label": "Home", "icon": LucideIcons.layoutDashboard},
    {"label": "Bookings", "icon": LucideIcons.bookmark},
    {"label": "History", "icon": LucideIcons.history},
    {"label": "Profile", "icon": LucideIcons.userCircle},
  ];

  // Data for quick action chips
  final List<Map<String, dynamic>> _quickActions = [
    {"label": "Saved", "icon": LucideIcons.heart},
    {"label": "Offers", "icon": LucideIcons.percent},
    {"label": "Wallet", "icon": LucideIcons.wallet},
    {"label": "Support", "icon": LucideIcons.headphones},
  ];

  // Data for recent booking list
  final List<Map<String, String>> _recentBookings = [
    {
      "location": "City Center Mall",
      "details": "Today, 10:30 AM - 1:00 PM",
      "status": "Active"
    },
    {
      "location": "Downtown Plaza",
      "details": "Yesterday, 6:00 PM - 9:00 PM",
      "status": "Completed"
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- THEME DEFINITIONS ---
  ThemeData _buildTheme(bool isDark) {
    final primaryColor = Colors.deepPurple;
    final secondaryColor = Colors.amber;
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
        secondary: secondaryColor,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[500],
        type: BottomNavigationBarType.fixed,
        elevation: 5,
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        bodyMedium: TextStyle(color: subtleTextColor),
      ),
    );
  }

  // --- UI BUILDER METHODS ---

  // Builds the welcome header
  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hello, Alex!",
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          "Where would you like to park?",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  // Builds the main "Find Parking" card with search functionality
  Widget _buildFindParkingCard() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search for a location...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  prefixIcon:
                      const Icon(LucideIcons.search, color: Colors.white),
                  fillColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {/* Handle filter */},
              icon: const Icon(LucideIcons.slidersHorizontal,
                  color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the horizontal list of quick action chips
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Quick Actions", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickActions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final action = _quickActions[index];
              return ActionChip(
                onPressed: () {/* Handle action */},
                avatar: Icon(action["icon"], size: 18),
                label: Text(action["label"]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                backgroundColor: Theme.of(context).cardTheme.color,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              );
            },
          ),
        ),
      ],
    );
  }

  // Builds the list of recent bookings
  Widget _buildRecentBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recent Bookings",
                style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () {/* Handle View All */},
              child: const Text("View All"),
            ),
          ],
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentBookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final booking = _recentBookings[index];
            final bool isActive = booking["status"] == "Active";
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    LucideIcons.parkingCircle,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(booking["location"]!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(booking["details"]!),
                trailing: Chip(
                  label: Text(
                    booking["status"]!,
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: isActive
                      ? Colors.green.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide.none,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false), // Light Theme
      darkTheme: _buildTheme(true), // Dark Theme
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(LucideIcons.parkingCircle,
                color: Colors.deepPurple, size: 28),
          ),
          title: Text(
            "SmartPark",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color),
          ),
          actions: [
            IconButton(
              icon: Icon(_darkMode ? LucideIcons.sun : LucideIcons.moon),
              onPressed: () => setState(() => _darkMode = !_darkMode),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            _buildFindParkingCard(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentBookings(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: _navItems
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(item["icon"]),
                    label: item["label"],
                  ))
              .toList(),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

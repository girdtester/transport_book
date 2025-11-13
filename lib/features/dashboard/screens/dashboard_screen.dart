import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/api_service.dart';
import '../../trucks/screens/my_trucks_screen.dart';
import '../../trips/screens/my_trips_screen.dart';
import '../../party/screens/party_khata_screen.dart';
import '../../trips/screens/add_trip_from_dashboard_screen.dart';
import '../../supplier/screens/supplier_khata_screen.dart';
import '../../driver/screens/driver_khata_screen.dart';
import '../../expenses/screens/my_expenses_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../help/screens/help_screen.dart';
import 'dashboard_menu_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedBottomNavIndex = 0;
  bool _isLoading = true;
  String _firmName = 'TransportBook';

  // Dashboard stats
  int _activeTripsCount = 0;
  int _inactiveTrucksCount = 0;
  double _partyBalance = 0.0;
  double _supplierBalance = 0.0;

  // Recent activity
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'TMS Prime';
      setState(() {
        _firmName = userName;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all dashboard data in one API call
      final dashboardData = await ApiService.getDashboardData();

      if (dashboardData != null) {
        // Extract data from API response
        final activeTrips = dashboardData['activeTrips'] ?? 0;
        final inactiveTrucks = dashboardData['inactiveTrucks'] ?? 0;
        final partyBalance = (dashboardData['partyBalance'] ?? 0).toDouble();
        final supplierBalance = (dashboardData['supplierBalance'] ?? 0).toDouble();
        final recentActivity = List<Map<String, dynamic>>.from(
          dashboardData['recentActivity'] ?? []
        );

        setState(() {
          _activeTripsCount = activeTrips;
          _inactiveTrucksCount = inactiveTrucks;
          _partyBalance = partyBalance;
          _supplierBalance = supplierBalance;
          _recentActivity = recentActivity;
          _isLoading = false;
        });
      } else {
        // Fallback: If new API fails, use old method (4 separate calls)
        await _loadDashboardDataFallback();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading dashboard data: $e');
    }
  }

  // Fallback method using 4 separate API calls (backward compatibility)
  Future<void> _loadDashboardDataFallback() async {
    try {
      // Fetch data concurrently
      final results = await Future.wait([
        ApiService.getAllTrips(),
        ApiService.getTrucks(),
        ApiService.getParties(),
        ApiService.getSuppliers(),
      ]);

      final trips = results[0] as List<dynamic>;
      final trucks = results[1] as List<dynamic>;
      final parties = results[2] as List<dynamic>;
      final suppliers = results[3] as List<dynamic>;

      // Calculate active trips
      int activeTrips = trips.where((trip) {
        final status = trip['status']?.toString().toLowerCase() ?? '';
        return status == 'started' || status == 'in_transit' ||
               status == 'loading' || status == 'active' ||
               status == 'load in progress' || status == 'in progress';
      }).length;

      // Calculate inactive trucks (only Own trucks whose trip is completed)
      int inactiveTrucks = trucks.where((truck) {
        final type = truck['type']?.toString() ?? '';
        final status = truck['status']?.toString().toLowerCase() ?? '';
        return type == 'Own' && (status == 'available' || status == 'inactive');
      }).length;

      // Calculate party outstanding balance
      double totalPartyBalance = 0.0;
      for (var party in parties) {
        final balance = double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0;
        if (balance > 0) {
          totalPartyBalance += balance;
        }
      }

      // Calculate supplier outstanding balance
      double totalSupplierBalance = 0.0;
      for (var supplier in suppliers) {
        final balance = double.tryParse(supplier['balance']?.toString() ?? '0') ?? 0.0;
        if (balance > 0) {
          totalSupplierBalance += balance;
        }
      }

      // Get recent activity (last 10 trips sorted by most recent)
      List<Map<String, dynamic>> activity = [];
      final sortedTrips = List<Map<String, dynamic>>.from(trips);
      sortedTrips.sort((a, b) {
        final dateA = a['createdAt']?.toString() ?? a['startDate']?.toString() ?? '';
        final dateB = b['createdAt']?.toString() ?? b['startDate']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      final recentTrips = sortedTrips.take(10).toList();
      for (var trip in recentTrips) {
        activity.add({
          'tripNumber': trip['lrNumber'] ?? trip['tripNumber'] ?? 'N/A',
          'truckNumber': trip['truckNumber'] ?? 'N/A',
          'partyName': trip['partyName'] ?? 'Unknown Party',
          'origin': trip['origin'] ?? '',
          'destination': trip['destination'] ?? '',
          'status': trip['status'] ?? 'Unknown',
          'date': trip['startDate'] ?? trip['createdAt'] ?? '',
        });
      }

      setState(() {
        _activeTripsCount = activeTrips;
        _inactiveTrucksCount = inactiveTrucks;
        _partyBalance = totalPartyBalance;
        _supplierBalance = totalSupplierBalance;
        _recentActivity = activity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading dashboard data (fallback): $e');
    }
  }

  String _formatCurrency(double amount) {
    // Use Indian currency format with commas
    // For dashboard cards, show compact format for large amounts
    return CurrencyFormatter.formatCompact(amount.toInt());
  }

  Widget _getSelectedScreen() {
    switch (_selectedBottomNavIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const MyTripsScreen();
      case 2:
        return const DashboardMenuScreen();
      case 3:
        return const HelpScreen();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Cards (Full width vertical stack)
            _buildStatCard(
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF4CAF50),
              iconBgColor: const Color(0xFFE8F5E9),
              title: 'Active Trips',
              value: _isLoading ? '...' : _activeTripsCount.toString(),
              valueColor: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyTripsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFFF44336),
              iconBgColor: const Color(0xFFFFEBEE),
              title: 'Inactive Trucks',
              value: _isLoading ? '...' : _inactiveTrucksCount.toString(),
              valueColor: const Color(0xFFF44336),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyTrucksScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF2196F3),
              iconBgColor: const Color(0xFFE3F2FD),
              title: 'Party Balance',
              value: _isLoading ? '...' : _formatCurrency(_partyBalance),
              valueColor: const Color(0xFF2196F3),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PartyKhataScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.business,
              iconColor: const Color(0xFF9C27B0),
              iconBgColor: const Color(0xFFF3E5F5),
              title: 'Truck Suppliers',
              value: _isLoading ? '...' : _formatCurrency(_supplierBalance),
              valueColor: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SupplierKhataScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action Buttons (2x2 grid)
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.local_shipping_outlined,
                    label: 'Add Trip',
                    bgColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTripFromDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'My Expenses',
                    bgColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey.shade300,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyExpensesScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.book_outlined,
                    label: 'Driver Khata',
                    bgColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey.shade300,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DriverKhataScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.trending_up,
                    label: 'Reports',
                    bgColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey.shade300,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Activity Section
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Recent Activity List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentActivity.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No recent activity',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ..._recentActivity.map((activity) {
                // Get status color
                final status = activity['status']?.toString().toLowerCase() ?? '';
                Color statusColor = Colors.grey;
                if (status.contains('complete') || status == 'settled') {
                  statusColor = const Color(0xFF4CAF50); // Green
                } else if (status.contains('active') || status.contains('transit') || status == 'started') {
                  statusColor = const Color(0xFF2196F3); // Blue
                } else if (status.contains('loading')) {
                  statusColor = const Color(0xFFFF9800); // Orange
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip number and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Trip ${activity['tripNumber']}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              activity['status'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Party name
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activity['partyName'] ?? 'Unknown Party',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Route
                      if (activity['origin'] != null && activity['origin'] != '' &&
                          activity['destination'] != null && activity['destination'] != '')
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${activity['origin']} → ${activity['destination']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      // Truck number and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                activity['truckNumber'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (activity['date'] != null && activity['date'] != '')
                            Text(
                              activity['date'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildKhataScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Khata Section',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Quick access to all khata screens',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(Icons.local_shipping_outlined, color: Colors.black87, size: 28),
        ),
        title: Text(
          _firmName,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black87),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedBottomNavIndex,
            selectedItemColor: const Color(0xFF2196F3),
            unselectedItemColor: Colors.grey.shade600,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
            onTap: (index) {
              setState(() {
                _selectedBottomNavIndex = index;
              });
              // Refresh dashboard data when switching back to dashboard tab
              if (index == 0) {
                _loadDashboardData();
              }
            },
            items: [
              // Home
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.home_outlined,
                    size: 26,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home,
                    size: 26,
                  ),
                ),
                label: 'Home',
              ),
              // My Trips
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 26,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment,
                    size: 26,
                  ),
                ),
                label: 'My Trips',
              ),
              // Menus
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.menu,
                    size: 26,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu,
                    size: 26,
                  ),
                ),
                label: 'Menus',
              ),
              // Help
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.help_outline,
                    size: 26,
                  ),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.help,
                    size: 26,
                  ),
                ),
                label: 'Help',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon WITHOUT background - just colored icon
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(width: 16),
            // Title and value
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../trips/screens/add_trip_screen.dart';
import '../../trips/screens/trip_details_screen.dart';
import '../../expenses/screens/add_expense_screen.dart';
import '../../expenses/screens/expense_list_screen.dart';
import '../../documents/screens/documents_screen.dart';
import '../../documents/screens/documents_book_screen.dart';
import '../../emi/screens/emi_book_screen.dart';
import '../../trips/screens/trip_book_screen.dart';
import 'truck_profit_loss_report_screen.dart';

class TruckDetailsScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;

  const TruckDetailsScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
  });

  @override
  State<TruckDetailsScreen> createState() => _TruckDetailsScreenState();
}

class _TruckDetailsScreenState extends State<TruckDetailsScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? truckDetails;
  bool _isLoading = true;

  // Dynamic data
  List<dynamic> _allTrips = [];
  List<dynamic> _filteredTrips = [];
  List<dynamic> _allExpenses = [];
  List<dynamic> _filteredExpenses = [];

  // Calculated values
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _totalProfit = 0.0;
  int _tripDays = 0;
  int _refuelCount = 0;
  int _tripsStarted = 0;

  // Filter states for trips
  String? _selectedTripMonth;

  // Filter states for expenses
  final Set<String> _selectedExpenseTypes = {};

  List<Widget> _buildCombinedList() {
    List<Widget> widgets = [];

    // Add trips (limit to 5)
    int tripsToShow = _filteredTrips.length > 5 ? 5 : _filteredTrips.length;
    for (int i = 0; i < tripsToShow; i++) {
      widgets.add(_buildTripCard(_filteredTrips[i]));
    }

    // Add expenses (limit to 5)
    int expensesToShow = _filteredExpenses.length > 5 ? 5 : _filteredExpenses.length;
    for (int i = 0; i < expensesToShow; i++) {
      widgets.add(_buildExpenseCard(_filteredExpenses[i]));
    }

    return widgets;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when app comes to foreground
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadTruckDetails(),
      _loadTrips(),
      _loadExpenses(),
    ]);
    _calculateSummary();
  }

  Future<void> _loadTruckDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await ApiService.getTruckDetails(widget.truckId);
      if (mounted) {
        setState(() {
          truckDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading truck details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading truck details: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadTruckDetails,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await ApiService.getTripsByTruck(widget.truckId);
      if (mounted) {
        setState(() {
          _allTrips = trips ?? [];
          _filteredTrips = trips ?? [];
        });
        _calculateSummary();
      }
    } catch (e) {
      print('Error loading trips: $e');
      if (mounted) {
        setState(() {
          _allTrips = [];
          _filteredTrips = [];
        });
      }
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final expenses = await ApiService.getExpenses(widget.truckId);
      if (mounted) {
        setState(() {
          _allExpenses = expenses ?? [];
          _filteredExpenses = expenses ?? [];
        });
        _calculateSummary();
      }
    } catch (e) {
      print('Error loading expenses: $e');
      if (mounted) {
        setState(() {
          _allExpenses = [];
          _filteredExpenses = [];
        });
      }
    }
  }

  void _calculateSummary() {
    if (!mounted) return;

    // Calculate revenue from trips
    double revenue = 0.0;
    int tripsStarted = 0;
    int tripDays = 0;

    for (var trip in _allTrips) {
      // Add freight amount to revenue
      final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
      revenue += freightAmount;

      // Count started trips
      if (trip['status'] != 'Pending') {
        tripsStarted++;
      }

      // Calculate trip days if trip is completed
      if (trip['tripStartDate'] != null && trip['tripEndDate'] != null) {
        try {
          final startDate = DateFormat('yyyy-MM-dd').parse(trip['tripStartDate']);
          final endDate = DateFormat('yyyy-MM-dd').parse(trip['tripEndDate']);
          tripDays += endDate.difference(startDate).inDays + 1;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    // Calculate expenses
    double expenses = 0.0;
    int refuelCount = 0;

    for (var expense in _allExpenses) {
      final amount = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0;
      expenses += amount;

      // Count diesel/refuel expenses
      final expenseType = expense['expenseType']?.toString().toLowerCase() ?? '';
      if (expenseType.contains('diesel') || expenseType.contains('fuel')) {
        refuelCount++;
      }
    }

    // Calculate profit
    double profit = revenue - expenses;

    setState(() {
      _totalRevenue = revenue;
      _totalExpenses = expenses;
      _totalProfit = profit;
      _tripDays = tripDays;
      _refuelCount = refuelCount;
      _tripsStarted = tripsStarted;
    });
  }

  void _filterTrips() {
    setState(() {
      _filteredTrips = _allTrips.where((trip) {
        // Month filter
        if (_selectedTripMonth != null) {
          try {
            final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
            final tripMonth = DateFormat('MMMM yyyy').format(tripDate);
            if (tripMonth != _selectedTripMonth) {
              return false;
            }
          } catch (e) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _filterExpenses() {
    setState(() {
      _filteredExpenses = _allExpenses.where((expense) {
        // Expense type filter
        if (_selectedExpenseTypes.isNotEmpty) {
          if (!_selectedExpenseTypes.contains(expense['expenseType']?.toString() ?? '')) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.info,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textWhite,
            size: 26,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.truckNumber,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (truckDetails != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: truckDetails!['status'] == 'On Trip'
                          ? AppColors.info
                          : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${truckDetails!['status']} • ${truckDetails!['location'] ?? ''}',
                    style: TextStyle(
                      color: AppColors.textWhite.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit,
              color: AppColors.textWhite,
            ),
            onPressed: () => _showEditTruckDialog(),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : truckDetails == null
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load truck details',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Driver Info
            if (truckDetails != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LEFT SIDE → Icon + Texts
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_gas_station,
                            size: 30,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 12),

                          // Text + rupee grouped together
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                const TextSpan(text: 'Diesel Balance: '),
                                TextSpan(
                                  text: '₹',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.info, // Same as screenshot
                                  ),
                                ),
                                const TextSpan(
                                  text: '0',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SIDE → Recharge Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text('Recharge'),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 10,),
            if (truckDetails != null && truckDetails!['driver'] != null)

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Driver Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            truckDetails!['driver']['name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)
                    ),
                      child: IconButton(
                        icon: const Icon(Icons.phone, color: AppColors.info),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Action Grid
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  // New way - with image asset
                  _buildActionCard('Diesel Book', Icons.local_gas_station,
                      Colors.pink.shade50, Colors.pink.shade600, 'Diesel'),
                  _buildActionCard(
                      'Documents', Icons.file_copy_sharp, AppColors.info.withOpacity(0.1), AppColors.info.withOpacity(0.8), 'Documents Book'),
                  _buildActionCard(
                      'Maintenance\nBook', Icons.build, Colors.grey.shade100, Colors.grey.shade700, 'Maintenance'),
                  _buildActionCard('Driver & Other\nexpenses',
                      Icons.person, Colors.teal.shade50, Colors.teal.shade600, 'Driver Payment'),
                  _buildActionCard(
                      'EMI Book', Icons.calendar_month, Colors.purple.shade50, Colors.purple.shade600, 'EMI'),
                  _buildActionCard(
                      'Trip Book', Icons.local_shipping, AppColors.info.withOpacity(0.1), AppColors.info, 'Trip Book'),
                  _buildActionCard(
                      'Fastag', Icons.credit_card, Colors.orange.shade50, Colors.orange.shade700, 'Fastag'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profit & Loss Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'PROFIT & LOSS SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dropdown-style button for "All Months"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All Mont...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade700, size: 20),
                          ],
                        ),
                      ),
                      // View Profit Report button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TruckProfitLossReportScreen(
                                    truckId: widget.truckId,
                                    truckNumber: widget.truckNumber,
                                  ),
                                ),
                              );
                              _loadAllData();
                            },
                            child: Text(
                              "View Profit Report",
                              style: TextStyle(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppColors.info, size: 18),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // First row: Revenue, Expenses, Profit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: _buildStatColumn(
                          'Revenue',
                          '₹${_totalRevenue.toStringAsFixed(0)}',
                          AppColors.info,
                        ),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          'Expenses',
                          '₹${_totalExpenses.toStringAsFixed(0)}',
                          Colors.black,
                        ),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          'Profit',
                          '₹${_totalProfit.toStringAsFixed(0)}',
                          _totalProfit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Second row: Trip Days, Refuel, Trips Started
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: _buildStatColumn(
                          'Trip Days',
                          '$_tripDays',
                          Colors.black,
                        ),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          'Refuel',
                          _refuelCount > 0 ? '$_refuelCount' : '--',
                          Colors.black,
                        ),
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          'Trips Started',
                          '$_tripsStarted Trip',
                          Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Trips & Expenses Header
            const SizedBox(height: 24),

// Trips & Expenses Header - REMOVED "Clear Filters" button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'TRIPS & EXPENSES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

// Filter Dropdowns Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Month Filter Dropdown
                  SizedBox(
                    width: 120, // 👈 set the width you want
                    child: InkWell(
                      onTap: () => _showTripMonthFilter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTripMonth ?? 'All Mont...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Trips & Expenses Filter Dropdown
                  SizedBox(
                    width: 160, // 👈 adjust as needed
                    child: InkWell(
                      onTap: () => _showExpenseTypeFilter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedExpenseTypes.isEmpty
                                    ? 'All Trips & Expenses'
                                    : '${_selectedExpenseTypes.length} Selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

// Combined Trips & Expenses List
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Build combined list of trips and expenses
                  if (_filteredTrips.isEmpty && _filteredExpenses.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No trips or expenses found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._buildCombinedList(),
                ],
              ),
            ),


            const SizedBox(height: 100),
          ],
        ),
      ),
    ),
      floatingActionButton: _isLoading
          ? null
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // circular border
            ),
            heroTag: 'add_trip_button',
            onPressed: () async {
              // Try to determine truck type from truckDetails, or show picker
              String truckType = truckDetails?['type']?.toString() ?? 'Own';

              // If truck details are not loaded, ask user to select type
              if (truckDetails == null) {
                final selectedType = await _showTruckTypeDialog();
                if (selectedType == null) return;
                truckType = selectedType;
              }

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTripScreen(
                    truckId: widget.truckId,
                    truckNumber: widget.truckNumber,
                    truckType: truckType,
                  ),
                ),
              );
              // Always reload after returning, regardless of result
              _loadAllData();
            },
            backgroundColor: AppColors.info,
            icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 22),
            label: const Text(
              'Add ',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // circular border
            ),
            heroTag: 'add_expense_button',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddExpenseScreen(
                    truckId: widget.truckId,
                    truckNumber: widget.truckNumber,
                  ),
                ),
              );
              // Always reload after returning, regardless of result
              _loadAllData();
            },
            backgroundColor: AppColors.info,
            icon: const Icon(Icons.auto_graph, color: Colors.white, size: 22),
            label: const Text(
              'Add Expense',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(tripId: trip['id'] ?? 1),
          ),
        );
        _loadAllData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Truck icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_shipping,
                size: 24,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip['status']?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: trip['status'] == 'Settled' ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trip['startDate']?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip['origin'] ?? 'N/A'} - ${trip['destination'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    trip['partyName']?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${trip['freightAmount']?.toString() ?? '0'}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Receipt icon with background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long,
              size: 24,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['expenseType']?.toString() ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense['date']?.toString() ?? 'N/A',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${expense['amount']?.toString() ?? '0'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showTripMonthFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Month',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMonthOption(
                      'All Months',
                      null,
                      setModalState,
                    ),
                    ..._getAvailableMonths().map((month) {
                      return _buildMonthOption(
                        month,
                        month,
                        setModalState,
                      );
                    }).toList(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _filterTrips();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'APPLY FILTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Expense Type',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _getAvailableExpenseTypes().map((type) {
                    return _buildExpenseTypeOption(
                      type,
                      setModalState,
                    );
                  }).toList(),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _filterExpenses();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'APPLY FILTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthOption(String label, String? monthValue, StateSetter setModalState) {
    final isSelected = _selectedTripMonth == monthValue;

    return InkWell(
      onTap: () {
        setModalState(() {
          _selectedTripMonth = monthValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? AppColors.primaryGreen : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTypeOption(String type, StateSetter setModalState) {
    final isSelected = _selectedExpenseTypes.contains(type);

    return InkWell(
      onTap: () {
        setModalState(() {
          if (isSelected) {
            _selectedExpenseTypes.remove(type);
          } else {
            _selectedExpenseTypes.add(type);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? AppColors.primaryGreen : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              type,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getAvailableMonths() {
    final months = <String>{};
    for (var trip in _allTrips) {
      try {
        final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
        final monthStr = DateFormat('MMMM yyyy').format(tripDate);
        months.add(monthStr);
      } catch (e) {
        // Skip invalid dates
      }
    }
    return months.toList()..sort((a, b) => b.compareTo(a)); // Most recent first
  }

  List<String> _getAvailableExpenseTypes() {
    final types = <String>{};
    for (var expense in _allExpenses) {
      final type = expense['expenseType']?.toString() ?? '';
      if (type.isNotEmpty) {
        types.add(type);
      }
    }
    return types.toList()..sort();
  }

  Widget _buildActionCard(
      String label,
      IconData icon,                 // Only IconData now
      Color bgColor,
      Color? iconColor,             // Made optional
      String action,
      ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (action == 'Diesel') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseListScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
                expenseType: 'Diesel',
              ),
            ),
          );
          _loadAllData();
        } else if (action == 'Documents Book') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentsBookScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
              ),
            ),
          );
        } else if (action == 'Maintenance') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseListScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
                expenseType: 'Maintenance',
              ),
            ),
          );
          _loadAllData();
        } else if (action == 'Driver Payment') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseListScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
                expenseType: null,
              ),
            ),
          );
          _loadAllData();
        } else if (action == 'EMI') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmiBookScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
              ),
            ),
          );
        } else if (action == 'Trip Book') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripBookScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
              ),
            ),
          );
          _loadAllData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), // Reduced horizontal padding for wider cards
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon – using Material Icons
            Icon(icon, size: 32, color: iconColor ?? Colors.grey),

            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<String?> _showTruckTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Truck Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Truck details could not be loaded. Please select the truck type:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Own Truck'),
                subtitle: const Text('My truck'),
                onTap: () => Navigator.pop(context, 'Own'),
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.orange),
                title: const Text('Market Truck'),
                subtitle: const Text('Hired truck'),
                onTap: () => Navigator.pop(context, 'Market'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTruckDialog() {
    final truckNumberController = TextEditingController(text: widget.truckNumber);
    String selectedTruckType = truckDetails?['type']?.toString() ?? 'Own';

    final List<String> truckTypes = ['Own', 'Market'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Truck Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: truckNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Truck Number',
                    hintText: 'Enter truck number',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                // Truck Type Dropdown
                DropdownButtonFormField<String>(
                  value: selectedTruckType,
                  decoration: const InputDecoration(
                    labelText: 'Truck Type',
                    border: OutlineInputBorder(),
                  ),
                  items: truckTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            type == 'Own' ? Icons.check_circle : Icons.local_shipping,
                            color: type == 'Own' ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(type == 'Own' ? 'Own Truck' : 'Market Truck'),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      selectedTruckType = value ?? 'Own';
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (truckNumberController.text.isNotEmpty) {
                        // Call API to update truck
                        final success = await ApiService.updateTruck(
                          truckId: widget.truckId,
                          truckNumber: truckNumberController.text,
                          truckType: selectedTruckType,
                        );

                        if (success && mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Truck updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Reload the screen with new data
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TruckDetailsScreen(
                                truckId: widget.truckId,
                                truckNumber: truckNumberController.text,
                              ),
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update truck'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


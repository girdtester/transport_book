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
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.appBarTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.truckNumber,
              style: TextStyle(
                color: AppColors.appBarTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (truckDetails != null)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: truckDetails!['status'] == 'On Trip'
                          ? Colors.blue
                          : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${truckDetails!['status']} • ${truckDetails!['location'] ?? ''}',
                    style: TextStyle(
                      color: AppColors.appBarTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showEditTruckDialog(),
            icon: Icon(Icons.edit, color: AppColors.appBarTextColor, size: 18),
            label: Text(
              'Edit',
              style: TextStyle(color: AppColors.appBarTextColor),
            ),
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
                      if (truckDetails!['driver'] != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                              IconButton(
                                icon: const Icon(Icons.phone, color: Colors.blue),
                                onPressed: () {},
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
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            _buildActionCard('Diesel Book', Icons.local_gas_station,
                                Colors.pink.shade50, Colors.red.shade400, 'Diesel'),
                            _buildActionCard(
                                'Documents', Icons.description, Colors.blue.shade50, Colors.blue.shade600, 'Documents Book'),
                            _buildActionCard(
                                'Maintenance\nBook', Icons.build, Colors.grey.shade100, Colors.grey.shade600, 'Maintenance'),
                            _buildActionCard('Driver & Other\nexpenses',
                                Icons.person, Colors.teal.shade50, Colors.teal.shade600, 'Driver Payment'),
                            _buildActionCard(
                                'EMI Book', Icons.calendar_today, Colors.purple.shade50, Colors.purple.shade600, 'EMI'),
                            _buildActionCard(
                                'Trip Book', Icons.local_shipping, Colors.blue.shade50, Colors.blue.shade700, 'Trip Book'),
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
                                const Text('All Months'),
                                ElevatedButton.icon(
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
                                    // Always reload after returning
                                    _loadAllData();
                                  },
                                  icon: const Icon(Icons.assessment, size: 16, color: Colors.white),
                                  label: const Text('View P&L Report', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn(
                                  'Revenue',
                                  '₹${_totalRevenue.toStringAsFixed(0)}',
                                  Colors.black,
                                ),
                                _buildStatColumn(
                                  'Expenses',
                                  '₹${_totalExpenses.toStringAsFixed(0)}',
                                  Colors.black,
                                ),
                                _buildStatColumn(
                                  'Profit',
                                  '₹${_totalProfit.toStringAsFixed(0)}',
                                  _totalProfit >= 0 ? Colors.green : Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatColumn(
                                  'Trip Days',
                                  '$_tripDays',
                                  Colors.black,
                                ),
                                _buildStatColumn(
                                  'Refuel',
                                  '$_refuelCount',
                                  Colors.black,
                                ),
                                _buildStatColumn(
                                  'Trips Started',
                                  '$_tripsStarted',
                                  Colors.black,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Trips & Expenses Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TRIPS & EXPENSES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTripMonth = null;
                                  _selectedExpenseTypes.clear();
                                  _filterTrips();
                                  _filterExpenses();
                                });
                              },
                              child: const Text(
                                'Clear Filters',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Trips Section
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Trips',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showTripMonthFilter(),
                                      icon: const Icon(Icons.filter_list, size: 16),
                                      label: Text(
                                        _selectedTripMonth ?? 'All Months',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TripBookScreen(
                                              truckId: widget.truckId,
                                              truckNumber: widget.truckNumber,
                                            ),
                                          ),
                                        );
                                        // Always reload after returning
                                        _loadAllData();
                                      },
                                      child: const Text(
                                        'View All >',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (_filteredTrips.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No trips found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(
                                _filteredTrips.length > 5 ? 5 : _filteredTrips.length,
                                (index) {
                                  final trip = _filteredTrips[index];
                                  return _buildTripCard(trip);
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Expenses Section
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showExpenseTypeFilter(),
                                      icon: const Icon(Icons.filter_list, size: 16),
                                      label: Text(
                                        _selectedExpenseTypes.isEmpty
                                            ? 'All Types'
                                            : '${_selectedExpenseTypes.length} Selected',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExpenseListScreen(
                                              truckId: widget.truckId,
                                              truckNumber: widget.truckNumber,
                                              expenseType: null, // Show all expenses
                                            ),
                                          ),
                                        );
                                        // Always reload after returning
                                        _loadAllData();
                                      },
                                      child: const Text(
                                        'View All >',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (_filteredExpenses.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'No expenses found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(
                                _filteredExpenses.length > 5 ? 5 : _filteredExpenses.length,
                                (index) {
                                  final expense = _filteredExpenses[index];
                                  return _buildExpenseCard(expense);
                                },
                              ),
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
                  backgroundColor: AppColors.primaryGreen,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Trip',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
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
                  backgroundColor: Colors.blue,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
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
        // Reload data when returning from trip details
        _loadAllData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping,
              size: 32,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: trip['status'] == 'Settled' ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip['status']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip['origin'] ?? 'N/A'} → ${trip['destination'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trip['partyName']?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    trip['startDate']?.toString() ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${trip['freightAmount']?.toString() ?? '0'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt,
            size: 32,
            color: Colors.grey.shade600,
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
                if (expense['paymentMode'] != null)
                  Text(
                    'Payment: ${expense['paymentMode']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '₹${expense['amount']?.toString() ?? '0'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
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

  Widget _buildActionCard(String label, IconData icon, Color bgColor, Color iconColor, String action) {
    return InkWell(
      onTap: () async {
        if (action == 'Diesel') {
          // Open diesel expense list
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
          // Always reload after returning
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
          // Always reload after returning
          _loadAllData();
        } else if (action == 'Driver Payment') {
          // Show ALL truck-related expenses (no expenseType filter)
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseListScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
                expenseType: null, // Show all expenses for this truck
              ),
            ),
          );
          // Always reload after returning
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
          // Always reload after returning
          _loadAllData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
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
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (truckNumberController.text.isNotEmpty) {
                      // Call API to update truck number
                      final success = await ApiService.updateTruck(
                        truckId: widget.truckId,
                        truckNumber: truckNumberController.text,
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
    );
  }
}

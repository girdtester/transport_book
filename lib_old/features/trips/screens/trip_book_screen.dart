import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'add_trip_screen.dart';
import 'trip_details_screen.dart';
import 'trip_book_report_screen.dart';

class TripBookScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;

  const TripBookScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
  });

  @override
  State<TripBookScreen> createState() => _TripBookScreenState();
}

class _TripBookScreenState extends State<TripBookScreen> {
  List<dynamic> _trips = [];
  List<dynamic> _expenses = [];
  bool _isLoading = true;
  String _selectedMonth = 'All Months';
  String _selectedFilter = 'All Trips';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  // Get status color based on trip status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Load in Progress':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Completed':
        return Colors.purple;
      case 'POD Received':
        return Colors.indigo;
      case 'POD Submitted':
        return Colors.teal;
      case 'Settled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
    });

    // Fetch both trips and expenses for this truck
    final trips = await ApiService.getTripsByTruck(widget.truckId);
    final expenses = await ApiService.getExpenses(widget.truckId);

    print('=== TRIP BOOK DEBUG ===');
    print('Total trips fetched: ${trips.length}');
    print('Total expenses fetched: ${expenses.length}');
    if (trips.isNotEmpty) {
      print('First trip data: ${trips[0]}');
    }
    if (expenses.isNotEmpty) {
      print('First expense data: ${expenses[0]}');
    }

    // Store expenses
    _expenses = expenses;

    // Apply filters
    List<dynamic> filteredTrips = trips;

    // Apply date filter
    if (_selectedMonth == 'Last 3 Months') {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      filteredTrips = filteredTrips.where((trip) {
        try {
          final dateStr = trip['startDate']?.toString() ?? '';
          if (dateStr.isEmpty) return false;
          // Try to parse as ISO format first (yyyy-MM-dd), then try other formats
          DateTime tripDate;
          try {
            tripDate = DateTime.parse(dateStr); // ISO format
          } catch (e) {
            tripDate = DateFormat('dd MMM yyyy').parse(dateStr); // Fallback format
          }
          return tripDate.isAfter(threeMonthsAgo);
        } catch (e) {
          print('Error parsing date for trip: $e, dateStr: ${trip['startDate']}');
          return false;
        }
      }).toList();
    } else if (_selectedMonth == 'Custom' && _customStartDate != null && _customEndDate != null) {
      filteredTrips = filteredTrips.where((trip) {
        try {
          final dateStr = trip['startDate']?.toString() ?? '';
          if (dateStr.isEmpty) return false;
          // Try to parse as ISO format first (yyyy-MM-dd), then try other formats
          DateTime tripDate;
          try {
            tripDate = DateTime.parse(dateStr); // ISO format
          } catch (e) {
            tripDate = DateFormat('dd MMM yyyy').parse(dateStr); // Fallback format
          }
          return tripDate.isAfter(_customStartDate!.subtract(const Duration(days: 1))) &&
                 tripDate.isBefore(_customEndDate!.add(const Duration(days: 1)));
        } catch (e) {
          print('Error parsing date for trip: $e, dateStr: ${trip['startDate']}');
          return false;
        }
      }).toList();
    }

    // Apply status filter
    if (_selectedFilter != 'All Trips') {
      filteredTrips = filteredTrips.where((trip) {
        final status = trip['status']?.toString() ?? '';
        if (_selectedFilter == 'Active Trips') {
          return status != 'Settled';
        } else if (_selectedFilter == 'Settled Trips') {
          return status == 'Settled';
        } else if (_selectedFilter == 'In Progress') {
          return status == 'In Progress';
        } else if (_selectedFilter == 'Due Trips') {
          return status == 'POD Submitted';
        }
        return true;
      }).toList();
    }

    print('After filters: ${filteredTrips.length} trips remaining');
    print('Filter settings: Month=$_selectedMonth, Status=$_selectedFilter');

    setState(() {
      _trips = filteredTrips;
      _isLoading = false;
    });
  }

  double _calculateTotalRevenue() {
    print('Calculating revenue from ${_trips.length} trips');
    double total = _trips.fold(0.0, (sum, trip) {
      // Revenue is the freight amount for each trip
      final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0;
      print('Trip ${trip['id']}: freightAmount=$freightAmount');
      return sum + freightAmount;
    });
    print('Total revenue: $total');
    return total;
  }

  double _calculateTotalExpenses() {
    // Sum expenses from the truck expenses table (same as truck details screen)
    print('Calculating expenses from ${_expenses.length} expenses');
    double total = _expenses.fold(0.0, (sum, expense) {
      final amount = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
      print('Expense ${expense['id']}: amount=$amount, category=${expense['category']}');
      return sum + amount;
    });
    print('Total expenses: $total');
    return total;
  }

  double _calculateTotalProfit() {
    return _calculateTotalRevenue() - _calculateTotalExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Book',
              style: TextStyle(
                color: AppColors.appBarTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.truckNumber,
              style: TextStyle(
                color: AppColors.appBarTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.green.shade700, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripBookReportScreen(
                    truckNumber: widget.truckNumber,
                    trips: _trips,
                    totalRevenue: _calculateTotalRevenue(),
                    totalExpenses: _calculateTotalExpenses(),
                    totalProfit: _calculateTotalProfit(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Dropdowns
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showMonthFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedMonth == 'Custom' && _customStartDate != null && _customEndDate != null
                                  ? '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM').format(_customEndDate!)}'
                                  : _selectedMonth,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTripStatusFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedFilter,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Trip Revenue', _calculateTotalRevenue()),
                _buildSummaryItem('Trip Expenses', _calculateTotalExpenses()),
                _buildSummaryItem('Trip Profit', _calculateTotalProfit()),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Trips List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No trips found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) {
                          final trip = _trips[index];
                          final status = trip['status']?.toString() ?? 'Settled';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Party Name and Amount
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        trip['partyName']?.toString() ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '₹${trip['freightAmount']?.toString() ?? '0'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Route with Full Arrow Line
                                Row(
                                  children: [
                                    // Origin
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trip['origin']?.toString() ?? 'Origin',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            trip['startDate']?.toString() ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Full Arrow Line Design
                                    Expanded(
                                      flex: 2,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Full horizontal line
                                          Container(
                                            height: 1.5,
                                            color: Colors.grey.shade300,
                                          ),
                                          // Circle with arrow in the middle
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward,
                                              size: 18,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Destination
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            trip['destination']?.toString() ?? 'Destination',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            trip['startDate']?.toString() ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Status and View Trip Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        // Navigate to trip details and wait for result
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TripDetailsScreen(
                                              tripId: trip['id'] ?? 1,
                                            ),
                                          ),
                                        );

                                        // Reload trips if any changes were made
                                        if (result == true || result == null) {
                                          await _loadTrips();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'View Trip',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_trip_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTripScreen(
                truckId: widget.truckId,
                truckNumber: widget.truckNumber,
                truckType: 'Own',
              ),
            ),
          );
          if (result == true) {
            _loadTrips();
          }
        },
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: const Text(
          'Add Trip',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummaryItem(String label, double value) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: label.contains('Profit') ? Colors.green.shade700 : Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  void _showMonthFilter() {
    String tempSelected = _selectedMonth;
    DateTime? tempStartDate = _customStartDate;
    DateTime? tempEndDate = _customEndDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Date Range',
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
              const SizedBox(height: 16),
              _buildRadioOption(
                'All Months',
                tempSelected == 'All Months',
                () {
                  setModalState(() {
                    tempSelected = 'All Months';
                  });
                },
              ),
              _buildRadioOption(
                'Last 3 Months',
                tempSelected == 'Last 3 Months',
                () {
                  setModalState(() {
                    tempSelected = 'Last 3 Months';
                  });
                },
              ),
              _buildRadioOption(
                'Custom',
                tempSelected == 'Custom',
                () {
                  setModalState(() {
                    tempSelected = 'Custom';
                  });
                },
              ),

              // Show date pickers when Custom is selected
              if (tempSelected == 'Custom') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: tempStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              tempStartDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tempStartDate != null
                                    ? DateFormat('dd MMM yyyy').format(tempStartDate!)
                                    : 'Select start date',
                                style: TextStyle(
                                  color: tempStartDate != null ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: tempEndDate ?? DateTime.now(),
                            firstDate: tempStartDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              tempEndDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tempEndDate != null
                                    ? DateFormat('dd MMM yyyy').format(tempEndDate!)
                                    : 'Select end date',
                                style: TextStyle(
                                  color: tempEndDate != null ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Validate custom dates if selected
                    if (tempSelected == 'Custom' && (tempStartDate == null || tempEndDate == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select both start and end dates')),
                      );
                      return;
                    }

                    setState(() {
                      _selectedMonth = tempSelected;
                      _customStartDate = tempStartDate;
                      _customEndDate = tempEndDate;
                    });
                    Navigator.pop(context);
                    _loadTrips(); // Trigger API call with filters
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply',
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

  void _showTripStatusFilter() {
    String tempSelected = _selectedFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Status',
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
              const SizedBox(height: 16),
              _buildRadioOption(
                'Active Trips (Not Settled)',
                tempSelected == 'Active Trips',
                () {
                  setModalState(() {
                    tempSelected = 'Active Trips';
                  });
                },
              ),
              _buildRadioOption(
                'All Trips',
                tempSelected == 'All Trips',
                () {
                  setModalState(() {
                    tempSelected = 'All Trips';
                  });
                },
              ),
              _buildRadioOption(
                'Due Trips (POD Submitted)',
                tempSelected == 'Due Trips',
                () {
                  setModalState(() {
                    tempSelected = 'Due Trips';
                  });
                },
              ),
              _buildRadioOption(
                'Settled Trips',
                tempSelected == 'Settled Trips',
                () {
                  setModalState(() {
                    tempSelected = 'Settled Trips';
                  });
                },
              ),
              _buildRadioOption(
                'In Progress (Started)',
                tempSelected == 'In Progress',
                () {
                  setModalState(() {
                    tempSelected = 'In Progress';
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = tempSelected;
                    });
                    Navigator.pop(context);
                    _loadTrips(); // Trigger API call with filters
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply',
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

  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

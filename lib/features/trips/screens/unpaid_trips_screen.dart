import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/appbar.dart';
import 'add_trip_screen.dart';
import 'trip_details_screen.dart';
import 'add_trip_from_dashboard_screen.dart';
import '../widgets/trip_status_dialogs.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class UnpaidTripsScreen extends StatefulWidget {
  const UnpaidTripsScreen({super.key});

  @override
  State<UnpaidTripsScreen> createState() => _UnpaidTripsScreenState();
}

class _UnpaidTripsScreenState extends State<UnpaidTripsScreen> {
  List<dynamic> _allTrips = [];
  List<dynamic> _filteredTrips = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Filter states
  final Set<String> _selectedTrucks = {};
  final Set<String> _selectedParties = {};
  final Set<String> _selectedRoutes = {};
  final Set<String> _selectedStatuses = {};
  String _selectedPODFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
    });

    final allTrips = await ApiService.getAllTrips();
    // Filter only unpaid trips (status != 'Settled')
    final unpaidTrips = allTrips.where((trip) {
      final status = trip['status']?.toString() ?? '';
      return status != 'Settled';
    }).toList();

    setState(() {
      _allTrips = unpaidTrips;
      _filteredTrips = unpaidTrips;
      _isLoading = false;
    });
  }

  void _filterTrips() {
    setState(() {
      _filteredTrips = _allTrips.where((trip) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final searchLower = _searchQuery.toLowerCase();
          final truckNumber = trip['truckNumber']?.toString().toLowerCase() ?? '';
          final party = trip['partyName']?.toString().toLowerCase() ?? '';
          final lrNumber = trip['lrNumber']?.toString().toLowerCase() ?? '';
          if (!truckNumber.contains(searchLower) &&
              !party.contains(searchLower) &&
              !lrNumber.contains(searchLower)) {
            return false;
          }
        }

        // Truck filter
        if (_selectedTrucks.isNotEmpty) {
          if (!_selectedTrucks.contains(trip['truckNumber']?.toString() ?? '')) {
            return false;
          }
        }

        // Party filter
        if (_selectedParties.isNotEmpty) {
          if (!_selectedParties.contains(trip['partyName']?.toString() ?? '')) {
            return false;
          }
        }

        // Routes filter
        if (_selectedRoutes.isNotEmpty) {
          final route = '${trip['origin']} to ${trip['destination']}';
          if (!_selectedRoutes.contains(route)) {
            return false;
          }
        }

        // Status filter
        if (_selectedStatuses.isNotEmpty) {
          if (!_selectedStatuses.contains(trip['status']?.toString() ?? '')) {
            return false;
          }
        }

        // POD Challan filter
        if (_selectedPODFilter.isNotEmpty) {
          // Implement POD filter logic
        }

        // Date filter
        if (_startDate != null && _endDate != null) {
          try {
            final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
            if (tripDate.isBefore(_startDate!) || tripDate.isAfter(_endDate!)) {
              return false;
            }
          } catch (e) {
            // Skip invalid dates
          }
        }

        // Month filter
        if (_selectedMonth != null) {
          try {
            final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
            final tripMonth = DateFormat('MMMM yyyy').format(tripDate);
            if (tripMonth != _selectedMonth) {
              return false;
            }
          } catch (e) {
            // Skip invalid dates
          }
        }

        return true;
      }).toList();
    });
  }

  void _applyFilters() {
    _filterTrips();
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _selectedTrucks.clear();
      _selectedParties.clear();
      _selectedRoutes.clear();
      _selectedStatuses.clear();
      _selectedPODFilter = '';
      _startDate = null;
      _endDate = null;
      _selectedMonth = null;
      _searchQuery = '';
      _filteredTrips = _allTrips;
    });
    _filterTrips();
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedTrucks.isNotEmpty) count++;
    if (_selectedParties.isNotEmpty) count++;
    if (_selectedRoutes.isNotEmpty) count++;
    if (_selectedStatuses.isNotEmpty) count++;
    if (_selectedPODFilter.isNotEmpty) count++;
    if (_startDate != null && _endDate != null) count++;
    if (_selectedMonth != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  bool _hasActiveFilters() {
    return _getActiveFiltersCount() > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: CustomAppBar(
        title: 'Unpaid Trips',
        showBackButton: true,
      ),

      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterTrips();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for Trips',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showFiltersPanel(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Applied Banner
          if (_hasActiveFilters())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: AppColors.info.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_getActiveFiltersCount()} Filter${_getActiveFiltersCount() == 1 ? '' : 's'} has been applied',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Trips List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoader())
                : _filteredTrips.isEmpty
                    ? const Center(child: Text('No unpaid trips found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _filteredTrips[index];
                          return _buildTripCard(trip);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_trip_fab_unpaid_trips',
        onPressed: () async {
          // Navigate to add trip screen and wait for result
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTripFromDashboardScreen(),
            ),
          );
          // Reload trips after coming back from add trip screen
          await _loadTrips();
          _filterTrips();
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: const Text(
          'ADD TRIP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final isMarket = trip['truckType'] == 'Market';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(tripId: trip['id'] ?? 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party and Amount Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['partyName']?.toString() ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            trip['truckNumber']?.toString() ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                          if (isMarket) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Market',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '₹${trip['freightAmount']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, size: 14),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route Row with Better Line Design
            Row(
              children: [
                // Origin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['origin']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trip['startDate']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Route Line with Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 1.5,
                            color: Colors.grey.shade300,
                          ),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          Container(
                            width: 40,
                            height: 1.5,
                            color: Colors.grey.shade300,
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
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
                        trip['destination']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trip['startDate']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status and LR Number with Status Update Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trip['status']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      trip['lrNumber']?.toString() ?? '#LRN-000',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Update Action Button on Right
                    if (TripStatusDialogs.getNextActionText(trip['status']?.toString() ?? '') != null)
                      InkWell(
                        onTap: () {
                          TripStatusDialogs.showStatusUpdateDialog(
                            context,
                            tripId: trip['id'] ?? 0,
                            currentStatus: trip['status']?.toString() ?? '',
                            onSuccess: () async {
                              // Reload trips after status update
                              await _loadTrips();
                              _filterTrips();
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            TripStatusDialogs.getNextActionText(trip['status']?.toString() ?? '') ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFiltersPanel() {
    String currentFilter = 'Truck';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
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

              // Filter Content
              Expanded(
                child: Row(
                  children: [
                    // Left Sidebar
                    Container(
                      width: 140,
                      color: Colors.grey.shade100,
                      child: ListView(
                        children: [
                          _buildFilterTab('Start Date', currentFilter == 'Start Date', () {
                            setModalState(() {
                              currentFilter = 'Start Date';
                            });
                          }),
                          _buildFilterTab('Trip Status', currentFilter == 'Trip Status', () {
                            setModalState(() {
                              currentFilter = 'Trip Status';
                            });
                          }),
                          _buildFilterTab('POD Challan', currentFilter == 'POD Challan', () {
                            setModalState(() {
                              currentFilter = 'POD Challan';
                            });
                          }),
                          _buildFilterTab('Truck', currentFilter == 'Truck', () {
                            setModalState(() {
                              currentFilter = 'Truck';
                            });
                          }),
                          _buildFilterTab('Party', currentFilter == 'Party', () {
                            setModalState(() {
                              currentFilter = 'Party';
                            });
                          }),
                          _buildFilterTab('Routes', currentFilter == 'Routes', () {
                            setModalState(() {
                              currentFilter = 'Routes';
                            });
                          }),
                        ],
                      ),
                    ),

                    // Right Content
                    Expanded(
                      child: _buildFilterContent(currentFilter, setModalState),
                    ),
                  ],
                ),
              ),

              // Bottom Bar
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_getSelectedFiltersCount()} Trips',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'have been selected',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _applyFilters(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'APPLY FILTERS',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.info : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent(String filterType, StateSetter setModalState) {
    switch (filterType) {
      case 'Start Date':
        return _buildStartDateFilter(setModalState);
      case 'Trip Status':
        return _buildTripStatusFilter(setModalState);
      case 'POD Challan':
        return _buildPODChallanFilter(setModalState);
      case 'Truck':
        return _buildTruckFilter(setModalState);
      case 'Party':
        return _buildPartyFilter(setModalState);
      case 'Routes':
        return _buildRoutesFilter(setModalState);
      default:
        return Container();
    }
  }

  Widget _buildStartDateFilter(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton(
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.info,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.info, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Choose Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ),

          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 12),
            Text(
              '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Choose Trip Start Month',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Month options - dynamically generated from trip data
          ..._getAvailableMonths().map((month) {
            final tripCount = _calculateTripCount(month: month);
            return _buildCheckboxOption(
              month,
              _selectedMonth == month,
              '($tripCount ${tripCount == 1 ? 'Trip' : 'Trips'})',
              () {
                setModalState(() {
                  _selectedMonth = _selectedMonth == month ? null : month;
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTripStatusFilter(StateSetter setModalState) {
    // Extract unique statuses from actual trip data
    final statuses = _allTrips
        .map((t) => t['status']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: statuses.map((status) {
        final tripCount = _calculateTripCount(status: status);
        return _buildCheckboxOption(
          status,
          _selectedStatuses.contains(status),
          '($tripCount ${tripCount == 1 ? 'Trip' : 'Trips'})',
          () {
            setModalState(() {
              if (_selectedStatuses.contains(status)) {
                _selectedStatuses.remove(status);
              } else {
                _selectedStatuses.add(status);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPODChallanFilter(StateSetter setModalState) {
    final uploadedCount = _calculateTripCount(podFilter: 'Uploaded');
    final notUploadedCount = _calculateTripCount(podFilter: 'Not Uploaded');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCheckboxOption(
          'Uploaded',
          _selectedPODFilter == 'Uploaded',
          '($uploadedCount ${uploadedCount == 1 ? 'Trip' : 'Trips'})',
          () {
            setModalState(() {
              _selectedPODFilter = _selectedPODFilter == 'Uploaded' ? '' : 'Uploaded';
            });
          },
        ),
        _buildCheckboxOption(
          'Not Uploaded',
          _selectedPODFilter == 'Not Uploaded',
          '($notUploadedCount ${notUploadedCount == 1 ? 'Trip' : 'Trips'})',
          () {
            setModalState(() {
              _selectedPODFilter = _selectedPODFilter == 'Not Uploaded' ? '' : 'Not Uploaded';
            });
          },
        ),
      ],
    );
  }

  Widget _buildTruckFilter(StateSetter setModalState) {
    final trucks = _allTrips
        .map((t) => t['truckNumber']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'My Trucks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: trucks.map((truck) {
              final tripCount = _calculateTripCount(truck: truck);
              return _buildCheckboxOption(
                truck,
                _selectedTrucks.contains(truck),
                '($tripCount ${tripCount == 1 ? 'Trip' : 'Trips'})',
                () {
                  setModalState(() {
                    if (_selectedTrucks.contains(truck)) {
                      _selectedTrucks.remove(truck);
                    } else {
                      _selectedTrucks.add(truck);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPartyFilter(StateSetter setModalState) {
    final parties = _allTrips
        .map((t) => t['partyName']?.toString() ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: parties.map((party) {
        final tripCount = _calculateTripCount(party: party);
        return _buildCheckboxOption(
          party,
          _selectedParties.contains(party),
          '($tripCount ${tripCount == 1 ? 'Trip' : 'Trips'})',
          () {
            setModalState(() {
              if (_selectedParties.contains(party)) {
                _selectedParties.remove(party);
              } else {
                _selectedParties.add(party);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildRoutesFilter(StateSetter setModalState) {
    final routes = _allTrips
        .map((t) => '${t['origin']} to ${t['destination']}')
        .where((r) => r != ' to ')
        .toSet()
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for a City',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: routes.map((route) {
              final tripCount = _calculateTripCount(route: route);
              return _buildCheckboxOption(
                route,
                _selectedRoutes.contains(route),
                '($tripCount ${tripCount == 1 ? 'Trip' : 'Trips'})',
                () {
                  setModalState(() {
                    if (_selectedRoutes.contains(route)) {
                      _selectedRoutes.remove(route);
                    } else {
                      _selectedRoutes.add(route);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(String title, bool isSelected, String count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.info : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? AppColors.info : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getSelectedFiltersCount() {
    return _filteredTrips.length;
  }

  // Helper method to calculate trip count for a specific filter option
  int _calculateTripCount({
    String? month,
    String? status,
    String? podFilter,
    String? truck,
    String? party,
    String? route,
  }) {
    return _allTrips.where((trip) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final truckNumber = trip['truckNumber']?.toString().toLowerCase() ?? '';
        final partyName = trip['partyName']?.toString().toLowerCase() ?? '';
        final lrNumber = trip['lrNumber']?.toString().toLowerCase() ?? '';
        if (!truckNumber.contains(searchLower) &&
            !partyName.contains(searchLower) &&
            !lrNumber.contains(searchLower)) {
          return false;
        }
      }

      // Month filter (either use parameter or current selection)
      final monthToCheck = month ?? _selectedMonth;
      if (monthToCheck != null) {
        try {
          final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
          final tripMonth = DateFormat('MMMM yyyy').format(tripDate);
          if (tripMonth != monthToCheck) {
            return false;
          }
        } catch (e) {
          return false;
        }
      }

      // Status filter
      final statusToCheck = status != null ? {status} : _selectedStatuses;
      if (statusToCheck.isNotEmpty) {
        if (!statusToCheck.contains(trip['status']?.toString() ?? '')) {
          return false;
        }
      }

      // POD filter
      final podToCheck = podFilter ?? _selectedPODFilter;
      if (podToCheck.isNotEmpty) {
        // Implement POD filter logic when available
      }

      // Truck filter
      final trucksToCheck = truck != null ? {truck} : _selectedTrucks;
      if (trucksToCheck.isNotEmpty) {
        if (!trucksToCheck.contains(trip['truckNumber']?.toString() ?? '')) {
          return false;
        }
      }

      // Party filter
      final partiesToCheck = party != null ? {party} : _selectedParties;
      if (partiesToCheck.isNotEmpty) {
        if (!partiesToCheck.contains(trip['partyName']?.toString() ?? '')) {
          return false;
        }
      }

      // Route filter
      final routesToCheck = route != null ? {route} : _selectedRoutes;
      if (routesToCheck.isNotEmpty) {
        final tripRoute = '${trip['origin']} to ${trip['destination']}';
        if (!routesToCheck.contains(tripRoute)) {
          return false;
        }
      }

      // Date range filter
      if (_startDate != null && _endDate != null) {
        try {
          final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
          if (tripDate.isBefore(_startDate!) || tripDate.isAfter(_endDate!)) {
            return false;
          }
        } catch (e) {
          return false;
        }
      }

      return true;
    }).length;
  }

  // Get available months from trip data
  List<String> _getAvailableMonths() {
    final months = <String>{};
    for (var trip in _allTrips) {
      try {
        final tripDate = DateFormat('yyyy-MM-dd').parse(trip['startDate']?.toString() ?? '');
        final monthYear = DateFormat('MMMM yyyy').format(tripDate);
        months.add(monthYear);
      } catch (e) {
        // Skip invalid dates
      }
    }
    // Sort months in descending order (most recent first)
    final sortedMonths = months.toList();
    sortedMonths.sort((a, b) {
      try {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    return sortedMonths;
  }
}


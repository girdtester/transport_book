import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/app_loader.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/custom_button.dart';
import '../../../utils/custom_dropdown.dart';
import '../../../utils/custom_textfield.dart';
import '../../invoices/screens/invoice_details_screen.dart';
import '../../invoices/widgets/create_invoice_helper.dart';
import '../../trips/screens/add_trip_from_dashboard_screen.dart';
import '../../trips/screens/trip_details_screen.dart';
import 'party_balance_report_screen.dart';

class PartyDetailScreen extends StatefulWidget {
  final int partyId;
  final String partyName;

  const PartyDetailScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allTrips = [];
  List<dynamic> _filteredTrips = [];
  List<dynamic> _allInvoices = [];
  bool _isLoading = true;
  double _partyBalance = 0.0;
  bool _showMoreActions = false;
  String _searchQuery = '';
  Map<String, dynamic>? _partyDetails;
  bool _hasChanges = false; // Track if data was modified

  // Trip filter states
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedMonth;
  final Set<String> _selectedTripStatus = {};
  final Set<String> _selectedTrucks = {};
  final Set<String> _selectedRoutes = {};

  // Passbook filter state
  String _passbookFilter = 'Trips & Payments'; // 'Trips & Payments', 'Trips', 'Payments'
  String _passbookMonthFilter = 'All Months';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allParties = await ApiService.getParties();
      final allTrips = await ApiService.getAllTrips();
      final allInvoices = await ApiService.getInvoices();

      // Find the party details by ID
      final partyData = allParties.firstWhere(
        (party) => party['id'] == widget.partyId,
        orElse: () => {'name': widget.partyName, 'phone': null, 'email': null, 'address': null},
      );

      // Filter trips for this party
      final partyTrips = allTrips.where((trip) {
        final partyName = trip['partyName']?.toString() ?? '';
        return partyName == widget.partyName;
      }).toList();

      // Filter invoices for this party
      final partyInvoices = allInvoices.where((invoice) {
        final partyName = invoice['partyName']?.toString() ?? '';
        return partyName == widget.partyName;
      }).toList();

      // Get balance from party data (includes opening balance + trip balance)
      double balance = double.tryParse(partyData['balance']?.toString() ?? '0') ?? 0.0;

      setState(() {
        _partyDetails = partyData;
        _allTrips = partyTrips;
        _filteredTrips = partyTrips;
        _allInvoices = partyInvoices;
        _partyBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(
          context,
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _applyTripFilters() {
    setState(() {
      _filteredTrips = _allTrips.where((trip) {
        // Date filter
        if (_startDate != null || _endDate != null) {
          final tripDate = DateTime.tryParse(trip['startDate']?.toString() ?? '');
          if (tripDate != null) {
            if (_startDate != null && tripDate.isBefore(_startDate!)) return false;
            if (_endDate != null && tripDate.isAfter(_endDate!)) return false;
          }
        }

        // Month filter
        if (_selectedMonth != null) {
          final tripDate = DateTime.tryParse(trip['startDate']?.toString() ?? '');
          if (tripDate != null) {
            final monthYear = DateFormat('MMMM yyyy').format(tripDate);
            if (monthYear != _selectedMonth) return false;
          }
        }

        // Trip status filter
        if (_selectedTripStatus.isNotEmpty) {
          final status = trip['status']?.toString() ?? '';
          if (!_selectedTripStatus.contains(status)) return false;
        }

        // Truck filter
        if (_selectedTrucks.isNotEmpty) {
          final truckNumber = trip['truckNumber']?.toString() ?? '';
          if (!_selectedTrucks.contains(truckNumber)) return false;
        }

        // Routes filter
        if (_selectedRoutes.isNotEmpty) {
          final origin = trip['origin']?.toString() ?? '';
          final destination = trip['destination']?.toString() ?? '';
          final route = '$origin - $destination';
          if (!_selectedRoutes.contains(route)) return false;
        }

        return true;
      }).toList();
    });
    Navigator.pop(context);
  }

  void _showFilters() {
    String currentFilter = 'Start Date';

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
                            setModalState(() => currentFilter = 'Start Date');
                          }),
                          _buildFilterTab('Trip Status', currentFilter == 'Trip Status', () {
                            setModalState(() => currentFilter = 'Trip Status');
                          }),
                          _buildFilterTab('POD Challan', currentFilter == 'POD Challan', () {
                            setModalState(() => currentFilter = 'POD Challan');
                          }),
                          _buildFilterTab('Truck', currentFilter == 'Truck', () {
                            setModalState(() => currentFilter = 'Truck');
                          }),
                          _buildFilterTab('Routes', currentFilter == 'Routes', () {
                            setModalState(() => currentFilter = 'Routes');
                          }),
                        ],
                      ),
                    ),

                    // Right Content
                    Expanded(
                      child: _buildTripFilterContent(currentFilter, setModalState),
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
                            '${_filteredTrips.length} Trips',
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
                      onPressed: _applyTripFilters,
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

  Widget _buildTripFilterContent(String filterType, StateSetter setModalState) {
    switch (filterType) {
      case 'Start Date':
        return _buildStartDateFilter(setModalState);
      case 'Trip Status':
        return _buildTripStatusFilter(setModalState);
      case 'POD Challan':
        return _buildPODChallanFilter(setModalState);
      case 'Truck':
        return _buildTruckFilter(setModalState);
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
              );
              if (picked != null) {
                setModalState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
            style: OutlinedButton.styleFrom(
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

          // Month options
          _buildCheckboxOption(
            'October 2025',
            _selectedMonth == 'October 2025',
            '(${_allTrips.length} Trips)',
            () {
              setModalState(() {
                _selectedMonth = _selectedMonth == 'October 2025' ? null : 'October 2025';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatusFilter(StateSetter setModalState) {
    final statuses = ['Load in Progress', 'POD Pending', 'POD Received', 'Settled'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: statuses.map((status) {
        return _buildCheckboxOption(
          status,
          _selectedTripStatus.contains(status),
          '',
          () {
            setModalState(() {
              if (_selectedTripStatus.contains(status)) {
                _selectedTripStatus.remove(status);
              } else {
                _selectedTripStatus.add(status);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPODChallanFilter(StateSetter setModalState) {
    return const Center(
      child: Text('POD Challan filters coming soon'),
    );
  }

  Widget _buildTruckFilter(StateSetter setModalState) {
    final trucks = _allTrips.map((trip) => trip['truckNumber']?.toString() ?? '').toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: trucks.map((truck) {
        return _buildCheckboxOption(
          truck,
          _selectedTrucks.contains(truck),
          '',
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
    );
  }

  Widget _buildRoutesFilter(StateSetter setModalState) {
    final routes = _allTrips.map((trip) {
      final origin = trip['origin']?.toString() ?? '';
      final destination = trip['destination']?.toString() ?? '';
      return '$origin - $destination';
    }).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: routes.map((route) {
        return _buildCheckboxOption(
          route,
          _selectedRoutes.contains(route),
          '',
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
            if (count.isNotEmpty)
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

  void _viewReport() {
    // Navigate to PDF report for this party only with unsettled trips
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyBalanceReportScreen(
          parties: [
            {
              'id': widget.partyId,
              'name': widget.partyName,
              'balance': _partyBalance,
            }
          ],
        ),
      ),
    );
  }

  void _createInvoice() {
    showCreateInvoiceSheet(
      context,
      onInvoiceCreated: () {
        _loadData();
      },
      preselectedPartyName: widget.partyName,
    );
  }

  void _viewTrip(Map<String, dynamic> trip) {
    final tripId = trip['id'];
    if (tripId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripDetailsScreen(tripId: tripId),
        ),
      ).then((_) => _loadData()); // Reload data when returning
    }
  }

  PopupMenuItem<String> _popupItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: iconColor == Colors.red ? Colors.red : Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: CustomAppBar(
          title: widget.partyName,
          onBack: () {
            Navigator.pop(context);
          },
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.appBarColor,
              ),
              color: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'call':
                    _callParty();
                    break;
                  case 'edit':
                    _showEditPartyDialog();
                    break;
                  case 'delete':
                    _deleteParty();
                    break;
                  case 'opening_balance':
                    _showAddOpeningBalanceDialog();
                    break;
                  case 'details':
                    _showPartyDetailsDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                _popupItem(
                  value: 'call',
                  icon: Icons.phone,
                  iconColor: Colors.black87,
                  text: "Call Party",
                ),
                _popupItem(
                  value: 'edit',
                  icon: Icons.edit,
                  iconColor: Colors.black87,
                  text: "Edit Party",
                ),
                _popupItem(
                  value: 'delete',
                  icon: Icons.delete,
                  iconColor: Colors.red,
                  text: "Delete Party",
                ),
                _popupItem(
                  value: 'opening_balance',
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.black87,
                  text: "Add Opening Balance",
                ),
                _popupItem(
                  value: 'details',
                  icon: Icons.info_outline,
                  iconColor: Colors.black87,
                  text: "Party Details",
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: AppLoader())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Party Balance Section as Sliver
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Party Balance : ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatWithSymbol(_partyBalance.toInt()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _viewReport,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                        color: AppColors.info.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                          Icon(Icons.picture_as_pdf,
                                              color: AppColors.info, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                          'View Report',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                              color: AppColors.info,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_partyBalance > 0) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _createInvoice,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.receipt_long, color: Colors.purple.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Create Invoice',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.purple.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tabs as Sliver
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                          labelColor: AppColors.info,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: AppColors.info,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(text: 'Trips'),
                          Tab(text: 'Passbook'),
                          Tab(text: 'Invoices'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripsTab(),
                  _buildPassbookTab(),
                  _buildInvoicesTab(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTripsTab() {
    return Stack(
      children: [
        Column(
          children: [
            // Search and Filter
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: '',
                      controller: TextEditingController(text: _searchQuery),
                      hint: 'Search for ',
                      suffix: const Icon(Icons.search, color: Colors.grey),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined, size: 20),
                          const SizedBox(width: 4),
                          const Text('Filters'),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Trip List
            Expanded(
              child: _filteredTrips.isEmpty
                  ? const Center(child: Text('No trips found'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _filteredTrips.length,
                      itemBuilder: (context, index) {
                        final trip = _filteredTrips[index];
                        return _buildTripCard(trip);
                      },
                    ),
            ),
          ],
        ),
        // Floating Action Buttons - Add Trip and Add Payment
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: _addTrip,
                  backgroundColor: const Color(0xFF2E8B57),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Trip',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: _showAddPaymentDialog,
                  backgroundColor: AppColors.info,
                  heroTag: 'addPaymentTrip',
                  icon: const Icon(Icons.payment, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Payment',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final truckNumber = trip['truckNumber']?.toString() ?? '';
    final origin = trip['origin']?.toString() ?? '';
    final destination = trip['destination']?.toString() ?? '';
    final startDate = trip['startDate']?.toString() ?? '';
    final endDate = trip['endDate']?.toString() ?? startDate;
    final status = trip['status']?.toString() ?? '';
    final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    final payment = double.tryParse(trip['payment']?.toString() ?? '0') ?? 0.0;
    final balance = freightAmount - payment;
    final truckType = trip['truckType']?.toString() ?? 'Market';
    final isMarket = truckType == 'Market';

    return InkWell(
      onTap: () => _viewTrip(trip),
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
                        widget.partyName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            truckNumber,
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
                      CurrencyFormatter.formatWithSymbol(freightAmount.toInt()),
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
                        origin,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        startDate,
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
                        destination,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        endDate,
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

            const SizedBox(height: 10),

            // Status Badge and View Trip Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Completed'
                        ? AppColors.primaryGreen.withOpacity(0.1)
                        : AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: status == 'Completed'
                          ? AppColors.primaryGreen.withOpacity(0.25)
                          : AppColors.info.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'Completed'
                          ? AppColors.primaryGreen.withOpacity(0.8)
                          : AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _viewTrip(trip),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View Trip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTripOptions(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trip Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppColors.info),
              title: const Text('View Trip'),
              onTap: () {
                Navigator.pop(context);
                _viewTrip(trip);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Trip'),
              onTap: () {
                Navigator.pop(context);
                ToastHelper.showSnackBarToast(
                  context,
                  const SnackBar(content: Text('Edit Trip - Coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Trip'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTrip(trip);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTrip(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement API call to delete trip
              if (mounted) {
                ToastHelper.showSnackBarToast(
                  context,
                  const SnackBar(content: Text('Trip deleted successfully')),
                );
                _loadData();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPassbookFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Entries',
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

            // Options
            _buildRadioOption(
              'Trips & Payments',
              _passbookFilter == 'Trips & Payments',
              () {
                setState(() {
                  _passbookFilter = 'Trips & Payments';
                });
              },
            ),
            _buildRadioOption(
              'Trips',
              _passbookFilter == 'Trips',
              () {
                setState(() {
                  _passbookFilter = 'Trips';
                });
              },
            ),
            _buildRadioOption(
              'Payments',
              _passbookFilter == 'Payments',
              () {
                setState(() {
                  _passbookFilter = 'Payments';
                });
              },
            ),

            const SizedBox(height: 24),

            // Apply Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPassbookMonthFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Month',
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

            // Options
            _buildRadioOption(
              'All Months',
              _passbookMonthFilter == 'All Months',
              () {
                setState(() {
                  _passbookMonthFilter = 'All Months';
                });
              },
            ),
            _buildRadioOption(
              'This Month',
              _passbookMonthFilter == 'This Month',
              () {
                setState(() {
                  _passbookMonthFilter = 'This Month';
                });
              },
            ),
            _buildRadioOption(
              'Last 3 Months',
              _passbookMonthFilter == 'Last 3 Months',
              () {
                setState(() {
                  _passbookMonthFilter = 'Last 3 Months';
                });
              },
            ),
            _buildRadioOption(
              'Last 6 Months',
              _passbookMonthFilter == 'Last 6 Months',
              () {
                setState(() {
                  _passbookMonthFilter = 'Last 6 Months';
                });
              },
            ),
            _buildRadioOption(
              'This Year',
              _passbookMonthFilter == 'This Year',
              () {
                setState(() {
                  _passbookMonthFilter = 'This Year';
                });
              },
            ),

            const SizedBox(height: 24),

            // Apply Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
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

  Widget _buildPassbookTab() {
    return Stack(
      children: [
        _buildPassbookContent(),
        // Floating Action Buttons
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: _addTrip,
                  backgroundColor: const Color(0xFF2E8B57),
                  heroTag: 'addTripPassbook',
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Trip',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: _showAddPaymentDialog,
                  backgroundColor: AppColors.info,
                  heroTag: 'addPaymentPassbook',
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: const Text(
                    'Add Payment',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassbookContent() {
    // Generate passbook entries from trips
    List<Map<String, dynamic>> passbookEntries = [];

    for (var trip in _allTrips) {
      final tripId = trip['id'];
      final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
      final startDate = trip['startDate']?.toString() ?? '';
      final truckNumber = trip['truckNumber']?.toString() ?? '';
      final origin = trip['origin']?.toString() ?? '';
      final destination = trip['destination']?.toString() ?? '';
      final lrNumber = trip['lrNumber']?.toString() ?? '';

      // Add trip entry (if filter allows)
      if (_passbookFilter == 'Trips & Payments' || _passbookFilter == 'Trips') {
        passbookEntries.add({
          'type': 'trip',
          'tripId': tripId,
          'trip': trip, // Store full trip data for editing
          'title': '$lrNumber - $origin â–¸ $destination',
          'date': startDate,
          'truckNumber': truckNumber,
          'amount': freightAmount,
          'isRevenue': true,
        });
      }

      // Add individual advance entries if exists (if filter allows)
      if (_passbookFilter == 'Trips & Payments' || _passbookFilter == 'Payments') {
        final advances = trip['advances'] as List? ?? [];
        for (var advance in advances) {
          final advanceAmount = double.tryParse(advance['amount']?.toString() ?? '0') ?? 0.0;
          if (advanceAmount > 0) {
            final advanceDate = advance['date']?.toString() ?? startDate;
            passbookEntries.add({
              'type': 'advance',
              'tripId': tripId,
              'trip': trip,
              'title': 'Trip Advance - $lrNumber',
              'date': advanceDate,
              'truckNumber': '',
              'amount': advanceAmount,
              'isRevenue': false,
            });
          }
        }
      }

      // Add individual payment entries if exists (if filter allows)
      if (_passbookFilter == 'Trips & Payments' || _passbookFilter == 'Payments') {
        final payments = trip['payments'] as List? ?? [];
        for (var payment in payments) {
          final paymentAmount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
          if (paymentAmount > 0) {
            final paymentDate = payment['date']?.toString() ?? startDate;
            final paymentMode = payment['paymentMode']?.toString() ?? '';
            passbookEntries.add({
              'type': 'payment',
              'tripId': tripId,
              'trip': trip,
              'title': 'Payment - $lrNumber${paymentMode.isNotEmpty ? ' ($paymentMode)' : ''}',
              'date': paymentDate,
              'truckNumber': '',
              'amount': paymentAmount,
              'isRevenue': false,
            });
          }
        }
      }
    }

    return Column(
      children: [
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showPassbookMonthFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_passbookMonthFilter),
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showPassbookFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_passbookFilter),
                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Headers
        if (passbookEntries.isNotEmpty)
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'TRIPS AND PAYMENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'PAYMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REVENUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

        // Transaction List
        Expanded(
          child: passbookEntries.isEmpty
              ? const Center(child: Text('No transactions found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: passbookEntries.length,
                  itemBuilder: (context, index) {
                    final entry = passbookEntries[index];
                    return _buildPassbookEntry(entry);
                  },
                ),
        ),

      ],
    );
  }

  Widget _buildPassbookEntry(Map<String, dynamic> entry) {
    final isRevenue = entry['isRevenue'] as bool;
    final amount = entry['amount'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showPassbookEntryOptions(entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['title'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      entry['date'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (entry['truckNumber'].isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry['truckNumber'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isRevenue)
            Expanded(
              flex: 2,
              child: Text(
                CurrencyFormatter.formatWithSymbol(amount.toInt()),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.right,
              ),
            )
          else
            const Expanded(flex: 2, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text(
              isRevenue ? CurrencyFormatter.formatWithSymbol(amount.toInt()) : '',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                  textAlign: TextAlign.right,
            ),
          ),
          ],
        ),
        ),
      ),
    );
  }

  void _showPassbookEntryOptions(Map<String, dynamic> entry) {
    final entryType = entry['type']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${entryType == 'trip' ? 'Trip' : 'Payment'} Options',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppColors.info),
              title: Text('View ${entryType == 'trip' ? 'Trip' : 'Payment'}'),
              onTap: () {
                Navigator.pop(context);
                if (entryType == 'trip') {
                  _viewTrip(entry['trip']);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: Text('Edit ${entryType == 'trip' ? 'Trip' : 'Payment'}'),
              onTap: () {
                Navigator.pop(context);
                _editPassbookEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete ${entryType == 'trip' ? 'Trip' : 'Payment'}'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePassbookEntry(entry);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePassbookEntry(Map<String, dynamic> entry) {
    final entryType = entry['type']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${entryType == 'trip' ? 'Trip' : 'Payment'}'),
        content: Text('Are you sure you want to delete this ${entryType == 'trip' ? 'trip' : 'payment'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              bool success = false;
              final tripId = entry['tripId'];

              if (tripId == null) {
                if (mounted) {
                  ToastHelper.showSnackBarToast(
                    context,
                    const SnackBar(content: Text('Error: Unable to delete entry')),
                  );
                }
                return;
              }

              // Delete trip (all passbook entries are trip-based)
              success = await ApiService.deleteTrip(tripId);

              if (!mounted) return;

              if (success) {
                setState(() {
                  _hasChanges = true; // Mark that data was changed
                });
                ToastHelper.showSnackBarToast(
                  context,
                  SnackBar(content: Text('${entryType == 'trip' ? 'Trip' : 'Payment'} deleted successfully')),
                );
                await _loadData(); // Reload data to reflect changes
              } else {
                ToastHelper.showSnackBarToast(
                  context,
                  SnackBar(content: Text('Failed to delete ${entryType == 'trip' ? 'trip' : 'payment'}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editPassbookEntry(Map<String, dynamic> entry) {
    final entryType = entry['type']?.toString() ?? '';
    final tripId = entry['tripId'];

    if (tripId == null) {
      ToastHelper.showSnackBarToast(
        context,
        const SnackBar(content: Text('Error: Unable to edit entry')),
      );
      return;
    }

    // For all passbook entries, navigate to trip details screen for editing
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(tripId: tripId),
      ),
    ).then((_) {
      setState(() {
        _hasChanges = true;
      });
      _loadData(); // Reload data after returning
    });
  }

  Widget _buildInvoicesTab() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: _allInvoices.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No invoices found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _allInvoices.length,
                      itemBuilder: (context, index) {
                        final invoice = _allInvoices[index];
                        return _buildInvoiceCard(invoice);
                      },
                    ),
            ),
          ],
        ),

        // Floating Action Buttons
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: _addTrip,
                  backgroundColor: const Color(0xFF2E8B57),
                  heroTag: 'addTripInvoice',
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Add Trip',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: () {
                    showCreateInvoiceSheet(
                      context,
                      onInvoiceCreated: () {
                        _loadData();
                      },
                      preselectedPartyName: widget.partyName,
                    );
                  },
                  backgroundColor: AppColors.info,
                  heroTag: 'addInvoice',
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: const Text(
                    'Add Invoice',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoiceNumber']?.toString() ?? '';
    final partyName = invoice['partyName']?.toString() ?? '';
    final totalAmount = double.tryParse(invoice['totalAmount']?.toString() ?? '0') ?? 0.0;
    final balanceAmount = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
    final createdDate = invoice['createdDate']?.toString() ?? '';
    final dueDate = invoice['dueDate']?.toString() ?? '';

    // Calculate days until due
    int daysUntilDue = 0;
    if (dueDate.isNotEmpty) {
      try {
        final due = DateTime.parse(dueDate);
        daysUntilDue = due.difference(DateTime.now()).inDays;
      } catch (e) {
        daysUntilDue = 0;
      }
    }

    final dueDateText = daysUntilDue > 0
        ? 'Due in $daysUntilDue days'
        : daysUntilDue == 0
            ? 'Due today'
            : 'Overdue by ${-daysUntilDue} days';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showInvoiceOptions(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoiceNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partyName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatWithSymbol(totalAmount.toInt()),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  createdDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 4),
                Text('•', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(width: 4),
                Text(
                  dueDateText,
                  style: TextStyle(
                    fontSize: 13,
                    color: daysUntilDue < 0 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (balanceAmount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      CurrencyFormatter.formatWithSymbol(balanceAmount.toInt()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    child: Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                  ),
                ],
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceOptions(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Invoice Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppColors.info),
              title: const Text('View Invoice'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoiceDetailsScreen(
                      invoiceId: invoice['id'],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Invoice'),
              onTap: () {
                Navigator.pop(context);
                ToastHelper.showSnackBarToast(
                  context,
                  const SnackBar(content: Text('Edit Invoice - Coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Invoice'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteInvoice(invoice);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteInvoice(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement API call to delete invoice
              if (mounted) {
                ToastHelper.showSnackBarToast(
                  context,
                  const SnackBar(content: Text('Invoice deleted successfully')),
                );
                _loadData();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTripFromDashboardScreen(),
      ),
    );
  }

  void _showAddPaymentDialog() {
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String paymentMode = 'Cash';
    List<Map<String, dynamic>> selectedTripsWithAmounts = [];
    double totalPaymentAmount = 0.0;

    // Calculate pending balance for each trip
    Map<int, double> tripPendingBalances = {};
    for (var trip in _allTrips) {
      final tripId = trip['id'] as int;
      final freight = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;

      // Calculate total advances
      double totalAdvances = 0.0;
      final advances = trip['advances'] as List? ?? [];
      for (var advance in advances) {
        totalAdvances += double.tryParse(advance['amount']?.toString() ?? '0') ?? 0.0;
      }

      // Calculate total payments
      double totalPayments = 0.0;
      final payments = trip['payments'] as List? ?? [];
      for (var payment in payments) {
        totalPayments += double.tryParse(payment['amount']?.toString() ?? '0') ?? 0.0;
      }

      // Calculate total charges
      double totalCharges = 0.0;
      final charges = trip['charges'] as List? ?? [];
      for (var charge in charges) {
        totalCharges += double.tryParse(charge['amount']?.toString() ?? '0') ?? 0.0;
      }

      final settleAmount = double.tryParse(trip['settleAmount']?.toString() ?? '0') ?? 0.0;
      final pendingBalance = freight + totalCharges - totalAdvances - totalPayments - settleAmount;
      tripPendingBalances[tripId] = pendingBalance;
    }

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Payment',
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

                  // Trip Selector
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text('Select Trips to Pay'),
                      subtitle: Text(
                        selectedTripsWithAmounts.isEmpty
                            ? 'No trips selected'
                            : '${selectedTripsWithAmounts.length} trip(s) selected',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        await _showTripSelectionDialog(
                          setModalState,
                          selectedTripsWithAmounts,
                          tripPendingBalances,
                          (updatedList, total) {
                            setModalState(() {
                              selectedTripsWithAmounts = updatedList;
                              totalPaymentAmount = total;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Trips List
                  if (selectedTripsWithAmounts.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Allocation:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...selectedTripsWithAmounts.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['label'],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatWithSymbol(item['amount'].toInt()),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Payment:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatWithSymbol(totalPaymentAmount.toInt()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF2E8B57),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Date Field
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setModalState(() {
                          dateController.text = DateFormat('yyyy-MM-dd').format(date);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: CustomTextField(
                        label: 'Payment Date',
                        controller: dateController,
                        suffix: const Icon(Icons.calendar_today),
                        readOnly: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Mode Field
                  CustomDropdown(
                    label: 'Payment Mode',
                    value: paymentMode,
                    items: ['Cash', 'Online', 'Cheque'],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => paymentMode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedTripsWithAmounts.isEmpty) {
                        ToastHelper.showSnackBarToast(
                          context,
                          const SnackBar(content: Text('Please select at least one trip')),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        // Add payment for each selected trip
                        int successCount = 0;
                        for (var tripPayment in selectedTripsWithAmounts) {
                          final result = await ApiService.addTripPayment(
                            tripId: tripPayment['tripId'],
                            amount: tripPayment['amount'].toInt().toString(),
                            date: dateController.text,
                            paymentMode: paymentMode,
                          );
                          if (result != null) successCount++;
                        }

                        // Reload data first (before showing snackbar)
                        if (mounted) {
                          setState(() {
                            _hasChanges = true; // Mark that data was changed
                          });
                          await _loadData();
                          // Switch to passbook tab to show new payments
                          _tabController.animateTo(1);
                        }

                        // Then show feedback (only if still mounted)
                        if (!mounted) return;

                        if (successCount == selectedTripsWithAmounts.length) {
                          try {
                            ToastHelper.showSnackBarToast(
                              context,
                              SnackBar(
                                content: Text('Payment added successfully for $successCount trip(s)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        } else {
                          try {
                            ToastHelper.showSnackBarToast(
                              context,
                              SnackBar(
                                content: Text('Payment added for $successCount of ${selectedTripsWithAmounts.length} trips'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        try {
                          ToastHelper.showSnackBarToast(
                            context,
                            SnackBar(content: Text('Error adding payment: $e')),
                          );
                        } catch (e) {
                          // Ignore snackbar errors if widget is disposed
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTripSelectionDialog(
    StateSetter parentSetState,
    List<Map<String, dynamic>> selectedTripsWithAmounts,
    Map<int, double> tripPendingBalances,
    Function(List<Map<String, dynamic>>, double) onUpdate,
  ) async {
    // Create working copies
    List<Map<String, dynamic>> workingSelection = List.from(selectedTripsWithAmounts);
    Map<int, TextEditingController> amountControllers = {};

    // Initialize controllers for already selected trips
    for (var item in workingSelection) {
      amountControllers[item['tripId']] = TextEditingController(
        text: item['amount'].toInt().toString(),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double calculateTotal() {
            return workingSelection.fold(0.0, (sum, item) => sum + item['amount']);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Trips',
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
                const SizedBox(height: 8),
                Text(
                  'Select trips and enter payment amount for each',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Trip List
                Expanded(
                  child: ListView.builder(
                    itemCount: _allTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _allTrips[index];
                      final tripId = trip['id'] as int;
                      final origin = trip['origin']?.toString() ?? '';
                      final destination = trip['destination']?.toString() ?? '';
                      final lrNumber = trip['lrNumber']?.toString() ?? '';
                      final pendingBalance = tripPendingBalances[tripId] ?? 0.0;
                      final isSelected = workingSelection.any((item) => item['tripId'] == tripId);

                      if (pendingBalance <= 0) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          // Add trip
                                          amountControllers[tripId] = TextEditingController(
                                            text: pendingBalance.toInt().toString(),
                                          );
                                          workingSelection.add({
                                            'tripId': tripId,
                                            'label':
                                                '$lrNumber - $origin â†’ $destination',
                                            'amount': pendingBalance,
                                          });
                                        } else {
                                          // Remove trip
                                          workingSelection.removeWhere((item) => item['tripId'] == tripId);
                                          amountControllers[tripId]?.dispose();
                                          amountControllers.remove(tripId);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$lrNumber - $origin â†’ $destination',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pending: ${CurrencyFormatter.formatWithSymbol(pendingBalance.toInt())}',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 8),
                                CustomTextField(
                                  label: 'Payment Amount',
                                  controller: amountControllers[tripId]!,
                                  keyboard: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (value) {
                                    setModalState(() {
                                      final amount = double.tryParse(value) ?? 0.0;
                                      final itemIndex = workingSelection.indexWhere((item) => item['tripId'] == tripId);
                                      if (itemIndex != -1) {
                                        workingSelection[itemIndex]['amount'] = amount;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Total and Confirm
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payment:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatWithSymbol(calculateTotal().toInt()),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E8B57),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Confirm Selection (${workingSelection.length} trips)',
                  color: const Color(0xFF2E8B57),
                  onPressed: () {
                    onUpdate(workingSelection, calculateTotal());
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );

    // Dispose controllers
    for (var controller in amountControllers.values) {
      controller.dispose();
    }
  }

  // Call Party
  Future<void> _callParty() async {
    final phone = _partyDetails?['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      ToastHelper.showSnackBarToast(
        context,
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(
        context,
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  // Show Edit Party Dialog
  void _showEditPartyDialog() {
    final nameController = TextEditingController(text: _partyDetails?['name'] ?? '');
    final phoneController = TextEditingController(text: _partyDetails?['phone'] ?? '');
    final emailController = TextEditingController(text: _partyDetails?['email'] ?? '');
    final addressController = TextEditingController(text: _partyDetails?['address'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Party Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'Party Name',
                  controller: nameController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Phone Number',
                  controller: phoneController,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Email',
                  controller: emailController,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Address',
                  controller: addressController,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Update Party',
                  color: const Color(0xFF2196F3),
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ToastHelper.showSnackBarToast(
                        context,
                        const SnackBar(content: Text('Please enter party name')),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    final success = await ApiService.updateParty(
                      partyId: widget.partyId,
                      name: nameController.text,
                      phone: phoneController.text.isEmpty ? null : phoneController.text,
                      email: emailController.text.isEmpty ? null : emailController.text,
                      address: addressController.text.isEmpty ? null : addressController.text,
                    );

                    if (!mounted) return;

                    if (success) {
                      _hasChanges = true; // Mark that data was changed
                      ToastHelper.showSnackBarToast(
                        context,
                        const SnackBar(content: Text('Party updated successfully')),
                      );
                      await _loadData();
                    } else {
                      ToastHelper.showSnackBarToast(
                        context,
                        const SnackBar(content: Text('Failed to update party')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Delete Party
  Future<void> _deleteParty() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Party'),
        content: Text('Are you sure you want to delete ${widget.partyName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteParty(partyId: widget.partyId);
      if (!mounted) return;

      if (success) {
        ToastHelper.showSnackBarToast(
          context,
          const SnackBar(content: Text('Party deleted successfully')),
        );
        Navigator.pop(context, true); // Go back to party list
      } else {
        ToastHelper.showSnackBarToast(
          context,
          const SnackBar(content: Text('Failed to delete party')),
        );
      }
    }
  }

  // Show Add Opening Balance Dialog
  void _showAddOpeningBalanceDialog() {
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Opening Balance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'This amount will be ADDED to the current balance of ${CurrencyFormatter.formatWithSymbol(_partyBalance.toInt())}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Opening Balance Amount',
                controller: amountController,
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Add Balance',
                color: const Color(0xFF2196F3),
                onPressed: () async {
                  if (amountController.text.isEmpty) {
                    ToastHelper.showSnackBarToast(
                      context,
                      const SnackBar(content: Text('Please enter amount')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  final amount = double.tryParse(amountController.text) ?? 0;
                  final success = await ApiService.addPartyOpeningBalance(
                    partyId: widget.partyId,
                    amount: amount,
                  );

                  if (!mounted) return;

                  if (success) {
                    _hasChanges = true; // Mark that data was changed
                    ToastHelper.showSnackBarToast(
                      context,
                      const SnackBar(content: Text('Opening balance added successfully')),
                    );
                    await _loadData();
                  } else {
                    ToastHelper.showSnackBarToast(
                      context,
                      const SnackBar(content: Text('Failed to add opening balance')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show Party Details Dialog
  void _showPartyDetailsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Party Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Name', _partyDetails?['name'] ?? 'N/A'),
            const Divider(),
            _buildDetailRow('Phone', _partyDetails?['phone'] ?? 'N/A'),
            const Divider(),
            _buildDetailRow('Email', _partyDetails?['email'] ?? 'N/A'),
            const Divider(),
            _buildDetailRow('Address', _partyDetails?['address'] ?? 'N/A'),
            const Divider(),
            _buildDetailRow('Current Balance', CurrencyFormatter.formatWithSymbol(_partyBalance.toInt())),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Close',
              color: Colors.grey.shade700,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Delegate for SliverPersistentHeader to make TabBar sticky
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

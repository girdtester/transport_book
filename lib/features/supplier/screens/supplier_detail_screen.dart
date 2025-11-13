import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../trips/screens/add_trip_from_dashboard_screen.dart';
import '../../trips/screens/trip_details_screen.dart';
import 'supplier_balance_report_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierDetailScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _supplierData;
  List<dynamic> _allTransactions = [];
  List<dynamic> _filteredTransactions = [];
  List<dynamic> _supplierTrips = [];

  late TabController _tabController;
  int _selectedTabIndex = 0;

  String _selectedMonth = 'All Months';
  String _selectedTripFilter = 'All Trips';
  String _selectedPassbookFilter = 'Trips & Payments';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
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
      // Load supplier details
      final suppliers = await ApiService.getSuppliers();
      final supplier = suppliers.firstWhere(
        (s) => s['id'] == widget.supplierId,
        orElse: () => {
          'id': widget.supplierId,
          'name': widget.supplierName,
          'balance': 0.0,
          'phone': '',
        },
      );

      // Load trips for this supplier (only Market trips)
      final allTrips = await ApiService.getAllTrips();
      final supplierTrips = allTrips.where((trip) {
        final supplierName = trip['supplierName']?.toString() ?? '';
        final truckType = trip['truckType']?.toString() ?? '';
        // Use supplier['name'] from API instead of widget.supplierName to handle name updates
        return supplierName == supplier['name'] && truckType == 'Market';
      }).toList();

      // Calculate balance from unsettled trips
      double balance = 0.0;
      for (var trip in supplierTrips) {
        final status = trip['status']?.toString() ?? '';
        if (status != 'Settled') {
          balance += double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
        }
      }

      // Load supplier transactions (advances, charges, payments)
      final transactionsData = await ApiService.getSupplierTransactions(widget.supplierId);
      final transactions = transactionsData?['transactions'] as List? ?? [];

      setState(() {
        _supplierData = {
          'id': widget.supplierId,
          'name': supplier['name'],
          'balance': balance,
          'phone': supplier['phone'] ?? '',
        };
        _supplierTrips = supplierTrips;
        _allTransactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _addTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTripFromDashboardScreen(),
      ),
    ).then((_) {
      // Reload data after returning from add trip screen
      _loadData();
    });
  }

  void _showAddPaymentDialog({Map<String, dynamic>? prefilledTrip}) async {
    // Load all unsettled trips for this supplier
    final allTrips = await ApiService.getAllTrips();
    final unsettledTrips = allTrips.where((trip) {
      final supplierName = trip['supplierName']?.toString() ?? '';
      final status = trip['status']?.toString() ?? '';
      final truckType = trip['truckType']?.toString() ?? '';
      return supplierName == widget.supplierName &&
             status != 'Settled' &&
             truckType == 'Market';
    }).toList();

    if (!mounted) return;

    // Controllers
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String paymentMethod = 'Cash';
    DateTime selectedDate = DateTime.now();
    List<dynamic> selectedTrips = [];

    // If a trip is prefilled, set it and the amount
    if (prefilledTrip != null) {
      selectedTrips = [prefilledTrip];
      final amount = prefilledTrip['truckHireCost'] ?? 0;
      amountController.text = amount.toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Calculate total of selected trips
          double selectedTotal = 0;
          for (var trip in selectedTrips) {
            selectedTotal += double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
          }

          return Padding(
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

                    // Supplier Name (disabled)
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Supplier Name',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      controller: TextEditingController(text: widget.supplierName),
                    ),
                    const SizedBox(height: 16),

                    // Trips Selection
                    if (unsettledTrips.isNotEmpty) ...[
                      Text(
                        'Select Trips to Settle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: unsettledTrips.length,
                          itemBuilder: (context, index) {
                            final trip = unsettledTrips[index];
                            final isSelected = selectedTrips.any((t) => t['id'] == trip['id']);
                            final hireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;

                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedTrips.add(trip);
                                  } else {
                                    selectedTrips.removeWhere((t) => t['id'] == trip['id']);
                                  }
                                  // Update amount based on selected trips
                                  double total = 0;
                                  for (var t in selectedTrips) {
                                    total += double.tryParse(t['truckHireCost']?.toString() ?? '0') ?? 0.0;
                                  }
                                  amountController.text = total.toStringAsFixed(0);
                                });
                              },
                              title: Text(
                                '${trip['origin']} → ${trip['destination']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${trip['truckNumber']} • ₹${hireCost.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected trips summary
                      if (selectedTrips.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedTrips.length} trip(s) selected',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Total: ₹${selectedTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Amount Paid
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                        helperText: 'Edit if paying partial amount',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Payment Method
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other']
                          .map((method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          paymentMethod = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter amount')),
                          );
                          return;
                        }

                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter valid amount')),
                          );
                          return;
                        }

                        // If trips are selected and amount covers them, settle the trips
                        bool allSettled = true;
                        int settledCount = 0;
                        List<String> errorMessages = [];

                        if (selectedTrips.isNotEmpty) {
                          for (var trip in selectedTrips) {
                            final tripId = trip['id'] as int;
                            final hireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;

                            // Calculate how much of this trip's cost is covered
                            double amountForThisTrip = hireCost;
                            if (amount < selectedTotal) {
                              // Partial payment - distribute proportionally
                              amountForThisTrip = (hireCost / selectedTotal) * amount;
                            }

                            // Only settle if trip cost is fully covered
                            if (amountForThisTrip >= hireCost * 0.99) { // 99% to account for rounding
                              final result = await ApiService.settleTrip(
                                tripId: tripId,
                                settleAmount: hireCost.toString(),
                                settlePaymentMode: paymentMethod,
                                settleDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                                settleNotes: noteController.text.isNotEmpty
                                    ? 'Supplier payment: ${noteController.text}'
                                    : 'Supplier payment received',
                              );

                              if (result['success'] == true) {
                                settledCount++;
                              } else {
                                allSettled = false;
                                final tripInfo = '${trip['origin']} → ${trip['destination']}';
                                errorMessages.add('$tripInfo: ${result['message']}');
                              }
                            }
                          }
                        }

                        Navigator.pop(context);
                        if (mounted) {
                          if (selectedTrips.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment of ₹${amount.toStringAsFixed(0)} recorded'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (settledCount > 0 && errorMessages.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$settledCount trip(s) settled successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (settledCount > 0 && errorMessages.isNotEmpty) {
                            // Show partial success with first error
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$settledCount trip(s) settled. ${errorMessages.length} failed:\n${errorMessages.first}',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } else if (errorMessages.isNotEmpty) {
                            // Show first error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessages.first),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to settle trips. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          _loadData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Submit Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.appBarColor,
          foregroundColor: AppColors.appBarTextColor,
          title: Text(widget.supplierName),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final balance = _supplierData?['balance'] ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Text(widget.supplierName),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'call':
                  _callSupplier();
                  break;
                case 'edit':
                  _showEditSupplierDialog();
                  break;
                case 'delete':
                  _confirmDeleteSupplier();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'call',
                enabled: _supplierData?['phone']?.toString().isNotEmpty ?? false,
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: (_supplierData?['phone']?.toString().isNotEmpty ?? false) ? Colors.black87 : Colors.grey),
                    const SizedBox(width: 12),
                    Text('Call Supplier', style: TextStyle(color: (_supplierData?['phone']?.toString().isNotEmpty ?? false) ? Colors.black87 : Colors.grey)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Edit Supplier'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Supplier', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Balance and View Report Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Supplier Balance : ',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '₹${balance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SupplierBalanceReportScreen(
                                  suppliers: [
                                    {
                                      'id': widget.supplierId,
                                      'name': widget.supplierName,
                                      'balance': balance,
                                    }
                                  ],
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue.shade100,
                            foregroundColor: Colors.black87,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 24),
                          label: const Text(
                            'View Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Trips'),
                    Tab(text: 'Passbook'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTripsTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedMonth,
                  items: ['All Months', 'This Month', 'Last 3 Months', 'Last 6 Months', 'This Year'],
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedTripFilter,
                  items: ['All Trips', 'Market', 'Contract', 'Settled', 'Unsettled'],
                  onChanged: (value) {
                    setState(() {
                      _selectedTripFilter = value!;
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: Show search
                },
              ),
            ],
          ),
        ),

        // Trips List
        Expanded(
          child: _supplierTrips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No trips found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _supplierTrips.length,
                  itemBuilder: (context, index) {
                    return _buildTripCard(_supplierTrips[index]);
                  },
                ),
        ),

        // Action Buttons
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
                child: FloatingActionButton.extended(
                  onPressed: _addTrip,
                  backgroundColor: const Color(0xFF2E8B57),
                  heroTag: 'addTripFromSupplier',
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
                  backgroundColor: Colors.blue,
                  heroTag: 'addPaymentFromSupplier',
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

  Widget _buildPassbookTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedMonth,
                  items: ['All Months', 'This Month', 'Last 3 Months'],
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedPassbookFilter,
                  items: ['Trips & Payments', 'Trips', 'Payments'],
                  onChanged: (value) {
                    setState(() {
                      _selectedPassbookFilter = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Passbook List
        Expanded(
          child: _filteredTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _filteredTransactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
        ),

        // Action Buttons
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
                child: FloatingActionButton.extended(
                  onPressed: _addTrip,
                  backgroundColor: const Color(0xFF2E8B57),
                  heroTag: 'addTripFromPassbook',
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
                  backgroundColor: Colors.blue,
                  heroTag: 'addPaymentFromPassbook2',
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final hireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
    final status = trip['status']?.toString() ?? 'Pending';
    final truckType = trip['truckType']?.toString() ?? 'Market';
    final startDate = trip['startDate']?.toString() ?? '';
    final tripId = trip['id'] ?? 0;

    // Format date if needed
    String formattedDate = startDate;
    if (startDate.isNotEmpty) {
      try {
        final date = DateTime.parse(startDate);
        formattedDate = DateFormat('dd MMM yyyy').format(date);
      } catch (e) {
        formattedDate = startDate;
      }
    }

    return GestureDetector(
      onTap: () async {
        // Navigate to trip detail screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(tripId: tripId),
          ),
        );
        // Reload data when returning from trip detail screen
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    trip['truckNumber']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      truckType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '₹${hireCost.toStringAsFixed(0)}',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip['origin']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip['destination']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: status == 'Settled' ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  _showAddPaymentDialog(prefilledTrip: trip);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Manage Supplier Balance'),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? '';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final date = transaction['date']?.toString() ?? '';
    final description = transaction['description']?.toString() ?? '';

    // Format date
    String formattedDate = date;
    if (date.isNotEmpty) {
      try {
        final dateObj = DateTime.parse(date);
        formattedDate = DateFormat('dd MMM yyyy').format(dateObj);
      } catch (e) {
        formattedDate = date;
      }
    }

    // Determine color and icon based on transaction type
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    bool isCredit = false;

    switch (type) {
      case 'advance':
        typeColor = Colors.orange;
        typeIcon = Icons.arrow_upward;
        typeLabel = 'Advance';
        isCredit = false;
        break;
      case 'charge':
        typeColor = Colors.red;
        typeIcon = Icons.add_circle_outline;
        typeLabel = 'Charge';
        isCredit = true;
        break;
      case 'payment':
        typeColor = Colors.green;
        typeIcon = Icons.payment;
        typeLabel = 'Payment';
        isCredit = false;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.receipt;
        typeLabel = type;
        isCredit = false;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Transaction type icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Amount and actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} ₹${amount.toInt()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transaction['paymentMode']?.toString() ??
                transaction['chargeType']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _showEditTransactionDialog(transaction),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showDeleteTransactionDialog(transaction),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.delete, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditTransactionDialog(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? '';
    final id = transaction['id']?.toString() ?? '';
    final tripId = transaction['tripId'];

    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: Trip ID not found')),
      );
      return;
    }

    // Extract numeric ID from the prefixed ID (e.g., "adv_1" -> 1)
    int numericId;
    try {
      numericId = int.parse(id.split('_').last);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid transaction ID')),
      );
      return;
    }

    final amountController = TextEditingController(
      text: transaction['amount']?.toString() ?? '',
    );
    final dateController = TextEditingController(
      text: transaction['date']?.toString() ?? '',
    );
    String selectedValue = transaction['paymentMode']?.toString() ??
        transaction['chargeType']?.toString() ?? 'Cash';

    String dialogTitle = type == 'advance'
        ? 'Edit Advance'
        : type == 'charge'
            ? 'Edit Charge'
            : 'Edit Payment';

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dialogTitle,
                        style: const TextStyle(
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
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(dateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setModalState(() {
                          dateController.text =
                              DateFormat('yyyy-MM-dd').format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (type == 'advance' || type == 'payment')
                    DropdownButtonFormField<String>(
                      value: selectedValue,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cash', 'Online', 'Cheque'].map((mode) {
                        return DropdownMenuItem(value: mode, child: Text(mode));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedValue = value);
                        }
                      },
                    ),
                  if (type == 'charge')
                    DropdownButtonFormField<String>(
                      value: selectedValue,
                      decoration: const InputDecoration(
                        labelText: 'Charge Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'Detention Charges',
                        'Extra Charges',
                        'Halting Charges',
                        'Loading Charges',
                        'Unloading Charges',
                        'Other',
                      ].map((chargeType) {
                        return DropdownMenuItem(
                          value: chargeType,
                          child: Text(chargeType),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedValue = value);
                        }
                      },
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter amount')),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        bool success = false;

                        if (type == 'advance') {
                          success = await ApiService.updateSupplierAdvance(
                            tripId: tripId,
                            advanceId: numericId,
                            amount: amountController.text,
                            date: dateController.text,
                            paymentMode: selectedValue,
                          );
                        } else if (type == 'charge') {
                          success = await ApiService.updateSupplierCharge(
                            tripId: tripId,
                            chargeId: numericId,
                            amount: amountController.text,
                            date: dateController.text,
                            chargeType: selectedValue,
                          );
                        } else if (type == 'payment') {
                          success = await ApiService.updateSupplierPayment(
                            tripId: tripId,
                            paymentId: numericId,
                            amount: amountController.text,
                            date: dateController.text,
                            paymentMode: selectedValue,
                          );
                        }

                        if (mounted) {
                          await _loadData();
                        }

                        if (!mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$dialogTitle updated successfully'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update $type'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  void _showDeleteTransactionDialog(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? '';
    final id = transaction['id']?.toString() ?? '';
    final tripId = transaction['tripId'];

    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Trip ID not found')),
      );
      return;
    }

    // Extract numeric ID from the prefixed ID (e.g., "adv_1" -> 1)
    int numericId;
    try {
      numericId = int.parse(id.split('_').last);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid transaction ID')),
      );
      return;
    }

    String itemName = type == 'advance'
        ? 'Advance'
        : type == 'charge'
            ? 'Charge'
            : 'Payment';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemName'),
        content: Text('Are you sure you want to delete this $itemName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                bool success = false;

                if (type == 'advance') {
                  success = await ApiService.deleteSupplierAdvance(
                    tripId: tripId,
                    advanceId: numericId,
                  );
                } else if (type == 'charge') {
                  success = await ApiService.deleteSupplierCharge(
                    tripId: tripId,
                    chargeId: numericId,
                  );
                } else if (type == 'payment') {
                  success = await ApiService.deleteSupplierPayment(
                    tripId: tripId,
                    paymentId: numericId,
                  );
                }

                if (mounted) {
                  await _loadData();
                }

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$itemName deleted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete $itemName')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _callSupplier() async {
    final phoneNumber = _supplierData?['phone']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error making phone call')),
        );
      }
    }
  }

  void _showEditSupplierDialog() {
    final nameController = TextEditingController(text: _supplierData?['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: _supplierData?['phone']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Supplier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier name is required')),
                          );
                          return;
                        }

                        Navigator.pop(context);

                        try {
                          final success = await ApiService.updateSupplier(
                            supplierId: widget.supplierId,
                            name: name,
                            phone: phoneController.text.trim(),
                          );

                          if (success && mounted) {
                            // Reload data immediately after update
                            await _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Supplier updated successfully')),
                              );
                            }
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to update supplier')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSupplier() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final success = await ApiService.deleteSupplier(supplierId: widget.supplierId);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supplier deleted successfully')),
                  );
                  Navigator.pop(context); // Go back to supplier list
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete supplier')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

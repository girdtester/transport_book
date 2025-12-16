import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/appbar.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'invoice_details_screen.dart';

class DigitalInvoiceListScreen extends StatefulWidget {
  const DigitalInvoiceListScreen({super.key});

  @override
  State<DigitalInvoiceListScreen> createState() => _DigitalInvoiceListScreenState();
}

class _DigitalInvoiceListScreenState extends State<DigitalInvoiceListScreen> {
  List<dynamic> _allInvoices = [];
  List<dynamic> _filteredInvoices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Paid', 'Unpaid'
  bool _sortLatestToOldest = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await ApiService.getInvoices();
      setState(() {
        _allInvoices = invoices;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      // Start with all invoices
      List<dynamic> filtered = _allInvoices;

      // Apply status filter
      if (_selectedFilter == 'Paid') {
        filtered = filtered.where((invoice) {
          final balance = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
          return balance == 0;
        }).toList();
      } else if (_selectedFilter == 'Unpaid') {
        filtered = filtered.where((invoice) {
          final balance = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
          return balance > 0;
        }).toList();
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        filtered = filtered.where((invoice) {
          final invoiceNumber = invoice['invoiceNumber']?.toString().toLowerCase() ?? '';
          final partyName = invoice['partyName']?.toString().toLowerCase() ?? '';
          return invoiceNumber.contains(searchLower) || partyName.contains(searchLower);
        }).toList();
      }

      // Apply sorting
      filtered.sort((a, b) {
        final dateA = DateTime.tryParse(a['invoiceDate']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['invoiceDate']?.toString() ?? '') ?? DateTime.now();
        return _sortLatestToOldest ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      });

      _filteredInvoices = filtered;
    });
  }

  void _filterInvoices(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilters();
  }

  void _toggleSort() {
    setState(() {
      _sortLatestToOldest = !_sortLatestToOldest;
    });
    _applyFilters();
  }

  int _getFilterCount(String filter) {
    if (filter == 'All') {
      return _allInvoices.length;
    } else if (filter == 'Paid') {
      return _allInvoices.where((invoice) {
        final balance = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
        return balance == 0;
      }).length;
    } else if (filter == 'Unpaid') {
      return _allInvoices.where((invoice) {
        final balance = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
        return balance > 0;
      }).length;
    }
    return 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Partially Paid':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedFilter != 'All') count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  bool _hasActiveFilters() {
    return _getActiveFiltersCount() > 0;
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'All';
      _searchQuery = '';
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(title: "Invoices",onBack: () {
        Navigator.pop(context);
      },

      ),
      body: Column(
        children: [
          // Filter Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterCard(
                    title: 'All Invoices',
                    count: _getFilterCount('All'),
                    isSelected: _selectedFilter == 'All',
                    color: AppColors.info,
                    onTap: () => _setFilter('All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterCard(
                    title: 'Paid Invoices',
                    count: _getFilterCount('Paid'),
                    isSelected: _selectedFilter == 'Paid',
                    color: AppColors.lightGreen,
                    onTap: () => _setFilter('Paid'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterCard(
                    title: 'Unpaid Invoices',
                    count: _getFilterCount('Unpaid'),
                    isSelected: _selectedFilter == 'Unpaid',
                    color: AppColors.error,
                    onTap: () => _setFilter('Unpaid'),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: TextField(
              controller: TextEditingController(text: _searchQuery),
              onChanged: _filterInvoices,
              decoration: InputDecoration(
                hintText: 'Search Invoice No, Party',
                hintStyle: TextStyle(color: Colors.grey[400]),
                suffixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
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

          // Section Header with Sort
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invoices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                InkWell(
                  onTap: _toggleSort,
                  child: Row(
                    children: [
                      Text(
                        _sortLatestToOldest ? 'Latest to Oldest' : 'Oldest to Latest',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _sortLatestToOldest ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: AppColors.info,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Invoice List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No invoices found'
                        : 'No invoices match your search',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadInvoices,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _filteredInvoices.length,
                itemBuilder: (context, index) {
                  final invoice = _filteredInvoices[index];
                  return _buildInvoiceCard(invoice);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: _showCreateInvoiceBottomSheet,
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, size: 22),
        label: const Text('ADD INVOICE'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFilterCard({
    required String title,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded( // Add this to make all cards equal width
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Add this
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSelected ? color : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2, // Allow text to wrap if needed
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final balanceAmount = double.tryParse(invoice['balanceAmount']?.toString() ?? '0') ?? 0.0;
    final isPaid = balanceAmount == 0;
    final totalAmount = double.tryParse(invoice['totalAmount']?.toString() ?? '0') ?? 0.0;
    final invoiceDate = invoice['invoiceDate']?.toString() ?? '';

    // Format date
    String formattedDate = invoiceDate;
    try {
      final date = DateTime.parse(invoiceDate);
      formattedDate = DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      // Keep original format if parsing fails
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvoiceDetailsScreen(
                invoiceId: invoice['id'] ?? 0,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice['invoiceNumber']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoice['partyName']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid ? AppColors.primaryGreen : AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Unpaid',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

  void _showCreateInvoiceBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateInvoiceSheet(
        onInvoiceCreated: () {
          _loadInvoices();
        },
      ),
    );
  }
}

class _CreateInvoiceSheet extends StatefulWidget {
  final VoidCallback onInvoiceCreated;

  const _CreateInvoiceSheet({required this.onInvoiceCreated});

  @override
  State<_CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<_CreateInvoiceSheet> {
  List<dynamic> _parties = [];
  List<dynamic> _allTrips = [];
  List<dynamic> _selectedTrips = [];
  Map<String, dynamic>? _selectedParty;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = true;
  String _invoiceNumber = '';
  Set<int> _usedTripIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final parties = await ApiService.getParties();
    final trips = await ApiService.getAllTrips();

    // Generate invoice number - find the highest number and increment
    final invoices = await ApiService.getInvoices();
    int maxNumber = 0;
    for (var invoice in invoices) {
      final invoiceNum = invoice['invoiceNumber']?.toString() ?? '';
      // Extract number from "INV-0001" format
      final match = RegExp(r'INV-(\d+)').firstMatch(invoiceNum);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxNumber) maxNumber = num;
      }
    }
    final invoiceNumber = 'INV-${(maxNumber + 1).toString().padLeft(4, '0')}';

    // Collect all trip IDs that are already in invoices
    final Set<int> usedTripIds = {};
    for (var invoice in invoices) {
      if (invoice['trips'] != null && invoice['trips'] is List) {
        for (var trip in invoice['trips']) {
          if (trip['id'] != null) {
            usedTripIds.add(trip['id'] as int);
          }
        }
      }
    }

    // Debug: Print used trip IDs
    print('=== INVOICE DEBUG (Digital) ===');
    print('Used trip IDs: $usedTripIds');
    print('Total invoices: ${invoices.length}');

    setState(() {
      _parties = parties;
      _allTrips = trips;
      _invoiceNumber = invoiceNumber;
      _usedTripIds = usedTripIds;
      _isLoading = false;
    });
  }

  List<dynamic> _getPartTrips() {
    if (_selectedParty == null) return [];

    print('=== FILTERING TRIPS (Digital) ===');
    print('Selected party: ${_selectedParty!['name']}');
    print('Total trips: ${_allTrips.length}');
    print('Used trip IDs: $_usedTripIds');

    final filtered = _allTrips.where((trip) {
      final tripId = trip['id'] as int;
      final partyName = trip['partyName'];
      final status = trip['status'];
      final isPartyMatch = partyName == _selectedParty!['name'];
      final isNotSettled = status != 'Settled';
      final isNotUsed = !_usedTripIds.contains(tripId);

      print('Trip $tripId: party=$partyName (match=$isPartyMatch), status=$status (notSettled=$isNotSettled), used=${!isNotUsed}');

      return isPartyMatch && isNotSettled && isNotUsed;
    }).toList();

    print('Filtered trips: ${filtered.length}');
    return filtered;
  }

  double _calculateTotal() {
    double total = 0;
    for (var trip in _selectedTrips) {
      total += double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    }
    return total;
  }

  Future<void> _createInvoice() async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a party')),
      );
      return;
    }

    if (_selectedTrips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one trip')),
      );
      return;
    }

    // Prepare trip data for invoice
    final tripData = _selectedTrips.map((trip) => {
      'tripId': trip['id'],
      'origin': trip['origin'],
      'destination': trip['destination'],
      'truckNumber': trip['truckNumber'],
      'date': trip['startDate'],
      'freightAmount': trip['freightAmount'],
    }).toList();

    final totalAmount = _calculateTotal();

    final result = await ApiService.createInvoice(
      invoiceNumber: _invoiceNumber,
      partyName: _selectedParty!['name'],
      partyAddress: _selectedParty!['address'] ?? '',
      partyGST: _selectedParty!['gst'] ?? '',
      invoiceDate: DateFormat('yyyy-MM-dd').format(_invoiceDate),
      dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
      totalAmount: totalAmount,
      balanceAmount: totalAmount,
      paidAmount: 0.0,
      trips: tripData,
    );

    if (result != null && mounted) {
      Navigator.pop(context);
      widget.onInvoiceCreated();

      // Navigate to invoice preview
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceDetailsScreen(
            invoiceId: result['id'],
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Invoice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textWhite,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textWhite),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice Number
                    Text(
                      'Invoice Number',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _invoiceNumber,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Party Selection
                    Text(
                      'Select Party',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          isExpanded: true,
                          value: _selectedParty,
                          hint: const Text('Select a party'),
                          items: _parties.map((party) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: party,
                              child: Text(party['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedParty = value;
                              _selectedTrips = [];
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _invoiceDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    setState(() => _invoiceDate = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_invoiceDate),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _dueDate,
                                    firstDate: _invoiceDate,
                                    lastDate: DateTime(2030),
                                  );
                                  if (date != null) {
                                    setState(() => _dueDate = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_dueDate),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const Icon(Icons.calendar_today, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Trip Selection
                    if (_selectedParty != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Trips',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_selectedTrips.isNotEmpty)
                            Text(
                              '${_selectedTrips.length} selected',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E8B57),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _getPartTrips().isEmpty
                            ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No trips found for this party',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _getPartTrips().length,
                          itemBuilder: (context, index) {
                            final trip = _getPartTrips()[index];
                            final isSelected = _selectedTrips.contains(trip);

                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedTrips.add(trip);
                                  } else {
                                    _selectedTrips.remove(trip);
                                  }
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
                                '${trip['truckNumber']} • ₹${trip['freightAmount']}',
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

                      // Total Amount
                      if (_selectedTrips.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₹${_calculateTotal().toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E8B57),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 24),

                    // Create Invoice Button
                    ElevatedButton(
                      onPressed: _createInvoice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create Invoice',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textWhite
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
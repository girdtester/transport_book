import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../screens/invoice_details_screen.dart';

/// Helper function to show the create invoice bottom sheet
void showCreateInvoiceSheet(
  BuildContext context, {
  VoidCallback? onInvoiceCreated,
  String? preselectedPartyName,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateInvoiceSheet(
      onInvoiceCreated: onInvoiceCreated ?? () {},
      preselectedPartyName: preselectedPartyName,
    ),
  );
}

class CreateInvoiceSheet extends StatefulWidget {
  final VoidCallback onInvoiceCreated;
  final String? preselectedPartyName;

  const CreateInvoiceSheet({
    super.key,
    required this.onInvoiceCreated,
    this.preselectedPartyName,
  });

  @override
  State<CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<CreateInvoiceSheet> {
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
    print('=== INVOICE DEBUG ===');
    print('Used trip IDs: $usedTripIds');
    print('Total invoices: ${invoices.length}');

    // Auto-select party if preselectedPartyName is provided
    Map<String, dynamic>? selectedParty;
    if (widget.preselectedPartyName != null) {
      try {
        selectedParty = parties.firstWhere(
          (party) => party['name'] == widget.preselectedPartyName,
        );
      } catch (e) {
        // Party not found, leave null
        selectedParty = null;
      }
    }

    setState(() {
      _parties = parties;
      _allTrips = trips;
      _invoiceNumber = invoiceNumber;
      _selectedParty = selectedParty;
      _usedTripIds = usedTripIds;
      _isLoading = false;
    });
  }

  List<dynamic> _getPartyTrips() {
    if (_selectedParty == null) return [];

    print('=== FILTERING TRIPS ===');
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
              decoration: const BoxDecoration(
                color: Color(0xFF2E8B57),
                borderRadius: BorderRadius.only(
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
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
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
                        color: Colors.grey[600],
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Party Selection
                    Text(
                      'Select Party',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
                                  color: Colors.grey[600],
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
                                  color: Colors.grey[600],
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
                        child: _getPartyTrips().isEmpty
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
                                itemCount: _getPartyTrips().length,
                                itemBuilder: (context, index) {
                                  final trip = _getPartyTrips()[index];
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
                        backgroundColor: const Color(0xFF2E8B57),
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

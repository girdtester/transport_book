import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import 'add_trip_screen.dart';
import 'add_load_screen.dart';
import 'trip_bill_screen.dart';
import '../../trucks/screens/truck_details_screen.dart';
import '../../driver/screens/driver_detail_screen.dart';
import '../../driver/screens/driver_report_screen.dart';
import '../../party/screens/party_detail_screen.dart';
import '../../supplier/screens/supplier_detail_screen.dart';
import '../../lr/screens/create_lr_screen.dart';
import '../../lr/screens/view_lr_screen.dart';
import 'pod_challan_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final int tripId;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _tripDetails;
  List<dynamic> _driverTransactions = [];
  List<Map<String, dynamic>> _loads = [];
  bool _isLoading = true;
  int? _expandedAccordionIndex; // Track which accordion is expanded (null = none, 0 = main trip, 1+ = loads)
  List<dynamic> _parties = [];
  List<String> _cities = [];
  List<dynamic> _lorryReceipts = []; // Store LRs for this trip

  // Store selected IDs for update
  int? _selectedPartyId;
  int? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs: Loads/Party, Profit, Driver, More
    _loadTripDetails();
    _loadLorryReceipts(); // Load LRs for this trip
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTripDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    print('=== LOADING TRIP DETAILS ===');
    print('Trip ID: ${widget.tripId}');

    final details = await ApiService.getTripDetails(widget.tripId);

    if (!mounted) return;

    print('Trip details response: $details');
    if (details != null) {
      print('Trip Status: ${details['status']}');
      print('Truck Type: ${details['truckType']}');
      print('Supplier: ${details['supplierName']}');
    }

    // Load driver transactions if driver exists
    print('Trip details loaded. Driver ID: ${details?['driverId']}, Driver Name: ${details?['driverName']}');

    if (details != null && details['driverId'] != null) {
      try {
        print('Fetching driver details for driver ID: ${details['driverId']}');
        final driverDetails = await ApiService.getDriverDetails(details['driverId']);

        if (!mounted) return;

        print('Driver details response: $driverDetails');

        if (driverDetails != null && driverDetails['transactions'] != null) {
          _driverTransactions = driverDetails['transactions'];
          print('Loaded ${_driverTransactions.length} driver transactions');
        } else {
          print('No transactions found in driver details');
        }
      } catch (e) {
        print('Error loading driver transactions: $e');
      }
    } else {
      print('No driverId found in trip details. Cannot load driver transactions.');
    }

    // Load trip loads
    await _loadTripLoads();

    if (!mounted) return;

    setState(() {
      _tripDetails = details;
      // Store IDs for update
      _selectedPartyId = details?['partyId'];
      _selectedDriverId = details?['driverId'];
      _isLoading = false;
    });
  }

  Future<void> _loadTripLoads() async {
    try {
      final loads = await ApiService.getTripLoads(widget.tripId);

      if (!mounted) return;

      setState(() {
        _loads = loads;
      });
      print('Loaded ${_loads.length} loads for trip ${widget.tripId}');
    } catch (e) {
      print('Error loading trip loads: $e');
    }
  }

  Future<void> _loadPartiesAndCities() async {
    try {
      // Load parties
      final parties = await ApiService.getParties();
      if (parties != null && mounted) {
        setState(() {
          _parties = parties;
        });
      }

      // Load cities
      final cities = await ApiService.getCities();
      if (mounted) {
        setState(() {
          _cities = cities;
        });
      }
    } catch (e) {
      print('Error loading parties and cities: $e');
    }
  }

  // Load Lorry Receipts for this trip
  Future<void> _loadLorryReceipts() async {
    try {
      // Use the ApiService method which handles headers internally
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/lorry-receipts/?trip_id=${widget.tripId}'),
        headers: await AuthStorage.getAuthHeaders(),
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> lrs = json.decode(response.body);
        setState(() {
          _lorryReceipts = lrs;
        });
        print('Loaded ${lrs.length} LRs for trip ${widget.tripId}');
      }
    } catch (e) {
      print('Error loading LRs: $e');
    }
  }

  // Handle menu actions (Delete, Call Party, Call Driver, Share, View LR)
  void _handleMenuAction(String action) {
    switch (action) {
      case 'delete':
        _confirmDeleteTrip();
        break;
      case 'call_party':
        _callParty();
        break;
      case 'call_driver':
        _callDriver();
        break;
      case 'share':
        _shareTrip();
        break;
      case 'view_lr':
        _viewLR();
        break;
    }
  }

  // Navigate to Truck Details
  void _navigateToTruckDetails() {
    if (_tripDetails?['truckId'] != null && _tripDetails?['truckNumber'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TruckDetailsScreen(
            truckId: _tripDetails!['truckId'],
            truckNumber: _tripDetails!['truckNumber'],
          ),
        ),
      );
    }
  }

  // Navigate to Driver or Supplier Details based on truck type
  void _navigateToDriverDetails() {
    final truckType = _tripDetails?['truckType'];

    // For market trucks, navigate to supplier details
    if (truckType == 'Market') {
      _navigateToSupplierDetails();
      return;
    }

    // For own trucks, navigate to driver details
    final driverId = _tripDetails?['driverId'];
    final driverName = _tripDetails?['driverName'];

    if (driverName == null || driverName == 'Not Assigned' || driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No driver assigned to this trip')),
      );
      return;
    }

    if (driverId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverDetailScreen(
            driverId: driverId,
            driverName: driverName,
          ),
        ),
      ).then((_) {
        // Reload trip details after returning
        _loadTripDetails();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver details not available')),
      );
    }
  }

  // Navigate to Supplier Details
  void _navigateToSupplierDetails() {
    final supplierId = _tripDetails?['supplierId'];
    final supplierName = _tripDetails?['supplierName'];

    if (supplierName == null || supplierName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No supplier assigned to this trip')),
      );
      return;
    }

    if (supplierId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupplierDetailScreen(
            supplierId: supplierId,
            supplierName: supplierName,
          ),
        ),
      ).then((_) {
        // Reload trip details after returning
        _loadTripDetails();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier details not available')),
      );
    }
  }

  // Open Driver Report
  void _openDriverReport() {
    final driverId = _tripDetails?['driverId'];
    final driverName = _tripDetails?['driverName'];

    if (driverName == null || driverName == 'Not Assigned' || driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No driver assigned to this trip')),
      );
      return;
    }

    if (driverId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverReportScreen(
            driverId: driverId,
            driverName: driverName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver report not available')),
      );
    }
  }

  // Navigate to Party Details
  void _navigateToPartyDetails() {
    final partyId = _tripDetails?['partyId'];
    final partyName = _tripDetails?['partyName'];

    if (partyName == null || partyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party details not available')),
      );
      return;
    }

    if (partyId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartyDetailScreen(
            partyId: partyId,
            partyName: partyName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party details not available')),
      );
    }
  }

  // Show Settle Amount Dialog
  void _showSettleAmountDialog() {
    final driverId = _tripDetails?['driverId'];
    final driverName = _tripDetails?['driverName'];
    final collectFromDriver = _tripDetails?['collectFromDriver'] ?? 0;

    if (driverName == null || driverName == 'Not Assigned' || driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No driver assigned to this trip')),
      );
      return;
    }

    // Prefill amount if balance > 0
    final TextEditingController amountController = TextEditingController(
      text: collectFromDriver > 0 ? collectFromDriver.toString() : '',
    );
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
                        'Settle Amount',
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
                    'Collect from: $driverName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Field
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(selectedDate),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setModalState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Notes Field
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Add any notes...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Confirm Button
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
                        // Use driver-level transaction API with type 'gave' (driver gave money to company)
                        if (driverId != null) {
                          final result = await ApiService.addDriverBalanceTransaction(
                            driverId: driverId,
                            type: 'gave',
                            amount: amountController.text,
                            reason: 'Trip Settlement - ${_tripDetails!['truckNumber']}',
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            note: notesController.text.isNotEmpty ? notesController.text : null,
                          );

                          // Reload trip details to refresh the balance
                          if (mounted) {
                            await _loadTripDetails();
                            await _loadTripLoads();
                          }

                          if (!mounted) return;

                          if (result != null) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Amount settled successfully')),
                              );
                            } catch (e) {
                              // Ignore snackbar errors if widget is disposed
                            }
                          } else {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to settle amount')),
                              );
                            } catch (e) {
                              // Ignore snackbar errors if widget is disposed
                            }
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } catch (e) {
                          // Ignore snackbar errors if widget is disposed
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm Settlement',
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

  // Open LR Creation (with trip selection if loads exist)
  void _openLRCreation() {
    // Show list of existing LRs or create new
    _showLRListDialog();
  }

  // Show LR list dialog
  void _showLRListDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lorry Receipts (LR)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            // Add new LR button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Check if this trip has loads
                  if (_loads != null && _loads!.isNotEmpty) {
                    _showTripSelectionDialog();
                  } else {
                    _navigateToLRCreation(widget.tripId, _tripDetails?['truckNumber']);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New LR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // List of existing LRs
            Expanded(
              child: _lorryReceipts.isEmpty
                  ? const Center(
                      child: Text(
                        'No LRs created yet',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _lorryReceipts.length,
                      itemBuilder: (context, index) {
                        final lr = _lorryReceipts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryGreen,
                              child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
                            ),
                            title: Text(
                              'LR #${lr['id']}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'From: ${lr['consignorName'] ?? 'N/A'}\nTo: ${lr['consigneeName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to LR details screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewLRScreen(lrId: lr['id']),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Show trip selection dialog for loads
  void _showTripSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Trip for LR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main trip
              ListTile(
                title: Text('Main Trip - ${_tripDetails?['truckNumber']}'),
                subtitle: Text(
                  '${_tripDetails?['origin']} → ${_tripDetails?['destination']}',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToLRCreation(widget.tripId, _tripDetails?['truckNumber']);
                },
              ),
              const Divider(),
              // Loads
              ...(_loads ?? []).map((load) {
                return ListTile(
                  title: Text('Load ${load['id']} - ${load['truckNumber']}'),
                  subtitle: Text(
                    '${load['origin']} → ${load['destination']}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToLRCreation(load['id'], load['truckNumber']);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Navigate to LR creation screen
  Future<void> _navigateToLRCreation(int tripId, String? truckNumber) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateLRScreen(
          tripId: tripId,
          truckNumber: truckNumber,
        ),
      ),
    );

    // Reload if LR was created
    if (result == true) {
      _loadTripDetails();
    }
  }

  // Open POD Challan upload
  void _openPODChallan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PODChallanScreen(
        tripId: widget.tripId,
        truckNumber: _tripDetails?['truckNumber'],
      ),
    ).then((result) {
      // Reload if POD was uploaded
      if (result == true) {
        _loadTripDetails();
      }
    });
  }

  // Confirm Delete Trip
  void _confirmDeleteTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrip();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete Trip
  Future<void> _deleteTrip() async {
    try {
      final success = await ApiService.deleteTrip(widget.tripId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to previous screen and signal reload
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete trip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Call Party
  Future<void> _callParty() async {
    final partyPhone = _tripDetails?['partyPhone'];
    final partyName = _tripDetails?['partyName'];

    if (partyPhone != null && partyPhone.toString().isNotEmpty) {
      try {
        final uri = Uri(scheme: 'tel', path: partyPhone.toString());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Party phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Call Driver
  Future<void> _callDriver() async {
    final driverPhone = _tripDetails?['driverPhone'];
    final driverName = _tripDetails?['driverName'];

    if (driverPhone != null && driverPhone.toString().isNotEmpty) {
      try {
        final uri = Uri(scheme: 'tel', path: driverPhone.toString());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Share Trip
  Future<void> _shareTrip() async {
    if (_tripDetails == null) return;

    try {
      final tripInfo = StringBuffer();
      tripInfo.writeln('📦 TRIP DETAILS');
      tripInfo.writeln('━━━━━━━━━━━━━━━━━━━━━━');
      tripInfo.writeln('');
      tripInfo.writeln('🚛 Truck: ${_tripDetails!['truckNumber']}');
      tripInfo.writeln('👤 Driver: ${_tripDetails!['driverName'] ?? 'Not Assigned'}');
      tripInfo.writeln('🏢 Party: ${_tripDetails!['partyName']}');
      tripInfo.writeln('');
      tripInfo.writeln('📍 Route:');
      tripInfo.writeln('   From: ${_tripDetails!['origin']}');
      tripInfo.writeln('   To: ${_tripDetails!['destination']}');
      tripInfo.writeln('');
      tripInfo.writeln('📅 Start Date: ${_tripDetails!['startDate']}');
      if (_tripDetails!['tripStartDate'] != null) {
        tripInfo.writeln('🚀 Trip Started: ${_tripDetails!['tripStartDate']}');
      }
      if (_tripDetails!['tripEndDate'] != null) {
        tripInfo.writeln('🏁 Trip Ended: ${_tripDetails!['tripEndDate']}');
      }
      tripInfo.writeln('');
      tripInfo.writeln('💰 Freight: ${CurrencyFormatter.formatWithSymbol(_tripDetails!['freightAmount'])}');
      tripInfo.writeln('📊 Status: ${_tripDetails!['status']}');

      if (_tripDetails!['lrNumber'] != null && _tripDetails!['lrNumber'].toString().isNotEmpty) {
        tripInfo.writeln('');
        tripInfo.writeln('📄 LR Number: ${_tripDetails!['lrNumber']}');
      }

      await Share.share(
        tripInfo.toString(),
        subject: 'Trip Details - ${_tripDetails!['truckNumber']}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // View LR (Lorry Receipt)
  Future<void> _viewLR() async {
    if (_tripDetails == null) return;

    final tripId = _tripDetails!['id'];
    if (tripId == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final lrData = await ApiService.getLRByTripId(tripId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (lrData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No LR found for this trip'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show LR in a dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E8B57),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lorry Receipt (LR)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LR Number and Date
                        _buildLRField('LR Number', lrData['lrNumber'] ?? 'N/A'),
                        _buildLRField('LR Date', lrData['lrDate'] ?? 'N/A'),
                        const Divider(height: 24),

                        // Company Details
                        const Text(
                          'Company Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildLRField('Name', lrData['companyName'] ?? 'N/A'),
                        _buildLRField('GST', lrData['companyGst'] ?? 'N/A'),
                        _buildLRField('Mobile', lrData['companyMobile'] ?? 'N/A'),
                        const Divider(height: 24),

                        // Consignor Details
                        const Text(
                          'Consignor (From)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildLRField('Name', lrData['consignorName'] ?? 'N/A'),
                        _buildLRField('GST', lrData['consignorGst'] ?? 'N/A'),
                        _buildLRField('Address', lrData['consignorAddressLine1'] ?? 'N/A'),
                        _buildLRField('Mobile', lrData['consignorMobile'] ?? 'N/A'),
                        const Divider(height: 24),

                        // Consignee Details
                        const Text(
                          'Consignee (To)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildLRField('Name', lrData['consigneeName'] ?? 'N/A'),
                        _buildLRField('GST', lrData['consigneeGst'] ?? 'N/A'),
                        _buildLRField('Address', lrData['consigneeAddressLine1'] ?? 'N/A'),
                        _buildLRField('Mobile', lrData['consigneeMobile'] ?? 'N/A'),
                        const Divider(height: 24),

                        // Goods Details
                        const Text(
                          'Goods Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildLRField('Goods', lrData['goods'] ?? 'N/A'),
                        _buildLRField('Description', lrData['materialDescription'] ?? 'N/A'),
                        _buildLRField('Total Packages', lrData['totalPackages']?.toString() ?? 'N/A'),
                        _buildLRField('Actual Weight', lrData['actualWeight']?.toString() ?? 'N/A'),
                        _buildLRField('Charged Weight', lrData['chargedWeight']?.toString() ?? 'N/A'),
                        const Divider(height: 24),

                        // Charges
                        const Text(
                          'Charges',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildLRField('Freight Amount', '₹${lrData['freightAmount'] ?? '0'}'),
                        _buildLRField('GST Amount', '₹${lrData['gstAmount'] ?? '0'}'),
                        _buildLRField('Other Charges', '₹${lrData['otherCharges'] ?? '0'}'),
                        _buildLRField('Total Amount', '₹${lrData['totalAmount'] ?? '0'}', bold: true),
                        const Divider(height: 24),

                        // Payment Details
                        _buildLRField('Payment Terms', lrData['paymentTerms'] ?? 'N/A'),
                        _buildLRField('Paid By', lrData['paidBy'] ?? 'N/A'),
                        _buildLRField('Status', lrData['status'] ?? 'N/A'),

                        if (lrData['remarks'] != null && lrData['remarks'].toString().isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildLRField('Remarks', lrData['remarks']),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading LR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper widget to build LR field
  Widget _buildLRField(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Edit Freight Amount
  void _editFreightAmount({int? tripId, Map<String, dynamic>? tripData}) {
    final int targetTripId = tripId ?? widget.tripId;
    final Map<String, dynamic> data = tripData ?? _tripDetails!;

    final TextEditingController controller = TextEditingController(
      text: data['freightAmount']?.toString() ?? '0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Freight Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Freight Amount',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newAmount = controller.text;
              Navigator.pop(context);
              await _updateFreightAmount(newAmount, targetTripId, data);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Update Freight Amount via API
  Future<void> _updateFreightAmount(String amount, int tripId, Map<String, dynamic> tripData) async {
    try {
      final success = await ApiService.updateTrip(
        tripId: tripId,  // Use the provided tripId
        origin: tripData['origin'],
        destination: tripData['destination'],
        startDate: tripData['startDate'],
        endDate: tripData['startDate'], // Using start date as placeholder
        lrNumber: tripData['lrNumber'] ?? '',
        freightAmount: amount,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Freight amount updated successfully')),
        );
        await _loadTripDetails();
        await _loadTripLoads(); // Reload loads to show updated data in accordion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update freight amount')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Show Add Advance Dialog
  void _showAddAdvanceDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String paymentMode = 'Cash';

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
                        'Add Advance',
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
                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Field
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
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
                  ),
                  const SizedBox(height: 16),
                  // Payment Mode Field
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'Online', 'Cheque'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
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
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter amount')),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        final result = await ApiService.addTripAdvance(
                          tripId: targetTripId,
                          amount: amountController.text,
                          date: dateController.text,
                          paymentMode: paymentMode,
                        );

                        // Reload data first (before showing snackbar)
                        if (mounted) {
                          await _loadTripDetails();
                          await _loadTripLoads();
                        }

                        // Then show feedback (only if still mounted)
                        if (!mounted) return;

                        if (result != null) {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Advance added successfully')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        } else {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to add advance')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } catch (_) {
                          // Ignore snackbar errors if widget is disposed
                        }
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
                      'Add Advance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show Add Charge Dialog
  void _showAddChargeDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController typeController = TextEditingController();
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

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
                        'Add Charge',
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
                  // Charge Type Field
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Charge Type',
                      hintText: 'e.g., Loading, Unloading',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Field
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
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
                  ),
                  const SizedBox(height: 24),
                  // Submit Button
                  ElevatedButton(
                    onPressed: () async {
                      if (typeController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter charge type')),
                        );
                        return;
                      }
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter amount')),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        final result = await ApiService.addTripCharge(
                          tripId: targetTripId,
                          chargeType: typeController.text,
                          amount: amountController.text,
                          date: dateController.text,
                        );

                        // Reload data first (before showing snackbar)
                        if (mounted) {
                          await _loadTripDetails();
                          await _loadTripLoads();
                        }

                        // Then show feedback (only if still mounted)
                        if (!mounted) return;

                        if (result != null) {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Charge added successfully')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        } else {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to add charge')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } catch (_) {
                          // Ignore snackbar errors if widget is disposed
                        }
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
                      'Add Charge',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show Add Payment Dialog
  void _showAddPaymentDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String paymentMode = 'Cash';

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
                  // Amount Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Field
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
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
                  ),
                  const SizedBox(height: 16),
                  // Payment Mode Field
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'Online', 'Cheque'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
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
                      if (amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter amount')),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      try {
                        final result = await ApiService.addTripPayment(
                          tripId: targetTripId,
                          amount: amountController.text,
                          date: dateController.text,
                          paymentMode: paymentMode,
                        );

                        // Reload data first (before showing snackbar)
                        if (mounted) {
                          await _loadTripDetails();
                          await _loadTripLoads();
                        }

                        // Then show feedback (only if still mounted)
                        if (!mounted) return;

                        if (result != null) {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment added successfully')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        } else {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to add payment')),
                            );
                          } catch (e) {
                            // Ignore snackbar errors if widget is disposed
                          }
                        }
                      } catch (e) {
                        if (!mounted) return;
                        try {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } catch (_) {
                          // Ignore snackbar errors if widget is disposed
                        }
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
                      'Add Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SUPPLIER FINANCIAL DIALOGS ====================

  void _showAddSupplierAdvanceDialog() {
    final amountController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String paymentMode = 'Cash';

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
                      const Text(
                        'Add Supplier Advance',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'Online', 'Cheque'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => paymentMode = value);
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
                        final result = await ApiService.addSupplierAdvanceFromTrip(
                          tripId: widget.tripId,
                          amount: amountController.text,
                          date: dateController.text,
                          paymentMode: paymentMode,
                        );

                        if (mounted) {
                          await _loadTripDetails();
                        }

                        if (!mounted) return;

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier advance added successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to add supplier advance')),
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
                      'Add Advance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showAddSupplierChargeDialog() {
    final amountController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String chargeType = 'Extra Charges';

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
                      const Text(
                        'Add Supplier Charge',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: chargeType,
                    decoration: const InputDecoration(
                      labelText: 'Charge Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Extra Charges', 'Detention', 'Penalty', 'Other'].map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => chargeType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
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
                        final result = await ApiService.addSupplierChargeFromTrip(
                          tripId: widget.tripId,
                          chargeType: chargeType,
                          amount: amountController.text,
                          date: dateController.text,
                        );

                        if (mounted) {
                          await _loadTripDetails();
                        }

                        if (!mounted) return;

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier charge added successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to add supplier charge')),
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
                      'Add Charge',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showAddSupplierPaymentDialog() {
    final amountController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    String paymentMode = 'Cash';

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
                      const Text(
                        'Add Supplier Payment',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'Online', 'Cheque'].map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => paymentMode = value);
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
                        final result = await ApiService.addSupplierPaymentFromTrip(
                          tripId: widget.tripId,
                          amount: amountController.text,
                          date: dateController.text,
                          paymentMode: paymentMode,
                        );

                        if (mounted) {
                          await _loadTripDetails();
                        }

                        if (!mounted) return;

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier payment added successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to add supplier payment')),
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
                      'Add Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  // Edit Supplier Financial Item (Advance/Charge/Payment)
  void _showEditSupplierFinancialDialog(int id, String type, Map<String, dynamic> item) {
    final amountController = TextEditingController(text: item['amount']?.toString() ?? '');
    final dateController = TextEditingController(text: item['date']?.toString() ?? '');
    String selectedValue = '';

    if (type == 'advance') {
      selectedValue = item['paymentMode']?.toString() ?? 'Cash';
    } else if (type == 'charge') {
      selectedValue = item['type']?.toString() ?? 'Detention Charges';
    } else if (type == 'payment') {
      selectedValue = item['paymentMode']?.toString() ?? 'Cash';
    }

    String dialogTitle = '';
    if (type == 'advance') {
      dialogTitle = 'Edit Supplier Advance';
    } else if (type == 'charge') {
      dialogTitle = 'Edit Supplier Charge';
    } else if (type == 'payment') {
      dialogTitle = 'Edit Supplier Payment';
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dialogTitle,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setModalState(() {
                          dateController.text = DateFormat('yyyy-MM-dd').format(date);
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
                      ].map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
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
                            tripId: widget.tripId,
                            advanceId: id,
                            amount: amountController.text,
                            date: dateController.text,
                            paymentMode: selectedValue,
                          );
                        } else if (type == 'charge') {
                          success = await ApiService.updateSupplierCharge(
                            tripId: widget.tripId,
                            chargeId: id,
                            amount: amountController.text,
                            date: dateController.text,
                            chargeType: selectedValue,
                          );
                        } else if (type == 'payment') {
                          success = await ApiService.updateSupplierPayment(
                            tripId: widget.tripId,
                            paymentId: id,
                            amount: amountController.text,
                            date: dateController.text,
                            paymentMode: selectedValue,
                          );
                        }

                        if (mounted) {
                          await _loadTripDetails();
                        }

                        if (!mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Supplier $type updated successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update supplier $type')),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  // Delete Supplier Financial Item Confirmation
  void _showDeleteSupplierFinancialDialog(int id, String type) {
    String itemName = '';
    if (type == 'advance') {
      itemName = 'Advance';
    } else if (type == 'charge') {
      itemName = 'Charge';
    } else if (type == 'payment') {
      itemName = 'Payment';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Supplier $itemName'),
        content: Text('Are you sure you want to delete this supplier $itemName?'),
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
                    tripId: widget.tripId,
                    advanceId: id,
                  );
                } else if (type == 'charge') {
                  success = await ApiService.deleteSupplierCharge(
                    tripId: widget.tripId,
                    chargeId: id,
                  );
                } else if (type == 'payment') {
                  success = await ApiService.deleteSupplierPayment(
                    tripId: widget.tripId,
                    paymentId: id,
                  );
                }

                if (mounted) {
                  await _loadTripDetails();
                }

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Supplier $itemName deleted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete supplier $itemName')),
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

  // Send Request Money via WhatsApp
  Future<void> _sendRequestMoneyWhatsApp({Map<String, dynamic>? tripData}) async {
    final data = tripData ?? _tripDetails!;
    final partyName = data['partyName'] ?? 'Party';
    final partyPhone = data['partyPhone'];
    final pendingBalance = data['pendingBalance'] ?? 0;
    final truckNumber = data['truckNumber'] ?? 'N/A';
    final lrNumber = data['lrNumber'] ?? 'N/A';
    final origin = data['origin'] ?? 'N/A';
    final destination = data['destination'] ?? 'N/A';
    final startDate = data['startDate'] ?? 'N/A';
    final freightAmount = data['freightAmount'] ?? 0;
    final totalPayments = data['totalPayments'] ?? 0;
    final totalAdvance = data['totalAdvance'] ?? 0;

    // Check if party phone is available
    if (partyPhone == null || partyPhone.toString().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Party phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // WhatsApp message template with complete trip details
    final message = '''Hello $partyName,

This is a payment reminder for the following trip:

📦 TRIP DETAILS
━━━━━━━━━━━━━━━━━━━━
🚚 Truck Number: $truckNumber
📄 LR Number: $lrNumber
📍 Route: $origin → $destination
📅 Start Date: $startDate

💰 PAYMENT DETAILS
━━━━━━━━━━━━━━━━━━━━
Freight Amount: ${CurrencyFormatter.formatWithSymbol(freightAmount)}
Advance Paid: ${CurrencyFormatter.formatWithSymbol(totalAdvance)}
Payments Made: ${CurrencyFormatter.formatWithSymbol(totalPayments)}
━━━━━━━━━━━━━━━━━━━━
Pending Balance: ${CurrencyFormatter.formatWithSymbol(pendingBalance)}

Please make the payment at your earliest convenience.

Thank you!''';

    try {
      // Clean phone number (remove spaces, dashes, and +)
      String cleanPhone = partyPhone.toString().replaceAll(RegExp(r'[\s\-\+]'), '');

      // Add country code if not present (assuming India +91)
      if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      // Encode the message for URL
      final encodedMessage = Uri.encodeComponent(message);

      // WhatsApp URL
      final whatsappUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening WhatsApp: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Edit Button with outline style
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: OutlinedButton(
              onPressed: () => _showEditTripDialog(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // More Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete Trip'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'call_party',
                child: Row(
                  children: [
                    Icon(Icons.call, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Call Party'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'call_driver',
                child: Row(
                  children: [
                    Icon(Icons.call, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('Call Driver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Text('Share Trip'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view_lr',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('View LR'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tripDetails == null
              ? const Center(child: Text('Trip not found'))
              : Column(
                  children: [
                    // Trip Info Header - Dark background with white container
                    Container(
                      color: const Color(0xFF1E3A5F), // Dark blue background
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Truck Number - Clickable
                            Expanded(
                              child: InkWell(
                                onTap: () => _navigateToTruckDetails(),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping, color: Color(0xFF2196F3), size: 20),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _tripDetails!['truckNumber'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2196F3),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Driver/Supplier Name - Clickable (shows supplier for Market trucks, driver for Own trucks)
                            Expanded(
                              child: InkWell(
                                onTap: () => _navigateToDriverDetails(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      _tripDetails!['truckType'] == 'Market'
                                        ? Icons.local_shipping
                                        : Icons.drive_eta,
                                      color: const Color(0xFF2196F3),
                                      size: 18
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _tripDetails!['truckType'] == 'Market'
                                          ? (_tripDetails!['supplierName'] ?? 'No Supplier')
                                          : (_tripDetails!['driverName'] ?? 'No Driver'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2196F3),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tabs
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.blue.shade700,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Colors.blue.shade700,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(text: _loads.isNotEmpty ? 'Loads' : 'Party'),
                          const Tab(text: 'Profit'),
                          Tab(text: _tripDetails?['truckType'] == 'Market' ? 'Supplier' : 'Driver'),
                          const Tab(text: 'More'),
                        ],
                      ),
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLoadsOrPartyTab(),
                          _buildProfitTab(),
                          _tripDetails?['truckType'] == 'Market' ? _buildSupplierTab() : _buildDriverTab(),
                          _buildMoreTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // New combined Loads/Party tab with accordion cards
  Widget _buildLoadsOrPartyTab() {
    // If no loads, show party content directly without accordion
    if (_loads.isEmpty) {
      return _buildPartyTab();
    }

    // If there are loads, show accordion cards
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main trip/party as first accordion card (index 0)
          _buildAccordionCard(
            index: 0,
            isMainTrip: true,
            partyName: _tripDetails?['partyName'] ?? 'N/A',
            origin: _tripDetails?['origin'] ?? 'N/A',
            destination: _tripDetails?['destination'] ?? 'N/A',
            amount: _tripDetails?['pendingBalance'] ?? 0,
            startDate: _tripDetails?['startDate'] ?? '',
            endDate: _tripDetails?['endDate'] ?? '',
            tripData: _tripDetails,
          ),

          const SizedBox(height: 12),

          // Load accordion cards (index 1, 2, 3...)
          ...List.generate(_loads.length, (index) {
            final load = _loads[index];
            return Column(
              children: [
                _buildAccordionCard(
                  index: index + 1,  // +1 because main trip is index 0
                  isMainTrip: false,
                  partyName: load['partyName'] ?? 'N/A',
                  origin: load['origin'] ?? 'N/A',
                  destination: load['destination'] ?? 'N/A',
                  amount: load['freightAmount'] ?? 0,
                  startDate: load['startDate'] ?? '',
                  endDate: load['tripEndDate'] ?? '',
                  tripData: load,
                ),
                const SizedBox(height: 12),
              ],
            );
          }),

          // "Add load to this Trip" button
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLoadScreen(
                    parentTripId: widget.tripId,
                    truckId: _tripDetails?['truckId'] ?? 0,
                    truckNumber: _tripDetails?['truckNumber'] ?? '',
                    truckType: _tripDetails?['truckType'] ?? 'Own',
                    driverName: _tripDetails?['driverName'],
                    parentDestination: _tripDetails?['destination'],
                  ),
                ),
              );
              if (result == true) {
                await _loadTripLoads();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Add load to this Trip',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade700),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Accordion card widget for loads/party
  Widget _buildAccordionCard({
    required int index,
    required bool isMainTrip,
    required String partyName,
    required String origin,
    required String destination,
    required dynamic amount,
    required String startDate,
    required String endDate,
    required Map<String, dynamic>? tripData,
  }) {
    final isExpanded = _expandedAccordionIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapsed header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                // Toggle: if already expanded, collapse; otherwise expand this one
                _expandedAccordionIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Party Name and Amount
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 20,
                        color: isMainTrip ? const Color(0xFF1976D2) : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          partyName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isMainTrip ? const Color(0xFF1976D2) : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatWithSymbol(amount ?? 0),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Route: Origin → Destination
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          origin,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 1.5,
                              color: Colors.grey.shade300,
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            Container(
                              width: 20,
                              height: 1.5,
                              color: Colors.grey.shade300,
                            ),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          destination,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content (only visible when expanded)
          if (isExpanded && tripData != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildAccordionExpandedContent(tripData, isMainTrip),
            ),
          ],
        ],
      ),
    );
  }

  // Expanded content for accordion card (Party tab content)
  Widget _buildAccordionExpandedContent(Map<String, dynamic> tripData, bool isMainTrip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route Details with dates
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Origin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripData['origin'] ?? 'Origin',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tripData['startDate'] ?? '',
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
                              width: 30,
                              height: 1.5,
                              color: Colors.grey.shade300,
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            Container(
                              width: 30,
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
                          tripData['destination'] ?? 'Destination',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tripData['endDate'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tripData['lrNumber'] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Trip Progress
              const SizedBox(height: 12),
              _buildTripProgressForData(tripData),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Action Buttons Row (Status Button + View Bill)
        _buildActionButtonsRowForData(tripData),

        const SizedBox(height: 12),

        // Freight Amount (Editable)
        _buildPaymentSectionForData(
          'Freight Amount',
          tripData['freightAmount'],
          tripData,
          isTotal: true,
          showEditIcon: true, // Allow editing for all trips
          onEdit: () => _editFreightAmount(tripId: tripData['id'], tripData: tripData),
        ),

        const SizedBox(height: 12),

        // Advances
        _buildPaymentSectionForData(
          '(-) Advance',
          tripData['totalAdvance'],
          tripData,
          items: tripData['advances'],
          addButtonText: 'Add Advance',
          onAdd: () => _showAddAdvanceDialogForTrip(tripData),
          onEditItem: (item) => _showEditAdvanceDialog(tripData['id'], item),
          onDeleteItem: (item) => _deleteAdvance(tripData['id'], item['id']),
        ),

        const SizedBox(height: 12),

        // Charges
        _buildPaymentSectionForData(
          '(+) Charges',
          tripData['totalCharges'],
          tripData,
          items: tripData['charges'],
          addButtonText: 'Add Charge',
          onAdd: () => _showAddChargeDialogForTrip(tripData),
          onEditItem: (item) => _showEditChargeDialog(tripData['id'], item),
          onDeleteItem: (item) => _deleteCharge(tripData['id'], item['id']),
        ),

        const SizedBox(height: 12),

        // Payments
        _buildPaymentSectionForData(
          '(-) Payments',
          tripData['totalPayments'],
          tripData,
          items: tripData['payments'],
          addButtonText: 'Add Payment',
          onAdd: () => _showAddPaymentDialogForTrip(tripData),
          onEditItem: (item) => _showEditPaymentDialog(tripData['id'], item),
          onDeleteItem: (item) => _deletePayment(tripData['id'], item['id']),
        ),

        const SizedBox(height: 12),

        // Pending Balance
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Balance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.formatWithSymbol(tripData['pendingBalance'] ?? 0),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Note and Request Money buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAddNoteDialogForTrip(tripData),
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                label: const Text(
                  'Note',
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _sendRequestMoneyWhatsAppForTrip(tripData),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'Request Money',
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods for accordion cards (work with any trip data)

  Widget _buildTripProgressForData(Map<String, dynamic> tripData) {
    final String status = tripData['status'] ?? 'Load in Progress';

    bool started = false;
    bool completed = false;
    bool podReceived = false;
    bool podSubmitted = false;
    bool settled = false;

    // Determine which stages are completed based on status
    switch (status) {
      case 'Settled':
        settled = true;
        podSubmitted = true;
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'POD Submitted':
        podSubmitted = true;
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'POD Received':
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'Completed':
        completed = true;
        started = true;
        break;
      case 'In Progress':
        started = true;
        break;
      case 'Load in Progress':
      default:
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            _buildStageIcon(started),
            Expanded(child: _buildStageLine(completed)),
            _buildStageIcon(completed),
            Expanded(child: _buildStageLine(podReceived)),
            _buildStageIcon(podReceived),
            Expanded(child: _buildStageLine(podSubmitted)),
            _buildStageIcon(podSubmitted),
            Expanded(child: _buildStageLine(settled)),
            _buildStageIcon(settled),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Started', style: TextStyle(fontSize: 10)),
            const Text('Completed', style: TextStyle(fontSize: 10)),
            const Text('POD\nRcvd', style: TextStyle(fontSize: 10), textAlign: TextAlign.center),
            const Text('POD\nSent', style: TextStyle(fontSize: 10), textAlign: TextAlign.center),
            const Text('Settled', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtonsRowForData(Map<String, dynamic> tripData) {
    final String status = tripData['status'] ?? '';
    final bool isSettled = status == 'Settled';
    final int tripId = tripData['id'] ?? 0;

    return Row(
      children: [
        // Status button (if not settled)
        if (!isSettled) ...[
          Expanded(
            child: _buildStatusActionButtonForData(tripData),
          ),
          const SizedBox(width: 12),
        ],
        // View Bill button
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripBillScreen(
                      tripDetails: tripData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View Bill',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActionButtonForData(Map<String, dynamic> tripData) {
    final String status = tripData['status'] ?? '';
    final int tripId = tripData['id'] ?? 0;

    if (status == 'Settled') {
      return const SizedBox.shrink();
    }

    String buttonText = '';
    VoidCallback onPressed = () {};
    IconData icon = Icons.play_arrow;

    switch (status) {
      case 'Load in Progress':
        buttonText = 'Start Trip';
        icon = Icons.play_arrow;
        onPressed = () => _showStartTripDialogForTrip(tripId);
        break;
      case 'In Progress':
        buttonText = 'Complete Trip';
        icon = Icons.check_circle;
        onPressed = () => _showCompleteTripDialogForTrip(tripId);
        break;
      case 'Completed':
        buttonText = 'POD Received';
        icon = Icons.description;
        onPressed = () => _showPodReceivedDialogForTrip(tripId);
        break;
      case 'POD Received':
        buttonText = 'Submit POD';
        icon = Icons.send;
        onPressed = () => _showPodSubmittedDialogForTrip(tripId);
        break;
      case 'POD Submitted':
        buttonText = 'Settle Trip';
        icon = Icons.account_balance_wallet;
        onPressed = () => _showSettleTripDialogForTrip(tripId);
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSectionForData(
    String title,
    dynamic amount,
    Map<String, dynamic> tripData, {
    List<dynamic>? items,
    bool isTotal = false,
    bool showEditIcon = false,
    VoidCallback? onEdit,
    String? addButtonText,
    VoidCallback? onAdd,
    Function(dynamic item)? onEditItem,
    Function(dynamic item)? onDeleteItem,
  }) {
    // Convert amount to int safely
    int displayAmount = 0;
    if (amount != null) {
      if (amount is int) {
        displayAmount = amount;
      } else if (amount is double) {
        displayAmount = amount.toInt();
      } else if (amount is String) {
        displayAmount = int.tryParse(amount) ?? 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.formatWithSymbol(displayAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (showEditIcon && onEdit != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (items != null && items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['date'] ?? '',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (item['paymentMode'] != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '• ${item['paymentMode']}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                  if (item['type'] != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '• ${item['type']}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                              CurrencyFormatter.formatWithSymbol(item['amount']),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (onEditItem != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onEditItem(item),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                            if (onDeleteItem != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onDeleteItem(item),
                                child: const Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          // Add button
          if (addButtonText != null && onAdd != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      addButtonText,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Dialog methods for specific trips - now simplified to directly call main dialog methods with tripId
  void _showStartTripDialogForTrip(int tripId) {
    _showStartTripDialog(tripId: tripId);
  }

  void _showCompleteTripDialogForTrip(int tripId) {
    _showCompleteTripDialog(tripId: tripId);
  }

  void _showPodReceivedDialogForTrip(int tripId) {
    _showPodReceivedDialog(tripId: tripId);
  }

  void _showPodSubmittedDialogForTrip(int tripId) {
    _showPodSubmittedDialog(tripId: tripId);
  }

  void _showSettleTripDialogForTrip(int tripId) {
    _showSettleTripDialog(tripId: tripId);
  }

  void _showAddAdvanceDialogForTrip(Map<String, dynamic> tripData) {
    _showAddAdvanceDialog(tripId: tripData['id']);
  }

  void _showAddChargeDialogForTrip(Map<String, dynamic> tripData) {
    _showAddChargeDialog(tripId: tripData['id']);
  }

  void _showAddPaymentDialogForTrip(Map<String, dynamic> tripData) {
    _showAddPaymentDialog(tripId: tripData['id']);
  }

  void _showAddNoteDialogForTrip(Map<String, dynamic> tripData) {
    _showAddNoteDialog(tripId: tripData['id']);
  }

  void _sendRequestMoneyWhatsAppForTrip(Map<String, dynamic> tripData) {
    _sendRequestMoneyWhatsApp(tripData: tripData);
  }

  // Edit and Delete methods for Advances, Charges, Payments

  void _showEditAdvanceDialog(int tripId, Map<String, dynamic> advance) {
    final amountController = TextEditingController(text: advance['amount'].toString());
    final dateController = TextEditingController(text: advance['date'] ?? '');
    String paymentMode = advance['paymentMode'] ?? 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Advance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                  items: ['Cash', 'UPI', 'Bank Transfer', 'Card', 'Cheque']
                      .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                      .toList(),
                  onChanged: (value) => setModalState(() => paymentMode = value!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final success = await ApiService.updateTripAdvance(
                        tripId: tripId,
                        advanceId: advance['id'],
                        amount: amountController.text,
                        date: dateController.text,
                        paymentMode: paymentMode,
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Advance updated successfully')),
                        );
                        await _loadTripDetails();
                        await _loadTripLoads();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update Advance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAdvance(int tripId, int advanceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Advance'),
        content: const Text('Are you sure you want to delete this advance?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTripAdvance(tripId: tripId, advanceId: advanceId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advance deleted successfully')),
        );
        await _loadTripDetails();
        await _loadTripLoads();
      }
    }
  }

  void _showEditChargeDialog(int tripId, Map<String, dynamic> charge) {
    final typeController = TextEditingController(text: charge['type'] ?? '');
    final amountController = TextEditingController(text: charge['amount'].toString());
    final dateController = TextEditingController(text: charge['date'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Charge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Charge Type',
                    hintText: 'e.g., Loading, Unloading, Toll',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (typeController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter charge type')),
                        );
                        return;
                      }

                      final success = await ApiService.updateTripCharge(
                        tripId: tripId,
                        chargeId: charge['id'],
                        chargeType: typeController.text,
                        amount: amountController.text,
                        date: dateController.text,
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Charge updated successfully')),
                        );
                        await _loadTripDetails();
                        await _loadTripLoads();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update Charge',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCharge(int tripId, int chargeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Charge'),
        content: const Text('Are you sure you want to delete this charge?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTripCharge(tripId: tripId, chargeId: chargeId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Charge deleted successfully')),
        );
        await _loadTripDetails();
        await _loadTripLoads();
      }
    }
  }

  void _showEditPaymentDialog(int tripId, Map<String, dynamic> payment) {
    final amountController = TextEditingController(text: payment['amount'].toString());
    final dateController = TextEditingController(text: payment['date'] ?? '');
    String paymentMode = payment['paymentMode'] ?? 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                  items: ['Cash', 'UPI', 'Bank Transfer', 'Card', 'Cheque']
                      .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                      .toList(),
                  onChanged: (value) => setModalState(() => paymentMode = value!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final success = await ApiService.updateTripPayment(
                        tripId: tripId,
                        paymentId: payment['id'],
                        amount: amountController.text,
                        date: dateController.text,
                        paymentMode: paymentMode,
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment updated successfully')),
                        );
                        await _loadTripDetails();
                        await _loadTripLoads();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePayment(int tripId, int paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTripPayment(tripId: tripId, paymentId: paymentId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully')),
        );
        await _loadTripDetails();
        await _loadTripLoads();
      }
    }
  }

  // Old loads tab (kept for reference, can be removed later)
  Widget _buildLoadsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display each load as a card (only if there are loads)
          if (_loads.isNotEmpty) ...[
            ..._loads.map((load) => _buildLoadCard(load)).toList(),
            const SizedBox(height: 12),
          ],

          // Show message if no loads
          if (_loads.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No loads added yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add multiple loads for this trip',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // "Add load to this Trip" button (always shown)
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLoadScreen(
                    parentTripId: widget.tripId,
                    truckId: _tripDetails?['truckId'] ?? 0,
                    truckNumber: _tripDetails?['truckNumber'] ?? '',
                    truckType: _tripDetails?['truckType'] ?? 'Own',
                    driverName: _tripDetails?['driverName'],
                    parentDestination: _tripDetails?['destination'],
                  ),
                ),
              );
              if (result == true) {
                // Reload loads after adding new load
                await _loadTripLoads();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add load to this Trip',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadCard(Map<String, dynamic> load) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Party Name and Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(
                    load['partyName'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${load['freightAmount'] ?? 0}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Origin to Destination with arrow
          Row(
            children: [
              Expanded(
                child: Text(
                  load['origin'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
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
                      width: 30,
                      height: 1.5,
                      color: Colors.grey.shade300,
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    Container(
                      width: 30,
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
              ),
              Expanded(
                child: Text(
                  load['destination'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // LR Number (centered)
          Center(
            child: Text(
              load['lrNumber'] ?? '',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          // View full details link
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              // Navigate to load details (which is also a trip details screen)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripDetailsScreen(tripId: load['id']),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View full details',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Party Name and Amount - Clickable
          InkWell(
            onTap: () => _navigateToPartyDetails(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tripDetails!['partyName'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatWithSymbol(_tripDetails!['pendingBalance'] ?? 0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Route and LR Number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Origin
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tripDetails!['origin'] ?? 'Origin',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tripDetails!['startDate'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Route Line with Arrow (matching My Trips design)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
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
                            _tripDetails!['destination'] ?? 'Destination',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tripDetails!['endDate'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _tripDetails!['lrNumber'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Trip Progress
                const SizedBox(height: 12),
                _buildTripProgress(),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Buttons Row (Status Button + View Bill)
          _buildActionButtonsRow(),

          const SizedBox(height: 10),

          // Freight Amount (Editable)
          _buildPaymentSection(
            'Freight Amount',
            _tripDetails!['freightAmount'],
            isTotal: true,
            showEditIcon: true,
            onEdit: () => _editFreightAmount(),
          ),

          const SizedBox(height: 8),

          // Advances
          _buildPaymentSection(
            '(-) Advance',
            _tripDetails!['totalAdvance'],
            items: _tripDetails!['advances'],
            addButtonText: 'Add Advance',
            onAdd: () => _showAddAdvanceDialog(),
            onEditItem: (item) => _showEditAdvanceDialog(widget.tripId, item),
            onDeleteItem: (item) => _deleteAdvance(widget.tripId, item['id']),
          ),

          const SizedBox(height: 8),

          // Charges
          _buildPaymentSection(
            '(+) Charges',
            _tripDetails!['totalCharges'],
            items: _tripDetails!['charges'],
            addButtonText: 'Add Charge',
            onAdd: () => _showAddChargeDialog(),
            onEditItem: (item) => _showEditChargeDialog(widget.tripId, item),
            onDeleteItem: (item) => _deleteCharge(widget.tripId, item['id']),
          ),

          const SizedBox(height: 8),

          // Payments
          _buildPaymentSection(
            '(-) Payments',
            _tripDetails!['totalPayments'],
            items: _tripDetails!['payments'],
            addButtonText: 'Add Payment',
            onAdd: () => _showAddPaymentDialog(),
            onEditItem: (item) => _showEditPaymentDialog(widget.tripId, item),
            onDeleteItem: (item) => _deletePayment(widget.tripId, item['id']),
          ),

          const SizedBox(height: 8),

          // Pending Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatWithSymbol(_tripDetails!['pendingBalance'] ?? 0),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Note and Request Money buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddNoteDialog(),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 22),
                  label: const Text(
                    'Note',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendRequestMoneyWhatsApp(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Request Money',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Add load to this Trip
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLoadScreen(
                    parentTripId: widget.tripId,
                    truckId: _tripDetails!['truckId'],
                    truckNumber: _tripDetails!['truckNumber'],
                    truckType: _tripDetails!['truckType'] ?? 'Own',
                    driverName: _tripDetails!['driverName'],
                    parentDestination: _tripDetails!['destination'],
                  ),
                ),
              );
              if (result == true) {
                await _loadTripLoads();
                _loadTripDetails();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add load to this Trip',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '(+) Revenue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatWithSymbol(_tripDetails!['revenue']['total']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tripDetails!['partyName'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatWithSymbol(_tripDetails!['revenue']['total']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildRevenueRow('Freight Amount', _tripDetails!['revenue']['freightAmount']),
                      _buildRevenueRow('Charges', _tripDetails!['revenue']['charges']),
                      _buildRevenueRow('Deductions', _tripDetails!['revenue']['deductions']),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Truck Hire Cost Section (only for market/supplier trucks)
          if (_tripDetails!['truckHireCost'] != null && _tripDetails!['truckHireCost'] > 0)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '(-) Truck Hire Cost',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatWithSymbol(_tripDetails!['truckHireCost']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tripDetails!['supplierName'] ?? 'Supplier',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            CurrencyFormatter.formatWithSymbol(_tripDetails!['truckHireCost']),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

          // Expenses Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '(-) Trip Expenses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatWithSymbol(_tripDetails!['totalExpenses']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_tripDetails!['expenses'].isNotEmpty)
                  ...(_tripDetails!['expenses'] as List).map((expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {},
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                expense['expenseType'] ?? expense['type'] ?? 'N/A',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Row(
                                children: [
                                  Text(
                                    CurrencyFormatter.formatWithSymbol(expense['amount']),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showAddExpenseDialog(),
                  child: const Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Profit
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatWithSymbol(_tripDetails!['profit']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierTab() {
    // Calculate supplier financial totals
    double truckHireCost = (_tripDetails?['truckHireCost'] as num?)?.toDouble() ?? 0.0;

    double totalAdvances = 0.0;
    final advances = _tripDetails?['supplierAdvances'] as List? ?? [];
    for (var adv in advances) {
      totalAdvances += (adv['amount'] as num?)?.toDouble() ?? 0.0;
    }

    double totalCharges = 0.0;
    final charges = _tripDetails?['supplierCharges'] as List? ?? [];
    for (var chg in charges) {
      totalCharges += (chg['amount'] as num?)?.toDouble() ?? 0.0;
    }

    double totalPayments = 0.0;
    final payments = _tripDetails?['supplierPayments'] as List? ?? [];
    for (var pay in payments) {
      totalPayments += (pay['amount'] as num?)?.toDouble() ?? 0.0;
    }

    double balancePending = truckHireCost + totalCharges - totalAdvances - totalPayments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier Name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, size: 24, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tripDetails?['supplierName'] ?? 'No Supplier',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Truck Hire Cost
          _buildSupplierInfoRow('Truck Hire Cost', truckHireCost, isEditable: true),

          const SizedBox(height: 16),

          // Supplier Advances
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '(-) Supplier Advances',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              Text(
                CurrencyFormatter.formatWithSymbol(totalAdvances.toInt()),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showAddSupplierAdvanceDialog(),
            child: const Text(
              'Add Supplier Advance',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          // List of advances
          if (advances.isNotEmpty)
            ...advances.map((adv) => _buildSupplierFinancialItem(
              adv,
              'advance',
              Colors.orange,
            )).toList(),

          const SizedBox(height: 16),

          // Supplier Charges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '(+) Supplier Charges',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              Text(
                CurrencyFormatter.formatWithSymbol(totalCharges.toInt()),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showAddSupplierChargeDialog(),
            child: const Text(
              'Add Supplier Charge',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          // List of charges
          if (charges.isNotEmpty)
            ...charges.map((chg) => _buildSupplierFinancialItem(
              chg,
              'charge',
              Colors.red,
            )).toList(),

          const SizedBox(height: 16),

          // Supplier Payments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '(-) Supplier Payments',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              Text(
                CurrencyFormatter.formatWithSymbol(totalPayments.toInt()),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showAddSupplierPaymentDialog(),
            child: const Text(
              'Add Supplier Payment',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          // List of payments
          if (payments.isNotEmpty)
            ...payments.map((pay) => _buildSupplierFinancialItem(
              pay,
              'payment',
              Colors.green,
            )).toList(),

          const Divider(height: 40, thickness: 1.5),

          // Balance Pending
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance Pending',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.formatWithSymbol(balancePending.toInt()),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: balancePending > 0 ? Colors.red.shade700 : Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pay Supplier Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: balancePending > 0 ? () => _showAddSupplierPaymentDialog() : null,
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text(
                'Pay Supplier',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierInfoRow(String label, double value, {bool isEditable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Row(
          children: [
            Text(
              CurrencyFormatter.formatWithSymbol(value.toInt()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isEditable) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  // TODO: Show edit dialog for truck hire cost
                },
                child: const Icon(Icons.edit, size: 18, color: Colors.blue),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierFinancialItem(Map<String, dynamic> item, String type, Color accentColor) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final date = item['date']?.toString() ?? '';
    final id = item['id'];

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

    String typeLabel = '';
    String detailText = '';

    if (type == 'advance') {
      typeLabel = 'Advance';
      detailText = item['paymentMode']?.toString() ?? '';
    } else if (type == 'charge') {
      typeLabel = 'Charge';
      detailText = item['type']?.toString() ?? '';
    } else if (type == 'payment') {
      typeLabel = 'Payment';
      detailText = item['paymentMode']?.toString() ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Amount and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.formatWithSymbol(amount.toInt()),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    if (detailText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          detailText,
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Edit and Delete buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: Colors.blue,
                onPressed: () => _showEditSupplierFinancialDialog(id, type, item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                color: Colors.red,
                onPressed: () => _showDeleteSupplierFinancialDialog(id, type),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tripDetails!['driverName'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _tripDetails!['driverStatus'] ?? 'Available',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Collect from driver
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Collect from driver',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatWithSymbol(_tripDetails!['collectFromDriver']),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: _showSettleAmountDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text(
                  'Settle Amount',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // View Report
          InkWell(
            onTap: _openDriverReport,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'View Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Transaction Table Headers
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'REASON',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'DRIVER GAVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'DRIVER GOT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Transactions
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: _driverTransactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No driver transactions found.\nTransactions added in Driver Khata will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : Column(
              children: _driverTransactions.map((transaction) {
                // Parse amount and type to determine which column to show
                final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
                final type = transaction['type'] ?? '';
                final driverGave = type == 'gave' ? amount : 0.0;
                final driverGot = type == 'got' ? amount : 0.0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction['reason'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  transaction['date'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              driverGave > 0 ? CurrencyFormatter.formatWithSymbol(driverGave.toInt()) : '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Text(
                              driverGot > 0 ? CurrencyFormatter.formatWithSymbol(driverGot.toInt()) : '',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Driver Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDriverGaveDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '- Driver Gave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDriverGotDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '+ Driver Got',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildMoreMenuItem(
            icon: Icons.receipt_long,
            title: 'Online Bilty/LR',
            onTap: _openLRCreation,
          ),
          const SizedBox(height: 12),
          _buildMoreMenuItem(
            icon: Icons.receipt,
            title: 'POD Challan',
            onTap: _openPODChallan,
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    final String status = _tripDetails!['status'] ?? '';
    final bool isSettled = status == 'Settled';

    return Row(
      children: [
        // Status button (if not settled)
        if (!isSettled) ...[
          Expanded(
            child: _buildStatusActionButton(),
          ),
          const SizedBox(width: 12),
        ],
        // View Bill button
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripBillScreen(
                      tripDetails: _tripDetails!,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Bill',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActionButton() {
    final String status = _tripDetails!['status'] ?? '';

    // Don't show button if trip is already settled
    if (status == 'Settled') {
      return const SizedBox.shrink();
    }

    String buttonText = '';
    VoidCallback onPressed = () {};
    IconData icon = Icons.play_arrow;

    switch (status) {
      case 'Load in Progress':
        buttonText = 'Start Trip';
        icon = Icons.play_arrow;
        onPressed = _showStartTripDialog;
        break;
      case 'In Progress':
        buttonText = 'Complete Trip';
        icon = Icons.check_circle;
        onPressed = _showCompleteTripDialog;
        break;
      case 'Completed':
        buttonText = 'Mark POD Received';
        icon = Icons.description;
        onPressed = _showPodReceivedDialog;
        break;
      case 'POD Received':
        buttonText = 'Submit POD';
        icon = Icons.send;
        onPressed = _showPodSubmittedDialog;
        break;
      case 'POD Submitted':
        buttonText = 'Settle Trip';
        icon = Icons.account_balance_wallet;
        onPressed = _showSettleTripDialog;
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTripProgress() {
    // Calculate stage completion based on actual trip status
    final String status = _tripDetails!['status'] ?? 'Load in Progress';

    bool started = false;
    bool completed = false;
    bool podReceived = false;
    bool podSubmitted = false;
    bool settled = false;

    // Determine which stages are completed based on status
    switch (status) {
      case 'Settled':
        settled = true;
        podSubmitted = true;
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'POD Submitted':
        podSubmitted = true;
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'POD Received':
        podReceived = true;
        completed = true;
        started = true;
        break;
      case 'Completed':
        completed = true;
        started = true;
        break;
      case 'In Progress':
        started = true;
        break;
      case 'Load in Progress':
      default:
        // All stages are false
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            _buildStageIcon(started),
            Expanded(child: _buildStageLine(completed)),
            _buildStageIcon(completed),
            Expanded(child: _buildStageLine(podReceived)),
            _buildStageIcon(podReceived),
            Expanded(child: _buildStageLine(podSubmitted)),
            _buildStageIcon(podSubmitted),
            Expanded(child: _buildStageLine(settled)),
            _buildStageIcon(settled),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Started', style: TextStyle(fontSize: 11)),
            const Text('Completed', style: TextStyle(fontSize: 11)),
            const Text('POD\nReceived', style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
            const Text('POD\nSubmitted', style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
            const Text('Settled', style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildStageIcon(bool completed) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: completed ? Colors.green : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: completed ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: completed
          ? const Icon(
              Icons.check,
              color: Colors.white,
              size: 14,
            )
          : null,
    );
  }

  Widget _buildStageLine(bool completed) {
    return Container(
      height: 2,
      color: completed ? Colors.green : Colors.grey.shade300,
    );
  }

  Widget _buildPaymentSection(String title, dynamic amount, {List<dynamic>? items, bool isTotal = false, bool showEditIcon = false, VoidCallback? onEdit, String? addButtonText, VoidCallback? onAdd, Function(dynamic item)? onEditItem, Function(dynamic item)? onDeleteItem}) {
    // Convert amount to int safely, handling null, string, double, etc.
    int displayAmount = 0;
    if (amount != null) {
      if (amount is int) {
        displayAmount = amount;
      } else if (amount is double) {
        displayAmount = amount.toInt();
      } else if (amount is String) {
        displayAmount = int.tryParse(amount) ?? 0;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.formatWithSymbol(displayAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (showEditIcon && onEdit != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onEdit,
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (items != null && items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item['date'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  if (item['paymentMode'] != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${item['paymentMode']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                  if (item['type'] != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${item['type']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                              CurrencyFormatter.formatWithSymbol(item['amount']),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (onEditItem != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onEditItem(item),
                                child: const Icon(Icons.edit, size: 18, color: Colors.blue),
                              ),
                            ],
                            if (onDeleteItem != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => onDeleteItem(item),
                                child: const Icon(Icons.delete, size: 18, color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          // Add button at the end
          if (addButtonText != null && onAdd != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      addButtonText,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            CurrencyFormatter.formatWithSymbol(amount),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Show Add Note Dialog
  void _showAddNoteDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    final noteController = TextEditingController();

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
                    'Add Note for Trip',
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
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Enter your note here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (noteController.text.isNotEmpty) {
                      try {
                        final result = await ApiService.addTripNote(
                          tripId: targetTripId,
                          note: noteController.text,
                        );

                        if (!mounted) return;

                        Navigator.pop(context);

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Note added successfully')),
                          );
                          await _loadTripDetails();
                          await _loadTripLoads();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to add note')),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Note',
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

  // Show Add Expense Dialog
  void _showAddExpenseDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedExpenseType = 'Diesel';
    String selectedPaymentMode = 'Cash';
    DateTime selectedDate = DateTime.now();
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    final List<String> expenseTypes = [
      'Diesel',
      'Toll',
      'Driver Salary',
      'Loading Charges',
      'Unloading Charges',
      'Maintenance',
      'Other'
    ];

    final List<String> paymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Card'];

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Expense',
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

                  // Expense Type Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedExpenseType,
                    decoration: const InputDecoration(
                      labelText: 'Expense Type',
                      border: OutlineInputBorder(),
                    ),
                    items: expenseTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedExpenseType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Mode Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: paymentModes.map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedPaymentMode = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Add notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Photo Upload
                  InkWell(
                    onTap: () async {
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        setModalState(() {
                          selectedImage = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey.shade600),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photo (Optional)',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(selectedImage!, fit: BoxFit.cover),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isNotEmpty) {
                          final result = await ApiService.addTripExpense(
                            tripId: widget.tripId,
                            expenseType: selectedExpenseType,
                            amount: amountController.text,
                            date: DateFormat('dd MMM yyyy').format(selectedDate),
                            paymentMode: selectedPaymentMode,
                            notes: notesController.text.isNotEmpty ? notesController.text : null,
                            imagePath: selectedImage?.path,
                          );
                          if (result != null && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Expense added successfully')),
                            );
                            _loadTripDetails();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Expense',
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
      ),
    );
  }

  // Show Driver Gave Dialog
  void _showDriverGaveDialog() {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Driver Gave',
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

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Enter reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Add note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isNotEmpty && reasonController.text.isNotEmpty) {
                          // Use driver-level transaction API
                          if (_tripDetails?['driverId'] != null) {
                            final result = await ApiService.addDriverBalanceTransaction(
                              driverId: _tripDetails!['driverId'],
                              type: 'gave',
                              amount: amountController.text,
                              reason: reasonController.text,
                              date: DateFormat('yyyy-MM-dd').format(selectedDate),
                              note: noteController.text.isNotEmpty ? noteController.text : null,
                            );
                            if (result != null && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Driver Gave transaction added')),
                              );
                              _loadTripDetails();
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit',
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
      ),
    );
  }

  // Show Driver Got Dialog
  void _showDriverGotDialog() {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Driver Got',
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

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Enter reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Add note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isNotEmpty && reasonController.text.isNotEmpty) {
                          // Use driver-level transaction API
                          if (_tripDetails?['driverId'] != null) {
                            final result = await ApiService.addDriverBalanceTransaction(
                              driverId: _tripDetails!['driverId'],
                              type: 'got',
                              amount: amountController.text,
                              reason: reasonController.text,
                              date: DateFormat('yyyy-MM-dd').format(selectedDate),
                              note: noteController.text.isNotEmpty ? noteController.text : null,
                            );
                            if (result != null && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Driver Got transaction added')),
                              );
                              _loadTripDetails();
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit',
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
      ),
    );
  }

  // Show Start Trip Dialog
  void _showStartTripDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    DateTime selectedDate = DateTime.now();

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
                      'Start Trip',
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

                // Trip Start Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
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
                      labelText: 'Trip Start Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final success = await ApiService.startTrip(
                          tripId: targetTripId,
                          tripStartDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                        );

                        if (!mounted) return;

                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trip started successfully')),
                          );
                          await _loadTripDetails();
                          await _loadTripLoads();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to start trip')),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Trip',
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

  // Show Complete Trip Dialog
  void _showCompleteTripDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    DateTime selectedDate = DateTime.now();
    final kmController = TextEditingController();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Complete Trip',
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

                  // Trip End Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                        labelText: 'Trip End Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total KM (Optional)
                  TextField(
                    controller: kmController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Total KM (Optional)',
                      hintText: 'Enter total kilometers',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final success = await ApiService.completeTrip(
                            tripId: targetTripId,
                            tripEndDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                            totalKm: kmController.text.isNotEmpty ? kmController.text : null,
                          );

                          if (!mounted) return;

                          Navigator.pop(context);

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip completed successfully')),
                            );
                            await _loadTripDetails();
                            await _loadTripLoads();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to complete trip')),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Complete Trip',
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
      ),
    );
  }

  // Show POD Received Dialog
  void _showPodReceivedDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    DateTime selectedDate = DateTime.now();
    List<File> selectedImages = [];
    final ImagePicker picker = ImagePicker();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'POD Received',
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

                  // POD Received Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                        labelText: 'POD Received Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Photos Upload
                  const Text(
                    'Upload POD Photos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final List<XFile> images = await picker.pickMultiImage();
                      if (images.isNotEmpty) {
                        setModalState(() {
                          selectedImages = images.map((img) => File(img.path)).toList();
                        });
                      }
                    },
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: selectedImages.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey.shade600),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Photos (Optional)',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: selectedImages.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(selectedImages[index], fit: BoxFit.cover),
                                );
                              },
                            ),
                    ),
                  ),
                  if (selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${selectedImages.length} photo(s) selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        print('=== SUBMITTING POD RECEIVED ===');
                        print('Trip ID: $targetTripId');
                        print('POD Received Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');
                        print('Photos: ${selectedImages.length}');

                        try {
                          final success = await ApiService.podReceived(
                            tripId: targetTripId,
                            podReceivedDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                            podPhotos: selectedImages.map((img) => img.path).toList(),
                          );

                          print('POD Received API returned: $success');

                          if (!mounted) return;

                          Navigator.pop(context);

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('POD received successfully')),
                            );
                            print('Reloading trip details after POD received...');
                            await _loadTripDetails();
                            await _loadTripLoads();
                            print('Trip details reloaded. New status: ${_tripDetails?['status']}');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to mark POD as received'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit',
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
      ),
    );
  }

  // Show POD Submitted Dialog
  void _showPodSubmittedDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    DateTime selectedDate = DateTime.now();

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
                      'POD Submitted',
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

                // POD Submitted Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
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
                      labelText: 'POD Submitted Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final success = await ApiService.podSubmitted(
                          tripId: targetTripId,
                          podSubmittedDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                        );

                        if (!mounted) return;

                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('POD submitted successfully')),
                          );
                          await _loadTripDetails();
                          await _loadTripLoads();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to submit POD')),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit',
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

  // Show Settle Trip Dialog
  void _showSettleTripDialog({int? tripId}) {
    final int targetTripId = tripId ?? widget.tripId;
    DateTime selectedDate = DateTime.now();

    // Auto-fill with pending balance amount
    final pendingBalance = _tripDetails?['pendingBalance'] ?? 0;
    final amountController = TextEditingController(text: pendingBalance.toString());

    final notesController = TextEditingController();
    String selectedPaymentMode = 'Cash';
    final List<String> paymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Card', 'Cheque'];

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Settle Trip',
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

                  // Settlement Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Settlement Amount *',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Mode
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode *',
                      border: OutlineInputBorder(),
                    ),
                    items: paymentModes.map((mode) {
                      return DropdownMenuItem(value: mode, child: Text(mode));
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedPaymentMode = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Settlement Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
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
                        labelText: 'Settlement Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Add notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isNotEmpty) {
                          try {
                            final result = await ApiService.settleTrip(
                              tripId: targetTripId,
                              settleAmount: amountController.text,
                              settlePaymentMode: selectedPaymentMode,
                              settleDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                              settleNotes: notesController.text.isNotEmpty ? notesController.text : null,
                            );

                            if (!mounted) return;

                            Navigator.pop(context);

                            if (result['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Trip settled successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              await _loadTripDetails();
                              await _loadTripLoads();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Failed to settle trip'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
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
                        'Settle Trip',
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
      ),
    );
  }

  // Helper method to build compact billing type buttons
  Widget _buildCompactBillingButton(String label, String selectedValue, Function(String) onSelect) {
    final bool isSelected = selectedValue == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _showPartyPickerForEdit(TextEditingController controller) async {
    if (_parties.isEmpty) {
      await _loadPartiesAndCities();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Party',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _parties.length,
                itemBuilder: (context, index) {
                  final party = _parties[index];
                  return ListTile(
                    title: Text(party['name'] ?? ''),
                    subtitle: party['phone'] != null ? Text(party['phone']) : null,
                    onTap: () {
                      controller.text = party['name'];
                      _selectedPartyId = party['id']; // Store the ID
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCityPickerForEdit(TextEditingController controller, bool isOrigin) async {
    if (_cities.isEmpty) {
      await _loadPartiesAndCities();
    }

    if (!mounted) return;

    final searchController = TextEditingController();
    List<String> filteredCities = List.from(_cities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOrigin ? 'Select Origin' : 'Select Destination',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search city...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setModalState(() {
                    if (value.isEmpty) {
                      filteredCities = List.from(_cities);
                    } else {
                      filteredCities = _cities
                          .where((city) => city.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    return ListTile(
                      title: Text(city),
                      onTap: () {
                        controller.text = city;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTripDialog() {
    if (_tripDetails == null) return;

    final partyNameController = TextEditingController(text: _tripDetails!['partyName']);
    final truckNumberController = TextEditingController(text: _tripDetails!['truckNumber']);
    final driverNameController = TextEditingController(text: _tripDetails!['driverName']);
    final originController = TextEditingController(text: _tripDetails!['origin']);
    final destinationController = TextEditingController(text: _tripDetails!['destination']);
    final lrNumberController = TextEditingController(text: _tripDetails!['lrNumber']);
    final freightAmountController = TextEditingController(
      text: _tripDetails!['freightAmount']?.toString() ?? '',
    );
    final rateController = TextEditingController(
      text: _tripDetails!['rate']?.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: _tripDetails!['quantity']?.toString() ?? '',
    );
    final materialController = TextEditingController(text: _tripDetails!['material'] ?? '');
    final kmReadingController = TextEditingController(text: _tripDetails!['totalKm']?.toString() ?? '');
    final remarksController = TextEditingController(text: _tripDetails!['remarks'] ?? '');

    String selectedBillingType = _tripDetails!['billingType'] ?? 'Fixed';
    String truckType = _tripDetails!['truckType'] ?? 'Own';

    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    try {
      startDate = DateFormat('yyyy-MM-dd').parse(_tripDetails!['startDate'] ?? '');
    } catch (e) {
      // Use default if parsing fails
    }

    try {
      endDate = DateFormat('yyyy-MM-dd').parse(_tripDetails!['endDate'] ?? '');
    } catch (e) {
      // Use default if parsing fails
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
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Trip Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Party Name (Dropdown)
                  TextField(
                    controller: partyNameController,
                    readOnly: true,
                    onTap: () => _showPartyPickerForEdit(partyNameController),
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Party/Customer Name',
                      labelStyle: TextStyle(fontSize: 12),
                      hintText: 'Select party',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      isDense: true,
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Truck Number and Driver Name in Row
                  Row(
                    children: [
                      // Truck Number (Read-only)
                      Expanded(
                        child: TextField(
                          controller: truckNumberController,
                          enabled: false,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Truck No.',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: 'Truck number',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Driver Name (Read-only, Optional)
                      Expanded(
                        child: TextField(
                          controller: driverNameController,
                          enabled: false,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Driver Name',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: 'Driver',
                            helperText: 'Optional',
                            helperStyle: const TextStyle(fontSize: 10),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Origin and Destination in Row (Dropdowns)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: originController,
                          readOnly: true,
                          onTap: () => _showCityPickerForEdit(originController, true),
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Origin',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'Select origin',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: destinationController,
                          readOnly: true,
                          onTap: () => _showCityPickerForEdit(destinationController, false),
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Destination',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'Select destination',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Party Billing Type - Compact buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Party Billing Type',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCompactBillingButton('Fixed', selectedBillingType, (val) {
                            setModalState(() => selectedBillingType = val);
                          }),
                          const SizedBox(width: 6),
                          _buildCompactBillingButton('Per Tonne', selectedBillingType, (val) {
                            setModalState(() => selectedBillingType = val);
                          }),
                          const SizedBox(width: 6),
                          _buildCompactBillingButton('Per KG', selectedBillingType, (val) {
                            setModalState(() => selectedBillingType = val);
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Rate and Quantity (only if not Fixed)
                  if (selectedBillingType != 'Fixed') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rateController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Rate',
                              labelStyle: TextStyle(fontSize: 12),
                              hintText: 'Rate',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              labelStyle: TextStyle(fontSize: 12),
                              hintText: 'Qty',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Start Date and End Date in Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              labelStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              isDense: true,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(startDate),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                endDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                              labelStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              isDense: true,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(endDate),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // LR Number and Material in Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lrNumberController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Trip/LR No',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'LR No',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: materialController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Material',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'Material',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Start KM Reading and Freight Amount in Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: kmReadingController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Start KM',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'KM',
                            suffixText: 'KMs',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.speed, size: 18),
                            helperText: 'Optional',
                            helperStyle: TextStyle(fontSize: 10),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: freightAmountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Freight Amount',
                            labelStyle: TextStyle(fontSize: 12),
                            hintText: 'Amount',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Remarks/Note
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      labelStyle: TextStyle(fontSize: 12),
                      hintText: 'Notes or remarks',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note, size: 18),
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (partyNameController.text.isNotEmpty &&
                            truckNumberController.text.isNotEmpty &&
                            originController.text.isNotEmpty &&
                            destinationController.text.isNotEmpty &&
                            freightAmountController.text.isNotEmpty) {
                          // Call API to update trip
                          final success = await ApiService.updateTrip(
                            tripId: widget.tripId,
                            partyId: _selectedPartyId, // Pass ID instead of name
                            driverId: _selectedDriverId, // Pass ID instead of name
                            origin: originController.text,
                            destination: destinationController.text,
                            billingType: selectedBillingType,
                            rate: rateController.text.isNotEmpty ? rateController.text : null,
                            quantity: quantityController.text.isNotEmpty ? quantityController.text : null,
                            startDate: DateFormat('yyyy-MM-dd').format(startDate),
                            endDate: DateFormat('yyyy-MM-dd').format(endDate),
                            lrNumber: lrNumberController.text,
                            freightAmount: freightAmountController.text,
                            material: materialController.text.isNotEmpty ? materialController.text : null,
                            totalKm: kmReadingController.text.isNotEmpty ? kmReadingController.text : null,
                            remarks: remarksController.text.isNotEmpty ? remarksController.text : null,
                          );

                          if (success && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Trip updated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadTripDetails();
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update trip'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all required fields'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
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
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/appbar.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../trips/screens/trip_details_screen.dart';
import 'supplier_balance_report_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class SupplierTripsScreen extends StatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierTripsScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierTripsScreen> createState() => _SupplierTripsScreenState();
}

class _SupplierTripsScreenState extends State<SupplierTripsScreen> {
  List<dynamic> _allTrips = [];
  List<dynamic> _filteredTrips = [];
  bool _isLoading = true;
  String _searchQuery = '';
  double _totalAmount = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final allTrips = await ApiService.getAllTrips();

      print('Total trips fetched: ${allTrips.length}');
      print('Looking for supplier: ${widget.supplierName}');

      // Filter trips for this supplier
      final supplierTrips = allTrips.where((trip) {
        final supplierName = trip['supplierName']?.toString() ?? '';
        print('Trip supplier: $supplierName');
        return supplierName.toLowerCase() == widget.supplierName.toLowerCase();
      }).toList();

      print('Filtered trips for supplier: ${supplierTrips.length}');

      setState(() {
        _allTrips = supplierTrips;
        _filteredTrips = supplierTrips;
        _calculateTotals();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trips: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  void _calculateTotals() {
    double total = 0.0;
    double paid = 0.0;

    for (var trip in _filteredTrips) {
      final truckHireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
      total += truckHireCost;

      // If trip is settled, consider it paid
      if (trip['status']?.toString() == 'Settled') {
        paid += truckHireCost;
      }
    }

    setState(() {
      _totalAmount = total;
      _totalPaid = paid;
    });
  }

  void _filterTrips(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTrips = _allTrips;
      } else {
        final searchLower = query.toLowerCase();
        _filteredTrips = _allTrips.where((trip) {
          final truckNumber = trip['truckNumber']?.toString().toLowerCase() ?? '';
          final origin = trip['origin']?.toString().toLowerCase() ?? '';
          final destination = trip['destination']?.toString().toLowerCase() ?? '';
          final lrNumber = trip['lrNumber']?.toString().toLowerCase() ?? '';

          return truckNumber.contains(searchLower) ||
              origin.contains(searchLower) ||
              destination.contains(searchLower) ||
              lrNumber.contains(searchLower);
        }).toList();
      }
      _calculateTotals();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Load in Progress':
        return Colors.orange;
      case 'POD Pending':
        return AppColors.info;
      case 'POD Received':
        return Colors.green;
      case 'Settled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showAmountDetailsDialog(Map<String, dynamic> trip) {
    final truckHireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
    final charges = 0.0; // TODO: Get from trip data
    final deductions = 0.0; // TODO: Get from trip data
    final advance = 0.0; // TODO: Get from trip data
    final payment = trip['status']?.toString() == 'Settled' ? truckHireCost : 0.0;
    final balance = truckHireCost + charges - deductions - advance - payment;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount Details',
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

            // Trip Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        trip['origin']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      Text(
                        trip['destination']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        trip['startDate']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(' • '),
                      Text(
                        trip['truckNumber']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount Breakdown
            _buildAmountRow('Freight Amount', truckHireCost, false),
            const SizedBox(height: 12),
            _buildAmountRow('Charges', charges, false),
            const SizedBox(height: 12),
            _buildAmountRow('Deductions', deductions, false),
            const SizedBox(height: 12),
            _buildAmountRow('Advance', advance, false),
            const SizedBox(height: 12),
            _buildAmountRow('Payment', payment, false, isNegative: true),
            const Divider(height: 32),
            _buildAmountRow('Balance', balance, true),
            const SizedBox(height: 24),

            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, bool isBold, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
        Text(
          '${isNegative ? '-' : ''}₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppColors.info : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = _totalAmount - _totalPaid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar:CustomAppBar(title: widget.supplierName,onBack: () {
        Navigator.pop(context);
      },),
      body: Column(
        children: [
          // Balance Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance based on Trips',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${balance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to PDF report for this supplier
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: const BorderSide(color: AppColors.info, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text(
                    'View PDF',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TRIP DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'BALANCE AMOUNT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Trip List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoader())
                : _filteredTrips.isEmpty
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
                              'No trips found for this supplier',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTrips,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _filteredTrips[index];
                            return _buildTripCard(trip);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final truckHireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
    final payment = trip['status']?.toString() == 'Settled' ? truckHireCost : 0.0;
    final balance = truckHireCost - payment;

    String formattedDate = trip['startDate']?.toString() ?? '';
    try {
      final date = DateTime.parse(trip['startDate']?.toString() ?? '');
      formattedDate = DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      // Keep original format
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
      child: InkWell(
        onTap: () {
          _showAmountDetailsDialog(trip);
        },
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
                        trip['origin']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      ),
                      Text(
                        trip['destination']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Text(
                        trip['truckNumber']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹${balance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: balance == 0 ? Colors.green : AppColors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



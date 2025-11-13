import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';
import 'party_balance_report_screen.dart';

class PartyBalanceDetailScreen extends StatefulWidget {
  final int partyId;
  final String partyName;

  const PartyBalanceDetailScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  @override
  State<PartyBalanceDetailScreen> createState() => _PartyBalanceDetailScreenState();
}

class _PartyBalanceDetailScreenState extends State<PartyBalanceDetailScreen> {
  List<dynamic> _allTrips = [];
  bool _isLoading = true;
  double _totalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final allTrips = await ApiService.getAllTrips();

      // Filter trips for this party
      final partyTrips = allTrips.where((trip) {
        final partyName = trip['partyName']?.toString() ?? '';
        return partyName == widget.partyName;
      }).toList();

      // Calculate total balance
      double balance = 0.0;
      for (var trip in partyTrips) {
        final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
        final settleAmount = double.tryParse(trip['settleAmount']?.toString() ?? '0') ?? 0.0;
        final status = trip['status']?.toString() ?? '';

        // Calculate balance including all financial components
        final charges = trip['charges'] as List<dynamic>? ?? [];
        final totalCharges = charges.fold<double>(
          0.0,
          (sum, chg) => sum + (double.tryParse(chg['amount']?.toString() ?? '0') ?? 0.0),
        );

        final advances = trip['advances'] as List<dynamic>? ?? [];
        final totalAdvances = advances.fold<double>(
          0.0,
          (sum, adv) => sum + (double.tryParse(adv['amount']?.toString() ?? '0') ?? 0.0),
        );

        final payments = trip['payments'] as List<dynamic>? ?? [];
        final totalPayments = payments.fold<double>(
          0.0,
          (sum, pay) => sum + (double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0),
        );

        // Only count unpaid trips
        if (status != 'Settled') {
          balance += freightAmount + totalCharges - totalAdvances - totalPayments - settleAmount;
        }
      }

      setState(() {
        _allTrips = partyTrips;
        _totalBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  void _viewPDF() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyBalanceReportScreen(
          parties: [
            {
              'id': widget.partyId,
              'name': widget.partyName,
              'balance': _totalBalance,
            }
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Text(widget.partyName),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Balance Summary
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance based on Trips',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_totalBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _viewPDF,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('View PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue, width: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Trip Headers
                if (_allTrips.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TRIP DETAILS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'BALANCE AMOUNT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Trip List
                Expanded(
                  child: _allTrips.isEmpty
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
                                'No trips found for this party',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _allTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _allTrips[index];
                            return _buildTripCard(trip);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _showAmountDetailsPopup(Map<String, dynamic> trip) {
    final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    final settleAmount = double.tryParse(trip['settleAmount']?.toString() ?? '0') ?? 0.0;

    // Calculate totals from arrays
    final charges = trip['charges'] as List<dynamic>? ?? [];
    final totalCharges = charges.fold<double>(
      0.0,
      (sum, chg) => sum + (double.tryParse(chg['amount']?.toString() ?? '0') ?? 0.0),
    );

    final advances = trip['advances'] as List<dynamic>? ?? [];
    final totalAdvances = advances.fold<double>(
      0.0,
      (sum, adv) => sum + (double.tryParse(adv['amount']?.toString() ?? '0') ?? 0.0),
    );

    final payments = trip['payments'] as List<dynamic>? ?? [];
    final totalPayments = payments.fold<double>(
      0.0,
      (sum, pay) => sum + (double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0),
    );

    final balance = freightAmount + totalCharges - totalAdvances - totalPayments - settleAmount;

    final origin = trip['origin']?.toString() ?? '';
    final destination = trip['destination']?.toString() ?? '';
    final startDate = trip['startDate']?.toString() ?? '';
    final truckNumber = trip['truckNumber']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Trip Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        origin,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        destination,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        startDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        truckNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Amount Details
            _buildAmountRow('Freight Amount', freightAmount),
            if (totalCharges > 0)
              _buildAmountRow('Charges', totalCharges),
            if (totalAdvances > 0)
              _buildAmountRow('Advance', -totalAdvances),
            if (totalPayments > 0)
              _buildAmountRow('Payment', -totalPayments),
            if (settleAmount > 0)
              _buildAmountRow('Settlement', -settleAmount),

            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 16),

            // Balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '₹${balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Close',
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

  Widget _buildAmountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Text(
            amount < 0 ? '-₹${(-amount).toStringAsFixed(0)}' : '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    final settleAmount = double.tryParse(trip['settleAmount']?.toString() ?? '0') ?? 0.0;
    final origin = trip['origin']?.toString() ?? '';
    final destination = trip['destination']?.toString() ?? '';
    final startDate = trip['startDate']?.toString() ?? '';
    final truckNumber = trip['truckNumber']?.toString() ?? '';
    final status = trip['status']?.toString() ?? '';

    // Calculate balance including all financial components
    final charges = trip['charges'] as List<dynamic>? ?? [];
    final totalCharges = charges.fold<double>(
      0.0,
      (sum, chg) => sum + (double.tryParse(chg['amount']?.toString() ?? '0') ?? 0.0),
    );

    final advances = trip['advances'] as List<dynamic>? ?? [];
    final totalAdvances = advances.fold<double>(
      0.0,
      (sum, adv) => sum + (double.tryParse(adv['amount']?.toString() ?? '0') ?? 0.0),
    );

    final payments = trip['payments'] as List<dynamic>? ?? [];
    final totalPayments = payments.fold<double>(
      0.0,
      (sum, pay) => sum + (double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0),
    );

    // Only show balance for unpaid trips
    final balance = status != 'Settled'
        ? freightAmount + totalCharges - totalAdvances - totalPayments - settleAmount
        : 0.0;

    return GestureDetector(
      onTap: () => _showAmountDetailsPopup(trip),
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    children: [
                      Text(
                        origin,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        destination,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date and Truck
                  Row(
                    children: [
                      Text(
                        startDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        truckNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Balance Amount
            Text(
              '₹${balance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: balance > 0 ? Colors.blue : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

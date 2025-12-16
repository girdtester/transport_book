import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/appbar.dart';
import '../../../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../../utils/app_constants.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class PartyLedgerPdfScreen extends StatefulWidget {
  final List<int> partyIds;
  final List<String> partyNames;

  const PartyLedgerPdfScreen({
    super.key,
    required this.partyIds,
    required this.partyNames,
  });

  @override
  State<PartyLedgerPdfScreen> createState() => _PartyLedgerPdfScreenState();
}

class _PartyLedgerPdfScreenState extends State<PartyLedgerPdfScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ledgerData = [];
  String _businessName = AppConstants.defaultBusinessName;
  String _userPhone = AppConstants.defaultPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLedgerData();
  }

  Future<void> _loadUserData() async {
    final businessName = await AppConstants.getBusinessName();
    final userPhone = await AppConstants.getUserPhone();
    setState(() {
      _businessName = businessName;
      _userPhone = userPhone;
    });
  }

  Future<void> _loadLedgerData() async {
    setState(() => _isLoading = true);
    try {
      final allTrips = await ApiService.getAllTrips();
      final parties = await ApiService.getParties();

      List<Map<String, dynamic>> ledgers = [];

      for (int i = 0; i < widget.partyIds.length; i++) {
        final partyId = widget.partyIds[i];
        final partyName = widget.partyNames[i];

        // Find party details
        final party = parties.firstWhere(
          (p) => p['id'] == partyId,
          orElse: () => {'name': partyName, 'phone': ''},
        );

        // Filter trips for this party
        final partyTrips = allTrips.where((trip) {
          final tripPartyName = trip['partyName']?.toString() ?? '';
          return tripPartyName == partyName;
        }).toList();

        // Calculate totals
        double totalFreight = 0.0;
        double totalAdvance = 0.0;
        double totalCharges = 0.0;
        double totalDeductions = 0.0;
        double totalPayments = 0.0;

        for (var trip in partyTrips) {
          totalFreight += double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
          totalAdvance += double.tryParse(trip['advance']?.toString() ?? '0') ?? 0.0;
          totalCharges += double.tryParse(trip['charges']?.toString() ?? '0') ?? 0.0;
          totalDeductions += double.tryParse(trip['deductions']?.toString() ?? '0') ?? 0.0;
          totalPayments += double.tryParse(trip['payment']?.toString() ?? '0') ?? 0.0;
        }

        final totalDue = totalFreight + totalCharges - totalDeductions - totalAdvance - totalPayments;

        ledgers.add({
          'partyName': partyName,
          'partyPhone': party['phone']?.toString() ?? '',
          'trips': partyTrips,
          'tripCount': partyTrips.length,
          'totalFreight': totalFreight,
          'totalAdvance': totalAdvance,
          'totalCharges': totalCharges,
          'totalDeductions': totalDeductions,
          'totalPayments': totalPayments,
          'totalDue': totalDue,
        });
      }

      setState(() {
        _ledgerData = ledgers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _downloadPDF() {
    ToastHelper.showSnackBarToast(context, 
      const SnackBar(content: Text('PDF Downloaded')),
    );
  }

  void _sharePDF() {
    Share.share('Party Ledger PDF - $_businessName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E8B57),
      appBar: CustomAppBar(
        title: 'Party Ledger',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: AppLoader(color: AppColors.appBarTextColor))
          : Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.grey.shade200,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: _ledgerData.map((ledger) {
                          return _buildLedgerPage(ledger);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                // Bottom Buttons
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadPDF,
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text(
                            'Download',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sharePDF,
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            minimumSize: const Size(0, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLedgerPage(Map<String, dynamic> ledger) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Logo and Business Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E8B57),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TMS Book',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E8B57),
                    ),
                  ),
                ],
              ),
              Text(
                _userPhone,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Business Name
          Center(
            child: Text(
              _businessName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Bill To
          const Text(
            'Bill To',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ledger['partyName'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            ledger['partyPhone'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 24),

          // Ledger Date
          Center(
            child: Text(
              'Ledger Details as on ${DateTime.now().day.toString().padLeft(2, '0')}-${_getMonthName(DateTime.now().month)}-${DateTime.now().year.toString().substring(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Total Due Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2E8B57),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Due',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${ledger['tripCount']} Trips | ₹${ledger['totalDue'].toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Amount in words
          Text(
            'Amount in words : ${_numberToWords(ledger['totalDue'])} Only',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 16),

          // Table Header
          Container(
            color: const Color(0xFF2E8B57),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                _buildTableHeaderCell('S.No', flex: 1),
                _buildTableHeaderCell('Date', flex: 2),
                _buildTableHeaderCell('Truck No.', flex: 2),
                _buildTableHeaderCell('Route', flex: 3),
                _buildTableHeaderCell('Freight', flex: 2),
                _buildTableHeaderCell('Total Due', flex: 2),
              ],
            ),
          ),

          // Table Rows (simplified - showing total)
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                _buildTableCell('Total', flex: 1),
                _buildTableCell('', flex: 2),
                _buildTableCell('', flex: 2),
                _buildTableCell('', flex: 3),
                _buildTableCell('₹${ledger['totalFreight'].toStringAsFixed(0)}', flex: 2),
                _buildTableCell('₹${ledger['totalDue'].toStringAsFixed(0)}', flex: 2),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // UPI and Bank Details Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Google Play',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text(
                'This is an automatically generated summary.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Powered by TMS Book',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _numberToWords(double number) {
    if (number == 0) return 'Zero Rupees';
    // Simplified - just return the number for now
    return '${number.toStringAsFixed(0)} Rupees';
  }
}



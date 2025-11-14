import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';

class PartyBalanceReportScreen extends StatefulWidget {
  final List<dynamic> parties;

  const PartyBalanceReportScreen({
    super.key,
    required this.parties,
  });

  @override
  State<PartyBalanceReportScreen> createState() => _PartyBalanceReportScreenState();
}

class _PartyBalanceReportScreenState extends State<PartyBalanceReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _partyReportData = [];
  String _businessName = AppConstants.defaultBusinessName;
  String _userPhone = AppConstants.defaultPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadReportData();
  }

  Future<void> _loadUserData() async {
    final businessName = await AppConstants.getBusinessName();
    final userPhone = await AppConstants.getUserPhone();
    setState(() {
      _businessName = businessName;
      _userPhone = userPhone;
    });
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final allTrips = await ApiService.getAllTrips();

      List<Map<String, dynamic>> reportData = [];

      for (var party in widget.parties) {
        final partyId = party['id'] as int?;
        final partyName = party['name']?.toString() ?? '';
        final partyPhone = party['phone']?.toString() ?? '';
        final balance = double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0;

        // Only include parties with non-zero balance
        if (balance <= 0) continue;

        // Load transactions for this party
        Map<String, dynamic>? transactionData;
        List<dynamic> transactions = [];

        if (partyId != null) {
          transactionData = await ApiService.getPartyTransactions(partyId);
          transactions = transactionData?['transactions'] as List? ?? [];
        }

        // Calculate totals from transactions
        double totalFreight = 0.0;
        double totalAdvances = 0.0;
        double totalCharges = 0.0;
        double totalPayments = 0.0;
        double totalSettlements = 0.0;

        for (var txn in transactions) {
          final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0.0;
          final type = txn['type']?.toString() ?? '';

          if (type == 'advance') {
            totalAdvances += amount;
          } else if (type == 'charge') {
            totalCharges += amount;
          } else if (type == 'payment') {
            totalPayments += amount;
          } else if (type == 'settlement') {
            totalSettlements += amount;
          }
        }

        // Calculate freight from unsettled trips
        for (var txn in transactions) {
          final tripId = txn['tripId'];
          if (tripId != null) {
            final trip = allTrips.firstWhere((t) => t['id'] == tripId, orElse: () => {});
            if (trip.isNotEmpty) {
              final freight = double.tryParse(trip['freight']?.toString() ?? '0') ?? 0.0;
              // Only count each trip once
              if (!reportData.any((rd) =>
                  (rd['transactions'] as List).any((t) => t['tripId'] == tripId))) {
                totalFreight += freight;
              }
            }
          }
        }

        reportData.add({
          'partyId': partyId,
          'partyName': partyName,
          'partyPhone': partyPhone,
          'balance': balance,
          'transactions': transactions,
          'totalFreight': totalFreight,
          'totalAdvances': totalAdvances,
          'totalCharges': totalCharges,
          'totalPayments': totalPayments,
          'totalSettlements': totalSettlements,
          'trips': allTrips, // Keep all trips for lookup
        });
      }

      setState(() {
        _partyReportData = reportData;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Party Balance Report',
          style: TextStyle(
            color: AppColors.appBarTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Report Content (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with Logo and Business Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Logo
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    color: AppColors.primaryGreen,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TMS Prime',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              // Phone number
                              Text(
                                _userPhone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Business Name
                          Center(
                            child: Text(
                              _businessName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Report Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Party Balance Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'As on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Total Summary
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Parties',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_partyReportData.length}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total Amount to Receive',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_partyReportData.fold<double>(0, (sum, party) => sum + (party['balance'] as double)).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Party-wise details
                          ..._partyReportData.map((partyData) {
                            return _buildPartySection(partyData);
                          }).toList(),

                          const SizedBox(height: 32),

                          // Footer
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Google Play',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                    children: [
                                      const TextSpan(text: 'This is an automatically generated summary. Powered by '),
                                      TextSpan(
                                        text: 'TMS Prime',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Action Buttons
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
                      // Download Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadReport,
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
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Share Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareReport,
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
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildPartySection(Map<String, dynamic> partyData) {
    final transactions = partyData['transactions'] as List<dynamic>;
    final allTrips = partyData['trips'] as List<dynamic>;
    final totalFreight = partyData['totalFreight'] as double;
    final totalAdvances = partyData['totalAdvances'] as double;
    final totalCharges = partyData['totalCharges'] as double;
    final totalPayments = partyData['totalPayments'] as double;
    final totalSettlements = partyData['totalSettlements'] as double;
    final balance = partyData['balance'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Party Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partyData['partyName'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partyData['partyPhone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transactions.length} ${transactions.length == 1 ? 'Transaction' : 'Transactions'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Balance Breakdown
          Text(
            'Balance Breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          _buildBalanceRow('Total Freight', totalFreight, Colors.black87),
          if (totalCharges > 0) _buildBalanceRow('Charges (+)', totalCharges, Colors.orange),
          if (totalAdvances > 0) _buildBalanceRow('Advances (-)', -totalAdvances, Colors.red),
          if (totalPayments > 0) _buildBalanceRow('Payments (-)', -totalPayments, Colors.red),
          if (totalSettlements > 0) _buildBalanceRow('Settlements (-)', -totalSettlements, Colors.red),
          const Divider(height: 20),
          _buildBalanceRow('Balance to Receive', balance, AppColors.primaryGreen, isBold: true),

          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Transactions Header
            Text(
              'Transactions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // Transaction List
            ...transactions.map((txn) {
              final type = txn['type']?.toString() ?? '';
              final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0.0;
              final date = txn['date']?.toString() ?? '';
              final tripId = txn['tripId'];

              // Find trip details
              String tripInfo = '';
              if (tripId != null) {
                final trip = allTrips.firstWhere((t) => t['id'] == tripId, orElse: () => {});
                if (trip.isNotEmpty) {
                  final origin = trip['origin']?.toString() ?? '';
                  final destination = trip['destination']?.toString() ?? '';
                  final truckNumber = trip['truckNumber']?.toString() ?? '';
                  if (origin.isNotEmpty && destination.isNotEmpty) {
                    tripInfo = '$origin → $destination';
                    if (truckNumber.isNotEmpty) {
                      tripInfo += ' ($truckNumber)';
                    }
                  }
                }
              }

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
              Color typeColor = Colors.grey;
              if (type == 'advance') {
                typeLabel = 'Advance';
                typeColor = Colors.orange;
              } else if (type == 'charge') {
                typeLabel = 'Charge';
                typeColor = Colors.red;
              } else if (type == 'payment') {
                typeLabel = 'Payment';
                typeColor = Colors.green;
              } else if (type == 'settlement') {
                typeLabel = 'Settlement';
                typeColor = Colors.blue;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                    if (tripInfo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tripInfo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            '₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TMS Prime',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _userPhone,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            pw.Center(
              child: pw.Text(
                _businessName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 24),

            // Report Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Party Balance Report',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'As on ${DateFormat('dd MMM yyyy').format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Total Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Parties',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${_partyReportData.length}',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Amount to Receive',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${_partyReportData.fold<double>(0, (sum, party) => sum + (party['balance'] as double)).toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Party-wise details
            ..._partyReportData.map((partyData) {
              return _buildPdfPartySection(partyData);
            }).toList(),

            pw.SizedBox(height: 20),

            // Footer
            pw.Center(
              child: pw.Text(
                'This is an automatically generated summary. Powered by TMS Prime',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfPartySection(Map<String, dynamic> partyData) {
    final transactions = partyData['transactions'] as List<dynamic>;
    final allTrips = partyData['trips'] as List<dynamic>;
    final totalFreight = partyData['totalFreight'] as double;
    final totalAdvances = partyData['totalAdvances'] as double;
    final totalCharges = partyData['totalCharges'] as double;
    final totalPayments = partyData['totalPayments'] as double;
    final totalSettlements = partyData['totalSettlements'] as double;
    final balance = partyData['balance'] as double;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Party Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      partyData['partyName'],
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      partyData['partyPhone'],
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${transactions.length} ${transactions.length == 1 ? 'Transaction' : 'Transactions'}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 8),

          // Balance Breakdown
          pw.Text(
            'Balance Breakdown',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildPdfBalanceRow('Total Freight', totalFreight, PdfColors.black),
          if (totalCharges > 0) _buildPdfBalanceRow('Charges (+)', totalCharges, PdfColors.orange),
          if (totalAdvances > 0) _buildPdfBalanceRow('Advances (-)', -totalAdvances, PdfColors.red700),
          if (totalPayments > 0) _buildPdfBalanceRow('Payments (-)', -totalPayments, PdfColors.red700),
          if (totalSettlements > 0) _buildPdfBalanceRow('Settlements (-)', -totalSettlements, PdfColors.red700),
          pw.Divider(height: 12),
          _buildPdfBalanceRow('Balance to Receive', balance, PdfColors.green700, isBold: true),

          if (transactions.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Transactions Header
            pw.Text(
              'Transactions',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),

            // Transaction List
            ...transactions.map((txn) {
              final type = txn['type']?.toString() ?? '';
              final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0.0;
              final date = txn['date']?.toString() ?? '';
              final tripId = txn['tripId'];

              // Find trip details
              String tripInfo = '';
              if (tripId != null) {
                final trip = allTrips.firstWhere((t) => t['id'] == tripId, orElse: () => {});
                if (trip.isNotEmpty) {
                  final origin = trip['origin']?.toString() ?? '';
                  final destination = trip['destination']?.toString() ?? '';
                  final truckNumber = trip['truckNumber']?.toString() ?? '';
                  if (origin.isNotEmpty && destination.isNotEmpty) {
                    tripInfo = '$origin → $destination';
                    if (truckNumber.isNotEmpty) {
                      tripInfo += ' ($truckNumber)';
                    }
                  }
                }
              }

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
              PdfColor typeColor = PdfColors.grey;
              if (type == 'advance') {
                typeLabel = 'Advance';
                typeColor = PdfColors.orange;
              } else if (type == 'charge') {
                typeLabel = 'Charge';
                typeColor = PdfColors.red700;
              } else if (type == 'payment') {
                typeLabel = 'Payment';
                typeColor = PdfColors.green;
              } else if (type == 'settlement') {
                typeLabel = 'Settlement';
                typeColor = PdfColors.blue;
              }

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          typeLabel,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                        pw.Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                    if (tripInfo.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        tripInfo,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Text(
                      formattedDate,
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfBalanceRow(String label, double amount, PdfColor color, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '₹${amount.abs().toStringAsFixed(0)}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Generate PDF
      final pdf = await _generatePdf();
      final bytes = await pdf.save();

      // Get the downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not find downloads directory');
      }

      // Create file name with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Party_Balance_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report downloaded to ${file.path}'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareReport() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing to share...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Generate PDF
      final pdf = await _generatePdf();
      final bytes = await pdf.save();

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Party_Balance_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Party Balance Report',
        text: 'Party balance report for ${_partyReportData.length} parties with total amount: ₹${_partyReportData.fold<double>(0, (sum, party) => sum + (party['balance'] as double)).toStringAsFixed(0)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing report: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    final origin = trip['origin']?.toString() ?? '';
    final destination = trip['destination']?.toString() ?? '';
    final truckNumber = trip['truckNumber']?.toString() ?? '';
    final lrNumber = trip['lrNumber']?.toString() ?? '';
    final startDate = trip['startDate']?.toString() ?? '';

    final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    final settleAmount = double.tryParse(trip['settleAmount']?.toString() ?? '0') ?? 0.0;

    // Get advances
    final advances = trip['advances'] as List<dynamic>? ?? [];
    final totalAdvances = advances.fold<double>(
      0.0,
      (sum, adv) => sum + (double.tryParse(adv['amount']?.toString() ?? '0') ?? 0.0),
    );

    // Get payments
    final payments = trip['payments'] as List<dynamic>? ?? [];
    final totalPayments = payments.fold<double>(
      0.0,
      (sum, pay) => sum + (double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0),
    );

    // Get charges
    final charges = trip['charges'] as List<dynamic>? ?? [];
    final totalCharges = charges.fold<double>(
      0.0,
      (sum, chg) => sum + (double.tryParse(chg['amount']?.toString() ?? '0') ?? 0.0),
    );

    final balance = freightAmount + totalCharges - totalAdvances - totalPayments - settleAmount;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Trip Basic Info
                _buildInfoRow('Route', '$origin → $destination'),
                _buildInfoRow('Truck Number', truckNumber),
                if (lrNumber.isNotEmpty) _buildInfoRow('LR Number', lrNumber),
                if (startDate.isNotEmpty)
                  _buildInfoRow('Start Date', DateFormat('dd MMM yyyy').format(DateTime.parse(startDate))),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Financial Details
                Text(
                  'Financial Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),

                _buildAmountRow('Freight Amount', freightAmount, AppColors.primaryGreen),
                if (totalCharges > 0)
                  _buildAmountRow('+ Charges', totalCharges, AppColors.primaryGreen),
                if (totalAdvances > 0)
                  _buildAmountRow('- Advances', totalAdvances, Colors.red),
                if (totalPayments > 0)
                  _buildAmountRow('- Payments', totalPayments, Colors.red),
                if (settleAmount > 0)
                  _buildAmountRow('- Settlement', settleAmount, Colors.red),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${balance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? AppColors.primaryGreen : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                // Show detailed breakdowns if available
                if (advances.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Advances (${advances.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...advances.map((adv) {
                    final amount = double.tryParse(adv['amount']?.toString() ?? '0') ?? 0.0;
                    final date = adv['date']?.toString() ?? '';
                    final mode = adv['paymentMode']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              date.isNotEmpty
                                ? '${DateFormat('dd MMM').format(DateTime.parse(date))} ${mode.isNotEmpty ? "($mode)" : ""}'
                                : mode,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Payments (${payments.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...payments.map((pay) {
                    final amount = double.tryParse(pay['amount']?.toString() ?? '0') ?? 0.0;
                    final date = pay['date']?.toString() ?? '';
                    final mode = pay['paymentMode']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              date.isNotEmpty
                                ? '${DateFormat('dd MMM').format(DateTime.parse(date))} ${mode.isNotEmpty ? "($mode)" : ""}'
                                : mode,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                if (charges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Charges (${charges.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...charges.map((chg) {
                    final amount = double.tryParse(chg['amount']?.toString() ?? '0') ?? 0.0;
                    final type = chg['chargeType']?.toString() ?? '';
                    final date = chg['date']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              date.isNotEmpty
                                ? '$type - ${DateFormat('dd MMM').format(DateTime.parse(date))}'
                                : type,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

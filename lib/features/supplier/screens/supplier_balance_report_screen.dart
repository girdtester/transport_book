import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'dart:io';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class SupplierBalanceReportScreen extends StatefulWidget {
  final List<dynamic> suppliers;

  const SupplierBalanceReportScreen({
    super.key,
    required this.suppliers,
  });

  @override
  State<SupplierBalanceReportScreen> createState() => _SupplierBalanceReportScreenState();
}

class _SupplierBalanceReportScreenState extends State<SupplierBalanceReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _supplierReportData = [];
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

      for (var supplier in widget.suppliers) {
        final supplierId = supplier['id'] as int?;
        final supplierName = supplier['name']?.toString() ?? '';
        final supplierPhone = supplier['phone']?.toString() ?? '';
        final balance = double.tryParse(supplier['balance']?.toString() ?? '0') ?? 0.0;

        // Only include suppliers with non-zero balance
        if (balance <= 0) continue;

        // Load transactions for this supplier
        Map<String, dynamic>? transactionData;
        List<dynamic> transactions = [];

        if (supplierId != null) {
          transactionData = await ApiService.getSupplierTransactions(supplierId);
          transactions = transactionData?['transactions'] as List? ?? [];
        }

        // Calculate totals from transactions
        double totalHireCost = 0.0;
        double totalAdvances = 0.0;
        double totalCharges = 0.0;
        double totalPayments = 0.0;

        for (var txn in transactions) {
          final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0.0;
          final type = txn['type']?.toString() ?? '';

          if (type == 'advance') {
            totalAdvances += amount;
          } else if (type == 'charge') {
            totalCharges += amount;
          } else if (type == 'payment') {
            totalPayments += amount;
          }
        }

        // Calculate hire cost from unsettled trips
        for (var txn in transactions) {
          final tripId = txn['tripId'];
          if (tripId != null) {
            final trip = allTrips.firstWhere((t) => t['id'] == tripId, orElse: () => {});
            if (trip.isNotEmpty) {
              final hireCost = double.tryParse(trip['truckHireCost']?.toString() ?? '0') ?? 0.0;
              // Only count each trip once
              if (!reportData.any((rd) =>
                  (rd['transactions'] as List).any((t) => t['tripId'] == tripId))) {
                totalHireCost += hireCost;
              }
            }
          }
        }

        reportData.add({
          'supplierId': supplierId,
          'supplierName': supplierName,
          'supplierPhone': supplierPhone,
          'balance': balance,
          'transactions': transactions,
          'totalHireCost': totalHireCost,
          'totalAdvances': totalAdvances,
          'totalCharges': totalCharges,
          'totalPayments': totalPayments,
          'trips': allTrips, // Keep all trips for lookup
        });
      }

      setState(() {
        _supplierReportData = reportData;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: CustomAppBar(title:'Supplier Balance Report' ,onBack: () => Navigator.pop(context),),
      body: _isLoading
          ? const Center(child: AppLoader())
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
                                    'TMS Book',
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
                                  'Supplier Balance Report',
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
                                      'Total Suppliers',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_supplierReportData.length}',
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
                                      'Total Amount to Pay',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_supplierReportData.fold<double>(0, (sum, supplier) => sum + (supplier['balance'] as double)).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Supplier-wise details
                          ..._supplierReportData.map((supplierData) {
                            return _buildSupplierSection(supplierData);
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
                                        text: 'TMS Book',
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

  Widget _buildSupplierSection(Map<String, dynamic> supplierData) {
    final transactions = supplierData['transactions'] as List<dynamic>;
    final allTrips = supplierData['trips'] as List<dynamic>;
    final totalHireCost = supplierData['totalHireCost'] as double;
    final totalAdvances = supplierData['totalAdvances'] as double;
    final totalCharges = supplierData['totalCharges'] as double;
    final totalPayments = supplierData['totalPayments'] as double;
    final balance = supplierData['balance'] as double;

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
          // Supplier Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplierData['supplierName'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supplierData['supplierPhone'],
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
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
          _buildBalanceRow('Total Hire Cost', totalHireCost, Colors.black87),
          if (totalCharges > 0) _buildBalanceRow('Charges (+)', totalCharges, Colors.orange),
          if (totalAdvances > 0) _buildBalanceRow('Advances (-)', -totalAdvances, Colors.green),
          if (totalPayments > 0) _buildBalanceRow('Payments (-)', -totalPayments, Colors.green),
          const Divider(height: 20),
          _buildBalanceRow('Balance to Pay', balance, Colors.red, isBold: true),

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
                    tripInfo = '$origin â†’ $destination';
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
                  'TMS Book',
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
                    'Supplier Balance Report',
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
                        'Total Suppliers',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${_supplierReportData.length}',
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
                        'Total Amount to Pay',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '₹${_supplierReportData.fold<double>(0, (sum, supplier) => sum + (supplier['balance'] as double)).toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Supplier-wise details
            ..._supplierReportData.map((supplierData) {
              return _buildPdfSupplierSection(supplierData);
            }).toList(),

            pw.SizedBox(height: 20),

            // Footer
            pw.Center(
              child: pw.Text(
                'This is an automatically generated summary. Powered by TMS Book',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfSupplierSection(Map<String, dynamic> supplierData) {
    final transactions = supplierData['transactions'] as List<dynamic>;
    final allTrips = supplierData['trips'] as List<dynamic>;
    final totalHireCost = supplierData['totalHireCost'] as double;
    final totalAdvances = supplierData['totalAdvances'] as double;
    final totalCharges = supplierData['totalCharges'] as double;
    final totalPayments = supplierData['totalPayments'] as double;
    final balance = supplierData['balance'] as double;

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
          // Supplier Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      supplierData['supplierName'],
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      supplierData['supplierPhone'],
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
                      color: PdfColors.red700,
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
          _buildPdfBalanceRow('Total Hire Cost', totalHireCost, PdfColors.black),
          if (totalCharges > 0) _buildPdfBalanceRow('Charges (+)', totalCharges, PdfColors.orange),
          if (totalAdvances > 0) _buildPdfBalanceRow('Advances (-)', -totalAdvances, PdfColors.green),
          if (totalPayments > 0) _buildPdfBalanceRow('Payments (-)', -totalPayments, PdfColors.green),
          pw.Divider(height: 12),
          _buildPdfBalanceRow('Balance to Pay', balance, PdfColors.red700, isBold: true),

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
                    tripInfo = '$origin â†’ $destination';
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
      ToastHelper.showSnackBarToast(context, 
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
      final fileName = 'Supplier_Balance_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        SnackBar(
          content: Text('Report downloaded to ${file.path}'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
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
      ToastHelper.showSnackBarToast(context, 
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
      final fileName = 'Supplier_Balance_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Supplier Balance Report',
        text: 'Supplier balance report for ${_supplierReportData.length} suppliers with total amount: ₹${_supplierReportData.fold<double>(0, (sum, supplier) => sum + (supplier['balance'] as double)).toStringAsFixed(0)}',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        SnackBar(
          content: Text('Error sharing report: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}



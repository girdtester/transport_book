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
        final partyName = party['name']?.toString() ?? '';
        final partyPhone = party['phone']?.toString() ?? '';
        final balance = double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0;

        // Only include parties with non-zero balance
        if (balance <= 0) continue;

        // Filter unsettled trips for this party
        final partyTrips = allTrips.where((trip) {
          final tripPartyName = trip['partyName']?.toString() ?? '';
          final status = trip['status']?.toString() ?? '';
          return tripPartyName == partyName && status != 'Settled';
        }).toList();

        reportData.add({
          'partyName': partyName,
          'partyPhone': partyPhone,
          'balance': balance,
          'trips': partyTrips,
          'tripCount': partyTrips.length,
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
    final trips = partyData['trips'] as List<dynamic>;

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
                    '₹${partyData['balance'].toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${partyData['tripCount']} ${partyData['tripCount'] == 1 ? 'Trip' : 'Trips'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (trips.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Trips Header
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Route',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Truck No.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Trip List
            ...trips.map((trip) {
              final origin = trip['origin']?.toString() ?? '';
              final destination = trip['destination']?.toString() ?? '';
              final truckNumber = trip['truckNumber']?.toString() ?? '';
              final amount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;

              return InkWell(
                onTap: () => _showTripDetails(trip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '$origin → $destination',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          truckNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
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
    final trips = partyData['trips'] as List<dynamic>;

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
                    '₹${partyData['balance'].toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${partyData['tripCount']} ${partyData['tripCount'] == 1 ? 'Trip' : 'Trips'}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),

          if (trips.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Trips Header
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Route',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Truck No.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            // Trip List
            ...trips.map((trip) {
              final origin = trip['origin']?.toString() ?? '';
              final destination = trip['destination']?.toString() ?? '';
              final truckNumber = trip['truckNumber']?.toString() ?? '';
              final amount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        '$origin → $destination',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        truckNumber,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
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

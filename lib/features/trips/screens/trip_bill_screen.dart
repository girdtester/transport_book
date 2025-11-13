import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';

class TripBillScreen extends StatefulWidget {
  final Map<String, dynamic> tripDetails;

  const TripBillScreen({
    super.key,
    required this.tripDetails,
  });

  @override
  State<TripBillScreen> createState() => _TripBillScreenState();
}

class _TripBillScreenState extends State<TripBillScreen> {
  final GlobalKey _billKey = GlobalKey();
  String _businessName = AppConstants.defaultBusinessName;
  String _userPhone = AppConstants.defaultPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final businessName = await AppConstants.getBusinessName();
    final userPhone = await AppConstants.getUserPhone();
    setState(() {
      _businessName = businessName;
      _userPhone = userPhone;
    });
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
          'Trip PDF',
          style: TextStyle(
            color: AppColors.appBarTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Bill Content (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _billKey,
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

                      // Trip Report Header
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
                              'Trip Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())} at ${DateFormat('hh:mm a').format(DateTime.now())}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bill To and Trip Details Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bill To Section
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bill To',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.tripDetails['partyName'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Trip Details Section
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Trip Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      'Trip ID / LR No: ${widget.tripDetails['lrNumber'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Origin to Destination
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.tripDetails['origin'] ?? 'Origin',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.tripDetails['startDate'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.grey.shade400),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            widget.tripDetails['destination'] ?? 'Destination',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.tripDetails['endDate'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Truck and Driver Info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Truck: ${widget.tripDetails['truckNumber'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Driver: ${widget.tripDetails['driverName'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Trip Status
                                Text(
                                  'Trip Status: ${widget.tripDetails['status'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Payment Details Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Payment Details Rows
                      _buildPaymentRow(
                        'Freight Amount',
                        '₹${widget.tripDetails['freightAmount'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      _buildPaymentRow(
                        'Advances (-)',
                        '₹${widget.tripDetails['totalAdvance'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      _buildPaymentRow(
                        'Charges (+)',
                        '₹${widget.tripDetails['totalCharges'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      _buildPaymentRow(
                        'Deductions (-)',
                        '₹0',
                      ),
                      const Divider(height: 16),

                      _buildPaymentRow(
                        'Payments (-)',
                        '₹${widget.tripDetails['totalPayments'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      // Total Pending Balance
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pending Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '₹${widget.tripDetails['pendingBalance'] ?? 0}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Trip Summary Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Trip Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Trip Summary Rows
                      _buildPaymentRow(
                        'Trip Revenue',
                        '₹${widget.tripDetails['revenue']?['total'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      _buildPaymentRow(
                        'Trip Expenses',
                        '₹${widget.tripDetails['totalExpenses'] ?? 0}',
                      ),
                      const Divider(height: 16),

                      // Profit
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Profit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '₹${widget.tripDetails['profit'] ?? 0}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: (widget.tripDetails['profit'] ?? 0) >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
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
                    onPressed: _downloadBill,
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
                    onPressed: _shareBill,
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

  Widget _buildPaymentRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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

              // Trip Report Header
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
                      'Trip Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Generated on ${DateFormat('dd MMM yyyy').format(now)} at ${DateFormat('hh:mm a').format(now)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Bill To and Trip Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Bill To',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          widget.tripDetails['partyName'] ?? 'N/A',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 16),

                  // Trip Details
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Trip Details',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              'Trip ID / LR No: ${widget.tripDetails['lrNumber'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  widget.tripDetails['origin'] ?? 'Origin',
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  widget.tripDetails['startDate'] ?? '',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            pw.Text('→', style: const pw.TextStyle(fontSize: 16)),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  widget.tripDetails['destination'] ?? 'Destination',
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  widget.tripDetails['endDate'] ?? '',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          'Truck: ${widget.tripDetails['truckNumber'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Driver: ${widget.tripDetails['driverName'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Trip Status: ${widget.tripDetails['status'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // Payment Details Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Payment Details',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              // Payment Details
              _buildPdfPaymentRow('Freight Amount', '₹${widget.tripDetails['freightAmount'] ?? 0}'),
              pw.Divider(),
              _buildPdfPaymentRow('Advances (-)', '₹${widget.tripDetails['totalAdvance'] ?? 0}'),
              pw.Divider(),
              _buildPdfPaymentRow('Charges (+)', '₹${widget.tripDetails['totalCharges'] ?? 0}'),
              pw.Divider(),
              _buildPdfPaymentRow('Deductions (-)', '₹0'),
              pw.Divider(),
              _buildPdfPaymentRow('Payments (-)', '₹${widget.tripDetails['totalPayments'] ?? 0}'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Pending Balance',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₹${widget.tripDetails['pendingBalance'] ?? 0}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // Trip Summary Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Trip Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              // Trip Summary Details
              _buildPdfPaymentRow('Trip Revenue', '₹${widget.tripDetails['revenue']?['total'] ?? 0}'),
              pw.Divider(),
              _buildPdfPaymentRow('Trip Expenses', '₹${widget.tripDetails['totalExpenses'] ?? 0}'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Profit',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₹${widget.tripDetails['profit'] ?? 0}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: (widget.tripDetails['profit'] ?? 0) >= 0
                          ? PdfColors.green700
                          : PdfColors.red700,
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'This is an automatically generated summary. Powered by TMS Prime',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfPaymentRow(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(amount, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _downloadBill() async {
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
      final fileName = 'Trip_Bill_${widget.tripDetails['lrNumber'] ?? 'Unknown'}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill downloaded to ${file.path}'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading bill: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareBill() async {
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
      final fileName = 'Trip_Bill_${widget.tripDetails['lrNumber'] ?? 'Unknown'}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Trip Bill - ${widget.tripDetails['lrNumber'] ?? 'N/A'}',
        text: 'Trip bill for ${widget.tripDetails['partyName'] ?? 'N/A'} - ${widget.tripDetails['origin']} to ${widget.tripDetails['destination']}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing bill: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

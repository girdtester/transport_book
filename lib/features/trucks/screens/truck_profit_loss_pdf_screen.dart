import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class TruckProfitLossPdfScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;
  final Map<String, dynamic> monthData;

  const TruckProfitLossPdfScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
    required this.monthData,
  });

  @override
  State<TruckProfitLossPdfScreen> createState() => _TruckProfitLossPdfScreenState();
}

class _TruckProfitLossPdfScreenState extends State<TruckProfitLossPdfScreen> {
  String _getStatusText(int? status) {
    switch (status) {
      case 0:
        return 'Created';
      case 1:
        return 'In Progress';
      case 2:
        return 'Completed';
      case 3:
        return 'Cancelled';
      case 4:
        return 'POD Received';
      case 5:
        return 'Settled';
      default:
        return status != null ? 'Status $status' : 'N/A';
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final reportDate = DateFormat('dd-MMM-yyyy  HH:mm').format(now);

    final monthName = widget.monthData['month'] ?? '';
    final tripsCount = widget.monthData['tripsStarted'] ?? 0;
    final revenue = (widget.monthData['revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (widget.monthData['expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = (widget.monthData['profit'] as num?)?.toDouble() ?? 0.0;
    final refuelQty = (widget.monthData['refuelQty'] as num?)?.toDouble() ?? 0.0;
    final trips = widget.monthData['trips'] as List? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TransportBook',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#2E8B57'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${widget.truckNumber} Profit & Loss Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#2E8B57'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Report generated on : $reportDate',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 16),

            // Month and Trip Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Number of trips started in $monthName',
                  style: const pw.TextStyle(fontSize: 13),
                ),
                pw.Text(
                  '$tripsCount',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Vehicle Revenue Section
            pw.Text(
              'Vehicle revenue in $monthName',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Freight', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text('₹ ${revenue.toStringAsFixed(0)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Charges', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text('₹ 0',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Deductions', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text('₹ 0',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Trip Costs Section
            pw.Text(
              'Trip costs in $monthName',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Detention Charges', style: const pw.TextStyle(fontSize: 13)),
                  pw.Text('₹ ${expenses.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Vehicle Costs Section
            pw.Text(
              'Vehicle costs in $monthName',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: const pw.TextStyle(fontSize: 13)),
                  pw.Text('₹ 0',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Total Costs
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total costs in $monthName',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '₹ ${expenses.toStringAsFixed(0)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Profit
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Profit for $monthName',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '₹ ${profit.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: profit >= 0 ? PdfColor.fromHex('#2E8B57') : PdfColors.red,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Notes Section
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '1. Revenue includes revenue for trips started in the month, even if the amount has not been received from the party',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '2. Supplier Charges and Deductions, if any, are adjusted in \'Trip Cost\' section',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '3. Trip level and non-trip expense level details can be found below',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '4. This report contains all information entered on the application till $reportDate',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 24),

            // Powered by
            pw.Center(
              child: pw.Text(
                'This is an automatically generated summary. Powered by TransportBook.',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),

            // Trip Details Table (if trips exist)
            if (trips.isNotEmpty) ...[
              pw.SizedBox(height: 40),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 16),
              pw.Text(
                'Trip Revenue & Expense Details',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.center,
                },
                headers: ['S.No.', 'Party Name', 'Origin', 'Destination', 'Start Date', 'Freight', 'Status'],
                data: trips.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final trip = entry.value;
                  return [
                    '$index',
                    trip['partyName'] ?? 'N/A',
                    trip['origin'] ?? 'N/A',
                    trip['destination'] ?? 'N/A',
                    trip['startDate'] ?? '',
                    '₹${(trip['freightAmount'] ?? 0).toStringAsFixed(0)}',
                    _getStatusText(trip['status'] as int?),
                  ];
                }).toList(),
              ),
            ],
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> _downloadReport() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdf = await _generatePdf();
      final bytes = await pdf.save();

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

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final monthName = widget.monthData['month'] ?? 'Report';
      final fileName = 'PL_${widget.truckNumber}_${monthName}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing to share...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdf = await _generatePdf();
      final bytes = await pdf.save();

      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final monthName = widget.monthData['month'] ?? 'Report';
      final fileName = 'PL_${widget.truckNumber}_${monthName}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(bytes);

      final profit = (widget.monthData['profit'] as num?)?.toDouble() ?? 0.0;
      final revenue = (widget.monthData['revenue'] as num?)?.toDouble() ?? 0.0;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Profit & Loss Report - ${widget.truckNumber} - $monthName',
        text: 'P&L report for ${widget.truckNumber} ($monthName). Revenue: ₹${revenue.toStringAsFixed(0)}, Profit: ₹${profit.toStringAsFixed(0)}',
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

  @override
  Widget build(BuildContext context) {
    final monthName = widget.monthData['month'] ?? '';
    final tripsCount = widget.monthData['tripsStarted'] ?? 0;
    final revenue = (widget.monthData['revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (widget.monthData['expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = (widget.monthData['profit'] as num?)?.toDouble() ?? 0.0;
    final refuelQty = (widget.monthData['refuelQty'] as num?)?.toDouble() ?? 0.0;
    final lastTripKm = (widget.monthData['lastTripKm'] as num?)?.toDouble() ?? 0.0;
    final trips = widget.monthData['trips'] as List? ?? [];

    final now = DateTime.now();
    final reportDate = DateFormat('dd-MMM-yyyy  HH:mm').format(now);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        title: Text('Truck Monthly Profit & Loss - ${widget.truckNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TransportBook',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E8B57),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.truckNumber} Profit & Loss Report',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E8B57),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report generated on : $reportDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // Month and Trip Summary
                _buildInfoRow('Number of trips started in $monthName', '$tripsCount'),
                const SizedBox(height: 20),

                // Vehicle Revenue Section
                _buildSectionHeader('Vehicle revenue in $monthName'),
                const SizedBox(height: 12),
                _buildInfoRow('Freight', '₹ ${revenue.toStringAsFixed(0)}', indent: true),
                _buildInfoRow('Total Charges', '₹ 0', indent: true),
                _buildInfoRow('Total Deductions', '₹ 0', indent: true),
                const SizedBox(height: 20),

                // Trip Costs Section
                _buildSectionHeader('Trip costs in $monthName'),
                const SizedBox(height: 12),
                _buildInfoRow('Detention Charges', '₹ ${expenses.toStringAsFixed(0)}', indent: true),
                const SizedBox(height: 20),

                // Vehicle Costs Section
                _buildSectionHeader('Vehicle costs in $monthName'),
                const SizedBox(height: 12),
                _buildInfoRow('Total', '₹ 0', indent: true),
                const SizedBox(height: 20),

                // Total Costs
                _buildInfoRow('Total costs in $monthName', '₹ ${expenses.toStringAsFixed(0)}', bold: true),
                const SizedBox(height: 20),

                // Profit
                _buildInfoRow('Profit for $monthName', '₹ ${profit.toStringAsFixed(0)}', bold: true, isProfit: true),
                const SizedBox(height: 24),

                // Notes Section
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNote('1. Revenue includes revenue for trips started in the month, even if the amount has not been received from the party'),
                _buildNote('2. Supplier Charges and Deductions, if any, are adjusted in \'Trip Cost\' section'),
                _buildNote('3. Trip level and non-trip expense level details can be found below'),
                _buildNote('4. This report contains all information entered on the application till $reportDate'),

                const SizedBox(height: 24),

                // Powered by
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/google_play.png',
                      height: 32,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        children: const [
                          TextSpan(text: 'This is an automatically generated summary. Powered by '),
                          TextSpan(
                            text: 'TransportBook',
                            style: TextStyle(
                              color: Color(0xFF2E8B57),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ],
                ),

                // Trip Details Table (if needed)
                if (trips.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  const Divider(thickness: 2),
                  const SizedBox(height: 16),
                  const Text(
                    'Trip Revenue & Expense Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTripsTable(trips),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloadReport,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Download', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareReport,
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool indent = false, bool bold = false, bool isProfit = false}) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 16.0 : 0, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: isProfit ? const Color(0xFF2E8B57) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[700],
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTripsTable(List<dynamic> trips) {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, width: 1),
      columnWidths: const {
        0: FixedColumnWidth(35),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: [
            _buildTableCell('S.No.', isHeader: true),
            _buildTableCell('Party Name', isHeader: true),
            _buildTableCell('Origin', isHeader: true),
            _buildTableCell('Destination', isHeader: true),
            _buildTableCell('Start Date', isHeader: true),
            _buildTableCell('Freight', isHeader: true),
            _buildTableCell('Status', isHeader: true),
          ],
        ),
        // Rows
        ...trips.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final trip = entry.value;
          return TableRow(
            children: [
              _buildTableCell('$index'),
              _buildTableCell(trip['partyName'] ?? 'N/A'),
              _buildTableCell(trip['origin'] ?? 'N/A'),
              _buildTableCell(trip['destination'] ?? 'N/A'),
              _buildTableCell(trip['startDate'] ?? ''),
              _buildTableCell('₹${(trip['freightAmount'] ?? 0).toStringAsFixed(0)}'),
              _buildTableCell(_getStatusText(trip['status'] as int?)),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: isHeader ? Colors.black87 : Colors.grey[800],
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }
}

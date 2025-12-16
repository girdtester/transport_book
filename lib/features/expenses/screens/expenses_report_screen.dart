import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/currency_formatter.dart';
import 'dart:io';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class ExpensesReportScreen extends StatefulWidget {
  final DateTime? selectedMonth;

  const ExpensesReportScreen({
    super.key,
    this.selectedMonth,
  });

  @override
  State<ExpensesReportScreen> createState() => _ExpensesReportScreenState();
}

class _ExpensesReportScreenState extends State<ExpensesReportScreen> {
  bool _isLoading = true;
  List<dynamic> _allExpenses = [];
  double _totalExpenses = 0.0;
  double _truckExpenses = 0.0;
  double _tripExpenses = 0.0;
  double _officeExpenses = 0.0;

  // Trip-wise grouped expenses
  Map<String, List<dynamic>> _tripWiseExpenses = {};
  double _tripWiseTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExpensesData();
  }

  Future<void> _loadExpensesData() async {
    setState(() => _isLoading = true);

    try {
      // Load all expenses (no date filter to show all data)
      final expenses = await ApiService.getMyExpenses();

      // Group by category
      double truckTotal = 0.0;
      double tripTotal = 0.0;
      double officeTotal = 0.0;

      // Group trip expenses by tripId
      Map<String, List<dynamic>> tripGroups = {};

      for (var expense in expenses) {
        final category = expense['category']?.toString() ?? '';
        final amount = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0;

        if (category == 'truck_expense') {
          truckTotal += amount;
        } else if (category == 'trip_expense') {
          tripTotal += amount;

          // Group by trip
          final tripId = expense['tripId']?.toString() ?? 'Unknown';
          tripGroups.putIfAbsent(tripId, () => []);
          tripGroups[tripId]!.add(expense);
        } else if (category == 'office_expense') {
          officeTotal += amount;
        }
      }

      setState(() {
        _allExpenses = expenses;
        _totalExpenses = truckTotal + tripTotal + officeTotal;
        _truckExpenses = truckTotal;
        _tripExpenses = tripTotal;
        _officeExpenses = officeTotal;
        _tripWiseExpenses = tripGroups;
        _tripWiseTotal = tripTotal;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading expenses data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Text(
            'Expenses Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 24),

          // Overall Summary
          pw.Container(
            padding:  pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.info.value),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Overall Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Expenses:', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '₹${_totalExpenses.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(AppColors.info.value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Category Breakdown
          pw.Text(
            'Category Breakdown',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Category',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Truck Expenses
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Truck Expenses'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '₹${_truckExpenses.toStringAsFixed(0)}',
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Trip Expenses
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Trip Expenses'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '₹${_tripExpenses.toStringAsFixed(0)}',
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Office Expenses
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Office Expenses'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '₹${_officeExpenses.toStringAsFixed(0)}',
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              // Total
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(AppColors.info.value).shade(0.1)),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '₹${_totalExpenses.toStringAsFixed(0)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Trip-wise Expenses
          if (_tripWiseExpenses.isNotEmpty) ...[
            pw.Text(
              'Trip-wise Expenses',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            ..._tripWiseExpenses.entries.map((entry) {
              final tripId = entry.key;
              final expenses = entry.value;
              final tripTotal = expenses.fold<double>(
                0.0,
                (sum, exp) => sum + (double.tryParse(exp['amount']?.toString() ?? '0') ?? 0.0),
              );

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Trip #$tripId',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '₹${tripTotal.toStringAsFixed(0)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      // Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Expense Type',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Date',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Amount',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      // Expense rows
                      ...expenses.map((expense) {
                        final expenseType = expense['expenseType']?.toString() ?? '';
                        final date = expense['date']?.toString() ?? '';
                        final amount = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0;

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(expenseType, style: const pw.TextStyle(fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: const pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],

          // Footer
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'This report is auto-generated from TMS Book - Transport Management System',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<void> _downloadReport() async {
    try {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)),
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

      if (directory == null) throw Exception('Could not find downloads directory');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Expenses_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        SnackBar(
          content: Text('Report downloaded to ${file.path}'),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF2196F3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        SnackBar(content: Text('Error downloading report: $e'), duration: const Duration(seconds: 3), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareReport() async {
    try {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Preparing to share...'), duration: Duration(seconds: 1)),
      );

      final pdf = await _generatePdf();
      final bytes = await pdf.save();

      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Expenses_Report_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Expenses Report',
        text: 'Expenses report with total: ₹${_totalExpenses.toStringAsFixed(0)} (Truck: ₹${_truckExpenses.toStringAsFixed(0)}, Trip: ₹${_tripExpenses.toStringAsFixed(0)}, Office: ₹${_officeExpenses.toStringAsFixed(0)})',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        SnackBar(content: Text('Error sharing report: $e'), duration: const Duration(seconds: 3), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      appBar: CustomAppBar(title: 'Expenses Report', onBack: () { Navigator.pop(context); },),
      body: _isLoading
          ? const Center(child: AppLoader())
          : Column(
              children: [
                // Report Content (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.info.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Expenses',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${CurrencyFormatter.formatIndianAmount(_totalExpenses)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Category Breakdown
                          const Text(
                            'Category Breakdown',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildCategoryCard('Truck Expenses', _truckExpenses, Icons.local_shipping, Colors.green),
                          const SizedBox(height: 8),
                          _buildCategoryCard('Trip Expenses', _tripExpenses, Icons.route, AppColors.info),
                          const SizedBox(height: 8),
                          _buildCategoryCard('Office Expenses', _officeExpenses, Icons.business, Colors.orange),
                          const SizedBox(height: 24),

                          // Trip-wise Expenses
                          if (_tripWiseExpenses.isNotEmpty) ...[
                            const Text(
                              'Trip-wise Expenses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._tripWiseExpenses.entries.map((entry) {
                              final tripId = entry.key;
                              final expenses = entry.value;
                              final tripTotal = expenses.fold<double>(
                                0.0,
                                (sum, exp) => sum + (double.tryParse(exp['amount']?.toString() ?? '0') ?? 0.0),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                child: ExpansionTile(
                                  title: Text(
                                    'Trip #$tripId',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${expenses.length} expense(s)',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Text(
                                    '₹${tripTotal.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                  children: expenses.map<Widget>((expense) {
                                    final expenseType = expense['expenseType']?.toString() ?? '';
                                    final date = expense['date']?.toString() ?? '';
                                    final amount = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0;

                                    return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: Text(expenseType),
                                      subtitle: Text(
                                        date,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Text(
                                        '₹${amount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ],

                          const SizedBox(height: 24),
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
                            backgroundColor: const Color(0xFF2196F3),
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
                            backgroundColor: const Color(0xFF2196F3),
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

  Widget _buildCategoryCard(String title, double amount, IconData icon, Color color) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
    '${CurrencyFormatter.formatIndianAmount(amount)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'invoice_pdf_screen.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  Map<String, dynamic>? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() => _isLoading = true);
    try {
      final invoice = await ApiService.getInvoiceById(widget.invoiceId);
      setState(() {
        _invoice = invoice;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoice: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Partially Paid':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.appBarColor,
          foregroundColor: AppColors.appBarTextColor,
          title: const Text('Invoice Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.appBarColor,
          foregroundColor: AppColors.appBarTextColor,
          title: const Text('Invoice Details'),
        ),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final invoiceNumber = _invoice!['invoiceNumber']?.toString() ?? '';
    final invoiceDate = _invoice!['invoiceDate']?.toString() ?? '';
    String formattedDate = invoiceDate;
    try {
      final date = DateTime.parse(invoiceDate);
      formattedDate = DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      // Keep original format
    }

    final balanceAmount = double.tryParse(_invoice!['balanceAmount']?.toString() ?? '0') ?? 0.0;
    final totalAmount = double.tryParse(_invoice!['totalAmount']?.toString() ?? '0') ?? 0.0;
    final paidAmount = double.tryParse(_invoice!['paidAmount']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Text(
          '$invoiceNumber | $formattedDate',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              // TODO: Navigate to edit invoice screen
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Edit'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Info Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _invoice!['partyName']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _invoice!['partyPhone']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Send reminder
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E8B57),
                      side: const BorderSide(color: Color(0xFF2E8B57)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Send Reminder'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Trip Details Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildTripDetails(),
              ),
            ),

            const SizedBox(height: 8),

            // Financial Breakdown Section
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _buildFinancialRow('Taxable Amount', totalAmount, false),
                  _buildFinancialRow('Total Invoice Value', totalAmount, true, isHighlighted: true),
                  if (paidAmount > 0) _buildPaymentRow(),
                  _buildFinancialRow('Total Balance', balanceAmount, true, isBalance: true),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InvoicePdfScreen(
                  invoice: _invoice!,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E8B57),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'View PDF',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTripDetails() {
    final trips = _invoice!['trips'] as List? ?? [];
    List<Widget> widgets = [];

    for (var trip in trips) {
      final origin = trip['origin']?.toString() ?? '';
      final destination = trip['destination']?.toString() ?? '';
      final date = trip['date']?.toString() ?? '';
      final truckNumber = trip['truckNumber']?.toString() ?? '';
      final amount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;

      String formattedDate = date;
      try {
        final parsedDate = DateTime.parse(date);
        formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        // Keep original format
      }

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        origin,
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
                        destination,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
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
                if (truckNumber.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('•', style: TextStyle(color: Colors.grey)),
                  ),
                  Text(
                    truckNumber,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (trip != trips.last) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300], height: 1),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    }

    return widgets;
  }

  Widget _buildFinancialRow(String label, double amount, bool isBold, {bool isHighlighted = false, bool isBalance = false}) {
    Color? bgColor;
    Color textColor = Colors.black87;

    if (isHighlighted) {
      bgColor = Colors.blueGrey[100];
    } else if (isBalance) {
      bgColor = amount == 0 ? Colors.green.shade50 : Colors.red.shade50;
      textColor = amount == 0 ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 15,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow() {
    final paidAmount = double.tryParse(_invoice!['paidAmount']?.toString() ?? '0') ?? 0.0;
    final paymentDate = _invoice!['paymentDate']?.toString() ?? '';

    String formattedDate = paymentDate;
    if (paymentDate.isNotEmpty) {
      try {
        final date = DateTime.parse(paymentDate);
        formattedDate = DateFormat('dd MMM yyyy').format(date);
      } catch (e) {
        // Keep original format
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Payment',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
              if (formattedDate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          Text(
            '₹${paidAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

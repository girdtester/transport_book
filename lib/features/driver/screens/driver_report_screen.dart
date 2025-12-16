import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class DriverReportScreen extends StatefulWidget {
  final int driverId;
  final String driverName;

  const DriverReportScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverReportScreen> createState() => _DriverReportScreenState();
}

class _DriverReportScreenState extends State<DriverReportScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  double _openingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final details = await ApiService.getDriverDetails(widget.driverId);

      if (details != null) {
        setState(() {
          _transactions = details['transactions'] ?? [];
          _openingBalance = double.tryParse(details['openingBalance']?.toString() ?? '0') ?? 0.0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    }
  }

  double _calculateRunningBalance(int upToIndex) {
    double balance = _openingBalance;
    for (int i = 0; i <= upToIndex; i++) {
      final transaction = _transactions[i];
      final type = transaction['type']?.toString() ?? '';
      final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;

      if (type == 'got') {
        balance += amount;
      } else if (type == 'gave') {
        balance -= amount;
      }
    }
    return balance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.driverName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ToastHelper.showSnackBarToast(context, 
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoader())
          : Column(
              children: [
                // Opening Balance
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opening Balance',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${_openingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _openingBalance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: AppColors.primaryGreen,
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'DATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'REASON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'GAVE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'GOT',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'BALANCE',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction List
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(0),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            final balance = _calculateRunningBalance(index);
                            return _buildReportRow(transaction, balance, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildReportRow(Map<String, dynamic> transaction, double balance, int index) {
    final reason = transaction['reason']?.toString() ?? '';
    final type = transaction['type']?.toString() ?? '';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final dateStr = transaction['date']?.toString() ?? '';

    String formattedDate = dateStr;
    try {
      final date = DateTime.parse(dateStr);
      formattedDate = DateFormat('dd MMM').format(date);
    } catch (e) {
      // Keep original format
    }

    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              type == 'gave' ? '${amount.toStringAsFixed(0)}' : '-',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              type == 'got' ? '${amount.toStringAsFixed(0)}' : '-',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              balance.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



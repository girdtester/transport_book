import 'package:flutter/material.dart';
import 'package:transport_book_app/utils/appbar.dart';
import '../../../utils/app_colors.dart';
import 'package:intl/intl.dart';
import 'truck_revenue_report_screen.dart';
import 'party_revenue_report_screen.dart';
import '../../balance_report/screens/balance_report_screen.dart';
import '../../supplier/screens/supplier_reports_screen.dart';
import '../../../services/api_service.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  double _totalProfit = 0.0;
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfitData();
  }

  Future<void> _loadProfitData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch data from backend profit/loss report endpoint
      final reportData = await ApiService.getProfitLossReport();

      if (reportData == null) {
        throw Exception('Failed to load report data');
      }

      setState(() {
        _totalRevenue = (reportData['totalRevenue'] as num).toDouble();
        _totalExpenses = (reportData['totalExpenses'] as num).toDouble();
        _totalProfit = (reportData['totalProfit'] as num).toDouble();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profit data: $e');
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
      appBar: CustomAppBar(
        onBack: () => Navigator.pop(context),
        title: 'Reports',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profit & Loss Report Card
            _buildProfitLossCard(),
            const SizedBox(height: 16),

            // Grid of Report Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildReportCard(
                  context,
                  icon: Icons.local_shipping,
                  title: 'Truck Revenue\nReport',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TruckRevenueReportScreen(),
                      ),
                    );
                  },
                ),
                _buildReportCard(
                  context,
                  icon: Icons.person,
                  title: 'Party Revenue\nReport',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PartyRevenueReportScreen(),
                      ),
                    );
                  },
                ),
                _buildReportCard(
                  context,
                  icon: Icons.account_balance_wallet,
                  title: 'Party Balance\nReport',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BalanceReportScreen(),
                      ),
                    );
                  },
                ),
                _buildReportCard(
                  context,
                  icon: Icons.account_balance,
                  title: 'Supplier Balance\nReport',
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SupplierReportsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossCard() {
    final currentMonth = DateFormat('MMMM').format(DateTime.now());
    final profitText = _isLoading
        ? 'Loading...'
        : '₹${_totalProfit.toStringAsFixed(0)} for $currentMonth';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 40,
              height: 40,
              child: AppLoader(
                strokeWidth: 3,
                color: Colors.amber,
              ),
            )
                : Icon(
              Icons.assessment,
              size: 60,
              color: Colors.amber,
            )

          ),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profit & Loss Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.appBarTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profitText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: _loadProfitData,
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



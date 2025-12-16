import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';
import 'truck_profit_loss_pdf_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class TruckProfitLossReportScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;

  const TruckProfitLossReportScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
  });

  @override
  State<TruckProfitLossReportScreen> createState() => _TruckProfitLossReportScreenState();
}

class _TruckProfitLossReportScreenState extends State<TruckProfitLossReportScreen> {
  bool _isLoading = true;
  List<dynamic> _months = [];
  String _truckNumber = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getTruckMonthlyProfitLoss(widget.truckId);

      if (data != null && mounted) {
        setState(() {
          _truckNumber = data['truckNumber'] ?? widget.truckNumber;
          _months = data['months'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading profit/loss data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
              'Profit & Loss Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'TL $_truckNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: AppLoader())
          : _months.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _months.length,
                    itemBuilder: (context, index) {
                      final month = _months[index];
                      return _buildMonthCard(month);
                    },
                  ),
                ),
    );
  }

  Widget _buildMonthCard(Map<String, dynamic> month) {
    final monthName = month['month'] ?? '';
    final tripsCount = month['tripsStarted'] ?? 0;
    final revenue = (month['revenue'] as num?)?.toDouble() ?? 0.0;
    final expenses = (month['expenses'] as num?)?.toDouble() ?? 0.0;
    final profit = (month['profit'] as num?)?.toDouble() ?? 0.0;
    final lastTripKm = (month['lastTripKm'] as num?)?.toDouble() ?? 0.0;
    final refuelQty = (month['refuelQty'] as num?)?.toDouble() ?? 0.0;
    final monthKey = month['monthKey'] ?? '';

    final profitColor = profit >= 0 ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header with View PDF button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TruckProfitLossPdfScreen(
                          truckId: widget.truckId,
                          truckNumber: _truckNumber,
                          monthData: month,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('View PDF'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.info,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'Trips Started',
                  value: '$tripsCount Trips',
                ),
                const SizedBox(width: 20),
                if (lastTripKm > 0)
                  _buildStatItem(
                    icon: Icons.speed,
                    label: 'Last Trip KM',
                    value: '--',
                  ),
                const SizedBox(width: 20),
                if (refuelQty > 0)
                  _buildStatItem(
                    icon: Icons.local_gas_station,
                    label: 'Refuel Qty.',
                    value: '${refuelQty.toStringAsFixed(1)} Ltrs',
                  ),
              ],
            ),

            const Divider(height: 24),

            // Financial summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Revenue',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${revenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Expenses',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${expenses.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Profit
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: profitColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: profitColor,
                    ),
                  ),
                  Text(
                    '₹${profit.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}



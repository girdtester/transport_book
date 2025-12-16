import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';

class TruckRevenueReportScreen extends StatefulWidget {
  const TruckRevenueReportScreen({super.key});

  @override
  State<TruckRevenueReportScreen> createState() => _TruckRevenueReportScreenState();
}

class _TruckRevenueReportScreenState extends State<TruckRevenueReportScreen> {
  bool _filterApplied = true;
  bool _isLoading = true;

  // Summary totals
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _totalProfit = 0.0;

  // Truck data
  List<Map<String, dynamic>> _myTrucks = [];
  List<Map<String, dynamic>> _marketTrucks = [];

  // Section totals
  double _myTrucksTotalRevenue = 0.0;
  double _myTrucksTotalExpenses = 0.0;
  double _myTrucksTotalProfit = 0.0;

  double _marketTrucksTotalRevenue = 0.0;
  double _marketTrucksTotalExpenses = 0.0;
  double _marketTrucksTotalProfit = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTruckRevenueData();
  }

  Future<void> _loadTruckRevenueData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch data from backend report endpoint
      final reportData = await ApiService.getTruckRevenueReport();

      if (reportData == null) {
        throw Exception('Failed to load report data');
      }

      // Extract summary data
      final summary = reportData['summary'] as Map<String, dynamic>;
      _totalRevenue = (summary['totalRevenue'] as num).toDouble();
      _totalExpenses = (summary['totalExpenses'] as num).toDouble();
      _totalProfit = (summary['totalProfit'] as num).toDouble();

      // Extract own trucks data
      final ownTrucksData = reportData['ownTrucks'] as Map<String, dynamic>;
      _myTrucks = (ownTrucksData['trucks'] as List).map((truck) => {
        'truck': truck['truckNumber'],
        'revenue': (truck['revenue'] as num).toDouble(),
        'expenses': (truck['expenses'] as num).toDouble(),
        'profit': (truck['profit'] as num).toDouble(),
        'tripCount': truck['tripCount'],
      }).toList();
      _myTrucksTotalRevenue = (ownTrucksData['totalRevenue'] as num).toDouble();
      _myTrucksTotalExpenses = (ownTrucksData['totalExpenses'] as num).toDouble();
      _myTrucksTotalProfit = (ownTrucksData['totalProfit'] as num).toDouble();

      // Extract market trucks data
      final marketTrucksData = reportData['marketTrucks'] as Map<String, dynamic>;
      _marketTrucks = (marketTrucksData['trucks'] as List).map((truck) => {
        'truck': truck['truckNumber'],
        'revenue': (truck['revenue'] as num).toDouble(),
        'expenses': (truck['expenses'] as num).toDouble(),
        'profit': (truck['profit'] as num).toDouble(),
        'tripCount': truck['tripCount'],
      }).toList();
      _marketTrucksTotalRevenue = (marketTrucksData['totalRevenue'] as num).toDouble();
      _marketTrucksTotalExpenses = (marketTrucksData['totalExpenses'] as num).toDouble();
      _marketTrucksTotalProfit = (marketTrucksData['totalProfit'] as num).toDouble();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading truck revenue data: $e');
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
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Truck Revenue Report',
              style: TextStyle(
                color: AppColors.appBarTextColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.download, color: Colors.green),
                            label: const Text(
                              'Download Excel',
                              style: TextStyle(color: Colors.black87),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadTruckRevenueData,
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            label: const Text(
                              'Refresh',
                              style: TextStyle(color: Colors.black87),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard('Total Expenses', '₹${_totalExpenses.toStringAsFixed(0)}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard('Total Profit', '₹${_totalProfit.toStringAsFixed(0)}'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // MY TRUCKS Section
                  if (_myTrucks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MY TRUCKS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDynamicTruckTable(
                            _myTrucks,
                            _myTrucksTotalRevenue,
                            _myTrucksTotalExpenses,
                            _myTrucksTotalProfit,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // MARKET TRUCKS Section
                  if (_marketTrucks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MARKET TRUCKS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDynamicTruckTable(
                            _marketTrucks,
                            _marketTrucksTotalRevenue,
                            _marketTrucksTotalExpenses,
                            _marketTrucksTotalProfit,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Empty state
                  if (_myTrucks.isEmpty && _marketTrucks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No truck data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTruckTable(
    List<Map<String, dynamic>> trucks,
    double totalRevenue,
    double totalExpenses,
    double totalProfit,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Truck No.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Revenue',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Expenses',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Text(
                        'Profit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Truck Rows
          ...trucks.map((truck) {
            final truckNumber = truck['truck']?.toString() ?? '';
            final revenue = truck['revenue'] as double? ?? 0.0;
            final expenses = truck['expenses'] as double? ?? 0.0;
            final profit = truck['profit'] as double? ?? 0.0;
            return _buildTruckRow(
              truckNumber,
              '₹${revenue.toStringAsFixed(0)}',
              '₹${expenses.toStringAsFixed(0)}',
              '₹${profit.toStringAsFixed(0)}',
            );
          }).toList(),

          // Total Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${totalRevenue.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${totalExpenses.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${totalProfit.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildTruckRow(String truckNo, String revenue, String expenses, String profit) {
    // Split truck number to highlight the number part
    final parts = truckNo.split(' ');
    final prefix = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : '';
    final number = parts.last;

    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    '$prefix ',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                revenue,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: Text(
                expenses,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    profit,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';

class PartyRevenueReportScreen extends StatefulWidget {
  const PartyRevenueReportScreen({super.key});

  @override
  State<PartyRevenueReportScreen> createState() => _PartyRevenueReportScreenState();
}

class _PartyRevenueReportScreenState extends State<PartyRevenueReportScreen> {
  bool _filterApplied = true;
  bool _isLoading = true;

  List<Map<String, dynamic>> _parties = [];
  double _totalRevenue = 0.0;
  int _totalTrips = 0;

  @override
  void initState() {
    super.initState();
    _loadPartyRevenueData();
  }

  Future<void> _loadPartyRevenueData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch data from backend report endpoint
      final reportData = await ApiService.getPartyRevenueReport();

      if (reportData == null) {
        throw Exception('Failed to load report data');
      }

      // Extract parties data
      final partiesList = reportData['parties'] as List;
      _parties = partiesList.map((party) => {
        'name': party['partyName'],
        'trips': party['tripCount'],
        'revenue': (party['revenue'] as num).toDouble(),
      }).toList();

      // Extract summary data
      final summary = reportData['summary'] as Map<String, dynamic>;
      _totalRevenue = (summary['totalRevenue'] as num).toDouble();
      _totalTrips = summary['totalTrips'] as int;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading party revenue data: $e');
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
    final totalTrips = _parties.fold<int>(0, (sum, party) => sum + (party['trips'] as int));

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
              'Party Revenue Report',
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
                            onPressed: _loadPartyRevenueData,
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

                  // Party Table
                  if (_parties.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
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
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Party/Customer Name',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Trips',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Total Revenue',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 24),
                                ],
                              ),
                            ),

                            // Party Rows
                            ..._parties.map((party) {
                              final name = party['name'] as String? ?? '';
                              final trips = party['trips'] as int? ?? 0;
                              final revenue = party['revenue'] as double? ?? 0.0;
                              return _buildPartyRow(
                                name,
                                trips,
                                '₹${revenue.toStringAsFixed(0)}',
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
                                    flex: 3,
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
                                      _totalTrips.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '₹${_totalRevenue.toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Empty state
                  if (_parties.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No party data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPartyRow(String partyName, int trips, String revenue) {
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
              flex: 3,
              child: Text(
                partyName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: Text(
                trips.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                revenue,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

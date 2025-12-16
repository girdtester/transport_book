import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';
import '../../trips/screens/trip_details_screen.dart';

class PartyTripsScreen extends StatefulWidget {
  final int partyId;
  final String partyName;

  const PartyTripsScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  @override
  State<PartyTripsScreen> createState() => _PartyTripsScreenState();
}

class _PartyTripsScreenState extends State<PartyTripsScreen> {
  List<dynamic> _allTrips = [];
  List<dynamic> _filteredTrips = [];
  bool _isLoading = true;
  String _searchQuery = '';
  double _totalAmount = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      final allTrips = await ApiService.getAllTrips();

      // Filter trips for this party
      final partyTrips = allTrips.where((trip) {
        final partyName = trip['partyName']?.toString() ?? '';
        return partyName == widget.partyName;
      }).toList();

      setState(() {
        _allTrips = partyTrips;
        _filteredTrips = partyTrips;
        _calculateTotals();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  void _calculateTotals() {
    double total = 0.0;
    double paid = 0.0;

    for (var trip in _filteredTrips) {
      final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
      total += freightAmount;

      // If trip is settled, consider it paid
      if (trip['status']?.toString() == 'Settled') {
        paid += freightAmount;
      }
    }

    setState(() {
      _totalAmount = total;
      _totalPaid = paid;
    });
  }

  void _filterTrips(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTrips = _allTrips;
      } else {
        final searchLower = query.toLowerCase();
        _filteredTrips = _allTrips.where((trip) {
          final truckNumber = trip['truckNumber']?.toString().toLowerCase() ?? '';
          final origin = trip['origin']?.toString().toLowerCase() ?? '';
          final destination = trip['destination']?.toString().toLowerCase() ?? '';
          final lrNumber = trip['lrNumber']?.toString().toLowerCase() ?? '';

          return truckNumber.contains(searchLower) ||
              origin.contains(searchLower) ||
              destination.contains(searchLower) ||
              lrNumber.contains(searchLower);
        }).toList();
      }
      _calculateTotals();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Load in Progress':
        return Colors.orange;
      case 'POD Pending':
        return Colors.blue;
      case 'POD Received':
        return Colors.green;
      case 'Settled':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _totalAmount - _totalPaid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Text(widget.partyName),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            color: const Color(0xFF2E8B57),
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          'Total Trips',
                          '${_filteredTrips.length}',
                          Colors.blue,
                        ),
                        _buildSummaryItem(
                          'Total Amount',
                          '₹${_totalAmount.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                        _buildSummaryItem(
                          'Balance',
                          '₹${balance.toStringAsFixed(2)}',
                          balance > 0 ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterTrips,
              decoration: InputDecoration(
                hintText: 'Search trips...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Trip List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTrips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No trips found for this party'
                                  : 'No trips match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTrips,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTrips.length,
                          itemBuilder: (context, index) {
                            final trip = _filteredTrips[index];
                            return _buildTripCard(trip);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = trip['status']?.toString() ?? '';
    final statusColor = _getStatusColor(status);
    final freightAmount = double.tryParse(trip['freightAmount']?.toString() ?? '0') ?? 0.0;
    final truckNumber = trip['truckNumber']?.toString() ?? '';
    final origin = trip['origin']?.toString() ?? '';
    final destination = trip['destination']?.toString() ?? '';
    final startDate = trip['startDate']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(
              tripId: trip['id'] ?? 0,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.appBarTextColor,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Truck Number
                  Text(
                    truckNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Route
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$origin → $destination',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '₹${freightAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  startDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

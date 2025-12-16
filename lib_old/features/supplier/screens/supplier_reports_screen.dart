import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'supplier_trips_screen.dart';
import 'supplier_balance_report_screen.dart';

class SupplierReportsScreen extends StatefulWidget {
  const SupplierReportsScreen({super.key});

  @override
  State<SupplierReportsScreen> createState() => _SupplierReportsScreenState();
}

class _SupplierReportsScreenState extends State<SupplierReportsScreen> {
  List<dynamic> _allSuppliers = [];
  List<dynamic> _filteredSuppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Set<int> _selectedSupplierIds = {};

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await ApiService.getSuppliers();
      setState(() {
        _allSuppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suppliers: $e')),
        );
      }
    }
  }

  void _filterSuppliers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSuppliers = _allSuppliers;
      } else {
        final searchLower = query.toLowerCase();
        _filteredSuppliers = _allSuppliers.where((supplier) {
          final name = supplier['name']?.toString().toLowerCase() ?? '';
          final phone = supplier['phone']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower) || phone.contains(searchLower);
        }).toList();
      }
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(int index) {
    final colors = [
      const Color(0xFF3D5A99),
      const Color(0xFF4CAF50),
      const Color(0xFFFF8C00),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF2196F3),
    ];
    return colors[index % colors.length];
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedSupplierIds.length == _filteredSuppliers.length) {
        _selectedSupplierIds.clear();
      } else {
        _selectedSupplierIds = _filteredSuppliers
            .map((s) => s['id'] as int? ?? 0)
            .toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Row(
          children: [
            const Text('Supplier Balance Report'),
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              size: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _filterSuppliers,
                    decoration: InputDecoration(
                      hintText: 'Search for a Supplier',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      suffixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Show filters
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                ),
              ],
            ),
          ),

          // Select All Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHOOSE SUPPLIERS TO VIEW PDF',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: const Text(
                    'Select All Suppliers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Supplier List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSuppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No suppliers found'
                                  : 'No suppliers match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSuppliers,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = _filteredSuppliers[index];
                            return _buildSupplierCard(supplier, index);
                          },
                        ),
                      ),
          ),
        ],
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
        child: ElevatedButton.icon(
          onPressed: _selectedSupplierIds.isEmpty
              ? null
              : () {
                  // Get selected suppliers data
                  final selectedSuppliers = _allSuppliers
                      .where((supplier) => _selectedSupplierIds.contains(supplier['id']))
                      .toList();

                  // Navigate to PDF report screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SupplierBalanceReportScreen(
                        suppliers: selectedSuppliers,
                      ),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedSupplierIds.isEmpty
                ? Colors.grey.shade300
                : const Color(0xFF3D5A99),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text(
            'View PDF',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier, int index) {
    final balance = double.tryParse(supplier['balance']?.toString() ?? '0') ?? 0.0;
    final supplierId = supplier['id'] ?? 0;
    final isSelected = _selectedSupplierIds.contains(supplierId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SupplierTripsScreen(
                supplierId: supplierId,
                supplierName: supplier['name']?.toString() ?? '',
              ),
            ),
          );
        },
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedSupplierIds.add(supplierId);
                  } else {
                    _selectedSupplierIds.remove(supplierId);
                  }
                });
              },
              activeColor: Colors.blue,
            ),
            const SizedBox(width: 12),
            // Supplier Info
            Expanded(
              child: Text(
                supplier['name']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Balance
            Text(
              '₹${balance.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

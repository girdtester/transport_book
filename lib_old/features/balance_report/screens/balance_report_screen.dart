import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../party/screens/party_balance_detail_screen.dart';
import '../../party/screens/party_ledger_pdf_screen.dart';

class BalanceReportScreen extends StatefulWidget {
  const BalanceReportScreen({super.key});

  @override
  State<BalanceReportScreen> createState() => _BalanceReportScreenState();
}

class _BalanceReportScreenState extends State<BalanceReportScreen> {
  List<dynamic> _allParties = [];
  List<dynamic> _filteredParties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<int> _selectedParties = {};

  // Filter states
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedMonth;
  final Set<String> _selectedBalanceTypes = {}; // "To Receive", "Settled", etc.

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    try {
      final parties = await ApiService.getParties();
      setState(() {
        _allParties = parties;
        _filteredParties = parties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading parties: $e')),
        );
      }
    }
  }

  void _filterParties(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredParties = _allParties;
      } else {
        final searchLower = query.toLowerCase();
        _filteredParties = _allParties.where((party) {
          final name = party['name']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower);
        }).toList();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedParties.length == _filteredParties.length) {
        _selectedParties.clear();
      } else {
        _selectedParties.clear();
        for (var party in _filteredParties) {
          _selectedParties.add(party['id'] ?? 0);
        }
      }
    });
  }

  void _togglePartySelection(int partyId) {
    setState(() {
      if (_selectedParties.contains(partyId)) {
        _selectedParties.remove(partyId);
      } else {
        _selectedParties.add(partyId);
      }
    });
  }

  void _applyFilters() {
    _filterParties(_searchQuery);
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedMonth = null;
      _selectedBalanceTypes.clear();
      _filteredParties = _allParties;
    });
  }

  void _showFilterPanel() {
    String currentFilter = 'Date';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter Content
              Expanded(
                child: Row(
                  children: [
                    // Left Sidebar
                    Container(
                      width: 140,
                      color: Colors.grey.shade100,
                      child: ListView(
                        children: [
                          _buildFilterTab('Date', currentFilter == 'Date', () {
                            setModalState(() {
                              currentFilter = 'Date';
                            });
                          }),
                          _buildFilterTab('Balance Type', currentFilter == 'Balance Type', () {
                            setModalState(() {
                              currentFilter = 'Balance Type';
                            });
                          }),
                        ],
                      ),
                    ),

                    // Right Content
                    Expanded(
                      child: _buildFilterContent(currentFilter, setModalState),
                    ),
                  ],
                ),
              ),

              // Bottom Bar
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_filteredParties.length} Parties',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'have been selected',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _applyFilters(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'APPLY FILTERS',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContent(String filterType, StateSetter setModalState) {
    switch (filterType) {
      case 'Date':
        return _buildDateFilter(setModalState);
      case 'Balance Type':
        return _buildBalanceTypeFilter(setModalState);
      default:
        return Container();
    }
  }

  Widget _buildDateFilter(StateSetter setModalState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton(
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setModalState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                });
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blue, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Choose Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),

          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 12),
            Text(
              '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Choose Month',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Month options
          _buildCheckboxOption(
            'October 2025',
            _selectedMonth == 'October 2025',
            '',
            () {
              setModalState(() {
                _selectedMonth = _selectedMonth == 'October 2025' ? null : 'October 2025';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTypeFilter(StateSetter setModalState) {
    final types = ['To Receive', 'Settled', 'All'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: types.map((type) {
        return _buildCheckboxOption(
          type,
          _selectedBalanceTypes.contains(type),
          '',
          () {
            setModalState(() {
              if (_selectedBalanceTypes.contains(type)) {
                _selectedBalanceTypes.remove(type);
              } else {
                _selectedBalanceTypes.add(type);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildCheckboxOption(String title, bool isSelected, String count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: isSelected ? Colors.blue : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (count.isNotEmpty)
              Text(
                count,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _viewPDF() {
    if (_selectedParties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one party')),
      );
      return;
    }

    // Get selected party details
    final selectedPartyDetails = _filteredParties
        .where((party) => _selectedParties.contains(party['id']))
        .toList();

    final partyIds = selectedPartyDetails.map((p) => p['id'] as int).toList();
    final partyNames = selectedPartyDetails.map((p) => p['name'].toString()).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyLedgerPdfScreen(
          partyIds: partyIds,
          partyNames: partyNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedParties.length == _filteredParties.length && _filteredParties.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: const Text('Party Balance Report'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _filterParties,
                    decoration: InputDecoration(
                      hintText: 'Search for a Party',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
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
                  onPressed: _showFilterPanel,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Select All Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHOOSE PARTIES TO VIEW PDF',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    allSelected ? 'Deselect All Parties' : 'Select All Parties',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Party List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredParties.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No parties found'
                                  : 'No parties match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = _filteredParties[index];
                          return _buildPartyCard(party);
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _viewPDF,
          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
          label: const Text(
            'View PDF',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade400,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyCard(Map<String, dynamic> party) {
    final partyId = party['id'] ?? 0;
    final isSelected = _selectedParties.contains(partyId);
    final balance = double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PartyBalanceDetailScreen(
              partyId: partyId,
              partyName: party['name']?.toString() ?? '',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            // Checkbox
            GestureDetector(
              onTap: () => _togglePartySelection(partyId),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade400,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected ? Colors.blue : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Party Name
            Expanded(
              child: Text(
                party['name']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
            // Chevron
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

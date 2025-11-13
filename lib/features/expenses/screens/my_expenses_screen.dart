import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'add_my_expense_screen.dart';
import 'expenses_report_screen.dart';

class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  List<dynamic> _expenses = [];
  List<dynamic> _filteredExpenses = [];
  List<dynamic> _allExpensesForMonth = []; // Store all expenses for grand total
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  // Category for each tab
  final List<String> _categories = ['truck_expense', 'trip_expense', 'office_expense'];
  final List<String> _tabLabels = ['Truck Expense', 'Trip Expense', 'Office Expense'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadExpenses();
    }
  }

  Future<void> _loadExpenses() async {
    print('DEBUG _loadExpenses: Starting to load expenses for category=${_categories[_tabController.index]}');
    setState(() => _isLoading = true);

    try {
      // Get start and end date of selected month
      final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      print('DEBUG _loadExpenses: Calling API for date range ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');

      // Load expenses for current tab
      final expenses = await ApiService.getMyExpenses(
        category: _categories[_tabController.index],
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
      );

      print('DEBUG _loadExpenses: Received ${expenses?.length ?? 0} expenses for current category');

      // Load ALL expenses for the month (for grand total calculation)
      final allExpenses = await ApiService.getMyExpenses(
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
      );

      setState(() {
        _expenses = expenses;
        _filteredExpenses = expenses;
        _allExpensesForMonth = allExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  void _filterExpenses(String query) {
    if (query.isEmpty) {
      setState(() => _filteredExpenses = _expenses);
      return;
    }

    setState(() {
      _filteredExpenses = _expenses.where((expense) {
        final type = expense['expenseType'].toString().toLowerCase();
        final truck = expense['truckNumber']?.toString().toLowerCase() ?? '';
        final amount = expense['amount'].toString();
        final searchLower = query.toLowerCase();

        return type.contains(searchLower) ||
            truck.contains(searchLower) ||
            amount.contains(searchLower);
      }).toList();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _loadExpenses();
  }

  double _calculateTotal() {
    return _filteredExpenses.fold(0.0, (sum, expense) {
      return sum + double.parse(expense['amount'].toString());
    });
  }

  double _calculateGrandTotal() {
    // Calculate total of ALL expenses (truck + trip + office)
    return _allExpensesForMonth.fold(0.0, (sum, expense) {
      return sum + double.parse(expense['amount'].toString());
    });
  }

  IconData _getExpenseIcon(String category) {
    switch (category) {
      case 'truck_expense':
        return Icons.local_shipping;
      case 'trip_expense':
        return Icons.route;
      case 'office_expense':
        return Icons.business;
      default:
        return Icons.receipt;
    }
  }

  String _getAddButtonLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Truck Expense';
      case 1:
        return 'Add Trip Expense';
      case 2:
        return 'Add Office Expense';
      default:
        return 'Add Expense';
    }
  }

  void _showAddExpenseForm() async {
    print('DEBUG: Navigating to AddMyExpenseScreen');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMyExpenseScreen(
          category: _categories[_tabController.index],
        ),
      ),
    );

    print('DEBUG: Returned from AddMyExpenseScreen, result=$result');
    // Reload expenses if expense was added
    if (result == true) {
      print('DEBUG: Reloading expenses after add');
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: const Text('Expenses'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with month navigation and total
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                // Month navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: Colors.black),
                    ),
                    Text(
                      DateFormat('MMM-yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Grand Total amount (all categories)
                Text(
                  '₹${_calculateGrandTotal().toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Expenses (All Categories)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                // View Report button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpensesReportScreen(
                            selectedMonth: _selectedMonth,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB3D4FF),
                      foregroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text(
                      'View Report',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2196F3),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2196F3),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Truck Expense'),
                Tab(text: 'Trip Expense'),
                Tab(text: 'Office Expense'),
              ],
            ),
          ),

          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterExpenses,
              decoration: InputDecoration(
                hintText: 'Search for ${_tabLabels[_tabController.index]}s',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Expense list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getExpenseIcon(_categories[_tabController.index]),
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadExpenses,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _filteredExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = _filteredExpenses[index];
                            return _buildExpenseItem(expense);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseForm,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: Text(
          _getAddButtonLabel(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> expense) {
    final category = expense['category'] ?? '';
    final expenseType = expense['expenseType'] ?? '';
    final date = expense['date'] ?? '';
    final amount = expense['amount']?.toString() ?? '0';
    final truckNumber = expense['truckNumber'] ?? '';
    final tripId = expense['tripId']?.toString() ?? '';

    String subtitle = '';
    if (category == 'truck_expense' && truckNumber.isNotEmpty) {
      subtitle = truckNumber;
    } else if (category == 'trip_expense' && tripId.isNotEmpty) {
      subtitle = 'Trip #$tripId';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showExpenseOptions(expense),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
            child: Icon(
              _getExpenseIcon(category),
              color: const Color(0xFF2196F3),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  expenseType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseOptions(Map<String, dynamic> expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Expense Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showExpenseDetails(expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Expense'),
              onTap: () {
                Navigator.pop(context);
                _editExpense(expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Expense'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteExpense(expense);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense['expenseType'] ?? 'Expense Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Category', expense['category']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'N/A'),
              _buildDetailRow('Amount', '₹${expense['amount']}'),
              _buildDetailRow('Date', expense['date'] ?? 'N/A'),
              _buildDetailRow('Payment Mode', expense['paymentMode'] ?? 'Cash'),
              if (expense['truckNumber'] != null)
                _buildDetailRow('Truck Number', expense['truckNumber']),
              if (expense['tripId'] != null)
                _buildDetailRow('Trip ID', expense['tripId'].toString()),
              if (expense['note'] != null && expense['note'].toString().isNotEmpty)
                _buildDetailRow('Note', expense['note']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMyExpenseScreen(
          category: expense['category'],
          expense: expense,
        ),
      ),
    );

    if (result == true) {
      _loadExpenses();
    }
  }

  void _confirmDeleteExpense(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteExpense(expense['id']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      final success = await ApiService.deleteMyExpense(expenseId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
          _loadExpenses();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete expense')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense: $e')),
        );
      }
    }
  }
}

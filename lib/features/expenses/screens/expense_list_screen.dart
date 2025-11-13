import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;
  final String? expenseType;

  const ExpenseListScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
    this.expenseType,
  });

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  List<dynamic> _expenses = [];
  bool _isLoading = true;
  bool _hasChanges = false; // Track if any changes were made

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    print('DEBUG _loadExpenses (expense_list): Loading expenses for truck ${widget.truckId}, expenseType=${widget.expenseType}');
    setState(() {
      _isLoading = true;
    });

    final expenses = await ApiService.getExpenses(widget.truckId);
    print('DEBUG _loadExpenses (expense_list): Received ${expenses.length} expenses from API');
    setState(() {
      // If expenseType is null, show all expenses for the truck
      if (widget.expenseType == null) {
        _expenses = expenses;
        print('DEBUG _loadExpenses (expense_list): Showing all ${_expenses.length} expenses');
      } else {
        _expenses = expenses.where((exp) => exp['expenseType'] == widget.expenseType).toList();
        print('DEBUG _loadExpenses (expense_list): Filtered to ${_expenses.length} expenses for type ${widget.expenseType}');
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.appBarTextColor),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.expenseType ?? 'All Expenses',
              style: TextStyle(
                color: AppColors.appBarTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.truckNumber,
              style: TextStyle(
                color: AppColors.appBarTextColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        widget.expenseType != null
                            ? 'No ${widget.expenseType} expenses found'
                            : 'No expenses found',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () => _showExpenseOptions(expense),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.receipt, color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expense['expenseType'] ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      expense['date'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (expense['pumpName'] != null)
                                  Text(
                                    expense['pumpName'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (expense['category'] != null)
                                  Text(
                                    expense['category'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                if (expense['driverName'] != null)
                                  Text(
                                    expense['driverName'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    expense['paymentMode'] ?? 'Cash',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${expense['amount']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ],
                        ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_expense_fab',
        onPressed: () async {
          if (widget.expenseType != null) {
            // Show bottom sheet for specific expense type
            print('DEBUG: Showing expense form bottom sheet');
            await showExpenseFormBottomSheet(
              context,
              truckId: widget.truckId,
              truckNumber: widget.truckNumber,
              expenseType: widget.expenseType!,
            );
            print('DEBUG: Bottom sheet closed, reloading expenses');
            setState(() {
              _hasChanges = true; // Mark that changes were made
            });
            _loadExpenses();
          } else {
            // Show expense type selector screen
            print('DEBUG: Navigating to AddExpenseScreen');
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddExpenseScreen(
                  truckId: widget.truckId,
                  truckNumber: widget.truckNumber,
                ),
              ),
            );
            print('DEBUG: Returned from AddExpenseScreen, result=$result');
            if (result == true) {
              print('DEBUG: Reloading expenses after add');
              setState(() {
                _hasChanges = true; // Mark that changes were made
              });
              _loadExpenses();
            }
          }
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              _buildDetailRow('Amount', '₹${expense['amount']}'),
              _buildDetailRow('Date', expense['date'] ?? 'N/A'),
              _buildDetailRow('Payment Mode', expense['paymentMode'] ?? 'Cash'),
              if (expense['pumpName'] != null)
                _buildDetailRow('Pump Name', expense['pumpName']),
              if (expense['category'] != null)
                _buildDetailRow('Category', expense['category']),
              if (expense['driverName'] != null)
                _buildDetailRow('Driver', expense['driverName']),
              if (expense['notes'] != null)
                _buildDetailRow('Notes', expense['notes']),
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

  void _editExpense(Map<String, dynamic> expense) async {
    if (widget.expenseType != null) {
      // Edit via bottom sheet
      await showExpenseFormBottomSheet(
        context,
        truckId: widget.truckId,
        truckNumber: widget.truckNumber,
        expenseType: widget.expenseType!,
        expense: expense,
      );
      setState(() {
        _hasChanges = true; // Mark that changes were made
      });
      _loadExpenses();
    } else {
      // Navigate to edit screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(
            truckId: widget.truckId,
            truckNumber: widget.truckNumber,
            expense: expense,
          ),
        ),
      );
      if (result == true) {
        setState(() {
          _hasChanges = true; // Mark that changes were made
        });
        _loadExpenses();
      }
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      final success = await ApiService.deleteExpense(expenseId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
          setState(() {
            _hasChanges = true; // Mark that changes were made
          });
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

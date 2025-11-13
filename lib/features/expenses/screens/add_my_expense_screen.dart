import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';

class AddMyExpenseScreen extends StatefulWidget {
  final String category; // 'truck_expense', 'trip_expense', 'office_expense'
  final Map<String, dynamic>? expense;

  const AddMyExpenseScreen({
    super.key,
    required this.category,
    this.expense,
  });

  @override
  State<AddMyExpenseScreen> createState() => _AddMyExpenseScreenState();
}

class _AddMyExpenseScreenState extends State<AddMyExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedExpenseType;
  String? _selectedTruckNumber;
  int? _selectedTripId;
  String _selectedPaymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<dynamic> _trucks = [];
  List<dynamic> _trips = [];
  bool _isLoading = false;

  // Expense types based on category
  List<String> _getExpenseTypes() {
    switch (widget.category) {
      case 'truck_expense':
        return ['Fuel Expense', 'Servicing', 'Maintenance', 'Tyre', 'Insurance', 'Other'];
      case 'trip_expense':
        return ['Toll', 'Loading', 'Unloading', 'Detention', 'Other'];
      case 'office_expense':
        return ['Salary', 'Rent', 'Electricity', 'Internet', 'Stationery', 'Other'];
      default:
        return ['Other'];
    }
  }

  String _getScreenTitle() {
    final isEditing = widget.expense != null;
    switch (widget.category) {
      case 'truck_expense':
        return isEditing ? 'Edit Truck Expense' : 'Add Truck Expense';
      case 'trip_expense':
        return isEditing ? 'Edit Trip Expense' : 'Add Trip Expense';
      case 'office_expense':
        return isEditing ? 'Edit Office Expense' : 'Add Office Expense';
      default:
        return isEditing ? 'Edit Expense' : 'Add Expense';
    }
  }

  @override
  void initState() {
    super.initState();

    // If editing, populate fields with existing data
    if (widget.expense != null) {
      _amountController.text = widget.expense!['amount']?.toString() ?? '';
      _noteController.text = widget.expense!['note']?.toString() ?? '';

      // Validate expense type exists in dropdown list before setting
      String? expenseTypeFromDb = widget.expense!['expenseType'];
      List<String> validTypes = _getExpenseTypes();
      if (expenseTypeFromDb != null && validTypes.contains(expenseTypeFromDb)) {
        _selectedExpenseType = expenseTypeFromDb;
      } else {
        // Default to 'Other' if the value doesn't exist in the dropdown list
        _selectedExpenseType = validTypes.contains('Other') ? 'Other' : null;
        print('Warning: Expense type "$expenseTypeFromDb" not found in valid types for ${widget.category}. Defaulting to "Other".');
      }

      _selectedPaymentMode = widget.expense!['paymentMode']?.toString() ?? 'Cash';
      _selectedTruckNumber = widget.expense!['truckNumber'];
      _selectedTripId = widget.expense!['tripId'];

      // Parse date
      if (widget.expense!['date'] != null) {
        try {
          _selectedDate = DateTime.parse(widget.expense!['date']);
        } catch (e) {
          _selectedDate = DateTime.now();
        }
      }
    }

    if (widget.category == 'truck_expense') {
      _loadTrucks();
    } else if (widget.category == 'trip_expense') {
      _loadTrips();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTrucks() async {
    try {
      final trucks = await ApiService.getTrucks();
      setState(() {
        _trucks = trucks;
      });
    } catch (e) {
      print('Error loading trucks: $e');
    }
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await ApiService.getAllTrips();
      setState(() {
        _trips = trips;
      });
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate category-specific fields
    if (widget.category == 'truck_expense' && _selectedTruckNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a truck')),
      );
      return;
    }

    if (widget.category == 'trip_expense' && _selectedTripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trip')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic>? result;

      if (widget.expense != null) {
        // Update existing expense
        Map<String, dynamic> expenseData = {
          'expenseType': _selectedExpenseType!,
          'amount': double.parse(_amountController.text),
          'paymentMode': _selectedPaymentMode,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        };

        if (_selectedTruckNumber != null) {
          expenseData['truckNumber'] = _selectedTruckNumber;
        }
        if (_selectedTripId != null) {
          expenseData['tripId'] = _selectedTripId;
        }
        if (_noteController.text.isNotEmpty) {
          expenseData['note'] = _noteController.text;
        }

        result = await ApiService.updateMyExpense(widget.expense!['id'], expenseData);
      } else {
        // Add new expense
        result = await ApiService.addMyExpense(
          category: widget.category,
          expenseType: _selectedExpenseType!,
          amount: _amountController.text,
          paymentMode: _selectedPaymentMode,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          truckNumber: _selectedTruckNumber,
          tripId: _selectedTripId,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
      }

      setState(() => _isLoading = false);

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expense != null ? 'Expense updated successfully' : 'Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.expense != null ? 'Failed to update expense' : 'Failed to add expense'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: Text(_getScreenTitle()),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Expense Type dropdown
            DropdownButtonFormField<String>(
              value: _selectedExpenseType,
              decoration: InputDecoration(
                labelText: 'Expense Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _getExpenseTypes().map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedExpenseType = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select expense type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Truck Number dropdown (for truck expenses)
            if (widget.category == 'truck_expense') ...[
              DropdownButtonFormField<String>(
                value: _selectedTruckNumber,
                decoration: InputDecoration(
                  labelText: 'Truck No.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _trucks.map<DropdownMenuItem<String>>((truck) {
                  return DropdownMenuItem<String>(
                    value: truck['number'] as String,
                    child: Text(truck['number'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTruckNumber = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Trip dropdown (for trip expenses)
            if (widget.category == 'trip_expense') ...[
              DropdownButtonFormField<int>(
                value: _selectedTripId,
                decoration: InputDecoration(
                  labelText: 'Trip',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _trips.map<DropdownMenuItem<int>>((trip) {
                  return DropdownMenuItem<int>(
                    value: trip['id'] as int,
                    child: Text('${trip['truckNumber']} - ${trip['origin']} to ${trip['destination']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTripId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Expense Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Expense Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Payment Mode
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Mode',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Cash'),
                        selected: _selectedPaymentMode == 'Cash',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPaymentMode = 'Cash');
                          }
                        },
                        selectedColor: const Color(0xFFE3F2FD),
                        side: BorderSide(
                          color: _selectedPaymentMode == 'Cash' ? const Color(0xFF2196F3) : Colors.grey[300]!,
                          width: 2,
                        ),
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(
                          color: _selectedPaymentMode == 'Cash' ? const Color(0xFF2196F3) : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Credit'),
                        selected: _selectedPaymentMode == 'Credit',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPaymentMode = 'Credit');
                          }
                        },
                        selectedColor: const Color(0xFFE3F2FD),
                        side: BorderSide(
                          color: _selectedPaymentMode == 'Credit' ? const Color(0xFF2196F3) : Colors.grey[300]!,
                          width: 2,
                        ),
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(
                          color: _selectedPaymentMode == 'Credit' ? const Color(0xFF2196F3) : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Online'),
                        selected: _selectedPaymentMode == 'Online',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPaymentMode = 'Online');
                          }
                        },
                        selectedColor: const Color(0xFFE3F2FD),
                        side: BorderSide(
                          color: _selectedPaymentMode == 'Online' ? const Color(0xFF2196F3) : Colors.grey[300]!,
                          width: 2,
                        ),
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(
                          color: _selectedPaymentMode == 'Online' ? const Color(0xFF2196F3) : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expense Date
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Expense Date',
                    hintText: DateFormat('dd MMM yyyy').format(_selectedDate),
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  controller: TextEditingController(
                    text: DateFormat('dd MMM yyyy').format(_selectedDate),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Note',
                hintText: 'Add any additional notes',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.subject),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

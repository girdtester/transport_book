import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import 'package:transport_book_app/utils/custom_dropdown.dart';
import 'package:transport_book_app/utils/custom_textfield.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';

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
  int? _selectedShopId;
  String _selectedPaymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<dynamic> _trucks = [];
  List<dynamic> _trips = [];
  List<dynamic> _shops = [];
  List<Map<String, dynamic>> _expenseTypes = [];
  bool _isLoading = false;
  bool _isLoadingExpenseTypes = true;

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
    _loadExpenseTypes();

    // If editing, populate fields with existing data
    if (widget.expense != null) {
      _amountController.text = widget.expense!['amount']?.toString() ?? '';
      _noteController.text = widget.expense!['note']?.toString() ?? '';
      _selectedExpenseType = widget.expense!['expenseType'];
      _selectedPaymentMode = widget.expense!['paymentMode']?.toString() ?? 'Cash';
      _selectedTruckNumber = widget.expense!['truckNumber'];
      _selectedTripId = widget.expense!['tripId'];

      // Parse shopId - handle both int and string
      final shopIdValue = widget.expense!['shopId'];
      if (shopIdValue != null) {
        _selectedShopId = shopIdValue is int ? shopIdValue : int.tryParse(shopIdValue.toString());
      }

      print('DEBUG Edit: paymentMode=$_selectedPaymentMode, shopId=$_selectedShopId');

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
      _loadShops(); // Always load shops for truck expenses
    } else if (widget.category == 'trip_expense') {
      _loadTrips();
    }
  }

  Future<void> _loadShops() async {
    try {
      final shops = await ApiService.getShops();
      if (mounted) {
        setState(() {
          _shops = shops;
        });
        print('DEBUG: Loaded ${shops.length} shops, selectedShopId=$_selectedShopId');
      }
    } catch (e) {
      print('Error loading shops: $e');
    }
  }

  Future<void> _loadExpenseTypes() async {
    try {
      final types = await ApiService.getExpenseTypes();
      if (mounted) {
        setState(() {
          _expenseTypes = types;
          _isLoadingExpenseTypes = false;
        });
      }
    } catch (e) {
      print('Error loading expense types: $e');
      if (mounted) {
        setState(() => _isLoadingExpenseTypes = false);
      }
    }
  }

  void _showExpenseTypePickerDialog() {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredTypes = _expenseTypes.where((type) {
            final name = type['name']?.toString().toLowerCase() ?? '';
            return name.contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: const Text('Select Expense Type'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search expense type...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() => searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Add new expense type option
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryGreen,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                    title: const Text('Add New Expense Type'),
                    onTap: () => _showAddExpenseTypeDialog(setDialogState),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredTypes.length,
                      itemBuilder: (context, index) {
                        final type = filteredTypes[index];
                        return ListTile(
                          title: Text(type['name'] ?? ''),
                          onTap: () {
                            setState(() => _selectedExpenseType = type['name']);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddExpenseTypeDialog(StateSetter setDialogState) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Expense Type'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter expense type name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              final result = await ApiService.addExpenseType(controller.text.trim());
              if (result != null && mounted) {
                // Extract expense type from response
                final expenseType = result['expenseType'] ?? result;
                // Add to local list and select it
                setState(() {
                  _expenseTypes.add(expenseType);
                  _selectedExpenseType = expenseType['name'];
                });
                setDialogState(() {}); // Refresh dialog list
                Navigator.pop(context); // Close add dialog
                Navigator.pop(context); // Close picker dialog
                ToastHelper.showSnackBarToast(context,
                  const SnackBar(content: Text('Expense type added successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

    // Validate expense type is selected
    if (_selectedExpenseType == null) {
      ToastHelper.showSnackBarToast(context,
        const SnackBar(content: Text('Please select expense type')),
      );
      return;
    }

    // Validate category-specific fields
    if (widget.category == 'truck_expense' && _selectedTruckNumber == null) {
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Please select a truck')),
      );
      return;
    }

    print('widget.category ${widget.category} _selectedTripId ${_selectedTripId}');
    if (widget.category == 'trip_expense' && _selectedTripId == null) {
      ToastHelper.showSnackBarToast(context, 
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
        // Include shopId for Credit payment mode
        if (_selectedPaymentMode == 'Credit' && _selectedShopId != null) {
          expenseData['shopId'] = _selectedShopId;
        }
        if (_noteController.text.isNotEmpty) {
          expenseData['note'] = _noteController.text;
        }

        result = await ApiService.updateMyExpense(widget.expense!['id'], expenseData);
      } else {
        // Add new expense
        final shopIdToSend = _selectedPaymentMode == 'Credit' ? _selectedShopId : null;
        print('DEBUG: Adding expense - paymentMode=$_selectedPaymentMode, shopId=$shopIdToSend');

        result = await ApiService.addMyExpense(
          category: widget.category,
          expenseType: _selectedExpenseType!,
          amount: _amountController.text,
          paymentMode: _selectedPaymentMode,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          truckNumber: _selectedTruckNumber,
          tripId: _selectedTripId,
          shopId: shopIdToSend,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
      }

      setState(() => _isLoading = false);

      if (result != null && mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(
            content: Text(widget.expense != null ? 'Expense updated successfully' : 'Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        if (mounted) {
          ToastHelper.showSnackBarToast(context, 
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
        ToastHelper.showSnackBarToast(context, 
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
      appBar: CustomAppBar(
        title: _getScreenTitle(), onBack: () {
        Navigator.pop(context);
      },
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ---------------- EXPENSE TYPE ----------------
            const Text(
              "Expense Type",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isLoadingExpenseTypes ? null : _showExpenseTypePickerDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isLoadingExpenseTypes
                          ? 'Loading...'
                          : (_selectedExpenseType ?? 'Select Expense Type'),
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedExpenseType != null ? Colors.black : Colors.grey,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- TRUCK NUMBER (IF TRUCK EXPENSE) ----------------
            if (widget.category == 'truck_expense') ...[
              CustomDropdown(
                label: "Truck No.",
                value: _selectedTruckNumber,
                items: _trucks.map<String>((t) => t['number']).toList(),
                onChanged: (value) {
                  setState(() => _selectedTruckNumber = value);
                },
              ),
              const SizedBox(height: 16),
            ],

            // ---------------- TRIP LIST (IF TRIP EXPENSE) ----------------
            if (widget.category == 'trip_expense') ...[
              CustomDropdown(
                label: "Trip",
                value: _selectedTripId?.toString(),
                items: _trips
                    .map<String>((trip) =>
                "${trip['id']} | ${trip['truckNumber']} - ${trip['origin']} to ${trip['destination']}")
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTripId = int.tryParse(value ?? "");
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // ---------------- AMOUNT ----------------
            CustomTextField(
              label: "Expense Amount",
              controller: _amountController,
              keyboard: TextInputType.number,
              hint: "Enter amount",
              suffix: const Icon(Icons.currency_rupee, size: 18),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: 16),

            // ---------------- PAYMENT MODE ----------------
            const Text(
              "Payment Mode",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildPaymentChip("Cash"),
                const SizedBox(width: 10),
                _buildPaymentChip("Credit"),
                const SizedBox(width: 10),
                _buildPaymentChip("Online"),
              ],
            ),
            const SizedBox(height: 16),

            // ---------------- SHOP DROPDOWN (IF CREDIT PAYMENT FOR TRUCK EXPENSE) ----------------
            if (widget.category == 'truck_expense' && _selectedPaymentMode == 'Credit') ...[
              const Text(
                "Select Shop",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _shops.any((s) => s['id'] == _selectedShopId) ? _selectedShopId : null,
                    hint: const Text('Select Shop'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No Shop'),
                      ),
                      ..._shops.map<DropdownMenuItem<int?>>((shop) {
                        final shopId = shop['id'] is int ? shop['id'] : int.tryParse(shop['id'].toString());
                        return DropdownMenuItem<int?>(
                          value: shopId,
                          child: Text(shop['name'] ?? 'Unknown Shop'),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      print('DEBUG: Shop selected - id=$value');
                      setState(() => _selectedShopId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---------------- DATE PICKER ----------------
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: CustomTextField(
                  label: "Expense Date",
                  controller: TextEditingController(
                    text: DateFormat('dd MMM yyyy').format(_selectedDate),
                  ),
                  readOnly: true,
                  suffix: const Icon(Icons.calendar_today),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- NOTE ----------------
            CustomTextField(
              label: "Note",
              hint: "Add any additional notes",
              controller: _noteController,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // ---------------- CONFIRM BUTTON ----------------
            CustomButton(
              text: _isLoading ? "Please wait..." : "Confirm",
              onPressed: _isLoading ? () {} : _submitExpense,
            ),
          ],
        ),
      ));




  }

  Widget _buildPaymentChip(String mode) {
    bool selected = _selectedPaymentMode == mode;

    return SizedBox(
      height: 48, // better height for a clean pill look
      child: ChoiceChip(
        label: Text(
          mode,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.info : Colors.black87,
          ),
        ),

        selected: selected,
        selectedColor: const Color(0xFFE3F2FD),
        backgroundColor: Colors.grey[200],

        // ðŸ”¥ MAIN CHANGE â†’ Circular pill shape (radius 14)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.info : Colors.grey!,
            width: 1,
          ),
        ),

        // Tap Handling
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedPaymentMode = mode;
              // Clear shop selection when payment mode changes from Credit
              if (mode != 'Credit') {
                _selectedShopId = null;
              }
            });
          }
        },
      ),
    );
  }

}


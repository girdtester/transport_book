import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';
import '../../../utils/custom_textfield.dart';

class AddExpenseScreen extends StatelessWidget {
  final int truckId;
  final String truckNumber;
  final Map<String, dynamic>? expense;

  const AddExpenseScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
    this.expense,
  });

  @override
  Widget build(BuildContext context) {
    // If editing an expense, directly open the bottom sheet and return empty container
    if (expense != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showExpenseFormBottomSheet(
          context,
          truckId: truckId,
          truckNumber: truckNumber,
          expenseType: expense!['expenseType'],
          expense: expense,
        ).then((_) => Navigator.pop(context, true));
      });
      return const Scaffold(
        body: Center(child: AppLoader()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Expense',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              truckNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Expense Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Expense Type Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildExpenseCard(
                    context,
                    'Diesel',
                    Icons.local_gas_station,
                    Colors.orange.shade100,
                    Colors.orange,
                  ),
                  _buildExpenseCard(
                    context,
                    'Driver Payment',
                    Icons.person,
                    AppColors.info.withOpacity(0.2),
                    AppColors.info,
                  ),
                  _buildExpenseCard(
                    context,
                    'Toll',
                    Icons.toll,
                    AppColors.primaryGreen.withOpacity(0.15),
                    AppColors.primaryGreen,
                  ),
                  _buildExpenseCard(
                    context,
                    'Fastag Recharge',
                    Icons.credit_card,
                    Colors.purple.shade100,
                    Colors.purple,
                  ),
                  _buildExpenseCard(
                    context,
                    'Maintenance',
                    Icons.build,
                    Colors.red.shade100,
                    Colors.red,
                  ),
                  _buildExpenseCard(
                    context,
                    'Other Expense',
                    Icons.receipt,
                    Colors.teal.shade100,
                    Colors.teal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return InkWell(
      onTap: () {
        // Close the current screen
        Navigator.pop(context);
        // Show expense form as bottom sheet
        showExpenseFormBottomSheet(
          context,
          truckId: truckId,
          truckNumber: truckNumber,
          expenseType: title,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show expense form as bottom sheet
Future<dynamic> showExpenseFormBottomSheet(
  BuildContext context, {
  required int truckId,
  required String truckNumber,
  required String expenseType,
  Map<String, dynamic>? expense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ExpenseDetailScreen(
      truckId: truckId,
      truckNumber: truckNumber,
      expenseType: expenseType,
      expense: expense,
    ),
  );
}

class ExpenseDetailScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;
  final String expenseType;
  final Map<String, dynamic>? expense;

  const ExpenseDetailScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
    required this.expenseType,
    this.expense,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _pumpNameController = TextEditingController();
  final TextEditingController _receiptNoController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _tripNoController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();

    // If editing, populate fields with existing data
    if (widget.expense != null) {
      _amountController.text = widget.expense!['amount']?.toString() ?? '';
      _quantityController.text = widget.expense!['quantity']?.toString() ?? '';
      _priceController.text = widget.expense!['price']?.toString() ?? '';
      _pumpNameController.text = widget.expense!['pumpName']?.toString() ?? '';
      _receiptNoController.text = widget.expense!['receiptNo']?.toString() ?? '';
      _remarksController.text = widget.expense!['remarks']?.toString() ?? '';
      _categoryController.text = widget.expense!['category']?.toString() ?? '';
      _driverNameController.text = widget.expense!['driverName']?.toString() ?? '';
      _paymentMode = widget.expense!['paymentMode']?.toString() ?? 'Cash';

      // Parse date
      if (widget.expense!['date'] != null) {
        try {
          _selectedDate = DateTime.parse(widget.expense!['date']);
        } catch (e) {
          _selectedDate = DateTime.now();
        }
      }
    }

    // Add listeners to required fields
    _amountController.addListener(_checkFormValidity);
    _quantityController.addListener(_checkFormValidity);
    _priceController.addListener(_checkFormValidity);
    _driverNameController.addListener(_checkFormValidity);
    _categoryController.addListener(_checkFormValidity);

    // Check form validity immediately after setup
    // This is needed especially for edit mode where fields are pre-populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFormValidity();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _pumpNameController.dispose();
    _receiptNoController.dispose();
    _remarksController.dispose();
    _tripNoController.dispose();
    _driverNameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _checkFormValidity() {
    bool isValid = false;

    if (widget.expenseType == 'Diesel') {
      isValid = _amountController.text.isNotEmpty &&
                _quantityController.text.isNotEmpty &&
                _priceController.text.isNotEmpty;
    } else if (widget.expenseType == 'Driver Payment') {
      isValid = _amountController.text.isNotEmpty &&
                _driverNameController.text.isNotEmpty;
    } else if (widget.expenseType == 'Maintenance') {
      isValid = _amountController.text.isNotEmpty &&
                _categoryController.text.isNotEmpty;
    } else if (widget.expenseType == 'Other Expense') {
      isValid = _amountController.text.isNotEmpty &&
                _categoryController.text.isNotEmpty;
    } else {
      // For Toll, Fastag Recharge
      isValid = _amountController.text.isNotEmpty;
    }

    print('Form validity check: isValid=$isValid, expenseType=${widget.expenseType}, editing=${widget.expense != null}');
    print('  amount=${_amountController.text}, quantity=${_quantityController.text}, price=${_priceController.text}');

    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expense != null ? 'Edit ${widget.expenseType}' : 'Add ${widget.expenseType} Expense',
                    style: const TextStyle(
                      fontSize: 18,
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

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.expenseType == 'Diesel') ..._buildDieselFields(),
                      if (widget.expenseType == 'Driver Payment') ..._buildDriverPaymentFields(),
                      if (widget.expenseType == 'Toll') ..._buildTollFields(),
                      if (widget.expenseType == 'Fastag Recharge') ..._buildFastagFields(),
                      if (widget.expenseType == 'Maintenance') ..._buildMaintenanceFields(),
                      if (widget.expenseType == 'Other Expense') ..._buildOtherExpenseFields(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // Save Button (Fixed at bottom)
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
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_isFormValid) ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isLoading || !_isFormValid) ? Colors.grey.shade400 : AppColors.primaryGreen,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: AppLoader(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.expense != null ? 'Update' : 'Confirm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDieselFields() {
    return [
      CustomTextField(
        label: 'Quantity (Litres)',
        controller: _quantityController,
        hint: 'Enter quantity',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Price per Litre',
        controller: _priceController,
        hint: '₹ Enter price',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Total Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Pump Name',
        controller: _pumpNameController,
        hint: 'Enter pump name',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Receipt No.',
        controller: _receiptNoController,
        hint: 'Enter receipt number',
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Remarks',
        controller: _remarksController,
        hint: 'Enter remarks',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildDriverPaymentFields() {
    return [
      CustomTextField(
        label: 'Driver Name',
        controller: _driverNameController,
        hint: 'Select driver',
        readOnly: true,
        onTap: _showDriverPicker,
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Trip No.',
        controller: _tripNoController,
        hint: 'Enter trip number',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Remarks',
        controller: _remarksController,
        hint: 'Enter remarks',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildTollFields() {
    return [
      CustomTextField(
        label: 'Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Toll Plaza Name',
        controller: _pumpNameController,
        hint: 'Enter toll plaza name',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Receipt No.',
        controller: _receiptNoController,
        hint: 'Enter receipt number',
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Remarks',
        controller: _remarksController,
        hint: 'Enter remarks',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildFastagFields() {
    return [
      CustomTextField(
        label: 'Recharge Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Transaction ID',
        controller: _receiptNoController,
        hint: 'Enter transaction ID',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Remarks',
        controller: _remarksController,
        hint: 'Enter remarks',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildMaintenanceFields() {
    return [
      CustomTextField(
        label: 'Category',
        controller: _categoryController,
        hint: 'Select category',
        readOnly: true,
        onTap: () => _showCategoryPicker(),
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Service Provider',
        controller: _pumpNameController,
        hint: 'Enter service provider',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Bill No.',
        controller: _receiptNoController,
        hint: 'Enter bill number',
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
            });
          }
        },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Description',
        controller: _remarksController,
        hint: 'Enter description',
        maxLines: 3,
      ),
    ];
  }

  List<Widget> _buildOtherExpenseFields() {
    return [
      CustomTextField(
        label: 'Expense Name',
        controller: _categoryController,
        hint: 'Enter expense name',
      ),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Amount',
        controller: _amountController,
        hint: '₹ Enter amount',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        ),
      const SizedBox(height: 16),
      GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
              });
            }
          },
        child: AbsorbPointer(
          child: CustomTextField(
            label: 'Date',
            controller: TextEditingController(
              text: DateFormat('dd MMM yyyy').format(_selectedDate),
            ),
            suffix: const Icon(Icons.calendar_today),
          ),
        ),
            ),
      const SizedBox(height: 16),
      _buildPaymentModeField(),
      const SizedBox(height: 16),
      CustomTextField(
        label: 'Description',
        controller: _remarksController,
        hint: 'Enter description',
        maxLines: 3,
        ),
    ];
  }



  Widget _buildPaymentModeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildPaymentModeButton('Cash'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentModeButton('Credit'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentModeButton('Paid by Driver'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentModeButton('Online'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentModeButton(String mode) {
    final isSelected = _paymentMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _paymentMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          mode,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    final categories = [
      'Engine Repair',
      'Tire Change',
      'Oil Change',
      'Battery Replacement',
      'Brake Service',
      'AC Repair',
      'Body Work',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...categories.map((category) => ListTile(
              title: Text(category),
              onTap: () {
                setState(() {
                  _categoryController.text = category;
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showDriverPicker() async {
    final drivers = await ApiService.getDrivers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Select Driver',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.add_circle, color: AppColors.primaryGreen),
              title: const Text('Add New Driver'),
              onTap: () {
                Navigator.pop(context);
                _showAddDriverDialog();
              },
            ),
            const Divider(),
            Expanded(
              child: drivers.isEmpty
                  ? const Center(
                      child: Text(
                        'No drivers found. Add a new driver.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: drivers.length,
                      itemBuilder: (context, index) {
                        final driver = drivers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryGreen,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(driver['name']?.toString() ?? ''),
                          subtitle: Text(driver['phone']?.toString() ?? ''),
                          onTap: () {
                            setState(() {
                              _driverNameController.text = driver['name']?.toString() ?? '';
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  hintText: 'Enter driver name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                        setDialogState(() => isLoading = true);

                        final result = await ApiService.addDriver(
                          name: nameController.text,
                          phone: phoneController.text,
                        );

                        if (result != null && mounted) {
                          setState(() {
                            _driverNameController.text = nameController.text;
                          });
                          Navigator.pop(context);
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(
                              content: Text('Driver added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (mounted) {
                          setDialogState(() => isLoading = false);
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(
                              content: Text('Failed to add driver'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: AppLoader(strokeWidth: 2),
                    )
                  : Text(widget.expense != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    print('_saveExpense called, editing=${widget.expense != null}');

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Build expense data
      Map<String, dynamic> expenseData = {
        'truckId': widget.truckId,
        'expenseType': widget.expenseType,
        'amount': _amountController.text,
        'date': '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'paymentMode': _paymentMode,
      };

      // Add type-specific fields
      if (widget.expenseType == 'Diesel') {
        expenseData['quantity'] = _quantityController.text;
        expenseData['price'] = _priceController.text;
        expenseData['pumpName'] = _pumpNameController.text;
        expenseData['receiptNo'] = _receiptNoController.text;
        expenseData['remarks'] = _remarksController.text;
      } else if (widget.expenseType == 'Driver Payment') {
        expenseData['driverName'] = _driverNameController.text;
        expenseData['tripNo'] = _tripNoController.text;
        expenseData['remarks'] = _remarksController.text;
      } else if (widget.expenseType == 'Toll' || widget.expenseType == 'Fastag Recharge') {
        expenseData['pumpName'] = _pumpNameController.text;
        expenseData['receiptNo'] = _receiptNoController.text;
        expenseData['remarks'] = _remarksController.text;
      } else if (widget.expenseType == 'Maintenance') {
        expenseData['category'] = _categoryController.text;
        expenseData['serviceProvider'] = _pumpNameController.text;
        expenseData['receiptNo'] = _receiptNoController.text;
        expenseData['description'] = _remarksController.text;
      } else if (widget.expenseType == 'Other Expense') {
        expenseData['category'] = _categoryController.text;
        expenseData['description'] = _remarksController.text;
      }

      // Call update or create API
      final Map<String, dynamic>? result;
      if (widget.expense != null) {
        // Update existing expense
        print('Calling updateExpense with id=${widget.expense!['id']}');
        result = await ApiService.updateExpense(widget.expense!['id'], expenseData);
        print('updateExpense result: $result');
      } else {
        // Create new expense
        print('Calling addExpense');
        result = await ApiService.addExpense(expenseData);
        print('addExpense result: $result');
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (result != null) {
          print('Save successful, popping with result=true');
          ToastHelper.showSnackBarToast(context, 
            SnackBar(content: Text(widget.expense != null ? 'Expense updated successfully' : 'Expense saved successfully')),
          );
          Navigator.pop(context, true);
        } else {
          print('Save failed, result is null');
          ToastHelper.showSnackBarToast(context, 
            SnackBar(content: Text(widget.expense != null ? 'Failed to update expense' : 'Failed to save expense')),
          );
        }
      }
    }
  }
}



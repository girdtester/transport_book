import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:intl/intl.dart';
import '../../trucks/screens/my_trucks_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';
import '../../../utils/custom_textfield.dart';

class AddLoadScreen extends StatefulWidget {
  final int parentTripId;
  final int truckId;
  final String truckNumber;
  final String truckType;
  final String? driverName;
  final String? parentDestination;

  const AddLoadScreen({
    super.key,
    required this.parentTripId,
    required this.truckId,
    required this.truckNumber,
    required this.truckType,
    this.driverName,
    this.parentDestination,
  });

  @override
  State<AddLoadScreen> createState() => _AddLoadScreenState();
}

class _AddLoadScreenState extends State<AddLoadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _truckNumberController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _freightAmountController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _truckHireCostController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _supplierRateController = TextEditingController();
  final TextEditingController _supplierQuantityController = TextEditingController();

  String _selectedBillingType = 'Fixed';
  String _selectedSupplierBillingType = 'Fixed';
  DateTime _selectedDate = DateTime.now();
  bool _sendSMS = false;
  bool _isLoading = false;
  bool _showMoreDetails = false;
  bool _showValidationErrors = false;
  List<Map<String, dynamic>> _cities = [];
  List<dynamic> _parties = [];
  List<dynamic> _drivers = [];
  List<dynamic> _allTrucks = [];
  int _selectedTruckId = 0;
  String _selectedTruckType = '';

  // Additional detail controllers
  final TextEditingController _lrNumberController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTruckId = widget.truckId;
    _truckNumberController.text = widget.truckNumber;
    _selectedTruckType = widget.truckType;
    if (widget.driverName != null && widget.driverName!.isNotEmpty) {
      _driverNameController.text = widget.driverName!;
    }
    // Prefill origin from parent trip's destination
    if (widget.parentDestination != null && widget.parentDestination!.isNotEmpty) {
      _originController.text = widget.parentDestination!;
    }
    _loadData();
    _generateLRNumber();
  }

  @override
  void dispose() {
    _partyNameController.dispose();
    _driverNameController.dispose();
    _truckNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _freightAmountController.dispose();
    _supplierNameController.dispose();
    _truckHireCostController.dispose();
    _rateController.dispose();
    _quantityController.dispose();
    _supplierRateController.dispose();
    _supplierQuantityController.dispose();
    _lrNumberController.dispose();
    _materialController.dispose();
    _weightController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _generateLRNumber() async {
    // Auto-generate LR number based on last trip
    try {
      final trips = await ApiService.getAllTrips();
      if (trips.isNotEmpty) {
        final lastTrip = trips.first;
        final lastLR = lastTrip['lrNumber'];
        if (lastLR != null) {
          final match = RegExp(r'\d+').firstMatch(lastLR);
          if (match != null) {
            final lastNumber = int.parse(match.group(0)!);
            final newNumber = lastNumber + 1;
            _lrNumberController.text = 'LR${newNumber.toString().padLeft(3, '0')}';
          }
        }
      } else {
        _lrNumberController.text = 'LR001';
      }
    } catch (e) {
      _lrNumberController.text = 'LR001';
    }
  }

  String _getRateLabel(String billingType) {
    switch (billingType) {
      case 'Per Ton':
        return 'Rate per Ton';
      case 'Per Kg':
        return 'Rate per Kg';
      case 'Per KM':
        return 'Rate per KM';
      case 'Per Hour':
        return 'Rate per Hour';
      case 'Per Liter':
        return 'Rate per Liter';
      case 'Per Bag':
        return 'Rate per Bag';
      case 'Per Box':
        return 'Rate per Box';
      default:
        return 'Rate';
    }
  }

  String _getQuantityLabel(String billingType) {
    switch (billingType) {
      case 'Per Ton':
        return 'Total Tons';
      case 'Per Kg':
        return 'Total Kg';
      case 'Per KM':
        return 'Total KM';
      case 'Per Hour':
        return 'Total Hours';
      case 'Per Liter':
        return 'Total Liters';
      case 'Per Bag':
        return 'Total Bags';
      case 'Per Box':
        return 'Total Boxes';
      default:
        return 'Quantity';
    }
  }

  void _calculateFreightAmount() {
    if (_rateController.text.isNotEmpty && _quantityController.text.isNotEmpty) {
      final rate = double.tryParse(_rateController.text) ?? 0;
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      _freightAmountController.text = (rate * quantity).toStringAsFixed(0);
    }
  }

  void _calculateTruckHireCost() {
    if (_supplierRateController.text.isNotEmpty && _supplierQuantityController.text.isNotEmpty) {
      final rate = double.tryParse(_supplierRateController.text) ?? 0;
      final quantity = double.tryParse(_supplierQuantityController.text) ?? 0;
      _truckHireCostController.text = (rate * quantity).toStringAsFixed(0);
    }
  }

  Future<void> _loadData() async {
    final cities = await ApiService.getCities();
    final parties = await ApiService.getParties();
    final drivers = await ApiService.getDrivers();
    final trucks = await ApiService.getTrucks();

    setState(() {
      _cities = cities;
      _parties = parties;
      _drivers = drivers;
      _allTrucks = trucks;
    });
  }

  Future<void> _selectDate() async {
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

  Future<void> _saveTrip() async {
    // Check mandatory fields
    setState(() {
      _showValidationErrors = true;
    });

    // Build list of missing fields
    List<String> missingFields = [];

    if (_partyNameController.text.isEmpty) {
      missingFields.add('Party/Customer Name');
    }
    if (_freightAmountController.text.isEmpty) {
      missingFields.add('Freight Amount');
    }
    if (_originController.text.isEmpty) {
      missingFields.add('Origin');
    }
    if (_destinationController.text.isEmpty) {
      missingFields.add('Destination');
    }

    if (missingFields.isNotEmpty) {
      ToastHelper.showSnackBarToast(context, 
        SnackBar(
          content: Text(
            'Please fill required fields:\n${missingFields.join(', ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate amount is greater than 0
    final amount = double.tryParse(_freightAmountController.text) ?? 0;
    if (amount <= 0) {
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(
          content: Text('Freight amount must be greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Call addTripLoad instead of addTrip
      final result = await ApiService.addTripLoad(
        tripId: widget.parentTripId,
        partyName: _partyNameController.text,
        origin: _originController.text,
        destination: _destinationController.text,
        billingType: _selectedBillingType,
        freightAmount: _freightAmountController.text,
        startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        rate: _selectedBillingType != 'Fixed' ? _rateController.text : null,
        quantity: _selectedBillingType != 'Fixed' ? _quantityController.text : null,
        lrNumber: _lrNumberController.text.isNotEmpty ? _lrNumberController.text : null,
        sendSms: _sendSMS,
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        if (mounted) {
          ToastHelper.showSnackBarToast(context, 
            const SnackBar(
              content: Text('Load added successfully'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ToastHelper.showSnackBarToast(context, 
            const SnackBar(
              content: Text('Failed to add load'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Load',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Green header strip with help button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fill in trip details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                    onPressed: () {
                      // Show help dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Help'),
                          content: const Text(
                            'Fill in the required fields:\n\n'
                            '• Party/Customer Name (Required)\n'
                            '• Truck Number (Required)\n'
                            '• Party Freight Amount (Required)\n'
                            '• Trip Start Date (Required)\n\n'
                            'All other fields are optional.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Party/Customer Name - Full Width
                    _buildDropdownField(
                      label: 'Party/Customer Name',
                      controller: _partyNameController,
                      onTap: _showPartyPicker,
                      isRequired: true,
                    ),
                    const SizedBox(height: 10),

                    // Truck No. (Disabled for loads - inherited from parent)
                    _buildDropdownField(
                      label: 'Truck No.',
                      controller: _truckNumberController,
                      onTap: () {}, // Disabled - inherited from parent trip
                      isRequired: true,
                    ),
                    const SizedBox(height: 10),

                    // Driver field (Editable for loads - can be changed if needed)
                    if (_selectedTruckId != 0 && _truckNumberController.text.isNotEmpty) ...[
                      _buildDropdownField(
                        label: _selectedTruckType == 'Own' ? 'Driver Name' : 'Supplier/Truck Owner',
                        controller: _selectedTruckType == 'Own'
                            ? _driverNameController
                            : _supplierNameController,
                        onTap: _selectedTruckType == 'Own' ? _showDriverPicker : () {},
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Origin and Destination - Same Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Origin',
                            controller: _originController,
                            onTap: () => _showCityPicker(true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Destination',
                            controller: _destinationController,
                            onTap: () => _showCityPicker(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Party Billing Type with info icon
                    Row(
                      children: [
                        const Text(
                          'Party Billing Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBillingTypeButton('Fixed', true),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildBillingTypeButton('Per Ton', true),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildBillingTypeButton('Per Kg', true),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMoreButton(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Rate and Quantity fields - Show for all types except Fixed
                    if (_selectedBillingType != 'Fixed') ...[
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: _getRateLabel(_selectedBillingType),
                              controller: _rateController,
                              hint: '₹ Enter rate',
                              keyboard: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              onChanged: (value) => _calculateFreightAmount(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextField(
                              label: _getQuantityLabel(_selectedBillingType),
                              controller: _quantityController,
                              hint: 'Enter quantity',
                              keyboard: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              onChanged: (value) => _calculateFreightAmount(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Party Freight Amount
                    CustomTextField(
                      label: 'Party Freight Amount',
                      controller: _freightAmountController,
                      hint: '₹ Enter amount',
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    ),
                    const SizedBox(height: 10),

                    // Supplier Billing Type - Market only
                    if (_selectedTruckType == 'Market') ...[
                      Row(
                        children: [
                          const Text(
                            'Supplier Billing Type',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBillingTypeButton('Fixed', false),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBillingTypeButton('Per Ton', false),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBillingTypeButton('Per Kg', false),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildMoreButton(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Supplier Rate and Quantity - Show for all types except Fixed
                      if (_selectedSupplierBillingType != 'Fixed') ...[
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: _getRateLabel(_selectedSupplierBillingType),
                                controller: _supplierRateController,
                                hint: '₹ Enter rate',
                                keyboard: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                onChanged: (value) => _calculateTruckHireCost(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomTextField(
                                label: _getQuantityLabel(_selectedSupplierBillingType),
                                controller: _supplierQuantityController,
                                hint: 'Enter quantity',
                                keyboard: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                onChanged: (value) => _calculateTruckHireCost(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Truck Hire Cost
                      CustomTextField(
                        label: 'Truck Hire Cost',
                        controller: _truckHireCostController,
                        hint: '₹ Enter cost',
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Trip Start Date
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: CustomTextField(
                          label: 'Trip Start Date',
                          controller: TextEditingController(
                            text: DateFormat('dd MMM yyyy').format(_selectedDate),
                          ),
                          suffix: const Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Add More Details Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showMoreDetails = !_showMoreDetails;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.info.withOpacity(0.8), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          _showMoreDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.info.withOpacity(0.8),
                        ),
                        label: Text(
                          _showMoreDetails ? 'Hide More Details' : 'Add More Details',
                          style: TextStyle(
                            color: AppColors.info.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Expandable Additional Details
                    if (_showMoreDetails) ...[
                      CustomTextField(
                        label: 'LR Number',
                        controller: _lrNumberController,
                        hint: 'Auto-generated (editable)',
                        keyboard: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        label: 'Material',
                        controller: _materialController,
                        hint: 'e.g., Steel, Cement, etc.',
                        keyboard: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        label: 'Weight (in Tons)',
                        controller: _weightController,
                        hint: 'Enter weight',
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 12, top: 6, right: 12),
                              child: Text(
                                'Remarks',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            TextFormField(
                              controller: _remarksController,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter any additional notes...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(left: 12, right: 12, bottom: 6),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Send SMS Checkbox - Market only
                    if (_selectedTruckType == 'Market')
                      Row(
                        children: [
                          const Text(
                            'Send SMS to :',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 0.9,
                            child: Checkbox(
                              value: _sendSMS,
                              onChanged: (value) {
                                setState(() {
                                  _sendSMS = value!;
                                });
                              },
                              activeColor: AppColors.primaryGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const Text(
                            'Supplier',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Save Trip Button - Fixed at bottom
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
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
                    : const Text(
                        'Save Load',
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

  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    bool isRequired = false,
  }) {
    final hasError = _showValidationErrors && isRequired && controller.text.isEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hasError ? Colors.red : Colors.grey.shade300,
            width: hasError ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasError ? Colors.red : Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (isRequired)
                  const Text(
                    ' *',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? (hasError ? 'Required' : '') : controller.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: controller.text.isEmpty && hasError ? Colors.red.shade300 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: hasError ? Colors.red : Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildBillingTypeButton(String type, bool isPartyBilling) {
    final isSelected = isPartyBilling
        ? _selectedBillingType == type
        : _selectedSupplierBillingType == type;

    Color selectedColor = isPartyBilling ? const Color(0xFF2196F3) : const Color(0xFFFF9066);

    return InkWell(
      onTap: () {
        setState(() {
          if (isPartyBilling) {
            _selectedBillingType = type;
            if (type == 'Fixed') {
              _rateController.clear();
              _quantityController.clear();
            }
          } else {
            _selectedSupplierBillingType = type;
            if (type == 'Fixed') {
              _supplierRateController.clear();
              _supplierQuantityController.clear();
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.grey.shade300,
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMoreButton(bool isPartyBilling) {
    return InkWell(
      onTap: () => _showMoreBillingTypes(isPartyBilling),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          border: Border.all(
            color: Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'More',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }

  void _showMoreBillingTypes(bool isPartyBilling) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPartyBilling ? 'Party Billing Type' : 'Supplier Billing Type',
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
            const SizedBox(height: 16),
            _buildBillingTypeOption('Per KM', isPartyBilling),
            _buildBillingTypeOption('Per Hour', isPartyBilling),
            _buildBillingTypeOption('Per Liter', isPartyBilling),
            _buildBillingTypeOption('Per Bag', isPartyBilling),
            _buildBillingTypeOption('Per Box', isPartyBilling),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingTypeOption(String type, bool isPartyBilling) {
    final isSelected = isPartyBilling
        ? _selectedBillingType == type
        : _selectedSupplierBillingType == type;

    return InkWell(
      onTap: () {
        setState(() {
          if (isPartyBilling) {
            _selectedBillingType = type;
          } else {
            _selectedSupplierBillingType = type;
          }
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              type,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: isPartyBilling ? const Color(0xFF2196F3) : const Color(0xFFFF9066),
              ),
          ],
        ),
      ),
    );
  }

  // Picker dialogs (keep existing implementations)
  void _showPartyPicker() async {
    if (_parties.isEmpty) {
      await _loadData();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Party',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
              title: const Text('Add New Party'),
              onTap: () {
                Navigator.pop(context);
                _showAddPartyDialog();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _parties.length,
                itemBuilder: (context, index) {
                  final party = _parties[index];
                  return ListTile(
                    title: Text(party['name']),
                    subtitle: party['phone'] != null ? Text(party['phone']) : null,
                    onTap: () {
                      setState(() {
                        _partyNameController.text = party['name'];
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

  void _showDriverPicker() async {
    if (_drivers.isEmpty) {
      await _loadData();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Driver',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
              title: const Text('Add New Driver'),
              onTap: () {
                Navigator.pop(context);
                _showAddDriverDialog();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _drivers.length,
                itemBuilder: (context, index) {
                  final driver = _drivers[index];
                  return ListTile(
                    title: Text(driver['name']),
                    subtitle: driver['phone'] != null ? Text(driver['phone']) : null,
                    onTap: () {
                      setState(() {
                        _driverNameController.text = driver['name'];
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

  void _showSupplierPicker() async {
    final suppliers = await ApiService.getSuppliers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Supplier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
              title: const Text('Add New Supplier'),
              onTap: () {
                Navigator.pop(context);
                _showAddSupplierDialog();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    title: Text(supplier['name']),
                    subtitle: Text(supplier['phone']),
                    onTap: () {
                      setState(() {
                        _supplierNameController.text = supplier['name'];
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

  void _showTruckPicker() async {
    if (_allTrucks.isEmpty) {
      await _loadData();
    }

    if (!mounted) return;

    // Navigate to full-screen truck picker
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TruckPickerScreen(
          allTrucks: _allTrucks,
          selectedTruckId: _selectedTruckId,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      // Debug: Print truck data
      print('Selected truck data: $result');
      print('Truck type: ${result['type']}');
      print('Supplier ID: ${result['supplierId']}, Supplier Name: ${result['supplierName']}');
      print('Driver ID: ${result['driverId']}, Driver Name: ${result['driverName']}');
      print('Last driver from trip: ${result['lastDriver']}');

      setState(() {
        _selectedTruckId = result['id'];
        _truckNumberController.text = result['number'];
        _selectedTruckType = result['type'];

        // Auto-populate driver or supplier based on truck type
        if (_selectedTruckType == 'Own') {
          _supplierNameController.clear();
          // Auto-populate driver: prioritize assigned driver, then fall back to last trip driver
          String? driverToUse;
          if (result['driverName'] != null && result['driverName'] != '') {
            driverToUse = result['driverName'];
            print('Using assigned driver from truck: $driverToUse');
          } else if (result['lastDriver'] != null && result['lastDriver'] != '') {
            driverToUse = result['lastDriver'];
            print('Using last driver from trip: $driverToUse');
          }

          if (driverToUse != null) {
            _driverNameController.text = driverToUse;
            print('Auto-populated driver: $driverToUse');
          } else {
            _driverNameController.clear();
            print('No driver found for Own truck');
          }
        } else {
          _driverNameController.clear();
          // Auto-populate supplier for Market truck using supplierName from relationship
          if (result['supplierName'] != null && result['supplierName'] != '') {
            _supplierNameController.text = result['supplierName'];
            print('Auto-populated supplier from relationship: ${result['supplierName']}');
          } else if (result['supplier'] != null && result['supplier'] != '') {
            // Fallback to legacy supplier field
            _supplierNameController.text = result['supplier'];
            print('Auto-populated supplier from legacy field: ${result['supplier']}');
          } else {
            _supplierNameController.clear();
            print('No supplier found for Market truck');
          }
        }
      });
    }
  }

  void _showCityPicker(bool isOrigin) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filteredCities = List.from(_cities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOrigin ? 'Select Origin' : 'Select Destination',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search city...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setModalState(() {
                    if (value.isEmpty) {
                      filteredCities = List.from(_cities);
                    } else {
                      filteredCities = _cities
                          .where((city) => (city['name'] ?? '').toString().toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              // Add New City button - always visible at top
              ListTile(
                leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
                title: const Text('Add New City'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddCityDialog(isOrigin);
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    final cityName = city['name'] ?? '';
                    return ListTile(
                      title: Text(cityName),
                      onTap: () {
                        setState(() {
                          if (isOrigin) {
                            _originController.text = cityName;
                          } else {
                            _destinationController.text = cityName;
                          }
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
      ),
    );
  }

  // Show dialog to add new city
  void _showAddCityDialog(bool isOrigin) {
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New City'),
        content: TextField(
          controller: cityController,
          decoration: const InputDecoration(
            hintText: 'Enter city name',
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
              if (cityController.text.trim().isEmpty) return;

              Navigator.pop(context); // Close dialog
              AppLoader.show(context);

              // Call API to add city to database
              final result = await ApiService.addCity(cityController.text.trim());

              if (mounted) {
                AppLoader.hide(context);
              }

              if (result != null && result['success'] == true) {
                final cityData = result['city'];
                setState(() {
                  // Add to local list if not already present
                  if (!_cities.any((c) => c['id'] == cityData['id'])) {
                    _cities.add(cityData);
                    _cities.sort((a, b) => a['name'].compareTo(b['name']));
                  }

                  if (isOrigin) {
                    _originController.text = cityData['name'];
                  } else {
                    _destinationController.text = cityData['name'];
                  }
                });

                if (mounted) {
                  ToastHelper.showSnackBarToast(context,
                    SnackBar(content: Text(result['message'] ?? 'City added successfully')),
                  );
                }
              } else {
                if (mounted) {
                  ToastHelper.showSnackBarToast(context,
                    const SnackBar(content: Text('Failed to add city')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddPartyDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Party',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Party Name field
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Party Name',
                      hintText: 'Enter party name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter party name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Number field
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter phone number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              setModalState(() {
                                isLoading = true;
                              });

                              try {
                                final result = await ApiService.addParty(
                                  name: nameController.text,
                                  phone: phoneController.text,
                                );

                                if (result != null && mounted) {
                                  setState(() {
                                    _partyNameController.text = nameController.text;
                                    _parties.add(result);
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Party added successfully'),
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Failed to add party'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isLoading = false;
                                });
                                ToastHelper.showSnackBarToast(context, 
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: AppLoader(
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Driver',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Driver Name field
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Driver Name',
                      hintText: 'Enter driver name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter driver name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Number field
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter phone number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              setModalState(() {
                                isLoading = true;
                              });

                              try {
                                final result = await ApiService.addDriver(
                                  name: nameController.text,
                                  phone: phoneController.text,
                                );

                                if (result != null && mounted) {
                                  setState(() {
                                    _driverNameController.text = nameController.text;
                                    _drivers.add(result);
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Driver added successfully'),
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Failed to add driver'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isLoading = false;
                                });
                                ToastHelper.showSnackBarToast(context, 
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: AppLoader(
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Supplier',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Supplier Name field
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Supplier Name',
                      hintText: 'Enter supplier name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter supplier name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Number field
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter phone number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              setModalState(() {
                                isLoading = true;
                              });

                              try {
                                final result = await ApiService.addSupplier(
                                  name: nameController.text,
                                  phone: phoneController.text,
                                );

                                if (result != null && mounted) {
                                  setState(() {
                                    _supplierNameController.text = nameController.text;
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Supplier added successfully'),
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ToastHelper.showSnackBarToast(context, 
                                    const SnackBar(
                                      content: Text('Failed to add supplier'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isLoading = false;
                                });
                                ToastHelper.showSnackBarToast(context, 
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: AppLoader(
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Full-Screen Truck Picker with Search and Own/Market Tabs
class _TruckPickerScreen extends StatefulWidget {
  final List<dynamic> allTrucks;
  final int selectedTruckId;

  const _TruckPickerScreen({
    required this.allTrucks,
    required this.selectedTruckId,
  });

  @override
  State<_TruckPickerScreen> createState() => _TruckPickerScreenState();
}

class _TruckPickerScreenState extends State<_TruckPickerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredTrucks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filteredTrucks = widget.allTrucks;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterTrucks(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredTrucks = widget.allTrucks;
      } else {
        _filteredTrucks = widget.allTrucks.where((truck) {
          final number = (truck['number'] ?? '').toString().toLowerCase();
          return number.contains(_searchQuery);
        }).toList();
      }
    });
  }

  List<dynamic> _getTrucksByType(String type) {
    return _filteredTrucks.where((truck) => truck['type'] == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Vehicle',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterTrucks,
                  decoration: InputDecoration(
                    hintText: 'Search by vehicle number...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _filterTrucks('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              // Tabs
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.info,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: AppColors.info,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car, size: 18),
                          const SizedBox(width: 6),
                          Text('Own (${_getTrucksByType('Own').length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_shipping, size: 18),
                          const SizedBox(width: 6),
                          Text('Market (${_getTrucksByType('Market').length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTruckList('Own'),
          _buildTruckList('Market'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTruckBottomSheet(
              onTruckAdded: () async {
                // Reload trucks after adding
                final trucks = await ApiService.getTrucks();
                if (mounted) {
                  setState(() {
                    widget.allTrucks.clear();
                    widget.allTrucks.addAll(trucks);
                    _filteredTrucks = widget.allTrucks;
                  });
                }
              },
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Truck',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTruckList(String type) {
    final trucks = _getTrucksByType(type);

    if (trucks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'Own' ? Icons.directions_car : Icons.local_shipping,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No $type trucks found'
                  : 'No $type trucks match your search',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: trucks.length,
      itemBuilder: (context, index) {
        final truck = trucks[index];
        final isSelected = truck['id'] == widget.selectedTruckId;
        final status = truck['status'] ?? 'Available';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: AppColors.info, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.info.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                type == 'Own' ? Icons.directions_car : Icons.local_shipping,
                color: isSelected ? AppColors.info : Colors.grey.shade600,
                size: 28,
              ),
            ),
            title: Text(
              truck['number'] ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.info : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'Available' ? AppColors.primaryGreen.withOpacity(0.1) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'Available' ? AppColors.primaryGreen.withOpacity(0.8) : Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (truck['supplier'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        truck['supplier'],
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: AppColors.info, size: 28)
                : const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.pop(context, truck);
            },
          ),
        );
      },
    );
  }
}



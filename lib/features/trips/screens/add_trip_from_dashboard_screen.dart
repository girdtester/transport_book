import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/validators.dart';
import '../../../utils/truck_number_formatter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';
import '../../../utils/appbar.dart';
import '../../../utils/custom_textfield.dart';

class AddTripFromDashboardScreen extends StatefulWidget {
  const AddTripFromDashboardScreen({super.key});

  @override
  State<AddTripFromDashboardScreen> createState() => _AddTripFromDashboardScreenState();
}

class _AddTripFromDashboardScreenState extends State<AddTripFromDashboardScreen> {
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
  List<dynamic> _suppliers = [];
  int _selectedTruckId = 0;
  String _selectedTruckType = '';

  // Store IDs for proper foreign key relationships
  int? _selectedPartyId;
  int? _selectedDriverId;
  int? _selectedSupplierId;
  int? _selectedOriginId;
  int? _selectedDestinationId;

  // Dropdown selected values
  String? _selectedPartyName;
  String? _selectedTruckNumber;
  String? _selectedDriverName;
  String? _selectedSupplierName;
  String? _selectedOrigin;
  String? _selectedDestination;

  // Additional detail controllers
  final TextEditingController _lrNumberController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _startKmController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _startKmController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _generateLRNumber() async {
    // Auto-generate LR number based on last trip
    try {
      final trips = await ApiService.getAllTrips();
      if (trips.isNotEmpty) {
        // Get the last LR number and increment
        final lastTrip = trips.first;
        final lastLR = lastTrip['lrNumber'];
        if (lastLR != null) {
          // Extract number from LR (e.g., "LR001" -> 1)
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
    final suppliers = await ApiService.getSuppliers();

    setState(() {
      _cities = cities;
      _parties = parties;
      _drivers = drivers;
      _allTrucks = trucks;
      _suppliers = suppliers;
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
    bool hasErrors = false;
    setState(() {
      _showValidationErrors = true;
    });

    if (_partyNameController.text.isEmpty) {
      hasErrors = true;
    }
    if (_selectedTruckId == 0 || _truckNumberController.text.isEmpty) {
      hasErrors = true;
    }
    if (_freightAmountController.text.isEmpty) {
      hasErrors = true;
    }

    if (hasErrors) {
      ToastHelper.showSnackBarToast(context,
        const SnackBar(
          content: Text('Please fill all required fields (Party, Truck, Amount, Date)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await ApiService.addTrip(
        truckId: _selectedTruckId,
        truckNumber: _truckNumberController.text,
        partyName: _partyNameController.text,
        origin: _originController.text,
        destination: _destinationController.text,
        billingType: _selectedBillingType,
        freightAmount: _freightAmountController.text,
        startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        driverName: _selectedTruckType == 'Own' ? _driverNameController.text : null,
        rate: _selectedBillingType != 'Fixed' ? _rateController.text : null,
        quantity: _selectedBillingType != 'Fixed' ? _quantityController.text : null,
        supplierName: _selectedTruckType == 'Market' ? _supplierNameController.text : null,
        supplierBillingType: _selectedTruckType == 'Market' ? _selectedSupplierBillingType : null,
        truckHireCost: _selectedTruckType == 'Market' ? _truckHireCostController.text : null,
        supplierRate: _selectedTruckType == 'Market' && _selectedSupplierBillingType != 'Fixed' ? _supplierRateController.text : null,
        supplierQuantity: _selectedTruckType == 'Market' && _selectedSupplierBillingType != 'Fixed' ? _supplierQuantityController.text : null,
        sendSMS: _selectedTruckType == 'Market' ? _sendSMS : false,
        // Pass IDs for proper foreign key relationships
        partyId: _selectedPartyId,
        driverId: _selectedDriverId,
        supplierId: _selectedSupplierId,
        originId: _selectedOriginId,
        destinationId: _selectedDestinationId,
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        if (mounted) {
          ToastHelper.showSnackBarToast(context,
            const SnackBar(
              content: Text('Trip added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ToastHelper.showSnackBarToast(context,
            const SnackBar(
              content: Text('Failed to add trip'),
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
      appBar:CustomAppBar(title: "Add Trip", onBack: () {
        Navigator.pop(context);
      },),
      // Replace your build method's body section with this updated layout:

      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(height: 10,
              decoration: BoxDecoration(color: Colors.grey.shade300),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Party/Customer Name - Full Width with search and add
                    _buildDropdownField(
                      label: 'Party/Customer Name',
                      controller: _partyNameController,
                      onTap: _showPartyPickerWithSearch,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // Truck No. and Driver/Supplier - Same Row with search and add
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Truck No.',
                            controller: _truckNumberController,
                            onTap: _showTruckPicker,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _selectedTruckId != 0 && _truckNumberController.text.isNotEmpty
                              ? _buildDropdownField(
                            label: _selectedTruckType == 'Own' ? 'Driver Name' : 'Supplier Name',
                            controller: _selectedTruckType == 'Own'
                                ? _driverNameController
                                : _supplierNameController,
                            onTap: _selectedTruckType == 'Own'
                                ? _showDriverPickerWithSearch
                                : _showSupplierPickerWithSearch,
                          )
                              : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver/Supplier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Select truck first',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Show "Optional" label under Driver/Supplier field
                    if (_selectedTruckId != 0 && _truckNumberController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          children: [
                            Expanded(child: Container()),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Optional',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Origin and Destination - Same Row with search
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Origin',
                            controller: _originController,
                            onTap: () => _showCityPickerWithSearch(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Destination',
                            controller: _destinationController,
                            onTap: () => _showCityPickerWithSearch(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Party Billing Type with info icon
                    Row(
                      children: [
                        const Text(
                          'Party Billing Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBillingTypeButton('Fixed', true),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBillingTypeButton('Per Ton', true),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBillingTypeButton('Per Kg', true),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMoreButton(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 16),
                    ],

                    // Party Freight Amount
                    CustomTextField(
                      label: 'Party Freight Amount',
                      controller: _freightAmountController,
                      hint: '₹ Enter amount',
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    ),
                    const SizedBox(height: 16),

                    // Supplier Billing Type - Market only
                    if (_selectedTruckType == 'Market') ...[
                      Row(
                        children: [
                          const Text(
                            'Supplier Billing Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBillingTypeButton('Fixed', false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildBillingTypeButton('Per Ton', false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildBillingTypeButton('Per Kg', false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMoreButton(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

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
                            const SizedBox(width: 12),
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
                        const SizedBox(height: 16),
                      ],

                      // Truck Hire Cost
                      CustomTextField(
                        label: 'Truck Hire Cost',
                        controller: _truckHireCostController,
                        hint: '₹ Enter cost',
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      ),
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 16),

                    // Add More Details Button
                    Align(alignment: Alignment.topRight,
                      child: OutlinedButton(
                        onPressed: () => _showMoreDetailsDrawer(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14,horizontal: 12),
                          side: BorderSide(color: Colors.grey.shade400, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Add More Details',
                          style: TextStyle(
                            color: AppColors.info.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show badge if additional details are filled
                    if (_lrNumberController.text.isNotEmpty ||
                        _materialController.text.isNotEmpty ||
                        _startKmController.text.isNotEmpty ||
                        _remarksController.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                    ],

                    // Send SMS Checkbox - Market only
                    if (_selectedTruckType == 'Market')
                      Row(
                        children: [
                          const Text(
                            'Send SMS to:',
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

                    const SizedBox(height: 80), // Extra space for floating button
                  ],
                ),
              ),
            ),

            // Save Trip Button - Fixed at bottom with blue background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Save Trip',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hasError ? Colors.red : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty
                        ? ''
                        : controller.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: controller.text.isEmpty
                          ? Colors.grey.shade400
                          : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                  color: Colors.grey.shade600,
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

    Color selectedColor = isPartyBilling ? AppColors.info.withOpacity(0.2) : AppColors.info.withOpacity(0.2);

    return InkWell(
      borderRadius: BorderRadius.circular(20),

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
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.grey.shade300,
          border: Border.all(
            color: isSelected ? AppColors.info : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.info : Colors.grey.shade700,
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
            ListTile(
              leading: const Icon(Icons.contacts, color: AppColors.info),
              title: const Text('Select from Contacts'),
              onTap: () {
                Navigator.pop(context);
                _pickContactForParty();
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
                        _selectedPartyId = party['id']; // Store party ID
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

  Future<void> _pickContactForParty() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          setState(() {
            _partyNameController.text = contact.displayName;
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
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
            ListTile(
              leading: const Icon(Icons.contacts, color: AppColors.info),
              title: const Text('Select from Contacts'),
              onTap: () {
                Navigator.pop(context);
                _pickContactForDriver();
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
                        _selectedDriverId = driver['id']; // Store driver ID
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

  Future<void> _pickContactForDriver() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          setState(() {
            _driverNameController.text = contact.displayName;
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
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
                        _selectedSupplierId = supplier['id']; // Store supplier ID
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

    // Navigate to full-screen truck selector
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TruckSelectorScreen(
          allTrucks: _allTrucks,
          selectedTruckId: _selectedTruckId,
          onTruckSelected: (truck) {
            // Debug: Print truck data
            print('Selected truck data (dashboard): $truck');
            print('Truck type: ${truck['type']}');
            print('Supplier ID: ${truck['supplierId']}, Supplier Name: ${truck['supplierName']}');
            print('Driver ID: ${truck['driverId']}, Driver Name: ${truck['driverName']}');
            print('Last driver from trip: ${truck['lastDriver']}');

            setState(() {
              _selectedTruckId = truck['id'];
              _truckNumberController.text = truck['number'];
              _selectedTruckType = truck['type'];

              // Clear supplier/driver based on truck type
              if (_selectedTruckType == 'Own') {
                _supplierNameController.clear();
                // Auto-populate driver: prioritize assigned driver, then fall back to last trip driver
                String? driverToUse;
                if (truck['driverName'] != null && truck['driverName'] != '') {
                  driverToUse = truck['driverName'];
                  print('Using assigned driver from truck: $driverToUse');
                } else if (truck['lastDriver'] != null && truck['lastDriver'] != '') {
                  driverToUse = truck['lastDriver'];
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
                if (truck['supplierName'] != null && truck['supplierName'] != '') {
                  _supplierNameController.text = truck['supplierName'];
                  print('Auto-populated supplier from relationship: ${truck['supplierName']}');
                } else if (truck['supplier'] != null && truck['supplier'] != '') {
                  // Fallback to legacy supplier field
                  _supplierNameController.text = truck['supplier'];
                  print('Auto-populated supplier from legacy field: ${truck['supplier']}');
                } else {
                  _supplierNameController.clear();
                  print('No supplier found for Market truck');
                }
              }
            });
          },
          onAddNewTruck: () async {
            // Refresh truck list after adding
            await _loadData();
          },
        ),
      ),
    );
  }

  Future<void> _autoPopulateDriver(int driverId) async {
    final driver = _drivers.firstWhere(
      (d) => d['id'] == driverId,
      orElse: () => null,
    );
    if (driver != null) {
      _driverNameController.text = driver['name'];
    }
  }

  Future<void> _autoPopulateSupplier(int supplierId) async {
    final suppliers = await ApiService.getSuppliers();
    final supplier = suppliers.firstWhere(
      (s) => s['id'] == supplierId,
      orElse: () => null,
    );
    if (supplier != null) {
      _supplierNameController.text = supplier['name'];
    }
  }

  // Searchable city picker method
  void _showCityPickerWithSearch(bool isOrigin) {
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
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search or type city name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setModalState(() {
                              filteredCities = List.from(_cities);
                            });
                          },
                        )
                      : null,
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
                          .where((city) => city['name'].toLowerCase().contains(value.toLowerCase()))
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
                child: filteredCities.isEmpty
                    ? Center(
                        child: Text(
                          'No cities found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredCities.length,
                        itemBuilder: (context, index) {
                          final city = filteredCities[index];
                          return ListTile(
                            title: Text(city['name']),
                            onTap: () {
                              setState(() {
                                if (isOrigin) {
                                  _originController.text = city['name'];
                                  _selectedOrigin = city['name'];
                                  _selectedOriginId = city['id'];
                                } else {
                                  _destinationController.text = city['name'];
                                  _selectedDestination = city['name'];
                                  _selectedDestinationId = city['id'];
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
                    _selectedOrigin = cityData['name'];
                    _selectedOriginId = cityData['id'];
                  } else {
                    _destinationController.text = cityData['name'];
                    _selectedDestination = cityData['name'];
                    _selectedDestinationId = cityData['id'];
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

  // New searchable party picker method
  void _showPartyPickerWithSearch() async {
    if (_parties.isEmpty) {
      await _loadData();
    }

    if (!mounted) return;

    final searchController = TextEditingController();
    List<dynamic> filteredParties = List.from(_parties);

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
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search party...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setModalState(() {
                              filteredParties = List.from(_parties);
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setModalState(() {
                    if (value.isEmpty) {
                      filteredParties = List.from(_parties);
                    } else {
                      filteredParties = _parties
                          .where((party) => (party['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
                title: const Text('Add New Party'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddPartyDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.contacts, color: AppColors.info),
                title: const Text('Select from Contacts'),
                onTap: () {
                  Navigator.pop(context);
                  _pickContactForParty();
                },
              ),
              const Divider(),
              Expanded(
                child: filteredParties.isEmpty
                    ? Center(
                        child: Text(
                          'No parties found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = filteredParties[index];
                          return ListTile(
                            title: Text(party['name'] ?? ''),
                            subtitle: party['phone'] != null ? Text(party['phone']) : null,
                            onTap: () {
                              setState(() {
                                _partyNameController.text = party['name'];
                                _selectedPartyId = party['id'];
                                _selectedPartyName = party['name'];
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

  // New searchable driver picker method
  void _showDriverPickerWithSearch() async {
    if (_drivers.isEmpty) {
      await _loadData();
    }

    if (!mounted) return;

    final searchController = TextEditingController();
    List<dynamic> filteredDrivers = List.from(_drivers);

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
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search driver...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setModalState(() {
                              filteredDrivers = List.from(_drivers);
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setModalState(() {
                    if (value.isEmpty) {
                      filteredDrivers = List.from(_drivers);
                    } else {
                      filteredDrivers = _drivers
                          .where((driver) => (driver['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
                title: const Text('Add New Driver'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddDriverDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.contacts, color: AppColors.info),
                title: const Text('Select from Contacts'),
                onTap: () {
                  Navigator.pop(context);
                  _pickContactForDriver();
                },
              ),
              const Divider(),
              Expanded(
                child: filteredDrivers.isEmpty
                    ? Center(
                        child: Text(
                          'No drivers found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = filteredDrivers[index];
                          return ListTile(
                            title: Text(driver['name'] ?? ''),
                            subtitle: driver['phone'] != null ? Text(driver['phone']) : null,
                            onTap: () {
                              setState(() {
                                _driverNameController.text = driver['name'];
                                _selectedDriverId = driver['id'];
                                _selectedDriverName = driver['name'];
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

  // New searchable supplier picker method
  void _showSupplierPickerWithSearch() async {
    final suppliers = await ApiService.getSuppliers();

    if (!mounted) return;

    final searchController = TextEditingController();
    List<dynamic> filteredSuppliers = List.from(suppliers);

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
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search supplier...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setModalState(() {
                              filteredSuppliers = List.from(suppliers);
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setModalState(() {
                    if (value.isEmpty) {
                      filteredSuppliers = List.from(suppliers);
                    } else {
                      filteredSuppliers = suppliers
                          .where((supplier) => (supplier['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
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
                child: filteredSuppliers.isEmpty
                    ? Center(
                        child: Text(
                          'No suppliers found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = filteredSuppliers[index];
                          return ListTile(
                            title: Text(supplier['name'] ?? ''),
                            subtitle: supplier['phone'] != null ? Text(supplier['phone']) : null,
                            onTap: () {
                              setState(() {
                                _supplierNameController.text = supplier['name'];
                                _selectedSupplierId = supplier['id'];
                                _selectedSupplierName = supplier['name'];
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
                                    _selectedPartyId = result['id'];
                                    _parties.add(result);
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context,
                                    const SnackBar(
                                      content: Text('Party added successfully'),
                                      backgroundColor: Colors.green,
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
                                    _selectedDriverId = result['id'];
                                    _drivers.add(result);
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context,
                                    const SnackBar(
                                      content: Text('Driver added successfully'),
                                      backgroundColor: Colors.green,
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
                                    _selectedSupplierId = result['id'];
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSnackBarToast(context,
                                    const SnackBar(
                                      content: Text('Supplier added successfully'),
                                      backgroundColor: Colors.green,
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

  // Show More Details Drawer
  void _showMoreDetailsDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Additional Details',
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
              const SizedBox(height: 20),

              // LR Number
              CustomTextField(
                label: 'LR Number',
                controller: _lrNumberController,
                hint: 'Auto-generated (editable)',
                keyboard: TextInputType.text,
              ),
              const SizedBox(height: 16),

              // Material
              CustomTextField(
                label: 'Material',
                controller: _materialController,
                hint: 'e.g., Steel, Cement, etc.',
                keyboard: TextInputType.text,
              ),
              const SizedBox(height: 16),

              // Start KM
              CustomTextField(
                label: 'Start KM',
                controller: _startKmController,
                hint: 'Enter starting odometer reading',
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              // Remarks
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
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Update state to show badge
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Additional details saved'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-screen Truck Selector with Own/Market tabs and search
class _TruckSelectorScreen extends StatefulWidget {
  final List<dynamic> allTrucks;
  final int selectedTruckId;
  final Function(Map<String, dynamic>) onTruckSelected;
  final VoidCallback onAddNewTruck;

  const _TruckSelectorScreen({
    required this.allTrucks,
    required this.selectedTruckId,
    required this.onTruckSelected,
    required this.onAddNewTruck,
  });

  @override
  State<_TruckSelectorScreen> createState() => _TruckSelectorScreenState();
}

class _TruckSelectorScreenState extends State<_TruckSelectorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredTrucks = [];
  List<dynamic> _ownTrucks = [];
  List<dynamic> _marketTrucks = [];
  List<dynamic> _allTrucks = []; // Local copy of all trucks

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allTrucks = List.from(widget.allTrucks); // Initialize with widget data
    _separateTrucks();
    _filteredTrucks = _allTrucks;
    _searchController.addListener(_filterTrucks);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Reload trucks from API
  Future<void> _reloadTrucks() async {
    try {
      final trucks = await ApiService.getTrucks();
      if (mounted) {
        setState(() {
          _allTrucks = trucks;
          _separateTrucks();
          _filterTrucks();
        });
      }
    } catch (e) {
      print('Error reloading trucks: $e');
    }
  }

  void _separateTrucks() {
    _ownTrucks = _allTrucks.where((truck) => truck['type'] == 'Own').toList();
    _marketTrucks = _allTrucks.where((truck) => truck['type'] == 'Market').toList();
  }

  void _filterTrucks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _ownTrucks = _allTrucks.where((truck) => truck['type'] == 'Own').toList();
        _marketTrucks = _allTrucks.where((truck) => truck['type'] == 'Market').toList();
      } else {
        _ownTrucks = _allTrucks
            .where((truck) =>
                truck['type'] == 'Own' &&
                truck['number'].toString().toLowerCase().contains(query))
            .toList();
        _marketTrucks = _allTrucks
            .where((truck) =>
                truck['type'] == 'Market' &&
                truck['number'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _showAddTruckDialog({String? preselectedType}) {
    final registrationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? validationError;
    // Pre-select based on current tab: 'Own' or 'Market'
    String selectedTruckType = preselectedType ?? 'Own';
    String? selectedSupplier;
    int? selectedSupplierId;
    List<dynamic> suppliersList = [];
    bool isLoadingSuppliers = false;

    // Function to load suppliers
    Future<void> loadSuppliers(StateSetter setModalState) async {
      setModalState(() => isLoadingSuppliers = true);
      try {
        final suppliers = await ApiService.getSuppliers();
        setModalState(() {
          suppliersList = suppliers;
          isLoadingSuppliers = false;
        });
      } catch (e) {
        setModalState(() => isLoadingSuppliers = false);
      }
    }

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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Truck',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
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
                  // Registration Number Input
                  const Text(
                    'Truck Registration No.*',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: registrationController,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      TruckNumberFormatter(),
                    ],
                    validator: validateTruckNumber,
                    decoration: InputDecoration(
                      hintText: 'ex. MH 12 KJ 1212',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      errorText: validationError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.info, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.info, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        validationError = validateTruckNumber(value);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Format: 2 letters (state) + 2 digits + alphanumeric\nExample: MH12TY9769, KA01AB1234',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Truck Type Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'Own',
                            groupValue: selectedTruckType,
                            onChanged: (value) {
                              setModalState(() {
                                selectedTruckType = value!;
                              });
                            },
                            activeColor: AppColors.primaryGreen,
                          ),
                          const Text('My Truck'),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'Market',
                            groupValue: selectedTruckType,
                            onChanged: (value) {
                              setModalState(() {
                                selectedTruckType = value!;
                              });
                              // Load suppliers when Market is selected
                              if (suppliersList.isEmpty) {
                                loadSuppliers(setModalState);
                              }
                            },
                            activeColor: Colors.orange,
                          ),
                          const Text('Market Truck'),
                        ],
                      ),
                    ],
                  ),
                  // Supplier Selection (shown when Market Truck is selected)
                  if (selectedTruckType == 'Market') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Supplier/Truck Owner *',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // Load suppliers if not loaded
                        if (suppliersList.isEmpty && !isLoadingSuppliers) {
                          loadSuppliers(setModalState);
                        }
                        // Show supplier picker
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => StatefulBuilder(
                            builder: (ctx, setSupplierState) {
                              List<dynamic> filteredSuppliers = List.from(suppliersList);
                              final searchController = TextEditingController();

                              return Container(
                                height: MediaQuery.of(context).size.height * 0.6,
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
                                            'Select Supplier',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _showAddSupplierForTruckDialog(setModalState, (name, id) {
                                                    setModalState(() {
                                                      selectedSupplier = name;
                                                      selectedSupplierId = id;
                                                    });
                                                  });
                                                },
                                                icon: const Icon(Icons.add, color: AppColors.primaryGreen),
                                                label: const Text('Add New', style: TextStyle(color: AppColors.primaryGreen)),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.pop(ctx),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Search
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: TextField(
                                        controller: searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Search supplier...',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setSupplierState(() {
                                            if (value.isEmpty) {
                                              filteredSuppliers = List.from(suppliersList);
                                            } else {
                                              filteredSuppliers = suppliersList
                                                  .where((s) => (s['name'] ?? '')
                                                      .toLowerCase()
                                                      .contains(value.toLowerCase()))
                                                  .toList();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // List
                                    Expanded(
                                      child: isLoadingSuppliers
                                          ? const Center(child: CircularProgressIndicator())
                                          : filteredSuppliers.isEmpty
                                              ? const Center(child: Text('No suppliers found'))
                                              : ListView.builder(
                                                  itemCount: filteredSuppliers.length,
                                                  itemBuilder: (ctx, index) {
                                                    final supplier = filteredSuppliers[index];
                                                    return ListTile(
                                                      title: Text(supplier['name'] ?? ''),
                                                      subtitle: supplier['phone'] != null
                                                          ? Text(supplier['phone'])
                                                          : null,
                                                      onTap: () {
                                                        setModalState(() {
                                                          selectedSupplier = supplier['name'];
                                                          selectedSupplierId = supplier['id'];
                                                        });
                                                        Navigator.pop(ctx);
                                                      },
                                                    );
                                                  },
                                                ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedSupplier ?? 'Select Supplier',
                              style: TextStyle(
                                color: selectedSupplier == null
                                    ? Colors.grey
                                    : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Confirm Button
                  ElevatedButton(
                    onPressed: () async {
                      // Validate form
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      // Validate supplier for Market truck
                      if (selectedTruckType == 'Market' && selectedSupplier == null) {
                        ToastHelper.showSnackBarToast(context,
                          const SnackBar(
                            content: Text('Please select a supplier'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Format truck number before saving
                      final formattedNumber = Validators.formatTruckNumber(
                        registrationController.text,
                      );

                      final result = await ApiService.addTruck(
                        number: formattedNumber,
                        type: selectedTruckType,
                        supplier: selectedSupplier,
                      );

                      if (result != null && mounted) {
                        Navigator.pop(context);

                        // Reload trucks in this selector screen
                        await _reloadTrucks();

                        // Also reload in parent screen
                        widget.onAddNewTruck();

                        ToastHelper.showSnackBarToast(context,
                          const SnackBar(
                            content: Text('Truck added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ToastHelper.showSnackBarToast(context,
                          const SnackBar(
                            content: Text('Failed to add truck'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  // Add supplier dialog for truck creation
  void _showAddSupplierForTruckDialog(StateSetter parentSetState, Function(String name, int id) onSupplierAdded) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Supplier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Supplier Name *',
                hintText: 'Enter supplier name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ToastHelper.showSnackBarToast(ctx,
                    const SnackBar(content: Text('Please enter supplier name')),
                  );
                  return;
                }

                final result = await ApiService.addSupplier(
                  name: nameController.text,
                  phone: phoneController.text,
                );

                if (result != null) {
                  Navigator.pop(ctx);
                  onSupplierAdded(result['name'], result['id']);
                  ToastHelper.showSnackBarToast(context,
                    const SnackBar(
                      content: Text('Supplier added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ToastHelper.showSnackBarToast(ctx,
                    const SnackBar(
                      content: Text('Failed to add supplier'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Supplier'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
          'Select Truck',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTruckDialog(
              preselectedType: _tabController.index == 0 ? 'Own' : 'Market',
            ),
            tooltip: 'Add New Truck',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by truck number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primaryGreen,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Own Trucks'),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_ownTrucks.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryGreen.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Market Trucks'),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_marketTrucks.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTruckList(_ownTrucks, 'Own'),
          _buildTruckList(_marketTrucks, 'Market'),
        ],
      ),
    );
  }

  Widget _buildTruckList(List<dynamic> trucks, String type) {
    if (trucks.isEmpty) {
      return Center(
        child: GestureDetector(
          onTap: () => _showAddTruckDialog(preselectedType: type),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No ${type.toLowerCase()} trucks found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Truck',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trucks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final truck = trucks[index];
        final isSelected = truck['id'] == widget.selectedTruckId;

        return InkWell(
          onTap: () {
            widget.onTruckSelected(truck);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: type == 'Own'
                        ? AppColors.primaryGreen.withOpacity(0.15)
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: type == 'Own'
                        ? AppColors.primaryGreen.withOpacity(0.8)
                        : Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck['number'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${truck['type']} • ${truck['status'] ?? 'Available'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          // Show supplier name for Market trucks
                          if (type == 'Market' && (truck['supplierName'] != null || truck['supplier'] != null)) ...[
                            Text(
                              ' • ${truck['supplierName'] ?? truck['supplier']}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/validators.dart';
import '../../../utils/truck_number_formatter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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
  List<String> _cities = [];
  List<dynamic> _parties = [];
  List<dynamic> _drivers = [];
  List<dynamic> _allTrucks = [];
  int _selectedTruckId = 0;
  String _selectedTruckType = '';

  // Store IDs for proper foreign key relationships
  int? _selectedPartyId;
  int? _selectedDriverId;
  int? _selectedSupplierId;

  // Additional detail controllers
  final TextEditingController _lrNumberController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
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
    _weightController.dispose();
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
      case 'Per Tonne':
        return 'Rate per Ton';
      case 'Per KG':
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
      case 'Per Tonne':
        return 'Total Tons';
      case 'Per KG':
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      );

      setState(() {
        _isLoading = false;
      });

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
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
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Trip',
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
                color: const Color(0xFF4CAF50),
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

                    // Truck No.
                    _buildDropdownField(
                      label: 'Truck No.',
                      controller: _truckNumberController,
                      onTap: _showTruckPicker,
                      isRequired: true,
                    ),
                    const SizedBox(height: 10),

                    // Driver/Supplier field - Only show after truck selection
                    if (_selectedTruckId != 0 && _truckNumberController.text.isNotEmpty) ...[
                      _buildDropdownField(
                        label: _selectedTruckType == 'Own' ? 'Driver Name' : 'Supplier/Truck Owner',
                        controller: _selectedTruckType == 'Own'
                            ? _driverNameController
                            : _supplierNameController,
                        onTap: _selectedTruckType == 'Own'
                            ? _showDriverPicker
                            : _showSupplierPicker,
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
                          child: _buildBillingTypeButton('Per Tonne', true),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildBillingTypeButton('Per KG', true),
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
                            child: _buildTextField(
                              label: _getRateLabel(_selectedBillingType),
                              controller: _rateController,
                              hintText: 'Enter rate',
                              prefixText: '₹ ',
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _calculateFreightAmount(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              label: _getQuantityLabel(_selectedBillingType),
                              controller: _quantityController,
                              hintText: 'Enter quantity',
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _calculateFreightAmount(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Party Freight Amount
                    _buildTextField(
                      label: 'Party Freight Amount',
                      controller: _freightAmountController,
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
                      keyboardType: TextInputType.number,
                      isRequired: true,
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
                            child: _buildBillingTypeButton('Per Tonne', false),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildBillingTypeButton('Per KG', false),
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
                              child: _buildTextField(
                                label: _getRateLabel(_selectedSupplierBillingType),
                                controller: _supplierRateController,
                                hintText: 'Enter rate',
                                prefixText: '₹ ',
                                keyboardType: TextInputType.number,
                                onChanged: (value) => _calculateTruckHireCost(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                label: _getQuantityLabel(_selectedSupplierBillingType),
                                controller: _supplierQuantityController,
                                hintText: 'Enter quantity',
                                keyboardType: TextInputType.number,
                                onChanged: (value) => _calculateTruckHireCost(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Truck Hire Cost
                      _buildTextField(
                        label: 'Truck Hire Cost',
                        controller: _truckHireCostController,
                        hintText: 'Enter cost',
                        prefixText: '₹ ',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Trip Start Date
                    _buildDateField(
                      label: 'Trip Start Date',
                      date: _selectedDate,
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 16),

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
                          side: BorderSide(color: Colors.blue.shade600, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          _showMoreDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.blue.shade600,
                        ),
                        label: Text(
                          _showMoreDetails ? 'Hide More Details' : 'Add More Details',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Expandable Additional Details
                    if (_showMoreDetails) ...[
                      _buildTextField(
                        label: 'LR Number',
                        controller: _lrNumberController,
                        hintText: 'Auto-generated (editable)',
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: 'Material',
                        controller: _materialController,
                        hintText: 'e.g., Steel, Cement, etc.',
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        label: 'Weight (in Tons)',
                        controller: _weightController,
                        hintText: 'Enter weight',
                        keyboardType: TextInputType.number,
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    String? prefixText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    bool isRequired = false,
  }) {
    final hasError = _showValidationErrors && isRequired && controller.text.isEmpty;

    return Container(
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
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, right: 12),
            child: Row(
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
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
                : null,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: hasError ? Colors.red.shade300 : Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
              isDense: true,
            ),
            onChanged: (value) {
              if (_showValidationErrors && value.isNotEmpty) {
                setState(() {
                  // Re-validate when user starts typing
                });
              }
              if (onChanged != null) onChanged(value);
            },
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'Required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
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
            ListTile(
              leading: const Icon(Icons.contacts, color: Colors.blue),
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
              leading: const Icon(Icons.contacts, color: Colors.blue),
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

  void _showCityPicker(bool isOrigin) {
    final searchController = TextEditingController();
    List<String> filteredCities = List.from(_cities);

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
                          .where((city) => city.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
                    return ListTile(
                      title: Text(city),
                      onTap: () {
                        setState(() {
                          if (isOrigin) {
                            _originController.text = city;
                          } else {
                            _destinationController.text = city;
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Party added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Driver added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Supplier added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                                ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _separateTrucks();
    _filteredTrucks = widget.allTrucks;
    _searchController.addListener(_filterTrucks);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _separateTrucks() {
    _ownTrucks = widget.allTrucks.where((truck) => truck['type'] == 'Own').toList();
    _marketTrucks = widget.allTrucks.where((truck) => truck['type'] == 'Market').toList();
  }

  void _filterTrucks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _ownTrucks = widget.allTrucks.where((truck) => truck['type'] == 'Own').toList();
        _marketTrucks = widget.allTrucks.where((truck) => truck['type'] == 'Market').toList();
      } else {
        _ownTrucks = widget.allTrucks
            .where((truck) =>
                truck['type'] == 'Own' &&
                truck['number'].toString().toLowerCase().contains(query))
            .toList();
        _marketTrucks = widget.allTrucks
            .where((truck) =>
                truck['type'] == 'Market' &&
                truck['number'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _showAddTruckDialog() {
    final registrationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? validationError;

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
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
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
                  // Truck Type Selection - removed for simplicity, only "Own" trucks
                  // Confirm Button
                  ElevatedButton(
                    onPressed: () async {
                      // Validate form
                      if (!formKey.currentState!.validate()) {
                        return;
                      }

                      // Format truck number before saving
                      final formattedNumber = Validators.formatTruckNumber(
                        registrationController.text,
                      );

                      final result = await ApiService.addTruck(
                        number: formattedNumber,
                        type: 'Own', // Default to Own
                      );

                      if (result != null && mounted) {
                        Navigator.pop(context);
                        widget.onAddNewTruck();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Truck added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
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
            onPressed: _showAddTruckDialog,
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
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_ownTrucks.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showAddTruckDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add New Truck'),
            ),
          ],
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
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: type == 'Own'
                        ? Colors.green.shade700
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
                      Text(
                        '${truck['type']} • ${truck['status'] ?? 'Available'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
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

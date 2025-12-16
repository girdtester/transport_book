import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class CreateLRScreen extends StatefulWidget {
  final int tripId;
  final String? truckNumber;

  const CreateLRScreen({
    super.key,
    required this.tripId,
    this.truckNumber,
  });

  @override
  State<CreateLRScreen> createState() => _CreateLRScreenState();
}

class _CreateLRScreenState extends State<CreateLRScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Company Details
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyGstController = TextEditingController();
  final TextEditingController _companyPanController = TextEditingController();
  final TextEditingController _companyAddress1Controller = TextEditingController();
  final TextEditingController _companyAddress2Controller = TextEditingController();
  final TextEditingController _companyPincodeController = TextEditingController();
  final TextEditingController _companyStateController = TextEditingController();
  final TextEditingController _companyMobileController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();

  // Step 2: LR & Consignor/Consignee
  final TextEditingController _lrNumberController = TextEditingController();
  DateTime _lrDate = DateTime.now();

  // Consignor
  final TextEditingController _consignorGstController = TextEditingController();
  final TextEditingController _consignorNameController = TextEditingController();
  final TextEditingController _consignorAddress1Controller = TextEditingController();
  final TextEditingController _consignorAddress2Controller = TextEditingController();
  final TextEditingController _consignorStateController = TextEditingController();
  final TextEditingController _consignorPincodeController = TextEditingController();
  final TextEditingController _consignorMobileController = TextEditingController();

  // Consignee
  final TextEditingController _consigneeGstController = TextEditingController();
  final TextEditingController _consigneeNameController = TextEditingController();
  final TextEditingController _consigneeAddress1Controller = TextEditingController();
  final TextEditingController _consigneeAddress2Controller = TextEditingController();
  final TextEditingController _consigneeStateController = TextEditingController();
  final TextEditingController _consigneePincodeController = TextEditingController();
  final TextEditingController _consigneeMobileController = TextEditingController();

  // Step 3: Goods Details
  final TextEditingController _materialDescController = TextEditingController();
  final TextEditingController _totalPackagesController = TextEditingController();
  final TextEditingController _actualWeightController = TextEditingController();
  final TextEditingController _chargedWeightController = TextEditingController();
  final TextEditingController _declaredValueController = TextEditingController();
  final TextEditingController _freightAmountController = TextEditingController();
  final TextEditingController _gstAmountController = TextEditingController();
  final TextEditingController _otherChargesController = TextEditingController();

  String _paymentTerms = 'To Pay';
  String? _paidBy;

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    // TODO: Load company details from settings/profile
    // For now, leave empty for user to fill
  }

  @override
  void dispose() {
    // Dispose all controllers
    _companyNameController.dispose();
    _companyGstController.dispose();
    _companyPanController.dispose();
    _companyAddress1Controller.dispose();
    _companyAddress2Controller.dispose();
    _companyPincodeController.dispose();
    _companyStateController.dispose();
    _companyMobileController.dispose();
    _companyEmailController.dispose();

    _lrNumberController.dispose();

    _consignorGstController.dispose();
    _consignorNameController.dispose();
    _consignorAddress1Controller.dispose();
    _consignorAddress2Controller.dispose();
    _consignorStateController.dispose();
    _consignorPincodeController.dispose();
    _consignorMobileController.dispose();

    _consigneeGstController.dispose();
    _consigneeNameController.dispose();
    _consigneeAddress1Controller.dispose();
    _consigneeAddress2Controller.dispose();
    _consigneeStateController.dispose();
    _consigneePincodeController.dispose();
    _consigneeMobileController.dispose();

    _materialDescController.dispose();
    _totalPackagesController.dispose();
    _actualWeightController.dispose();
    _chargedWeightController.dispose();
    _declaredValueController.dispose();
    _freightAmountController.dispose();
    _gstAmountController.dispose();
    _otherChargesController.dispose();

    super.dispose();
  }

  Widget _buildStep1CompanyDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo placeholder
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.camera_alt,
                size: 40,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Logo',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),

          // Company Name
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // GST Number
          TextField(
            controller: _companyGstController,
            decoration: const InputDecoration(
              labelText: 'GST Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // PAN Number
          TextField(
            controller: _companyPanController,
            decoration: const InputDecoration(
              labelText: 'PAN Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Address Line 1
          TextField(
            controller: _companyAddress1Controller,
            decoration: const InputDecoration(
              labelText: 'Address Line 1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Address Line 2
          TextField(
            controller: _companyAddress2Controller,
            decoration: const InputDecoration(
              labelText: 'Address Line 2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Pincode and State
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _companyPincodeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _companyStateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mobile Number
          TextField(
            controller: _companyMobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // E-mail
          TextField(
            controller: _companyEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2LRDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LR Date and Number in blue box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // LR Date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _lrDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _lrDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LR Date',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(_lrDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // LR Number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _lrNumberController,
                    decoration: const InputDecoration(
                      labelText: 'LR Number',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CONSIGNOR DETAILS
          const Text(
            'CONSIGNOR DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Add Consignor Button
          OutlinedButton.icon(
            onPressed: () => _showAddConsignorDialog(),
            icon: const Icon(Icons.add, color: Color(0xFF2196F3)),
            label: const Text(
              'Add Consignor',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Show consignor if added
          if (_consignorNameController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildConsignorCard(),
          ],

          const SizedBox(height: 24),

          // CONSIGNEE DETAILS
          const Text(
            'CONSIGNEE DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Add Consignee Button
          OutlinedButton.icon(
            onPressed: () => _showAddConsigneeDialog(),
            icon: const Icon(Icons.add, color: Color(0xFF2196F3)),
            label: const Text(
              'Add Consignee',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Show consignee if added
          if (_consigneeNameController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildConsigneeCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildConsignorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _consignorNameController.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showAddConsignorDialog(),
                ),
              ],
            ),
            if (_consignorGstController.text.isNotEmpty)
              Text('GST: ${_consignorGstController.text}'),
            if (_consignorAddress1Controller.text.isNotEmpty)
              Text(_consignorAddress1Controller.text),
            if (_consignorMobileController.text.isNotEmpty)
              Text('Mobile: ${_consignorMobileController.text}'),
          ],
        ),
      ),
    );
  }

  Widget _buildConsigneeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _consigneeNameController.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showAddConsigneeDialog(),
                ),
              ],
            ),
            if (_consigneeGstController.text.isNotEmpty)
              Text('GST: ${_consigneeGstController.text}'),
            if (_consigneeAddress1Controller.text.isNotEmpty)
              Text(_consigneeAddress1Controller.text),
            if (_consigneeMobileController.text.isNotEmpty)
              Text('Mobile: ${_consigneeMobileController.text}'),
          ],
        ),
      ),
    );
  }

  void _showAddConsignorDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConsignorDialog(),
    );
  }

  void _showAddConsigneeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConsigneeDialog(),
    );
  }

  Widget _buildConsignorDialog() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Consignor',
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
              const SizedBox(height: 8),
              const Text(
                'We will fetch consignor name and address from GST Number',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consignorGstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  hintText: 'Eg: 33AAGCK5803C1Z5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consignorNameController,
                decoration: const InputDecoration(
                  labelText: 'Consignor Name *',
                  hintText: 'Consignor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consignorAddress1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consignorAddress2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _consignorStateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _consignorPincodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consignorMobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Eg: 99914-54627',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  if (_consignorNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter consignor name')),
                    );
                    return;
                  }
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsigneeDialog() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Consignee',
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
              const SizedBox(height: 8),
              const Text(
                'We will fetch consignee name and address from GST Number',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consigneeGstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  hintText: 'Eg: 33AAGCK5803C1Z5',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consigneeNameController,
                decoration: const InputDecoration(
                  labelText: 'Consignee Name *',
                  hintText: 'Consignee Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consigneeAddress1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consigneeAddress2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _consigneeStateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _consigneePincodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _consigneeMobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Eg: 99914-54627',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  if (_consigneeNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter consignee name')),
                    );
                    return;
                  }
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3GoodsDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _materialDescController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Material Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _totalPackagesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Total Packages',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _actualWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Actual Weight (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _chargedWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Charged Weight (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _declaredValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Declared Value (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Freight & Charges',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _freightAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Freight Amount (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _gstAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'GST Amount (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _otherChargesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Other Charges (₹)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Payment Terms',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _paymentTerms,
            decoration: const InputDecoration(
              labelText: 'Payment Terms',
              border: OutlineInputBorder(),
            ),
            items: ['To Pay', 'Paid', 'To Be Billed'].map((term) {
              return DropdownMenuItem(value: term, child: Text(term));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _paymentTerms = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _paidBy,
            decoration: const InputDecoration(
              labelText: 'Paid By',
              border: OutlineInputBorder(),
            ),
            items: ['Consignor', 'Consignee'].map((payer) {
              return DropdownMenuItem(value: payer, child: Text(payer));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _paidBy = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Summary() {
    final freight = double.tryParse(_freightAmountController.text) ?? 0;
    final gst = double.tryParse(_gstAmountController.text) ?? 0;
    final other = double.tryParse(_otherChargesController.text) ?? 0;
    final total = freight + gst + other;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          _buildSummarySection('Company', [
            _companyNameController.text,
            'GST: ${_companyGstController.text}',
            _companyAddress1Controller.text,
          ]),

          _buildSummarySection('LR Details', [
            'LR Number: ${_lrNumberController.text}',
            'LR Date: ${DateFormat('dd MMM yyyy').format(_lrDate)}',
          ]),

          _buildSummarySection('Consignor', [
            _consignorNameController.text,
            if (_consignorGstController.text.isNotEmpty) 'GST: ${_consignorGstController.text}',
            _consignorAddress1Controller.text,
          ]),

          _buildSummarySection('Consignee', [
            _consigneeNameController.text,
            if (_consigneeGstController.text.isNotEmpty) 'GST: ${_consigneeGstController.text}',
            _consigneeAddress1Controller.text,
          ]),

          _buildSummarySection('Goods', [
            'Material: ${_materialDescController.text}',
            'Packages: ${_totalPackagesController.text}',
            'Weight: ${_actualWeightController.text} kg',
          ]),

          _buildSummarySection('Charges', [
            'Freight: ₹${freight.toStringAsFixed(2)}',
            'GST: ₹${gst.toStringAsFixed(2)}',
            'Other: ₹${other.toStringAsFixed(2)}',
            'Total: ₹${total.toStringAsFixed(2)}',
          ]),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ...items.where((item) => item.isNotEmpty).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(item),
        )),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _submitLR() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.createLorryReceipt(
        tripId: widget.tripId,
        lrNumber: _lrNumberController.text,
        lrDate: DateFormat('yyyy-MM-dd').format(_lrDate),
        companyName: _companyNameController.text,
        companyGst: _companyGstController.text,
        companyPan: _companyPanController.text,
        companyAddress1: _companyAddress1Controller.text,
        companyAddress2: _companyAddress2Controller.text,
        companyPincode: _companyPincodeController.text,
        companyState: _companyStateController.text,
        companyMobile: _companyMobileController.text,
        companyEmail: _companyEmailController.text,
        consignorGst: _consignorGstController.text,
        consignorName: _consignorNameController.text,
        consignorAddress1: _consignorAddress1Controller.text,
        consignorAddress2: _consignorAddress2Controller.text,
        consignorState: _consignorStateController.text,
        consignorPincode: _consignorPincodeController.text,
        consignorMobile: _consignorMobileController.text,
        consigneeGst: _consigneeGstController.text,
        consigneeName: _consigneeNameController.text,
        consigneeAddress1: _consigneeAddress1Controller.text,
        consigneeAddress2: _consigneeAddress2Controller.text,
        consigneeState: _consigneeStateController.text,
        consigneePincode: _consigneePincodeController.text,
        consigneeMobile: _consigneeMobileController.text,
        materialDescription: _materialDescController.text,
        totalPackages: _totalPackagesController.text,
        actualWeight: _actualWeightController.text,
        chargedWeight: _chargedWeightController.text,
        declaredValue: _declaredValueController.text,
        freightAmount: _freightAmountController.text,
        gstAmount: _gstAmountController.text,
        otherCharges: _otherChargesController.text,
        paymentTerms: _paymentTerms,
        paidBy: _paidBy,
      );

      if (!mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('LR created successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create LR')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create LR'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 4; i++) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentStep >= i ? const Color(0xFF2196F3) : const Color(0xFFE0E0E0),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: _currentStep >= i ? Colors.white : const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (i < 3)
                    Container(
                      width: 40,
                      height: 2,
                      color: _currentStep > i ? const Color(0xFF2196F3) : const Color(0xFFE0E0E0),
                    ),
                ],
              ],
            ),
          ),

          // Step content
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildStep1CompanyDetails(),
                _buildStep2LRDetails(),
                _buildStep3GoodsDetails(),
                _buildStep4Summary(),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF9E9E9E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      if (_currentStep < 3) {
                        // Validate current step
                        if (_currentStep == 0 && _companyNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter company name')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _lrNumberController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter LR number')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _consignorNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add consignor')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _consigneeNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add consignee')),
                          );
                          return;
                        }

                        setState(() {
                          _currentStep++;
                        });
                      } else {
                        _submitLR();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _currentStep < 3 ? 'Continue' : 'Submit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

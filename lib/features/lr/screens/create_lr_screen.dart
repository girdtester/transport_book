import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/app_colors.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import 'package:transport_book_app/utils/custom_dropdown.dart';
import 'package:transport_book_app/utils/custom_textfield.dart';
import '../../../services/api_service.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class CreateLRScreen extends StatefulWidget {
  final int tripId;
  final String? truckNumber;
  final String? lrNumber; // LR number from trip
  final String? partyName; // Party name for consignor
  final String? origin; // Origin city
  final String? destination; // Destination city
  final double? freightAmount; // Freight amount

  const CreateLRScreen({
    super.key,
    required this.tripId,
    this.truckNumber,
    this.lrNumber,
    this.partyName,
    this.origin,
    this.destination,
    this.freightAmount,
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
    _autoPopulateTripData();
  }

  Future<void> _loadCompanyDetails() async {
    // TODO: Load company details from settings/profile
    // For now, leave empty for user to fill
  }

  void _autoPopulateTripData() {
    // Auto-populate LR number from trip
    if (widget.lrNumber != null && widget.lrNumber!.isNotEmpty) {
      _lrNumberController.text = widget.lrNumber!;
    } else {
      // Generate LR number based on trip ID and date
      final now = DateTime.now();
      _lrNumberController.text = 'LR${now.year}${now.month.toString().padLeft(2, '0')}${widget.tripId.toString().padLeft(4, '0')}';
    }

    // Auto-populate consignor name from party name
    if (widget.partyName != null && widget.partyName!.isNotEmpty) {
      _consignorNameController.text = widget.partyName!;
    }

    // Auto-populate consignor address from origin
    if (widget.origin != null && widget.origin!.isNotEmpty) {
      _consignorAddress1Controller.text = widget.origin!;
    }

    // Auto-populate consignee address from destination
    if (widget.destination != null && widget.destination!.isNotEmpty) {
      _consigneeAddress1Controller.text = widget.destination!;
    }

    // Auto-populate freight amount
    if (widget.freightAmount != null && widget.freightAmount! > 0) {
      _freightAmountController.text = widget.freightAmount!.toStringAsFixed(0);
    }
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

          // ----------------------- LOGO BOX -----------------------
          Center(
            child: InkWell(
              onTap: () {
                // pick image logic later
              },
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Logo',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),

          const SizedBox(height: 24),

          // ----------------------- COMPANY NAME -----------------------
          CustomTextField(
            label: "Company Name",
            controller: _companyNameController,
            hint: "Enter company name",
          ),
          const SizedBox(height: 16),

          // ----------------------- GST NUMBER -----------------------
          CustomTextField(
            label: "GST Number",
            controller: _companyGstController,
            hint: "Enter GST number",
          ),
          const SizedBox(height: 16),

          // ----------------------- PAN NUMBER -----------------------
          CustomTextField(
            label: "PAN Number",
            controller: _companyPanController,
            hint: "Enter PAN",
          ),
          const SizedBox(height: 16),

          // ----------------------- ADDRESS LINE 1 -----------------------
          CustomTextField(
            label: "Address Line 1",
            controller: _companyAddress1Controller,
            hint: "Street / Road / Area",
          ),
          const SizedBox(height: 16),

          // ----------------------- ADDRESS LINE 2 -----------------------
          CustomTextField(
            label: "Address Line 2",
            controller: _companyAddress2Controller,
            hint: "Apartment / Landmark",
          ),
          const SizedBox(height: 16),

          // ----------------------- PINCODE + STATE -----------------------
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: "Pincode",
                  controller: _companyPincodeController,
                  keyboard: TextInputType.number,
                  hint: "Pincode",
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomTextField(
                  label: "State",
                  controller: _companyStateController,
                  hint: "State",
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ----------------------- MOBILE NUMBER -----------------------
          CustomTextField(
            label: "Mobile Number",
            controller: _companyMobileController,
            keyboard: TextInputType.phone,
            hint: "10-digit number",
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          // ----------------------- EMAIL -----------------------
          CustomTextField(
            label: "E-mail",
            controller: _companyEmailController,
            keyboard: TextInputType.emailAddress,
            hint: "Enter email",
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
              color: AppColors.info,
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
            icon: const Icon(Icons.add, color: AppColors.info),
            label: const Text(
              'Add Consignor',
              style: TextStyle(
                color: AppColors.info,
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
            icon: const Icon(Icons.add, color: AppColors.info),
            label: const Text(
              'Add Consignee',
              style: TextStyle(
                color: AppColors.info,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ---------- HEADER ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:  [
                    Text(
                      "Add Consignor",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: Colors.black54,
                        size: 22,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 12),

                Divider(
                  color: Colors.grey.shade300,
                  thickness: 1,
                  height: 1,
                ),

                const SizedBox(height: 12),

                // ---------- COMPACT SMALL TEXT ----------
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    "We will fetch consignor name and address from GST Number",
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ---------- FIELDS ----------
                CustomTextField(
                  label: "GST Number",
                  hint: "Eg: 33AAGCK5803C1Z5",
                  controller: _consignorGstController,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Consignor Name *",
                  hint: "Consignor Name",
                  controller: _consignorNameController,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Address Line 1",
                  controller: _consignorAddress1Controller,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Address Line 2",
                  controller: _consignorAddress2Controller,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: "State",
                        controller: _consignorStateController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: "Pincode",
                        controller: _consignorPincodeController,
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Mobile Number",
                  hint: "Eg: 99914-54627",
                  controller: _consignorMobileController,
                  keyboard: TextInputType.phone,
                  suffix: const Icon(Icons.phone, color: Colors.grey),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),

                const SizedBox(height: 26),

                // ---------- CONFIRM BUTTON ----------

                CustomButton(
                  text: "Confirm",
                  onPressed: () {
                    if (_consignorNameController.text.isEmpty) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(
                          content: Text("Please enter consignor name"),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);
                  },
                ),


                const SizedBox(height: 10),
              ],
            ),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ---------- HEADER ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Add Consignee",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.black54,
                        size: 22,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 12),

                Divider(
                  color: Colors.grey.shade300,
                  thickness: 1,
                  height: 1,
                ),

                const SizedBox(height: 12),

                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    "We will fetch consignee name and address from GST Number",
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ---------- FIELDS ----------
                CustomTextField(
                  label: "GST Number",
                  hint: "Eg: 33AAGCK5803C1Z5",
                  controller: _consigneeGstController,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Consignee Name *",
                  hint: "Consignee Name",
                  controller: _consigneeNameController,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Address Line 1",
                  controller: _consigneeAddress1Controller,
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Address Line 2",
                  controller: _consigneeAddress2Controller,
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: "State",
                        controller: _consigneeStateController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: "Pincode",
                        controller: _consigneePincodeController,
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                CustomTextField(
                  label: "Mobile Number",
                  hint: "Eg: 99914-54627",
                  controller: _consigneeMobileController,
                  keyboard: TextInputType.phone,
                  suffix: const Icon(Icons.phone, color: Colors.grey),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),

                const SizedBox(height: 26),

                // ---------- CONFIRM BUTTON ----------
                CustomButton(
                  text: "Confirm",
                  onPressed: () {
                    if (_consigneeNameController.text.isEmpty) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(
                          content: Text("Please enter consignee name"),
                        ),
                      );
                      return;
                    }
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 10),
              ],
            ),
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

          // ---------- MATERIAL DESCRIPTION ----------
          CustomTextField(
            label: "Material Description",
            hint: "Enter material description",
            controller: _materialDescController,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Total Packages",
            hint: "Number of packages",
            controller: _totalPackagesController,
            keyboard: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Actual Weight (kg)",
            hint: "Eg: 25.50",
            controller: _actualWeightController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Charged Weight (kg)",
            hint: "Eg: 30.00",
            controller: _chargedWeightController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Declared Value (₹)",
            hint: "Eg: 50000",
            controller: _declaredValueController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),

          // ---------------- TITLE: FREIGHT & CHARGES ----------------
          const Text(
            "Freight & Charges",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Freight Amount (₹)",
            hint: "Eg: 1500",
            controller: _freightAmountController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "GST Amount (₹)",
            hint: "Eg: 270",
            controller: _gstAmountController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: "Other Charges (₹)",
            hint: "Eg: 100",
            controller: _otherChargesController,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),

          // ---------------- TITLE: PAYMENT TERMS ----------------
          const Text(
            "Payment Terms",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // ---------------- PAYMENT TERMS DROPDOWN ----------------
          CustomDropdown(
            label: "Payment Terms",
            hint: "Select payment terms",
            value: _paymentTerms,
            items: ["To Pay", "Paid", "To Be Billed"],
            onChanged: (value) {
              setState(() {
                _paymentTerms = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // ---------------- PAID BY DROPDOWN ----------------
          CustomDropdown(
            label: "Paid By",
            hint: "Select payer",
            value: _paidBy,
            items: ["Consignor", "Consignee"],
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

  // Widget _buildStep3GoodsDetails() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.stretch,
  //       children: [
  //         TextField(
  //           controller: _materialDescController,
  //           maxLines: 3,
  //           decoration: const InputDecoration(
  //             labelText: 'Material Description',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _totalPackagesController,
  //           keyboardType: TextInputType.number,
  //           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //           decoration: const InputDecoration(
  //             labelText: 'Total Packages',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _actualWeightController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'Actual Weight (kg)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _chargedWeightController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'Charged Weight (kg)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _declaredValueController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'Declared Value (₹)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 24),
  //
  //         const Text(
  //           'Freight & Charges',
  //           style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _freightAmountController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'Freight Amount (₹)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _gstAmountController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'GST Amount (₹)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         TextField(
  //           controller: _otherChargesController,
  //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
  //           decoration: const InputDecoration(
  //             labelText: 'Other Charges (₹)',
  //             border: OutlineInputBorder(),
  //           ),
  //         ),
  //         const SizedBox(height: 24),
  //
  //         const Text(
  //           'Payment Terms',
  //           style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //
  //         DropdownButtonFormField<String>(
  //           value: _paymentTerms,
  //           decoration: const InputDecoration(
  //             labelText: 'Payment Terms',
  //             border: OutlineInputBorder(),
  //           ),
  //           items: ['To Pay', 'Paid', 'To Be Billed'].map((term) {
  //             return DropdownMenuItem(value: term, child: Text(term));
  //           }).toList(),
  //           onChanged: (value) {
  //             setState(() {
  //               _paymentTerms = value!;
  //             });
  //           },
  //         ),
  //         const SizedBox(height: 16),
  //
  //         DropdownButtonFormField<String>(
  //           value: _paidBy,
  //           decoration: const InputDecoration(
  //             labelText: 'Paid By',
  //             border: OutlineInputBorder(),
  //           ),
  //           items: ['Consignor', 'Consignee'].map((payer) {
  //             return DropdownMenuItem(value: payer, child: Text(payer));
  //           }).toList(),
  //           onChanged: (value) {
  //             setState(() {
  //               _paidBy = value;
  //             });
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
            color: AppColors.info,
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
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('LR created successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('Failed to create LR')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
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
        elevation: 0,
        backgroundColor: AppColors.info,
        centerTitle: true,
        automaticallyImplyLeading: false,

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),

        titleSpacing: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          'Create LR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                      color: _currentStep >= i ? AppColors.info : const Color(0xFFE0E0E0),
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
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Please enter company name')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _lrNumberController.text.isEmpty) {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Please enter LR number')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _consignorNameController.text.isEmpty) {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Please add consignor')),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _consigneeNameController.text.isEmpty) {
                          ToastHelper.showSnackBarToast(context, 
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
                      backgroundColor: AppColors.info,
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
                            child: AppLoader(
                              strokeWidth: 2,
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



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import 'package:transport_book_app/utils/custom_dropdown.dart';
import 'package:transport_book_app/utils/custom_textfield.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'driver_report_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class DriverDetailScreen extends StatefulWidget {
  final int driverId;
  final String driverName;

  const DriverDetailScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  Map<String, dynamic>? _driverDetails;
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  double _balance = 0.0;
  String _status = 'On Trip';

  @override
  void initState() {
    super.initState();
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await ApiService.getDriverDetails(widget.driverId);

      if (details != null) {
        setState(() {
          _driverDetails = details;
          _transactions = details['transactions'] ?? [];
          _balance = double.tryParse(details['balance']?.toString() ?? '0') ?? 0.0;
          _status = details['status']?.toString() ?? 'On Trip';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading driver details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading driver details: $e')),
        );
      }
    }
  }

  void _showDriverGaveDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedReason = 'Fuel Expense';
    bool isFormValid = false;

    final reasons = [
      'Fuel Expense',
      'Loading charge',
      'Toll Expense',
      'Other',
    ];

    void checkFormValidity() {
      isFormValid = amountController.text.isNotEmpty;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reduce Driver Balance (-)',
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

                // AMOUNT
                CustomTextField(
                  label: "Amount",
                  controller: amountController,
                  hint: "Enter amount",
                  keyboard: TextInputType.number,
                  suffix: const Icon(Icons.currency_rupee),
                  onChanged: (_) {
                    setModalState(() {
                      checkFormValidity();
                    });
                  },
                ),

                const SizedBox(height: 16),

                // REASON DROPDOWN
                CustomDropdown(
                  label: "Reason",
                  value: selectedReason,
                  items: reasons,
                  onChanged: (value) {
                    setModalState(() {
                      selectedReason = value!;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // DATE PICKER FIELD (with CustomTextField)
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setModalState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: CustomTextField(
                      label: "Date",
                      controller: TextEditingController(
                        text: DateFormat('dd MMM yyyy').format(selectedDate),
                      ),
                      suffix: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // NOTE FIELD
                CustomTextField(
                  label: "Note",
                  controller: noteController,
                  hint: "Optional",
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // CONFIRM BUTTON
                CustomButton(
                  text: "Confirm",
                  color: isFormValid ? Colors.red : Colors.grey.shade400,
                  onPressed: isFormValid
                      ? () async {
                    final amount = amountController.text;

                    if (amount.isEmpty) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(
                            content: Text('Please enter amount')),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    final result =
                    await ApiService.addDriverBalanceTransaction(
                      driverId: widget.driverId,
                      type: 'gave',
                      amount: amount,
                      reason: selectedReason,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                      note: noteController.text,
                    );

                    if (result != null) {
                      await _loadDriverDetails();
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Transaction added successfully'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Error adding transaction'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                      : () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettleAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),

        title: const Text(
          'Settle Amount',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        content: Text(
          'Are you sure you want to settle the driver balance of ₹${_balance.toStringAsFixed(0)}?\n\nThis will clear the current balance.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),

        actionsPadding: const EdgeInsets.only(bottom: 12, right: 12, left: 12),

        actions: [
          // âŒ CANCEL BUTTON
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // âœ” SETTLE BUTTON (THEME COLORED)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ApiService.settleDriverBalance(
                driverId: widget.driverId,
              );

              if (!mounted) return;

              if (success) {
                await _loadDriverDetails();
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(
                    content: Text('Amount settled successfully'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              } else {
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(
                    content: Text('Failed to settle amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,    // ðŸ”µ theme color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Settle',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverGotDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedReason = 'Trip Advance';
    bool isFormValid = false;

    final reasons = [
      'Trip Advance',
      'Driver Payment',
      'Party Payment',
      'Other',
    ];

    void checkFormValidity() {
      isFormValid = amountController.text.isNotEmpty;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------------- HEADER ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Driver Balance (+)',
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

                // ---------------- AMOUNT FIELD ----------------
                CustomTextField(
                  label: "Amount",
                  controller: amountController,
                  hint: "Enter amount",
                  keyboard: TextInputType.number,
                  suffix: const Icon(Icons.currency_rupee),
                  onChanged: (value) {
                    setModalState(() {
                      checkFormValidity();
                    });
                  },
                ),

                const SizedBox(height: 16),

                // ---------------- REASON DROPDOWN ----------------
                CustomDropdown(
                  label: "Reason",
                  value: selectedReason,
                  items: reasons,
                  onChanged: (val) {
                    setModalState(() {
                      selectedReason = val ?? reasons[0];
                    });
                  },
                ),

                const SizedBox(height: 16),

                // ---------------- DATE PICKER ----------------
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setModalState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: CustomTextField(
                      label: "Date",
                      controller: TextEditingController(
                        text: DateFormat('dd MMM yyyy').format(selectedDate),
                      ),
                      suffix: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- NOTE FIELD ----------------
                CustomTextField(
                  label: "Note",
                  controller: noteController,
                  hint: "Optional",
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // ---------------- CONFIRM BUTTON ----------------
                CustomButton(
                  text: "Confirm",
                  color: isFormValid ? Colors.green : Colors.grey.shade400,
                  onPressed: isFormValid
                      ? () async {
                    final amount = amountController.text;
                    if (amount.isEmpty) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(content: Text('Please enter amount')),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    final result =
                    await ApiService.addDriverBalanceTransaction(
                      driverId: widget.driverId,
                      type: 'got',
                      amount: amount,
                      reason: selectedReason,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                      note: noteController.text,
                    );

                    if (result != null) {
                      await _loadDriverDetails(); // Reload instantly
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Transaction added successfully'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Error adding transaction'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                      : () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDriverDialog() {
    final nameController = TextEditingController(text: widget.driverName);
    final phoneController =
    TextEditingController(text: _driverDetails?['phone']?.toString() ?? '');

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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Driver',
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

              // DRIVER NAME
              CustomTextField(
                label: "Driver Name",
                controller: nameController,
                hint: "Enter driver name",
              ),

              const SizedBox(height: 16),

              // PHONE NUMBER
              CustomTextField(
                label: "Phone Number",
                controller: phoneController,
                keyboard: TextInputType.phone,
                hint: "Enter phone number",
              ),

              const SizedBox(height: 24),

              // UPDATE BUTTON
              CustomButton(
                text: "Update",
                color: const Color(0xFF2196F3),
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    ToastHelper.showSnackBarToast(context, 
                      const SnackBar(
                        content: Text('Please enter driver name'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  final success = await ApiService.updateDriver(
                    driverId: widget.driverId,
                    name: nameController.text,
                    phone: phoneController.text.isNotEmpty
                        ? phoneController.text
                        : null,
                  );

                  if (!mounted) return;

                  if (success) {
                    ToastHelper.showSnackBarToast(context, 
                      const SnackBar(
                        content: Text('Driver updated successfully'),
                      ),
                    );
                    await _loadDriverDetails();
                  } else {
                    ToastHelper.showSnackBarToast(context, 
                      const SnackBar(
                        content: Text('Failed to update driver'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTransactionDialog(Map<String, dynamic> transaction) {
    final transactionId = transaction['id'];
    if (transactionId == null) return;

    final amountController = TextEditingController(
      text: transaction['amount']?.toString() ?? '0',
    );

    final type = transaction['type']?.toString() ?? 'got';
    final reason = transaction['reason']?.toString() ?? '';
    final note = transaction['note']?.toString() ?? '';
    final dateStr = transaction['date']?.toString() ?? '';

    DateTime selectedDate = DateTime.now();
    try {
      selectedDate = DateTime.parse(dateStr);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------------- HEADER ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Transaction',
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

                // ---------------- AMOUNT ----------------
                CustomTextField(
                  label: "Amount",
                  controller: amountController,
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffix: const Icon(Icons.currency_rupee),
                ),

                const SizedBox(height: 16),

                // ---------------- DATE ----------------
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setModalState(() => selectedDate = date);
                    }
                  },
                  child: AbsorbPointer(
                    child: CustomTextField(
                      label: "Date",
                      controller: TextEditingController(
                        text: DateFormat('dd MMM yyyy').format(selectedDate),
                      ),
                      suffix: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ---------------- UPDATE BUTTON ----------------
                CustomButton(
                  text: "Update",
                  onPressed: () async {
                    if (amountController.text.isEmpty) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(content: Text('Please enter amount')),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    final success = await ApiService.updateDriverTransaction(
                      driverId: widget.driverId,
                      transactionId: transactionId,
                      type: type,
                      amount: double.parse(amountController.text),
                      reason: reason,
                      date: DateFormat('yyyy-MM-dd').format(selectedDate),
                      note: note,
                    );

                    if (!mounted) return;

                    if (success) {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(
                          content: Text('Transaction updated successfully'),
                        ),
                      );
                      await _loadDriverDetails();
                    } else {
                      ToastHelper.showSnackBarToast(context, 
                        const SnackBar(
                          content: Text('Failed to update transaction'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,

        // ðŸ”¥ Rounded Bottom Shape like CustomAppBar
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),

        titleSpacing: 0,

        title: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(context),
            ),

            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 24,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            // Name + Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'call':
                  _callDriver();
                  break;
                case 'edit':
                  _showEditDriverDialog();
                  break;
                case 'delete':
                  _confirmDeleteDriver();
                  break;
                case 'settle':
                  _showSettleAmountDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'call',
                enabled: _driverDetails?['phone']?.toString().isNotEmpty ?? false,
                child: Row(
                  children: [
                    Icon(Icons.phone,
                        size: 20,
                        color: (_driverDetails?['phone']?.toString().isNotEmpty ??
                            false)
                            ? Colors.black87
                            : Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      'Call Driver',
                      style: TextStyle(
                        color:
                        (_driverDetails?['phone']?.toString().isNotEmpty ?? false)
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Edit Driver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete Driver', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settle',
                child: Row(
                  children: [
                    Icon(Icons.payment, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Settle Amount'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoader())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Balance Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: 'Collect from driver  ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '₹${_balance.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primaryGreen,        // ðŸ”¥ green amount
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              OutlinedButton(
                                onPressed: _showSettleAmountDialog,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.info,
                                  side: const BorderSide(color: AppColors.textDisabled, width: 1),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Settle Amount',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // View Report Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DriverReportScreen(
                                      driverId: widget.driverId,
                                      driverName: widget.driverName,
                                    ),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.picture_as_pdf, color: AppColors.info),
                                  SizedBox(width: 8),
                                  Text(
                                    'View Report',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Headers
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.grey.shade100,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'REASON',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'DRIVER GAVE',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'DRIVER GOT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              body: _transactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDriverDetails,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
                    ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: FloatingActionButton.extended(
                onPressed: _showDriverGaveDialog,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                heroTag: 'driverGave',
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 22),
                label: const Text(
                  'Driver Gave',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FloatingActionButton.extended(
                onPressed: _showDriverGotDialog,
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                heroTag: 'driverGot',
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                label: const Text(
                  'Driver Got',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    final phoneNumber = _driverDetails?['phone']?.toString() ?? '';
    if (phoneNumber.isEmpty) {
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ToastHelper.showSnackBarToast(context, 
            const SnackBar(content: Text('Cannot make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('Error making phone call')),
        );
      }
    }
  }

  void _confirmDeleteDriver() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),

        title: const Text(
          'Delete Driver',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        content: const Text(
          'Are you sure you want to delete this driver? This action marks the driver as deleted but preserves their transaction history.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),

        actionsPadding: const EdgeInsets.only(bottom: 12, right: 12, left: 12),

        actions: [
          // CANCEL BUTTON
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // DELETE BUTTON
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ApiService.deleteDriver(
                driverId: widget.driverId,
              );

              if (!mounted) return;

              if (success) {
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(
                    content: Text('Driver deleted successfully'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                Navigator.pop(context, true);
              } else {
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(
                    content: Text('Failed to delete driver'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionOptions(Map<String, dynamic> transaction) {
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
              'Transaction Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // ---- EDIT ----
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showEditTransactionDialog(transaction);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.orange.shade50,
                ),
                child: Row(
                  children: const [
                    Icon(Icons.edit, color: Colors.orange, size: 22),
                    SizedBox(width: 12),
                    Text(
                      "Edit Transaction",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ---- DELETE ----
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTransaction(transaction);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.shade50,
                ),
                child: Row(
                  children: const [
                    Icon(Icons.delete, color: Colors.red, size: 22),
                    SizedBox(width: 12),
                    Text(
                      "Delete Transaction",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTransaction(Map<String, dynamic> transaction) {
    final transactionId = transaction['id'];
    if (transactionId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),

        title: const Text(
          'Delete Transaction',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        content: const Text(
          'Are you sure you want to delete this transaction? The driver balance will be recalculated.',
          style: TextStyle(fontSize: 14),
        ),

        actionsPadding: const EdgeInsets.only(bottom: 12, right: 12, left: 12),

        actions: [
          // CANCEL
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // DELETE BUTTON (custom button style)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ApiService.deleteDriverTransaction(
                driverId: widget.driverId,
                transactionId: transactionId,
              );

              if (!mounted) return;

              if (success) {
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(content: Text('Transaction deleted successfully')),
                );
                await _loadDriverDetails();
              } else {
                ToastHelper.showSnackBarToast(context, 
                  const SnackBar(content: Text('Failed to delete transaction')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final reason = transaction['reason']?.toString() ?? '';
    final type = transaction['type']?.toString() ?? '';
    final amount = double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0.0;
    final dateStr = transaction['date']?.toString() ?? '';

    String formattedDate = dateStr;
    try {
      final date = DateTime.parse(dateStr);
      formattedDate = DateFormat('dd MMM').format(date);
    } catch (e) {
      // Keep original format
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTransactionOptions(transaction),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              type == 'gave' ? '₹${amount.toStringAsFixed(0)}' : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              type == 'got' ? '₹${amount.toStringAsFixed(0)}' : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:  AppColors.primaryGreen,
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



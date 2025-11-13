import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';

class DocumentsBookScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;

  const DocumentsBookScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
  });

  @override
  State<DocumentsBookScreen> createState() => _DocumentsBookScreenState();
}

class _DocumentsBookScreenState extends State<DocumentsBookScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;

  final List<String> documentTypes = [
    'Insurance',
    'RC Permit',
    'Registration Certificate',
    'National Permit',
    'Road Tax',
    'Fitness Certificate',
    'Driver\'s License',
    'Pollution Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final documents = await ApiService.getDocuments(widget.truckId);
    setState(() {
      _documents = documents;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documents Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.truckNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Manage vehicle documents and get expiry reminders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Documents List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDocuments,
                    child: _documents.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.description, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No documents added yet',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () => _showAddDocumentBottomSheet(null),
                                      child: const Text('Add First Document'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              final doc = _documents[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: doc['status'] == 'Active'
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.description,
                                      color: doc['status'] == 'Active'
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                      size: 28,
                                    ),
                                  ),
                                  title: Text(
                                    doc['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (doc['documentNumber'] != null)
                                        Text(
                                          'No: ${doc['documentNumber']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (doc['expiryDate'] != null)
                                        Text(
                                          'Expiry: ${doc['expiryDate']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: doc['status'] == 'Active'
                                          ? Colors.green
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      doc['status'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    // View document details
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDocumentBottomSheet(null),
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: const Text(
          'Add Document',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAddDocumentBottomSheet(int? index) {
    final TextEditingController expiryController = TextEditingController();
    final TextEditingController policyController = TextEditingController();
    final TextEditingController issueDateController = TextEditingController();
    String? selectedDocType;
    DateTime? selectedDate;
    DateTime? selectedIssueDate;
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDocType != null
                            ? 'Add $selectedDocType'
                            : 'Add Document',
                        style: const TextStyle(
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
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Truck Info
                      const Text(
                        'Truck Info.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.truckNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Document Type Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedDocType,
                        decoration: InputDecoration(
                          labelText: 'Document Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        items: documentTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setModalState(() {
                            selectedDocType = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Issue Date
                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedIssueDate = picked;
                              issueDateController.text = DateFormat('dd-MM-yyyy').format(picked);
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: issueDateController,
                            decoration: InputDecoration(
                              labelText: 'Issue Date',
                              hintText: 'Eg: 25-08-2020 - Optional',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Eg : 25 - 08 - 2020 - Optional',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Expiry Date
                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2050),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDate = picked;
                              expiryController.text = DateFormat('dd-MM-yyyy').format(picked);
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: expiryController,
                            decoration: InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'Eg: 25-08-2021',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Eg : 25 - 08 - 2021',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Policy Number
                      TextField(
                        controller: policyController,
                        decoration: InputDecoration(
                          labelText: 'Enter Policy No',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Add Photo Button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (image != null) {
                            setModalState(() {
                              selectedImage = File(image.path);
                            });
                          }
                        },
                        icon: Icon(Icons.add_a_photo, color: Colors.blue.shade700),
                        label: Text(
                          selectedImage == null ? 'Add Photo' : 'Photo Added',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue.shade700),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validate required fields
                            if (selectedDocType == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a document type'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (expiryController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select an expiry date'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (policyController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a policy number'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Format dates to yyyy-MM-dd
                            String? formattedIssueDate;
                            if (selectedIssueDate != null) {
                              formattedIssueDate = DateFormat('yyyy-MM-dd').format(selectedIssueDate!);
                            }

                            String formattedExpiryDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

                            try {
                              // Call API to add document
                              final result = await ApiService.addDocument(
                                truckId: widget.truckId,
                                name: selectedDocType!,
                                documentNumber: policyController.text,
                                issueDate: formattedIssueDate,
                                expiryDate: formattedExpiryDate,
                                imagePath: selectedImage?.path,
                                status: 'Active',
                              );

                              if (result != null) {
                                // Success - reload documents and close bottom sheet
                                Navigator.pop(context);
                                await _loadDocuments();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$selectedDocType added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                // Error from API
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to add document. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              // Handle exceptions
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExpenseDialog(int index) {
    final TextEditingController expenseDateController = TextEditingController();
    final TextEditingController expenseAmountController = TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    DateTime selectedExpenseDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add ${documentTypes[index]} Expense',
                        style: const TextStyle(
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
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Truck Info
                      const Text(
                        'Truck Info.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.truckNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Expense Date
                      GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedExpenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedExpenseDate = picked;
                              expenseDateController.text = DateFormat('dd-MM-yyyy').format(picked);
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: expenseDateController,
                            decoration: InputDecoration(
                              labelText: 'Expense Date',
                              hintText: 'Select date',
                              suffixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Expense Amount
                      TextField(
                        controller: expenseAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Expense Amount',
                          hintText: 'Enter amount',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Remarks
                      TextField(
                        controller: remarksController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Remarks (Optional)',
                          hintText: 'Enter remarks',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (expenseDateController.text.isNotEmpty &&
                                expenseAmountController.text.isNotEmpty) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${documentTypes[index]} expense of ₹${expenseAmountController.text} added',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill date and amount'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Expense',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

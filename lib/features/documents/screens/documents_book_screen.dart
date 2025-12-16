import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import '../../../services/api_service.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

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

  // Show document details dialog
  void _showDocumentDetailsDialog(Map<String, dynamic> doc) {
    final nameController = TextEditingController(text: doc['name'] ?? '');
    final documentNumberController = TextEditingController(text: doc['document_number'] ?? '');
    DateTime? issueDate;
    DateTime? expiryDate;
    String selectedStatus = doc['status'] ?? 'Active';
    bool isEditing = false;

    // Parse dates
    if (doc['issue_date'] != null) {
      try {
        issueDate = DateTime.parse(doc['issue_date']);
      } catch (e) {}
    }
    if (doc['expiry_date'] != null) {
      try {
        expiryDate = DateTime.parse(doc['expiry_date']);
      } catch (e) {}
    }

    // Get image URL
    String? imageUrl;
    if (doc['image_url'] != null) {
      imageUrl = '${AppConstants.serverUrl}${doc['image_url']}';
    } else if (doc['image_path'] != null) {
      imageUrl = '${AppConstants.serverUrl}/api/v1/documents/file/${doc['image_path']}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                    Text(
                      isEditing ? 'Edit Document' : 'Document Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (!isEditing)
                          IconButton(
                            onPressed: () {
                              setModalState(() => isEditing = true);
                            },
                            icon: const Icon(Icons.edit, color: AppColors.info),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Image
                      if (imageUrl != null)
                        GestureDetector(
                          onTap: () => _showFullImage(imageUrl!),
                          child: Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text('Image not available', style: TextStyle(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            ),
                          ),
                        ),
                      if (imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tap image to view full size',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Document Name
                      const Text('Document Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        )
                      else
                        Text(
                          doc['name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),

                      const SizedBox(height: 16),

                      // Document Number
                      const Text('Document Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        TextField(
                          controller: documentNumberController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        )
                      else
                        Text(
                          doc['document_number'] ?? 'Not provided',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),

                      const SizedBox(height: 16),

                      // Issue Date
                      const Text('Issue Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: issueDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() => issueDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  issueDate != null
                                      ? DateFormat('dd MMM yyyy').format(issueDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    color: issueDate != null ? Colors.black : Colors.grey,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          issueDate != null
                              ? DateFormat('dd MMM yyyy').format(issueDate!)
                              : 'Not provided',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),

                      const SizedBox(height: 16),

                      // Expiry Date
                      const Text('Expiry Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() => expiryDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  expiryDate != null
                                      ? DateFormat('dd MMM yyyy').format(expiryDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    color: expiryDate != null ? Colors.black : Colors.grey,
                                  ),
                                ),
                                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          expiryDate != null
                              ? DateFormat('dd MMM yyyy').format(expiryDate!)
                              : 'Not provided',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),

                      const SizedBox(height: 16),

                      // Status
                      const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      if (isEditing)
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: ['Active', 'Expired', 'Expiring Soon'].map((status) {
                            return DropdownMenuItem(value: status, child: Text(status));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => selectedStatus = value);
                            }
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: doc['status'] == 'Active' ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            doc['status'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Save/Delete buttons (when editing)
                      if (isEditing) ...[
                        ElevatedButton(
                          onPressed: () async {
                            // Save document
                            final result = await ApiService.updateDocument(
                              documentId: doc['id'],
                              name: nameController.text,
                              documentNumber: documentNumberController.text,
                              issueDate: issueDate != null
                                  ? DateFormat('yyyy-MM-dd').format(issueDate!)
                                  : null,
                              expiryDate: expiryDate != null
                                  ? DateFormat('yyyy-MM-dd').format(expiryDate!)
                                  : null,
                              status: selectedStatus,
                            );

                            if (result != null) {
                              Navigator.pop(context);
                              await _loadDocuments();
                              if (mounted) {
                                ToastHelper.showSnackBarToast(context,
                                  const SnackBar(
                                    content: Text('Document updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              ToastHelper.showSnackBarToast(context,
                                const SnackBar(
                                  content: Text('Failed to update document'),
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
                          child: const Text('Save Changes'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () async {
                            // Confirm delete
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Document'),
                                content: const Text('Are you sure you want to delete this document?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final result = await ApiService.deleteDocument(doc['id']);
                              if (result) {
                                Navigator.pop(context);
                                await _loadDocuments();
                                if (mounted) {
                                  ToastHelper.showSnackBarToast(context,
                                    const SnackBar(
                                      content: Text('Document deleted'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                ToastHelper.showSnackBarToast(context,
                                  const SnackBar(
                                    content: Text('Failed to delete document'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Delete Document'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show full screen image
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark background
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black87),
            ),
            // Image
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Format date string helper
  String _formatDateString(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Confirm delete document
  Future<void> _confirmDeleteDocument(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final docId = doc['id'] as int?;
      if (docId != null) {
        final success = await ApiService.deleteDocument(docId);
        if (success) {
          await _loadDocuments();
          if (mounted) {
            ToastHelper.showSnackBarToast(context,
              const SnackBar(
                content: Text('Document deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ToastHelper.showSnackBarToast(context,
              const SnackBar(
                content: Text('Failed to delete document'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  // Show edit document dialog
  void _showEditDocumentDialog(Map<String, dynamic> doc) {
    final nameController = TextEditingController(text: doc['name'] ?? '');
    final documentNumberController = TextEditingController(text: doc['document_number'] ?? '');
    DateTime? issueDate;
    DateTime? expiryDate;
    String selectedStatus = doc['status'] ?? 'Active';

    // Parse dates
    if (doc['issue_date'] != null) {
      try {
        issueDate = DateTime.parse(doc['issue_date'].toString());
      } catch (e) {}
    }
    if (doc['expiry_date'] != null) {
      try {
        expiryDate = DateTime.parse(doc['expiry_date'].toString());
      } catch (e) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
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
                    Text(
                      'Edit ${doc['name']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Truck Info
                      Text('Truck: ${widget.truckNumber}', style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 16),

                      // Document Type
                      const Text('Document Type', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Document Number
                      const Text('Document Number', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: documentNumberController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Issue Date
                      const Text('Issue Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: issueDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setModalState(() => issueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                issueDate != null ? DateFormat('dd MMM yyyy').format(issueDate!) : 'Select date',
                                style: TextStyle(color: issueDate != null ? Colors.black : Colors.grey),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Expiry Date
                      const Text('Expiry Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setModalState(() => expiryDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate!) : 'Select date',
                                style: TextStyle(color: expiryDate != null ? Colors.black : Colors.grey),
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status
                      const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ['Active', 'Expired', 'Expiring Soon'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) { if (v != null) setModalState(() => selectedStatus = v); },
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton(
                        onPressed: () async {
                          final result = await ApiService.updateDocument(
                            documentId: doc['id'],
                            name: nameController.text,
                            documentNumber: documentNumberController.text,
                            issueDate: issueDate != null ? DateFormat('yyyy-MM-dd').format(issueDate!) : null,
                            expiryDate: expiryDate != null ? DateFormat('yyyy-MM-dd').format(expiryDate!) : null,
                            status: selectedStatus,
                          );

                          if (result != null) {
                            Navigator.pop(context);
                            await _loadDocuments();
                            if (mounted) {
                              ToastHelper.showSnackBarToast(context,
                                const SnackBar(
                                  content: Text('Document updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            ToastHelper.showSnackBarToast(context,
                              const SnackBar(
                                content: Text('Failed to update document'),
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
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                fontWeight: FontWeight.w700,
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
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: AppColors.info,
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
                ? const Center(child: AppLoader())
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
                              final status = doc['status']?.toString() ?? 'Active';
                              final expiryDate = doc['expiry_date'] ?? doc['expiryDate'];
                              final documentNumber = doc['document_number'] ?? doc['documentNumber'];

                              // Get image URL
                              String? imageUrl;
                              if (doc['image_url'] != null) {
                                imageUrl = '${AppConstants.serverUrl}${doc['image_url']}';
                              } else if (doc['image_path'] != null) {
                                imageUrl = '${AppConstants.serverUrl}/api/v1/documents/file/${doc['image_path']}';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
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
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Document Image
                                    GestureDetector(
                                      onTap: imageUrl != null ? () => _showFullImage(imageUrl!) : null,
                                      child: Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: imageUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(7),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Icon(
                                                    Icons.description,
                                                    color: Colors.grey.shade400,
                                                    size: 32,
                                                  ),
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Icon(
                                                Icons.description,
                                                color: Colors.grey.shade400,
                                                size: 32,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Document Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  doc['name'] ?? 'Unknown',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: status == 'Active' ? Colors.green : Colors.red,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (documentNumber != null)
                                            Text(
                                              'No: $documentNumber',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          if (expiryDate != null)
                                            Text(
                                              'Expiry: ${_formatDateString(expiryDate.toString())}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Action Buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => _showDocumentDetailsDialog(doc),
                                          icon: const Icon(Icons.visibility, color: AppColors.info, size: 20),
                                          tooltip: 'View',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                        IconButton(
                                          onPressed: () => _showEditDocumentDialog(doc),
                                          icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                          tooltip: 'Edit',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmDeleteDocument(doc),
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Delete',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                      ],
                                    ),
                                  ],
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
        backgroundColor: AppColors.info,
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
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
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
                          color: AppColors.info,
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
                            final bytes = await image.readAsBytes();
                            setModalState(() {
                              selectedImage = image;
                              selectedImageBytes = bytes;
                            });
                          }
                        },
                        icon: Icon(Icons.add_a_photo, color: AppColors.info),
                        label: Text(
                          selectedImageBytes == null ? 'Add Photo' : 'Photo Added',
                          style: TextStyle(color: AppColors.info),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.info),
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
                              ToastHelper.showSnackBarToast(context, 
                                const SnackBar(
                                  content: Text('Please select a document type'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (expiryController.text.isEmpty) {
                              ToastHelper.showSnackBarToast(context, 
                                const SnackBar(
                                  content: Text('Please select an expiry date'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (policyController.text.isEmpty) {
                              ToastHelper.showSnackBarToast(context, 
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
                                imageBytes: selectedImageBytes,
                                fileName: selectedImage?.name,
                                status: 'Active',
                              );

                              if (result != null) {
                                // Success - reload documents and close bottom sheet
                                Navigator.pop(context);
                                await _loadDocuments();

                                if (context.mounted) {
                                  ToastHelper.showSnackBarToast(context, 
                                    SnackBar(
                                      content: Text('$selectedDocType added successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                // Error from API
                                if (context.mounted) {
                                  ToastHelper.showSnackBarToast(context, 
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
                                ToastHelper.showSnackBarToast(context, 
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
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
                          color: AppColors.info,
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
                              ToastHelper.showSnackBarToast(context, 
                                SnackBar(
                                  content: Text(
                                    '${documentTypes[index]} expense of ₹${expenseAmountController.text} added',
                                  ),
                                ),
                              );
                            } else {
                              ToastHelper.showSnackBarToast(context, 
                                const SnackBar(
                                  content: Text('Please fill date and amount'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
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



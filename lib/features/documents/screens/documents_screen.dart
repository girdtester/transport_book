import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
import 'add_document_screen.dart';
import 'package:transport_book_app/utils/app_loader.dart';
import 'package:transport_book_app/utils/toast_helper.dart';

class DocumentsScreen extends StatefulWidget {
  final int truckId;
  final String truckNumber;

  const DocumentsScreen({
    super.key,
    required this.truckId,
    required this.truckNumber,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<dynamic> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    final documents = await ApiService.getDocuments(widget.truckId);
    setState(() {
      _documents = documents;
      _isLoading = false;
    });
  }

  // Get image URL helper
  String? _getImageUrl(Map<String, dynamic> doc) {
    if (doc['image_url'] != null) {
      return '${AppConstants.serverUrl}${doc['image_url']}';
    } else if (doc['image_path'] != null) {
      return '${AppConstants.serverUrl}/api/v1/documents/file/${doc['image_path']}';
    }
    return null;
  }

  // Format date helper
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Show document details dialog with view/edit
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

    String? imageUrl = _getImageUrl(doc);

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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        if (!isEditing)
                          IconButton(
                            onPressed: () => setModalState(() => isEditing = true),
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
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text('Image not available', style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
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
                          child: Text('Tap image to view full size', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                        Text(doc['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),

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
                        Text(doc['document_number'] ?? 'Not provided', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),

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
                        )
                      else
                        Text(
                          issueDate != null ? DateFormat('dd MMM yyyy').format(issueDate!) : 'Not provided',
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
                        )
                      else
                        Text(
                          expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate!) : 'Not provided',
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
                          items: ['Active', 'Expired', 'Expiring Soon'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) { if (v != null) setModalState(() => selectedStatus = v); },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: doc['status'] == 'Active' ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(doc['status'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),

                      const SizedBox(height: 24),

                      // Save/Delete buttons
                      if (isEditing) ...[
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
                                ToastHelper.showSnackBarToast(context, const SnackBar(content: Text('Document updated'), backgroundColor: Colors.green));
                              }
                            } else {
                              ToastHelper.showSnackBarToast(context, const SnackBar(content: Text('Failed to update'), backgroundColor: Colors.red));
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
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Document'),
                                content: const Text('Are you sure?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final result = await ApiService.deleteDocument(doc['id']);
                              if (result) {
                                Navigator.pop(context);
                                await _loadDocuments();
                                if (mounted) {
                                  ToastHelper.showSnackBarToast(context, const SnackBar(content: Text('Document deleted'), backgroundColor: Colors.green));
                                }
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
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(color: Colors.black87)),
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load', style: TextStyle(color: Colors.white))),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 32)),
            ),
          ],
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
              'Documents',
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
          // Documents List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoader())
                : _documents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No documents uploaded',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to add documents',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          final bool isActive = doc['status'] == 'Active';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Document Image Preview
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _showDocumentDetailsDialog(doc),
                                    child: Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.grey.shade100,
                                            Colors.grey.shade200,
                                          ],
                                        ),
                                      ),
                                      child: _getImageUrl(doc) != null
                                          ? Image.network(
                                              _getImageUrl(doc)!,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                            loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Icon(
                                                    Icons.insert_drive_file,
                                                    size: 72,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.insert_drive_file,
                                                size: 72,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                // Document Info
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Document Name and Status Badge
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              doc['name'] ?? 'Document',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1a1a1a),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? const Color(0xFFE8F5E9)
                                                  : const Color(0xFFFFEBEE),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              isActive ? 'Active' : 'Expired',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFC62828),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Document Number
                                      if (doc['document_number'] != null &&
                                          doc['document_number'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.numbers,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'No: ${doc['document_number']}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Issue Date
                                      if (doc['issue_date'] != null &&
                                          doc['issue_date'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.event_note,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Issued: ${_formatDate(doc['issue_date'])}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Expiry Date
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event_available,
                                            size: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Expiry: ${doc['expiry_date'] != null ? _formatDate(doc['expiry_date']) : 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Add Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDocumentScreen(
                        truckId: widget.truckId,
                        truckNumber: widget.truckNumber,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadDocuments();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text(
                  'Add Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


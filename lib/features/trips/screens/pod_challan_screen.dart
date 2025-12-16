import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:transport_book_app/utils/app_colors.dart';

import '../../../services/api_service.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class PODChallanScreen extends StatefulWidget {
  final int tripId;
  final String? truckNumber;

  const PODChallanScreen({
    super.key,
    required this.tripId,
    this.truckNumber,
  });

  @override
  State<PODChallanScreen> createState() => _PODChallanScreenState();
}

class _PODChallanScreenState extends State<PODChallanScreen> {
  bool _isLoading = false;
  bool _isLoadingPhotos = true;
  List<String> _existingPODs = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingPODs();
  }

  Future<void> _loadExistingPODs() async {
    setState(() {
      _isLoadingPhotos = true;
    });
    try {
      final photos = await ApiService.getPODPhotos(widget.tripId);
      if (mounted) {
        setState(() {
          _existingPODs = photos;
          _isLoadingPhotos = false;
        });
      }
    } catch (e) {
      print('Error loading POD photos: $e');
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isLoading = true;
      });

      // Read image bytes for cross-platform support
      final Uint8List imageBytes = await image.readAsBytes();

      final result = await ApiService.uploadPODPhotos(
        tripId: widget.tripId,
        imageBytesList: [imageBytes],
        fileNames: [image.name],
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        ToastHelper.showSnackBarToast(context,
          const SnackBar(content: Text('POD uploaded successfully')),
        );

        await _loadExistingPODs();

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        ToastHelper.showSnackBarToast(context,
          const SnackBar(content: Text('Failed to upload POD')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ToastHelper.showSnackBarToast(context,
        SnackBar(content: Text('Error uploading POD: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
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
          children: [
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.info),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.info),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl, int index) {
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
            // Image with zoom
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Image counter
            Positioned(
              top: 50,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${index + 1} / ${_existingPODs.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.only(right: 8.0, left: 16.0, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'POD/Delivery Challan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22, color: Colors.black54),
                ),
              ],
            ),
          ),

          Divider(
            color: Colors.grey.shade300,
            thickness: 1,
            height: 1,
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _isLoadingPhotos
                ? const SizedBox(
                    height: 150,
                    child: Center(child: AppLoader()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Show uploaded PODs if available
                      if (_existingPODs.isNotEmpty) ...[
                        const Text(
                          'Uploaded POD/Challans',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _existingPODs.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _showFullScreenImage(_existingPODs[index], index),
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          _existingPODs[index],
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.error, color: Colors.red),
                                          ),
                                        ),
                                        // View icon overlay
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                      ],

                      // Upload section - show empty state if no photos
                      if (_existingPODs.isEmpty) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 70,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No POD/Challan uploaded yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your trip POD/Delivery Challan here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Upload button
                      Center(
                        child: SizedBox(
                          width: _existingPODs.isNotEmpty ? 160 : 180,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showImageSourceDialog,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: AppLoader(strokeWidth: 2),
                                  )
                                : Icon(
                                    _existingPODs.isNotEmpty ? Icons.add : Icons.cloud_upload,
                                    size: 18,
                                    color: AppColors.info,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Uploading...'
                                  : _existingPODs.isNotEmpty
                                      ? 'Add More'
                                      : 'Upload POD',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.info,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textWhite,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: AppColors.info.withOpacity(0.5),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

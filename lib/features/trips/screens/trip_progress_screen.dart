import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';

class TripProgressScreen extends StatefulWidget {
  final Map<String, dynamic> tripDetails;
  final VoidCallback? onUpdate;

  const TripProgressScreen({
    super.key,
    required this.tripDetails,
    this.onUpdate,
  });

  @override
  State<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends State<TripProgressScreen> {
  late Map<String, dynamic> _trip;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _podPhotos = [];
  List<String> _startPhotos = [];

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.tripDetails);
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    try {
      // Load POD photos from API
      final tripId = _trip['id'];
      print('DEBUG: Loading photos for trip ID: $tripId');

      if (tripId != null) {
        final podPhotos = await ApiService.getPODPhotos(tripId);
        print('DEBUG: POD photos from API: $podPhotos');

        if (mounted) {
          setState(() {
            _podPhotos = podPhotos;
          });
        }
      }

      // Also check if photos are in trip details
      final tripPodPhotos = _getPodPhotosFromTrip();
      print('DEBUG: POD photos from trip details: $tripPodPhotos');

      if (tripPodPhotos.isNotEmpty && _podPhotos.isEmpty) {
        // Convert trip photos to full URLs
        final convertedPhotos = tripPodPhotos.map((p) => _getFullUrl(p)).toList();
        print('DEBUG: Converted trip photos: $convertedPhotos');
        setState(() {
          _podPhotos = convertedPhotos;
        });
      }

      print('DEBUG: Final POD photos list: $_podPhotos');
    } catch (e) {
      print('Error loading photos: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int get _currentStatus {
    final status = _trip['status'];
    if (status == null) return 1;
    if (status is int) return status;
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'load in progress':
        case '1':
          return 1;
        case 'in progress':
        case 'started':
        case '2':
          return 2;
        case 'completed':
        case '3':
          return 3;
        case 'pod received':
        case '4':
          return 4;
        case 'pod submitted':
        case '5':
          return 5;
        case 'settled':
        case '6':
          return 6;
        default:
          return 1;
      }
    }
    return 1;
  }

  num _parseNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      if (date is String) {
        final parsed = DateTime.parse(date);
        return DateFormat('dd MMM yyyy').format(parsed);
      }
      return '';
    } catch (e) {
      return date.toString();
    }
  }

  List<String> _getPodPhotosFromTrip() {
    final photos = _trip['podPhotos'] ?? _trip['pod_photos'];
    if (photos == null) return [];
    if (photos is String) {
      try {
        final decoded = json.decode(photos);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        return [];
      }
    }
    if (photos is List) {
      return photos.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> _pickAndUploadPhoto(String stage) async {
    try {
      // Show option to pick from camera or gallery
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final tripId = _trip['id'];

      if (stage == 'pod' && tripId != null) {
        print('DEBUG: Uploading POD photo for trip ID: $tripId');
        print('DEBUG: Image bytes length: ${bytes.length}');

        // Upload POD photo
        final result = await ApiService.uploadPODPhotos(
          tripId: tripId,
          imageBytesList: [bytes],
          fileNames: ['pod_${DateTime.now().millisecondsSinceEpoch}.jpg'],
        );

        print('DEBUG: Upload result: $result');

        if (result != null) {
          // Reload photos
          await _loadPhotos();
          widget.onUpdate?.call();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('POD photo uploaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload photo'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (stage == 'start') {
        // For start photos - store locally for now
        // You can add a similar API endpoint for start photos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start photo captured')),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deletePhoto(String photoUrl, String stage) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      if (stage == 'pod') {
        // Remove from local list
        setState(() {
          _podPhotos.remove(photoUrl);
        });

        // TODO: Add API call to delete photo from server
        // await ApiService.deletePODPhoto(tripId, photoUrl);

        widget.onUpdate?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting photo: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  void _showFullImage(String imageUrl) {
    final fullUrl = _getFullUrl(imageUrl);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.close, color: Colors.black),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFullUrl(String url) {
    if (url.startsWith('http')) return url;

    // Get base URL without /api/v1
    final serverUrl = ApiService.baseUrl.replaceAll('/api/v1', '');

    // Handle different URL formats
    if (url.startsWith('/api/v1/')) {
      // URL like /api/v1/trips/1/pod-photos/file/abc.jpg
      return '$serverUrl$url';
    } else if (url.startsWith('/uploads')) {
      // URL like /uploads/pod_photos/trip_1/abc.jpg
      return '$serverUrl$url';
    } else if (url.startsWith('uploads/')) {
      // URL like uploads/pod_photos/trip_1/abc.jpg
      return '$serverUrl/$url';
    } else {
      // Fallback - assume it's a relative path
      return '$serverUrl/uploads/$url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final partyName = _trip['partyName'] ?? _trip['party_name'] ?? 'Unknown';
    final truckNumber = _trip['truckNumber'] ?? _trip['truck_number'] ?? '';
    final driverName = _trip['driverName'] ?? _trip['driver_name'] ?? '';
    final originName = _trip['originName'] ?? _trip['origin_name'] ?? '';
    final destinationName = _trip['destinationName'] ?? _trip['destination_name'] ?? '';
    final freightAmount = _trip['freightAmount'] ?? _trip['freight_amount'] ?? 0;
    final partyBalance = _trip['partyBalance'] ?? _trip['party_balance'] ?? 0;

    final startDate = _trip['startDate'] ?? _trip['start_date'];
    final tripStartDate = _trip['tripStartDate'] ?? _trip['trip_start_date'];
    final tripEndDate = _trip['tripEndDate'] ?? _trip['trip_end_date'];
    final podReceivedDate = _trip['podReceivedDate'] ?? _trip['pod_received_date'];
    final podSubmittedDate = _trip['podSubmittedDate'] ?? _trip['pod_submitted_date'];
    final settleDate = _trip['settleDate'] ?? _trip['settle_date'];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.info,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPhotos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Trip Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Party/Customer Name', partyName, isBold: true),
                        const SizedBox(height: 12),
                        _buildInfoRow('Truck No.', truckNumber, valueColor: AppColors.info),
                        const SizedBox(height: 12),
                        _buildInfoRow('Driver Name', driverName),
                        const SizedBox(height: 12),

                        // Route
                        const Text(
                          'Route',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey, width: 2),
                                  ),
                                ),
                                Container(width: 2, height: 30, color: Colors.grey.shade300),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey, width: 2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          originName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        '• ${_formatDate(startDate)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          destinationName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        '• ${_formatDate(tripEndDate ?? startDate)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Freight Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '₹${NumberFormat('#,##,###').format(_parseNumber(freightAmount))}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Party Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '₹${NumberFormat('#,##,###').format(_parseNumber(partyBalance))}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _parseNumber(partyBalance) > 0 ? AppColors.info : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Timeline Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Started
                        _buildTimelineStep(
                          title: 'Started',
                          date: tripStartDate ?? startDate,
                          isCompleted: _currentStatus >= 2,
                          isFirst: true,
                          photos: _startPhotos,
                          showCamera: _currentStatus >= 2,
                          stage: 'start',
                        ),

                        // Completed
                        _buildTimelineStep(
                          title: 'Completed',
                          date: tripEndDate,
                          isCompleted: _currentStatus >= 3,
                        ),

                        // POD Received
                        _buildTimelineStep(
                          title: 'POD Received',
                          date: podReceivedDate,
                          isCompleted: _currentStatus >= 4,
                          photos: _podPhotos,
                          showCamera: _currentStatus >= 4,
                          stage: 'pod',
                        ),

                        // POD Submitted
                        _buildTimelineStep(
                          title: 'POD Submitted',
                          date: podSubmittedDate,
                          isCompleted: _currentStatus >= 5,
                        ),

                        // Settled
                        _buildTimelineStep(
                          title: 'Settled',
                          date: settleDate,
                          isCompleted: _currentStatus >= 6,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    dynamic date,
    required bool isCompleted,
    bool isFirst = false,
    bool isLast = false,
    List<String>? photos,
    bool showCamera = false,
    String? stage,
  }) {
    final hasPhotos = photos != null && photos.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: hasPhotos ? 100 : (showCamera && isCompleted ? 80 : 50),
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (date != null && isCompleted)
                    Text(
                      _formatDate(date),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                ],
              ),

              // Photos section
              if (hasPhotos) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...photos!.map((photo) => _buildPhotoThumbnail(photo, stage ?? '')),
                    if (showCamera && stage != null)
                      _buildCameraButton(() => _pickAndUploadPhoto(stage)),
                  ],
                ),
              ] else if (showCamera && isCompleted && stage != null) ...[
                const SizedBox(height: 12),
                _buildCameraButton(() => _pickAndUploadPhoto(stage)),
              ],

              SizedBox(height: isLast ? 0 : 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoThumbnail(String photoUrl, String stage) {
    final fullUrl = _getFullUrl(photoUrl);

    return GestureDetector(
      onTap: () => _showFullImage(photoUrl),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fullUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => _deletePhoto(photoUrl, stage),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraButton(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.info, width: 2),
          color: Colors.white,
        ),
        child: Icon(Icons.add_a_photo_outlined, color: AppColors.info, size: 28),
      ),
    );
  }

  Widget? _buildBottomButton() {
    String? buttonText;
    VoidCallback? onPressed;

    if (_currentStatus == 4) {
      buttonText = 'Mark POD Submitted';
      onPressed = () => _updateStatus(5);
    } else if (_currentStatus == 5) {
      buttonText = 'Mark Settled';
      onPressed = () => _showSettleDialog();
    } else if (_currentStatus == 3) {
      buttonText = 'Mark POD Received';
      onPressed = () => _updateStatus(4);
    } else if (_currentStatus == 2) {
      buttonText = 'Mark Completed';
      onPressed = () => _updateStatus(3);
    } else if (_currentStatus == 1) {
      buttonText = 'Start Trip';
      onPressed = () => _updateStatus(2);
    }

    if (buttonText == null) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            buttonText,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(int newStatus) async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.updateTripStatus(_trip['id'], newStatus);

      if (result != null) {
        final now = DateTime.now().toIso8601String().split('T')[0];
        setState(() {
          _trip['status'] = newStatus;
          if (newStatus == 2) _trip['tripStartDate'] = now;
          if (newStatus == 3) _trip['tripEndDate'] = now;
          if (newStatus == 4) _trip['podReceivedDate'] = now;
          if (newStatus == 5) _trip['podSubmittedDate'] = now;
        });
        widget.onUpdate?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  void _showSettleDialog() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please settle from Trip Details screen')),
    );
  }
}

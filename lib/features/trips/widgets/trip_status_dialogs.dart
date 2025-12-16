import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';

/// Reusable trip status update dialogs
class TripStatusDialogs {
  /// Get the next action button text based on current status
  static String? getNextActionText(String currentStatus) {
    switch (currentStatus) {
      case 'Load in Progress':
        return 'Start';
      case 'In Progress':
        return 'Complete';
      case 'Completed':
        return 'POD Received';
      case 'POD Received':
        return 'POD Submitted';
      case 'POD Submitted':
        return 'Settle';
      default:
        return null;
    }
  }
  /// Show Start Trip Dialog
  static void showStartTripDialog(
    BuildContext context, {
    required int tripId,
    required VoidCallback onSuccess,
  }) {
    DateTime selectedDate = DateTime.now();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Start Trip',
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

                // Trip Start Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Trip Start Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final success = await ApiService.startTrip(
                          tripId: tripId,
                          tripStartDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                        );

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        if (success) {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Trip started successfully')),
                          );
                          onSuccess();
                        } else {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Failed to start trip')),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ToastHelper.showSnackBarToast(context, 
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Trip',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }

  /// Show Complete Trip Dialog
  static void showCompleteTripDialog(
    BuildContext context, {
    required int tripId,
    required VoidCallback onSuccess,
  }) {
    DateTime selectedDate = DateTime.now();
    final kmController = TextEditingController();

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Complete Trip',
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

                  // Trip End Date
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Trip End Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Total KM
                  TextField(
                    controller: kmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total KM (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final success = await ApiService.completeTrip(
                            tripId: tripId,
                            tripEndDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                            totalKm: kmController.text.isNotEmpty ? kmController.text : null,
                          );

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          if (success) {
                            ToastHelper.showSnackBarToast(context, 
                              const SnackBar(content: Text('Trip completed successfully')),
                            );
                            onSuccess();
                          } else {
                            ToastHelper.showSnackBarToast(context, 
                              const SnackBar(content: Text('Failed to complete trip')),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ToastHelper.showSnackBarToast(context, 
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Complete Trip',
                        style: TextStyle(
                          color: Colors.white,
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

  /// Show POD Received Dialog
  static void showPODReceivedDialog(
    BuildContext context, {
    required int tripId,
    required VoidCallback onSuccess,
  }) {
    DateTime selectedDate = DateTime.now();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'POD Received',
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

                // POD Received Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'POD Received Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final success = await ApiService.podReceived(
                          tripId: tripId,
                          podReceivedDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                          podPhotosBytes: [], // Empty list for quick status update without photos
                        );

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        if (success) {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('POD marked as received')),
                          );
                          onSuccess();
                        } else {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Failed to mark POD as received')),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ToastHelper.showSnackBarToast(context, 
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Mark POD Received',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }

  /// Show POD Submitted Dialog
  static void showPODSubmittedDialog(
    BuildContext context, {
    required int tripId,
    required VoidCallback onSuccess,
  }) {
    DateTime selectedDate = DateTime.now();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'POD Submitted',
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

                // POD Submitted Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'POD Submitted Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final success = await ApiService.podSubmitted(
                          tripId: tripId,
                          podSubmittedDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                        );

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        if (success) {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('POD marked as submitted')),
                          );
                          onSuccess();
                        } else {
                          ToastHelper.showSnackBarToast(context, 
                            const SnackBar(content: Text('Failed to mark POD as submitted')),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ToastHelper.showSnackBarToast(context, 
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Mark POD Submitted',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }

  /// Show appropriate status dialog based on current status
  static void showStatusUpdateDialog(
    BuildContext context, {
    required int tripId,
    required String currentStatus,
    required VoidCallback onSuccess,
  }) {
    switch (currentStatus) {
      case 'Load in Progress':
        showStartTripDialog(context, tripId: tripId, onSuccess: onSuccess);
        break;
      case 'In Progress':
        showCompleteTripDialog(context, tripId: tripId, onSuccess: onSuccess);
        break;
      case 'Completed':
        showPODReceivedDialog(context, tripId: tripId, onSuccess: onSuccess);
        break;
      case 'POD Received':
        showPODSubmittedDialog(context, tripId: tripId, onSuccess: onSuccess);
        break;
      case 'POD Submitted':
        // Show settle dialog (you can add this later)
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('Go to trip details to settle this trip')),
        );
        break;
      default:
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('Cannot update status')),
        );
    }
  }
}


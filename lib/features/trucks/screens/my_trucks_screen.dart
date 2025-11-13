import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/validators.dart';
import '../../../utils/truck_number_formatter.dart';
import 'truck_details_screen.dart';

class MyTrucksScreen extends StatefulWidget {
  const MyTrucksScreen({super.key});

  @override
  State<MyTrucksScreen> createState() => _MyTrucksScreenState();
}

class _MyTrucksScreenState extends State<MyTrucksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All Trucks';

  List<Map<String, dynamic>> trucks = [];
  List<Map<String, dynamic>> filteredTrucks = [];
  List<dynamic> allDocuments = [];
  Map<String, List<Map<String, dynamic>>> groupedDocuments = {};
  bool _isLoading = true;
  DateTime _lastRefreshed = DateTime.now();

  final List<String> documentTypes = [
    'Insurance',
    'Fitness Certificate',
    'National Permit',
    'RC Permit',
    'Road Tax',
    'Pollution Certificate',
    'Registration Certificate',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrucks();
    _loadAllDocuments();
  }

  Future<void> _loadTrucks() async {
    setState(() {
      _isLoading = true;
    });

    final trucksData = await ApiService.getTrucks();
    setState(() {
      trucks = List<Map<String, dynamic>>.from(
          trucksData.map((truck) => Map<String, dynamic>.from(truck)));
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    // First filter by status
    List<Map<String, dynamic>> tempTrucks;
    if (_selectedFilter == 'All Trucks') {
      tempTrucks = trucks;
    } else if (_selectedFilter == 'Available Trucks') {
      tempTrucks = trucks.where((truck) {
        final status = (truck['status'] ?? '').toString().toLowerCase();
        return status == 'available' || status.isEmpty;
      }).toList();
    } else if (_selectedFilter == 'Trucks On Trip') {
      tempTrucks = trucks.where((truck) {
        final status = (truck['status'] ?? '').toString().toLowerCase();
        return status.contains('trip') || status == 'on trip';
      }).toList();
    } else {
      tempTrucks = trucks;
    }

    // Then apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filteredTrucks = tempTrucks.where((truck) {
        final truckNumber = (truck['number'] ?? '').toString().toLowerCase();
        return truckNumber.contains(searchQuery);
      }).toList();
    } else {
      filteredTrucks = tempTrucks;
    }
  }

  int get _allTrucksCount => trucks.length;

  int get _availableTrucksCount {
    return trucks.where((truck) {
      final status = (truck['status'] ?? '').toString().toLowerCase();
      return status == 'available' || status.isEmpty;
    }).length;
  }

  int get _trucksOnTripCount {
    return trucks.where((truck) {
      final status = (truck['status'] ?? '').toString().toLowerCase();
      return status.contains('trip') || status == 'on trip';
    }).length;
  }

  Future<void> _loadAllDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documents = await ApiService.getAllDocuments();
      final trucksData = await ApiService.getTrucks();

      // Create a map of truck_id to truck number
      final truckIdToNumber = <int, String>{};
      for (var truck in trucksData) {
        truckIdToNumber[truck['id']] = truck['number'];
      }

      // Group documents by document type with truck info
      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var doc in documents) {
        final docType = doc['name']?.toString() ?? 'Other';
        // Backend returns snake_case
        final truckId = doc['truck_id'] as int?;
        final truckNumber = truckIdToNumber[truckId] ?? 'Unknown';

        // Add truck number to document and normalize field names
        final docWithTruck = Map<String, dynamic>.from(doc);
        docWithTruck['truckNumber'] = truckNumber;
        // Ensure camelCase fields are available for UI
        docWithTruck['truckId'] = truckId;
        docWithTruck['expiryDate'] = doc['expiry_date'];
        docWithTruck['issueDate'] = doc['issue_date'];
        docWithTruck['documentNumber'] = doc['document_number'];

        if (!grouped.containsKey(docType)) {
          grouped[docType] = [];
        }
        grouped[docType]!.add(docWithTruck);
      }

      setState(() {
        allDocuments = documents;
        groupedDocuments = grouped;
        _lastRefreshed = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading documents: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDocuments() async {
    await _loadAllDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trucks & Documents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryGreen,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.appBarTextColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Trucks'),
                Tab(text: 'Documents'),
              ],
            ),
          ),
          // TabBarView with content for each tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Trucks Tab
                Column(
                  children: [
                    // Filter Cards
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildFilterCard(
                              'All Trucks',
                              _allTrucksCount.toString(),
                              isSelected: _selectedFilter == 'All Trucks',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFilterCard(
                              'Available Trucks',
                              _availableTrucksCount.toString(),
                              isSelected: _selectedFilter == 'Available Trucks',
                              textColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFilterCard(
                              'Trucks On Trip',
                              _trucksOnTripCount.toString(),
                              isSelected: _selectedFilter == 'Trucks On Trip',
                              textColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _applyFilters();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by Truck Number',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          suffixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    // Truck List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredTrucks.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No trucks found',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredTrucks.length,
                                  itemBuilder: (context, index) {
                                    return _buildTruckCard(filteredTrucks[index]);
                                  },
                                ),
                    ),
                  ],
                ),
                // Documents Tab
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTruckBottomSheet(context),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, size: 22),
        label: const Text(
          'ADD TRUCK',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFilterCard(String label, String count,
      {bool isSelected = false, Color? textColor}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primaryGreen : (textColor ?? Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckCard(Map<String, dynamic> truck) {
    // Determine status color
    Color statusColor = AppColors.primaryGreen;
    String statusText = truck['status'] ?? 'Available';

    if (statusText.toLowerCase().contains('trip')) {
      statusColor = Colors.blue;
    } else if (statusText.toLowerCase().contains('maintenance')) {
      statusColor = Colors.orange;
    } else if (statusText.toLowerCase().contains('inactive')) {
      statusColor = Colors.red;
    }

    // Determine type badge color
    bool isOwn = truck['type'] == 'Own';
    Color typeColor = isOwn ? const Color(0xFF2196F3) : const Color(0xFFFF9800);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TruckDetailsScreen(
              truckId: truck['id'],
              truckNumber: truck['number'],
            ),
          ),
        );
        // Reload trucks when returning from truck details
        _loadTrucks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
          children: [
            // Truck Number and Badge
            Expanded(
              child: Row(
                children: [
                  // Truck Number
                  Text(
                    truck['number'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      truck['type'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status and Location Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (truck['location'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    truck['location'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(width: 8),

            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // Refresh Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documents Refreshed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last Updated at ${_lastRefreshed.day.toString().padLeft(2, '0')}-${_lastRefreshed.month.toString().padLeft(2, '0')}-${_lastRefreshed.year.toString().substring(2)}, ${_lastRefreshed.hour.toString().padLeft(2, '0')}:${_lastRefreshed.minute.toString().padLeft(2, '0')} ${_lastRefreshed.hour >= 12 ? 'PM' : 'AM'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _refreshDocuments,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Documents List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : groupedDocuments.isEmpty
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
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: documentTypes.length,
                        itemBuilder: (context, index) {
                          final docType = documentTypes[index];
                          final docs = groupedDocuments[docType] ?? [];

                          if (docs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          // Count document statuses
                          int expired = 0;
                          int expiringSoon = 0;
                          int allOk = 0;

                          for (var doc in docs) {
                            final status = doc['status']?.toString() ?? 'Active';
                            if (status == 'Expired') {
                              expired++;
                            } else if (status == 'Expiring Soon') {
                              expiringSoon++;
                            } else {
                              allOk++;
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Document Type Header
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            docType,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              // TODO: Navigate to view all documents of this type
                                            },
                                            child: const Row(
                                              children: [
                                                Text(
                                                  'View all Documents',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF2196F3),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 12,
                                                  color: Color(0xFF2196F3),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Status badges
                                      Row(
                                        children: [
                                          if (expired > 0)
                                            Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.red.shade50,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        expired.toString(),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.red.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Expired',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (expiringSoon > 0)
                                            Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.orange.shade50,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        expiringSoon.toString(),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.orange.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Expiring soon',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (allOk > 0)
                                            Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.green.shade50,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        allOk.toString(),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'All Ok',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600,
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
                                const Divider(height: 1),
                                // Trucks list
                                ...docs.map((doc) {
                                  final truckNumber = doc['truckNumber']?.toString() ?? 'Unknown';
                                  return InkWell(
                                    onTap: () => _showDocumentDetailPopup(doc),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey.shade200),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            truckNumber,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.grey.shade400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDocumentDetailPopup(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and action buttons
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc['name']?.toString() ?? 'Document',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Navigate to edit document screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit document feature coming soon')),
                    );
                  },
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Document'),
                        content: const Text('Are you sure you want to delete this document?'),
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
                      Navigator.pop(context);
                      final docId = doc['id'] as int?;
                      if (docId != null) {
                        final success = await ApiService.deleteDocument(docId);
                        if (success) {
                          await _loadAllDocuments();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Document deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to delete document'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Document ID not found'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Expiry date
            Text(
              'Expiring on ${doc['expiryDate'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            // View all documents link
            GestureDetector(
              onTap: () {
                // TODO: Navigate to all documents of this truck
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Viewing all documents of ${doc['truckNumber']}')),
                );
              },
              child: Row(
                children: [
                  Text(
                    'View all Documents of ${doc['truckNumber']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF2196F3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Add Photo button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement add photo
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add photo feature coming soon')),
                );
              },
              icon: const Icon(Icons.add_a_photo, color: Color(0xFF2196F3)),
              label: const Text('Add Photo', style: TextStyle(color: Color(0xFF2196F3))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2196F3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Download and Share buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement download
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Download feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement share
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddTruckBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTruckBottomSheet(
        onTruckAdded: () {
          _loadTrucks(); // Reload trucks after adding
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class AddTruckBottomSheet extends StatefulWidget {
  final VoidCallback onTruckAdded;

  const AddTruckBottomSheet({super.key, required this.onTruckAdded});

  @override
  State<AddTruckBottomSheet> createState() => _AddTruckBottomSheetState();
}

class _AddTruckBottomSheetState extends State<AddTruckBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _registrationController = TextEditingController();
  String _selectedType = 'My Truck';
  String? _selectedSupplier;
  bool _isLoading = false;
  String? _validationError;

  List<String> suppliers = [
    'Satish Supplier',
    'Ram Supplier',
    'Krishna Transport',
  ];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final suppliersData = await ApiService.getSuppliers();
    setState(() {
      suppliers = suppliersData
          .map((supplier) => supplier['name'] as String)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    controller: _registrationController,
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
                      errorText: _validationError,
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
                      setState(() {
                        _validationError = validateTruckNumber(value);
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
                  // Truck Type Selection
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'My Truck',
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                          },
                          title: const Text('My Truck'),
                          activeColor: Colors.purple,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          value: 'Market Truck',
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                          },
                          title: const Text('Market Truck'),
                          activeColor: Colors.purple,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  // Supplier Selection (shown when Market Truck is selected)
                  if (_selectedType == 'Market Truck') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Supplier/Truck Owner',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showSupplierOptions(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedSupplier ?? 'Select Supplier',
                              style: TextStyle(
                                color: _selectedSupplier == null
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Confirm Button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            // Validate form
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }

                            if (_selectedType == 'Market Truck' &&
                                _selectedSupplier == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a supplier'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isLoading = true;
                            });

                            // Format truck number before saving
                            final formattedNumber = Validators.formatTruckNumber(
                              _registrationController.text,
                            );

                            final result = await ApiService.addTruck(
                              number: formattedNumber,
                              type: _selectedType == 'My Truck' ? 'Own' : 'Market',
                              supplier: _selectedSupplier,
                            );

                            setState(() {
                              _isLoading = false;
                            });

                            if (result != null) {
                              widget.onTruckAdded();
                              Navigator.pop(context);
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
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
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
        ],
      ),
    );
  }

  void _showSupplierOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Supplier',
                  style: TextStyle(
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
          ),
          const Divider(height: 1),
          // Add New Supplier
          ListTile(
            leading: Icon(Icons.add_circle, color: AppColors.primaryGreen),
            title: Text(
              'Add New Supplier',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAddSupplierSheet(context);
            },
          ),
          // Select from Contacts
          ListTile(
            leading: const Icon(Icons.contacts, color: Colors.blue),
            title: const Text('Select from Contacts'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact picker feature')),
              );
            },
          ),
          const Divider(),
          // Existing Suppliers
          ...suppliers.map((supplier) => ListTile(
                title: Text(supplier),
                onTap: () {
                  setState(() {
                    _selectedSupplier = supplier;
                  });
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddSupplierSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Supplier',
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
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Supplier Name*',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number*',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        phoneController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all fields'),
                        ),
                      );
                      return;
                    }

                    final result = await ApiService.addSupplier(
                      name: nameController.text,
                      phone: phoneController.text,
                    );

                    if (result != null) {
                      setState(() {
                        suppliers.add(nameController.text);
                        _selectedSupplier = nameController.text;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Supplier added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to add supplier'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Save'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _registrationController.dispose();
    super.dispose();
  }
}

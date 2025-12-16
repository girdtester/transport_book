import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transport_book_app/utils/appbar.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_constants.dart';
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

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedFilter != 'All Trucks') count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  bool _hasActiveFilters() {
    return _getActiveFiltersCount() > 0;
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'All Trucks';
      _searchController.clear();
    });
    _applyFilters();
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
      appBar:CustomAppBar(title: "Trucks & Documents",onBack: () {
        Navigator.pop(context);
      },),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.info,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.info,
              unselectedLabelColor:AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterCard(
                              'Available Trucks',
                              _availableTrucksCount.toString(),
                              isSelected: _selectedFilter == 'Available Trucks',
                              textColor: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterCard(
                              'Trucks On Trip',
                              _trucksOnTripCount.toString(),
                              isSelected: _selectedFilter == 'Trucks On Trip',
                              textColor: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          suffixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    // Filter Applied Banner
                    if (_hasActiveFilters())
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: AppColors.info.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_getActiveFiltersCount()} Filter${_getActiveFiltersCount() == 1 ? '' : 's'} has been applied',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _clearFilters,
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
        icon: const Icon(Icons.add, size: 24),
        label: const Text(
          'ADD TRUCK',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.info : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppColors.textPrimary,
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
      statusColor = AppColors.info;
    } else if (statusText.toLowerCase().contains('maintenance')) {
      statusColor = AppColors.badgeMarket;
    } else if (statusText.toLowerCase().contains('inactive')) {
      statusColor =AppColors.error;
    }

    // Determine type badge color
    bool isOwn = truck['type'] == 'Own';
    Color typeColor = isOwn ?  AppColors.info: AppColors.badgeMarket;

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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Truck Number and Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Truck Number
                  Text(
                    truck['number'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Type Badge BELOW the number
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      truck['type'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last Updated at ${_lastRefreshed.day.toString().padLeft(2, '0')}-${_lastRefreshed.month.toString().padLeft(2, '0')}-${_lastRefreshed.year.toString().substring(2)}, ${_lastRefreshed.hour.toString().padLeft(2, '0')}:${_lastRefreshed.minute.toString().padLeft(2, '0')} ${_lastRefreshed.hour >= 12 ? 'PM' : 'AM'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _refreshDocuments,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:AppColors.info,
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
                      color: AppColors.textSecondary,
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
                                    fontWeight: FontWeight.w600,
                                    color:AppColors.textPrimary,
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
                                          color: AppColors.info,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color:AppColors.info
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
                      // Trucks list with images and action buttons
                      ...docs.map((doc) {
                        final truckNumber = doc['truckNumber']?.toString() ?? 'Unknown';
                        final status = doc['status']?.toString() ?? 'Active';
                        final expiryDate = doc['expiry_date'] ?? doc['expiryDate'];

                        // Get image URL
                        String? imageUrl;
                        if (doc['image_url'] != null) {
                          imageUrl = '${AppConstants.serverUrl}${doc['image_url']}';
                        } else if (doc['image_path'] != null) {
                          imageUrl = '${AppConstants.serverUrl}/api/v1/documents/file/${doc['image_path']}';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
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
                                              return Center(
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
                                        Text(
                                          truckNumber,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                    if (expiryDate != null)
                                      Text(
                                        'Expiry: ${_formatDateString(expiryDate.toString())}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    if (doc['document_number'] != null || doc['documentNumber'] != null)
                                      Text(
                                        'No: ${doc['document_number'] ?? doc['documentNumber']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Action Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // View Button
                                  IconButton(
                                    onPressed: () => _showDocumentDetailPopup(doc),
                                    icon: const Icon(Icons.visibility, color: AppColors.info, size: 20),
                                    tooltip: 'View',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  // Edit Button
                                  IconButton(
                                    onPressed: () => _showEditDocumentDialog(doc),
                                    icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                    tooltip: 'Edit',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  // Delete Button
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

  // Format date string helper
  String _formatDateString(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
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
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black87),
            ),
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
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

  // Confirm delete document
  Future<void> _confirmDeleteDocument(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc['name']}" for ${doc['truckNumber']}?'),
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
          await _loadAllDocuments();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
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
    final documentNumberController = TextEditingController(text: doc['document_number'] ?? doc['documentNumber'] ?? '');
    DateTime? issueDate;
    DateTime? expiryDate;
    String selectedStatus = doc['status'] ?? 'Active';

    // Parse dates
    final issueDateStr = doc['issue_date'] ?? doc['issueDate'];
    final expiryDateStr = doc['expiry_date'] ?? doc['expiryDate'];
    if (issueDateStr != null) {
      try {
        issueDate = DateTime.parse(issueDateStr.toString());
      } catch (e) {}
    }
    if (expiryDateStr != null) {
      try {
        expiryDate = DateTime.parse(expiryDateStr.toString());
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
                      Text('Truck: ${doc['truckNumber']}', style: TextStyle(color: Colors.grey.shade600)),
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
                            await _loadAllDocuments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Document updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
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

  void _showDocumentDetailPopup(Map<String, dynamic> doc) {
    // Get image URL
    String? imageUrl;
    if (doc['image_url'] != null) {
      imageUrl = '${AppConstants.serverUrl}${doc['image_url']}';
    } else if (doc['image_path'] != null) {
      imageUrl = '${AppConstants.serverUrl}/api/v1/documents/file/${doc['image_path']}';
    }

    final expiryDate = doc['expiry_date'] ?? doc['expiryDate'];
    final issueDate = doc['issue_date'] ?? doc['issueDate'];
    final documentNumber = doc['document_number'] ?? doc['documentNumber'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                children: [
                  Expanded(
                    child: Text(
                      doc['name']?.toString() ?? 'Document',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDocumentDialog(doc);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteDocument(doc);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No image uploaded', style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),

                    if (imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Tap image to view full size', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),

                    const SizedBox(height: 20),

                    // Document Details
                    _buildDetailRow('Truck', doc['truckNumber'] ?? 'Unknown'),
                    _buildDetailRow('Document Type', doc['name'] ?? 'Unknown'),
                    if (documentNumber != null) _buildDetailRow('Document Number', documentNumber.toString()),
                    if (issueDate != null) _buildDetailRow('Issue Date', _formatDateString(issueDate.toString())),
                    if (expiryDate != null) _buildDetailRow('Expiry Date', _formatDateString(expiryDate.toString())),
                    _buildDetailRow('Status', doc['status'] ?? 'Active'),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDocumentDialog(doc);
                            },
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            label: const Text('Edit', style: TextStyle(color: Colors.orange)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteDocument(doc);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddTruckBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTruckBottomSheet(
        preselectedType: _tabController.index == 0 ? 'Own' : 'Market',
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
  final String? preselectedType; // 'Own' or 'Market'

  const AddTruckBottomSheet({super.key, required this.onTruckAdded, this.preselectedType});

  @override
  State<AddTruckBottomSheet> createState() => _AddTruckBottomSheetState();
}

class _AddTruckBottomSheetState extends State<AddTruckBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _registrationController = TextEditingController();
  late String _selectedType;
  String? _selectedSupplier;
  bool _isLoading = false;
  bool _isSuppliersLoading = true;
  String? _validationError;

  List<Map<String, dynamic>> _suppliersData = [];
  List<String> suppliers = [];

  @override
  void initState() {
    super.initState();
    // Map 'Own' -> 'My Truck', 'Market' -> 'Market Truck'
    if (widget.preselectedType == 'Own') {
      _selectedType = 'My Truck';
    } else if (widget.preselectedType == 'Market') {
      _selectedType = 'Market Truck';
    } else {
      _selectedType = 'My Truck'; // Default
    }
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isSuppliersLoading = true;
    });

    try {
      final suppliersData = await ApiService.getSuppliers();
      if (mounted) {
        setState(() {
          _suppliersData = List<Map<String, dynamic>>.from(suppliersData);
          suppliers = suppliersData
              .where((supplier) => supplier['name'] != null)
              .map((supplier) => supplier['name'].toString())
              .toList();
          _isSuppliersLoading = false;
        });
      }
    } catch (e) {
      print('Error loading suppliers: $e');
      if (mounted) {
        setState(() {
          _isSuppliersLoading = false;
        });
      }
    }
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1,color: AppColors.divider,),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registration Number Input
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
                      hintText: 'Truck Registration No.*',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      errorText: _validationError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color:AppColors.info, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color:AppColors.info, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
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
                    'ex:KA01AB1234',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Truck Type Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'My Truck',
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                            activeColor: Colors.purple,
                          ),
                          const Text('My Truck'),
                        ],
                      ),

                      const SizedBox(width: 20), // adjust spacing as needed

                      Row(
                        children: [
                          Radio<String>(
                            value: 'Market Truck',
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                            activeColor: Colors.purple,
                          ),
                          const Text('Market Truck'),
                        ],
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
                        color: AppColors.textSecondary,
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
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
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
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
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
                leading: const Icon(Icons.contacts, color: AppColors.info),
                title: const Text('Select from Contacts'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact picker feature')),
                  );
                },
              ),
              const Divider(),
              // Show loading or suppliers list
              if (_isSuppliersLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (suppliers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No suppliers found.\nAdd a new supplier to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = suppliers[index];
                      return ListTile(
                        title: Text(supplier),
                        onTap: () {
                          setState(() {
                            _selectedSupplier = supplier;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
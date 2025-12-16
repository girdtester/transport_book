import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import 'package:transport_book_app/utils/custom_textfield.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import 'driver_detail_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class DriverKhataScreen extends StatefulWidget {
  const DriverKhataScreen({super.key});

  @override
  State<DriverKhataScreen> createState() => _DriverKhataScreenState();
}

class _DriverKhataScreenState extends State<DriverKhataScreen> {
  List<dynamic> _allDrivers = [];
  List<dynamic> _filteredDrivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  double _totalBalance = 0.0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _openingBalanceController = TextEditingController();
  bool _enableSMS = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final drivers = await ApiService.getDrivers();
      double total = 0.0;
      for (var driver in drivers) {
        final balance = double.tryParse(driver['balance']?.toString() ?? '0') ?? 0.0;
        total += balance;
      }

      setState(() {
        _allDrivers = drivers;
        _filteredDrivers = drivers;
        _totalBalance = total;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading drivers: $e')),
        );
      }
    }
  }

  void _filterDrivers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredDrivers = _allDrivers;
      } else {
        final searchLower = query.toLowerCase();
        _filteredDrivers = _allDrivers.where((driver) {
          final name = driver['name']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower);
        }).toList();
      }
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(int index) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF3D5A99),
      const Color(0xFF4CAF50),
      const Color(0xFFFF8C00),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[index % colors.length];
  }

  Future<void> _pickFromContacts() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null) {
            setState(() {
              _nameController.text = fullContact.displayName;
              if (fullContact.phones.isNotEmpty) {
                _phoneController.text = fullContact.phones.first.number;
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error picking contact: $e');
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(content: Text('Error accessing contacts')),
        );
      }
    }
  }

  void _showAddDriverDialog() {
    _nameController.clear();
    _phoneController.clear();
    _openingBalanceController.clear();
    _enableSMS = false;

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
                // ---------- HEADER ----------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Driver',
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

                // ---------- NAME + CONTACT PICKER ----------
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: "Driver Name",
                        hint: "Name *",
                        controller: _nameController,
                        onChanged: (value) {
                          setModalState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Contact Button
                    IconButton(
                      onPressed: () async {
                        await _pickFromContacts();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.contacts),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.info.withOpacity(0.1),
                        foregroundColor: AppColors.info,
                        padding: const EdgeInsets.all(16),
                      ),
                      tooltip: 'Pick from contacts',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ---------- PHONE FIELD ----------
                CustomTextField(
                  label: "Mobile No.",
                  hint: "Enter mobile number",
                  controller: _phoneController,
                  keyboard: TextInputType.phone,
                ),

                const SizedBox(height: 8),
                Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------- OPENING BALANCE BUTTON ----------
                OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Add Opening Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        content: CustomTextField(
                          label: "Opening Balance",
                          hint: "Enter amount",
                          controller: _openingBalanceController,
                          keyboard: TextInputType.number,
                          suffix: const Icon(Icons.currency_rupee),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Add',
                              style: TextStyle(color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: const BorderSide(color: AppColors.info),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Add Opening Balance'),
                ),

                const SizedBox(height: 16),

                // ---------- SMS ENABLE ----------
                Row(
                  children: [
                    Checkbox(
                      value: _enableSMS,
                      onChanged: (value) {
                        setModalState(() {
                          _enableSMS = value ?? false;
                        });
                      },
                      activeColor: AppColors.info,
                    ),
                    const Text('Enable SMS for transactions'),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------- SAVE BUTTON ----------
                CustomButton(
                  text: "Save Driver",
                  color: _nameController.text.isEmpty
                      ? Colors.grey.shade400
                      : AppColors.info,
                  onPressed: _nameController.text.isEmpty
                      ? () {}
                      : () async {
                    final name = _nameController.text;
                    final phone = _phoneController.text;
                    final openingBalance = double.tryParse(
                      _openingBalanceController.text,
                    ) ??
                        0.0;

                    Navigator.pop(context);

                    final result = await ApiService.addDriver(
                      name: name,
                      phone: phone,
                      openingBalance: openingBalance,
                      enableSMS: _enableSMS,
                    );

                    if (result != null) {
                      _loadDrivers();
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Driver added successfully'),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text('Error adding driver'),
                          ),
                        );
                      }
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
     appBar: CustomAppBar(title: 'Drivers',onBack: () => Navigator.pop(context),),
      body: Column(
        children: [
          // Total Driver Balance Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Total Driver Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.formatWithSymbol(_totalBalance.toInt()),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.appBarColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _filterDrivers,
              decoration: InputDecoration(
                hintText: 'Search by Driver Name',
                hintStyle: TextStyle(color: Colors.grey[400]),
                suffixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DRIVER NAME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'BALANCE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Driver List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoader())
                : _filteredDrivers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No drivers found'
                                  : 'No drivers match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDrivers,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = _filteredDrivers[index];
                            return _buildDriverCard(driver, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDriverDialog,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_sharp, size: 22),
        label: const Text(
          'Add Driver',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver, int index) {
    final balance = double.tryParse(driver['balance']?.toString() ?? '0') ?? 0.0;
    final driverId = driver['id'] ?? 0;
    final driverName = driver['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDetailScreen(
                driverId: driverId,
                driverName: driverName,
              ),
            ),
          ).then((_) => _loadDrivers()); // Reload drivers when coming back
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarColor(index),
              child: Text(
                _getInitials(driverName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                driverName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              CurrencyFormatter.formatWithSymbol(balance.toInt()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}



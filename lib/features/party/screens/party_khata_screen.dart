import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import 'package:transport_book_app/utils/custom_textfield.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/currency_formatter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../services/api_service.dart';
import 'party_detail_screen.dart';
import 'party_balance_report_screen.dart';
import '../../invoices/widgets/create_invoice_helper.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class PartyKhataScreen extends StatefulWidget {
  const PartyKhataScreen({super.key});

  @override
  State<PartyKhataScreen> createState() => _PartyKhataScreenState();
}

class _PartyKhataScreenState extends State<PartyKhataScreen> {
  List<dynamic> _allParties = [];
  List<dynamic> _filteredParties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  double _totalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    try {
      final parties = await ApiService.getParties();
      print('=== PARTIES DATA ===');
      print('Number of parties: ${parties.length}');
      for (var party in parties) {
        print('Party: ${party['name']}, Balance: ${party['balance']} (type: ${party['balance'].runtimeType})');
      }
      setState(() {
        _allParties = parties;
        _filteredParties = parties;
        _totalBalance = parties.fold(
          0.0,
          (sum, party) => sum + (double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0),
        );
        print('Total Balance: $_totalBalance');
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading parties: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error loading parties: $e')),
        );
      }
    }
  }

  void _filterParties(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredParties = _allParties;
      } else {
        final searchLower = query.toLowerCase();
        _filteredParties = _allParties.where((party) {
          final name = party['name']?.toString().toLowerCase() ?? '';
          final phone = party['phone']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower) || phone.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showAddPartyDialog() {
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
              const Text(
                'Add Party',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _addPartyManually();
                },
                icon: const Icon(Icons.edit),
                label: const Text('Add Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickFromContacts();
                },
                icon: const Icon(Icons.contacts),
                label: const Text('Select from Contacts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E8B57),
                  side: const BorderSide(color: Color(0xFF2E8B57)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPartyManually() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();

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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ---------------- HEADER ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Add Party Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.close, size: 24, color: Colors.black54),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ---------------- PARTY NAME ----------------
                  CustomTextField(
                    label: "Party Name *",
                    controller: nameController,
                    hint: "Enter party name",
                  ),

                  const SizedBox(height: 16),

                  // ---------------- PHONE NUMBER ----------------
                  CustomTextField(
                    label: "Phone Number *",
                    controller: phoneController,
                    hint: "10-digit number",
                    keyboard: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(height: 16),

                  // ---------------- EMAIL ----------------
                  CustomTextField(
                    label: "Email",
                    controller: emailController,
                    hint: "Optional",
                    keyboard: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  // ---------------- ADDRESS ----------------
                  CustomTextField(
                    label: "Address",
                    controller: addressController,
                    hint: "Optional",
                    maxLines: 2,
                  ),

                  const SizedBox(height: 24),

                  // ---------------- SUBMIT BUTTON ----------------
                  CustomButton(
                    text: "Add Party",
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          phoneController.text.isEmpty) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text("Name and Phone are required"),
                          ),
                        );
                        return;
                      }

                      final result = await ApiService.addParty(
                        name: nameController.text,
                        phone: "+91 ${phoneController.text}",
                        email: emailController.text.isEmpty
                            ? null
                            : emailController.text,
                        address: addressController.text.isEmpty
                            ? null
                            : addressController.text,
                      );

                      if (result != null && mounted) {
                        Navigator.pop(context);
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text("Party added successfully"),
                          ),
                        );
                        _loadParties();
                      } else if (mounted) {
                        ToastHelper.showSnackBarToast(context, 
                          const SnackBar(
                            content: Text("Failed to add party"),
                          ),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromContacts() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        if (!mounted) return;

        final selectedContact = await showDialog<Contact>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Contact'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2E8B57),
                      child: Text(
                        contact.displayName.isNotEmpty
                            ? contact.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(contact.displayName),
                    subtitle: Text(
                      contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : 'No phone',
                    ),
                    onTap: () => Navigator.pop(context, contact),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (selectedContact != null && mounted) {
          _addPartyFromContact(selectedContact);
        }
      } else {
        if (mounted) {
          ToastHelper.showSnackBarToast(context, 
            const SnackBar(content: Text('Contact permission denied')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(content: Text('Error accessing contacts: $e')),
        );
      }
    }
  }

  Future<void> _addPartyFromContact(Contact contact) async {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
    final address = contact.addresses.isNotEmpty ? contact.addresses.first.address : '';

    final result = await ApiService.addParty(
      name: contact.displayName,
      phone: phone,
      email: email.isEmpty ? null : email,
      address: address.isEmpty ? null : address,
    );

    if (result != null && mounted) {
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Party added from contact')),
      );
      _loadParties();
    } else if (mounted) {
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(content: Text('Failed to add party')),
      );
    }
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
      const Color(0xFFDC3545), // Red
      const Color(0xFF007BFF), // Blue
      const Color(0xFF6F42C1), // Purple
      const Color(0xFF28A745), // Green
      const Color(0xFFFD7E14), // Orange
      const Color(0xFF17A2B8), // Cyan
    ];
    return colors[index % colors.length];
  }

  Widget _buildPartyCard(Map<String, dynamic> party, int index) {
    final balance = double.tryParse(party['balance']?.toString() ?? '0') ?? 0.0;
    final partyName = party['name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PartyDetailScreen(
                partyId: party['id'] ?? 0,
                partyName: partyName,
              ),
            ),
          );

          // Reload parties if changes were made (or party was deleted)
          if (result == true || result == null) {
            await _loadParties();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with initials
              CircleAvatar(
                radius: 22,
                backgroundColor: _getAvatarColor(index),
                child: Text(
                  _getInitials(partyName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Party Name
              Expanded(
                child: Text(
                  partyName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              // Balance
              Text(
                CurrencyFormatter.formatWithSymbol(balance.toInt()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 22,
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
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Parties',
        onBack: () => Navigator.pop(context),
      ),

      body: Column(
        children: [
          // Total Balance Card
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
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Party Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatWithSymbol(_totalBalance.toInt()),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E8B57),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PartyBalanceReportScreen(
                          parties: _filteredParties,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics, size: 18),
                  label: const Text('View Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _filterParties,
              decoration: InputDecoration(
                hintText: 'Search by Party Name',
                hintStyle: TextStyle(color: Colors.grey[400]),
                suffixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  borderSide: const BorderSide(color: Color(0xFF2E8B57)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Column Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 36), // Space for avatar
                Expanded(
                  child: Text(
                    'PARTY/CUSTOMER NAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  'BALANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 30), // Space for chevron
              ],
            ),
          ),

          // Party List
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoader())
                : _filteredParties.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No parties found'
                                  : 'No parties match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: _filteredParties.length,
                        itemBuilder: (context, index) {
                          final party = _filteredParties[index];
                          return _buildPartyCard(party, index);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _showAddPartyDialog,
          backgroundColor: const Color(0xFF1E3A8A),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
          label: const Text(
            'Add Party',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}



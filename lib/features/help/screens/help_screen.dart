import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/custom_dropdown.dart';
import '../../../utils/appbar.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: CustomAppBar(
        title: 'Help & Guide',
        showBackButton: false,
        showDashboardLayout: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              controller: _tabController,
              labelColor: AppColors.info,
              unselectedLabelColor: Colors.grey.shade600,
              indicator: RoundedTabIndicator(
                color: AppColors.info,
                radius: 3,
              ),
              indicatorWeight: 3,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: EdgeInsets.zero,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Trucks'),
                Tab(text: 'Trips'),
                Tab(text: 'Suppliers'),
                Tab(text: 'Party'),
                Tab(text: 'Drivers'),
                Tab(text: 'Reports'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrucksHelp(),
                _buildTripsHelp(),
                _buildSuppliersHelp(),
                _buildPartyHelp(),
                _buildDriversHelp(),
                _buildReportsHelp(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrucksHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Managing Your Trucks'),
          _buildInfoCard(
            title: 'Adding a New Truck',
            steps: [
              'Navigate to "My Trucks" from the dashboard',
              'Tap the "+" button at the bottom right',
              'Enter truck details: Truck Number, Truck Type (Own/Market)',
              'Add truck capacity and other specifications',
              'Tap "Save" to add the truck to your fleet',
            ],
            icon: Icons.local_shipping,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Viewing Truck Details',
            steps: [
              'Go to "My Trucks" section',
              'Tap on any truck card to view details',
              'View trip history, revenue, and expenses',
              'Access the Trip Book for detailed records',
              'Manage documents from the Documents Book',
            ],
            icon: Icons.visibility,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          // Example with image asset instead of icon
          _buildInfoCard(
            title: 'Documents Management',
            steps: [
              'Open truck details and tap "Documents Book"',
              'Add documents: Insurance, RC, Permit, Fitness, etc.',
              'Upload photos of documents',
              'Set expiry dates for reminders',
              'Track document status (Active/Expired)',
            ],
            icon: Icons.description,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTripsHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Managing Trips'),
          _buildInfoCard(
            title: 'Creating a New Trip',
            steps: [
              'Tap "Add Trip" from the dashboard',
              'Select truck (Own or Market)',
              'Choose or add a party/customer',
              'Enter loading and unloading locations',
              'Set loading and unloading dates',
              'Enter freight amount and other charges',
              'For market trucks, add truck hire cost',
              'Tap "Save Trip" to create',
            ],
            icon: Icons.add_circle_outline,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Viewing Trips',
            steps: [
              'Go to "My Trips" to see all trips',
              'Filter by trip status (Active/Completed)',
              'View trip details by tapping on a trip card',
              'Check profit/loss for each trip',
              'Track payment status',
            ],
            icon: Icons.visibility_outlined,
            color: Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Managing Unpaid Trips',
            steps: [
              'Access "Unpaid Trips" from dashboard',
              'View all trips with pending payments',
              'Tap on a trip to mark as paid',
              'Add payment details and date',
              'Generate digital invoices for customers',
            ],
            icon: Icons.payment,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'POD (Proof of Delivery)',
            steps: [
              'Go to "POD due Trips" section',
              'View trips awaiting delivery confirmation',
              'Upload POD documents/photos',
              'Mark trip as delivered',
              'Track delivery timeline',
            ],
            icon: Icons.receipt_long,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Managing Suppliers'),
          _buildInfoCard(
            title: 'Adding a Supplier',
            steps: [
              'Navigate to "Supplier Khata" from dashboard',
              'Tap the "+" button to add new supplier',
              'Enter supplier name and contact details',
              'Add initial balance if any',
              'Save supplier information',
            ],
            icon: Icons.inventory_2,
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Recording Transactions',
            steps: [
              'Open "Supplier Khata"',
              'Select a supplier to view their account',
              'Add "You Gave" for payments made to supplier',
              'Add "You Got" for amounts received from supplier',
              'View running balance and transaction history',
            ],
            icon: Icons.receipt_long,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Supplier Reports',
            steps: [
              'Go to "Supplier Reports" section',
              'View total outstanding balances',
              'Filter suppliers by balance amount',
              'Generate supplier-wise statements',
              'Download reports for accounting',
            ],
            icon: Icons.assessment,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildPartyHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Managing Parties/Customers'),
          _buildInfoCard(
            title: 'Adding a Party',
            steps: [
              'Go to "Party Khata" from dashboard',
              'Tap "+" button to add new party',
              'Enter party name and contact information',
              'Add GST details if applicable',
              'Set credit limit if required',
              'Save party details',
            ],
            icon: Icons.person_add,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Managing Party Accounts',
            steps: [
              'Open "Party Khata" to view all parties',
              'Select a party to see their account',
              'View "You Gave" (payments made) entries',
              'View "You Got" (payments received) entries',
              'Check outstanding balance',
              'View trip history with the party',
            ],
            icon: Icons.account_balance_wallet,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Digital Invoices',
            steps: [
              'Access "Digital Invoice" from Party section',
              'Select trips to include in invoice',
              'Add party and billing details',
              'Review invoice preview',
              'Generate and share PDF invoice',
              'Track invoice payment status',
            ],
            icon: Icons.receipt_long,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Collection Reminders',
            steps: [
              'Set up reminders for payment collection',
              'View "Collection Reminders" section',
              'See upcoming and overdue payments',
              'Send reminder messages to parties',
              'Track payment follow-ups',
            ],
            icon: Icons.notifications_active,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDriversHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Managing Drivers'),
          _buildInfoCard(
            title: 'Adding a Driver',
            steps: [
              'Navigate to "Driver Khata" section',
              'Tap "+" to add new driver',
              'Enter driver name and contact details',
              'Add license number and expiry date',
              'Upload driver\'s license photo',
              'Save driver information',
            ],
            icon: Icons.person,
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Driver Account Management',
            steps: [
              'Open "Driver Khata" to view all drivers',
              'Select a driver to see their account',
              'Record advances given to driver',
              'Track salary payments',
              'View trip assignments',
              'Check outstanding balance',
            ],
            icon: Icons.account_balance_outlined,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Assigning Trips',
            steps: [
              'When creating a trip, select driver',
              'View driver\'s current assignments',
              'Check driver availability',
              'Assign trip to available driver',
              'Track trip completion by driver',
            ],
            icon: Icons.add_circle_outline,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildReportsHelp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Understanding Reports'),
          _buildInfoCard(
            title: 'Profit & Loss Report',
            steps: [
              'Shows overall business profit/loss',
              'Displays total revenue from all trips',
              'Calculates total expenses',
              'Net profit = Revenue - Expenses',
              'Updated in real-time with each trip',
            ],
            icon: Icons.account_balance,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Truck Revenue Report',
            steps: [
              'View revenue by each truck',
              'Separate sections for Own and Market trucks',
              'Shows revenue, expenses, and profit per truck',
              'Compare truck performance',
              'Download Excel report for analysis',
            ],
            icon: Icons.local_shipping,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Party Revenue Report',
            steps: [
              'View revenue generated from each party',
              'See total trips per party',
              'Analyze party-wise business contribution',
              'Identify top customers',
              'Export data for business planning',
            ],
            icon: Icons.account_balance_wallet,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            title: 'Balance Reports',
            steps: [
              'Party Balance: Outstanding amounts from customers',
              'Supplier Balance: Outstanding amounts to suppliers',
              'View all payables and receivables',
              'Filter by balance amount',
              'Track payment collection progress',
            ],
            icon: Icons.receipt_long,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<String> steps,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Steps
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
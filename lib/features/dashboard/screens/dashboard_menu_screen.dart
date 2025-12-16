import 'package:flutter/material.dart';
import '../../trucks/screens/my_trucks_screen.dart';
import '../../trips/screens/my_trips_screen.dart';
import '../../party/screens/party_khata_screen.dart';
import '../../balance_report/screens/balance_report_screen.dart';
import '../../invoices/screens/digital_invoice_list_screen.dart';
import '../../collection_reminders/screens/collection_reminder_list_screen.dart';
import '../../supplier/screens/supplier_khata_screen.dart';
import '../../supplier/screens/supplier_reports_screen.dart';
import '../../driver/screens/driver_khata_screen.dart';
import '../../shop/screens/shop_khata_screen.dart';
import '../../expenses/screens/my_expenses_screen.dart';
import '../../trips/screens/unpaid_trips_screen.dart';
import '../../trips/screens/pod_trips_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../../utils/appbar.dart';
import '../../../utils/app_colors.dart';

class DashboardMenuScreen extends StatefulWidget {
  const DashboardMenuScreen({super.key});

  @override
  State<DashboardMenuScreen> createState() => _DashboardMenuScreenState();
}

class _DashboardMenuScreenState extends State<DashboardMenuScreen> {
  // Track which sections are expanded
  bool _partyExpanded = false;
  bool _supplierExpanded = false;
  bool _shopExpanded = false;
  bool _trucksExpanded = false;
  bool _driverExpanded = false;
  bool _expensesExpanded = false;
  bool _reportsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Menu',
        showBackButton: false,
        showDashboardLayout: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 8),

            // Party Section
            _buildCollapsibleSection(
              context,
              title: 'Party',
              icon: Icons.people_outline,
              color: AppColors.info,
              isExpanded: _partyExpanded,
              onExpansionChanged: (expanded) => setState(() => _partyExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.menu_book,
                  label: 'Party Khata',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PartyKhataScreen())),
                ),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Unpaid Trips',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UnpaidTripsScreen())),
                ),
                _MenuItem(
                  icon: Icons.receipt,
                  label: 'Digital Invoice',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DigitalInvoiceListScreen())),
                ),
                _MenuItem(
                  icon: Icons.notifications_active_outlined,
                  label: 'Collection Reminder',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CollectionReminderListScreen())),
                ),
                _MenuItem(
                  icon: Icons.receipt_long,
                  label: 'Party Balance Report',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BalanceReportScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Truck Supplier Section
            _buildCollapsibleSection(
              context,
              title: 'Truck Supplier',
              icon: Icons.business,
              color: const Color(0xFF9C27B0),
              isExpanded: _supplierExpanded,
              onExpansionChanged: (expanded) => setState(() => _supplierExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.person_outline,
                  label: 'Supplier Khata',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupplierKhataScreen())),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'Supplier Reports',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupplierReportsScreen())),
                ),
                _MenuItem(
                  icon: Icons.access_time,
                  label: 'POD due Trips',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PodTripsScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Shop Section
            _buildCollapsibleSection(
              context,
              title: 'Shop',
              icon: Icons.shopping_cart_outlined,
              color: const Color(0xFFF44336),
              isExpanded: _shopExpanded,
              onExpansionChanged: (expanded) => setState(() => _shopExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.store,
                  label: 'Shop Khata',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopKhataScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // My Trucks Section
            _buildCollapsibleSection(
              context,
              title: 'My Trucks',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF4CAF50),
              isExpanded: _trucksExpanded,
              onExpansionChanged: (expanded) => setState(() => _trucksExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.directions_car,
                  label: 'View Trucks',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTrucksScreen())),
                ),
                _MenuItem(
                  icon: Icons.content_copy,
                  label: 'My Trips',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTripsScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Driver Section
            _buildCollapsibleSection(
              context,
              title: 'Driver',
              icon: Icons.person_outline,
              color: const Color(0xFFF44336),
              isExpanded: _driverExpanded,
              onExpansionChanged: (expanded) => setState(() => _driverExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.person,
                  label: 'Driver Khata',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverKhataScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Expenses Section
            _buildCollapsibleSection(
              context,
              title: 'Expenses',
              icon: Icons.attach_money,
              color: const Color(0xFFF44336),
              isExpanded: _expensesExpanded,
              onExpansionChanged: (expanded) => setState(() => _expensesExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'My Expenses',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyExpensesScreen())),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Reports Section
            _buildCollapsibleSection(
              context,
              title: 'Reports',
              icon: Icons.bar_chart,
              color: const Color(0xFF9C27B0),
              isExpanded: _reportsExpanded,
              onExpansionChanged: (expanded) => setState(() => _reportsExpanded = expanded),
              items: [
                _MenuItem(
                  icon: Icons.assessment,
                  label: 'View Reports',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen())),
                ),
              ],
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required bool isExpanded,
        required Function(bool) onExpansionChanged,
        required List<_MenuItem> items,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 12, left: 12, right: 12, top: 4),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.grey.shade600,
            size: 20,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  // Calculate width to fit 3 items per row with proper spacing
                  final screenWidth = MediaQuery.of(context).size.width;
                  final itemWidth = (screenWidth - 48) / 3; // 48 = 24 (padding left+right) + 16 (2 gaps of 8)

                  return InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: color, size: 24),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}


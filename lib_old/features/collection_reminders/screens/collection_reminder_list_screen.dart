import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import 'collection_reminder_details_screen.dart';

class CollectionReminderListScreen extends StatefulWidget {
  const CollectionReminderListScreen({super.key});

  @override
  State<CollectionReminderListScreen> createState() => _CollectionReminderListScreenState();
}

class _CollectionReminderListScreenState extends State<CollectionReminderListScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _allReminders = [];
  List<dynamic> _filteredReminders = [];
  bool _isLoading = true;
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0 = Upcoming (future), 1 = Pending (past/today)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _applyFilters();
        });
      }
    });
    _loadReminders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await ApiService.getCollectionReminders();
      setState(() {
        _allReminders = reminders;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reminders: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day); // Start of today

      _filteredReminders = _allReminders.where((reminder) {
        final dueDateStr = reminder['dueDate']?.toString() ?? '';
        final dueDate = DateTime.tryParse(dueDateStr);
        if (dueDate == null) return false;

        final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final status = reminder['status']?.toString() ?? '';
        final isCollected = status == 'Collected';

        if (_selectedTabIndex == 0) {
          // Upcoming tab: future reminders that are not collected
          return dueDateOnly.isAfter(today) && !isCollected;
        } else {
          // Pending tab: past/today reminders that are not collected
          return (dueDateOnly.isBefore(today) || dueDateOnly.isAtSameMomentAs(today)) && !isCollected;
        }
      }).toList();

      // Sort by due date (ascending)
      _filteredReminders.sort((a, b) {
        final aDate = DateTime.tryParse(a['dueDate']?.toString() ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['dueDate']?.toString() ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });
    });
  }

  Map<String, List<dynamic>> _groupByDate() {
    final Map<String, List<dynamic>> grouped = {};

    for (var reminder in _filteredReminders) {
      final dateStr = reminder['dueDate']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        final key = DateFormat('MMMM, yyyy').format(date).toUpperCase();
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(reminder);
      }
    }

    return grouped;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Overdue':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      case 'Reminded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showAddReminderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddReminderModal(
        onReminderAdded: () {
          _loadReminders();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTextColor,
        title: const Text('My Reminders'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Info Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.blue.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Never miss a payment, document renewal or maintenance by keeping Reminders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.appBarTextColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Pending'),
              ],
            ),
          ),

          // Reminder List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reminders found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReminders,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                          children: _buildGroupedReminders(),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderDialog,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, size: 22),
        label: const Text('Collection Reminder'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<Widget> _buildGroupedReminders() {
    final grouped = _groupByDate();
    final List<Widget> widgets = [];

    grouped.forEach((dateGroup, reminders) {
      // Date header
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            dateGroup,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );

      // Reminders for this date group
      for (var reminder in reminders) {
        widgets.add(_buildReminderCard(reminder));
      }
    });

    return widgets;
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final dueDate = DateTime.tryParse(reminder['dueDate']?.toString() ?? '') ?? DateTime.now();
    final dayNumber = dueDate.day;
    final dayOfWeek = DateFormat('E').format(dueDate);

    // Create title from party or invoice info
    final partyName = reminder['partyName']?.toString() ?? '';
    final invoiceNumber = reminder['invoiceNumber']?.toString() ?? '';
    final reminderType = reminder['type']?.toString() ?? 'collection';

    String title;
    if (reminderType == 'general') {
      title = 'General Reminder - All Parties';
    } else {
      title = partyName.isNotEmpty ? 'Collect from $partyName' : 'Collection Reminder';
    }

    // Create subtitle with date and invoice
    final formattedDate = DateFormat('dd MMM').format(dueDate);
    String subtitle;
    if (reminderType == 'general') {
      subtitle = formattedDate;
    } else {
      subtitle = invoiceNumber.isNotEmpty ? '$partyName • $formattedDate • $invoiceNumber' : '$partyName • $formattedDate';
    }

    final status = reminder['status']?.toString() ?? '';
    final isCompleted = status == 'Reminded';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CollectionReminderDetailsScreen(
                reminderId: reminder['id'] ?? 0,
              ),
            ),
          );

          if (result == true) {
            _loadReminders();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Date Box
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      dayOfWeek,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayNumber.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  color: isCompleted ? Colors.green : Colors.transparent,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReminderModal extends StatefulWidget {
  final VoidCallback onReminderAdded;

  const _AddReminderModal({required this.onReminderAdded});

  @override
  State<_AddReminderModal> createState() => _AddReminderModalState();
}

class _AddReminderModalState extends State<_AddReminderModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Collection Reminder fields
  List<dynamic> _parties = [];
  Map<String, dynamic>? _selectedParty;
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 3));
  int _daysBefore = 3;

  // General Reminder fields
  String _generalNotes = '';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadParties();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    try {
      final parties = await ApiService.getParties();
      setState(() {
        _parties = parties;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading parties: $e')),
        );
      }
    }
  }

  void _showPartySelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  'Select Party',
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
          Expanded(
            child: _parties.isEmpty
                ? const Center(child: Text('No parties found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _parties.length,
                    itemBuilder: (context, index) {
                      final party = _parties[index];
                      final name = party['name']?.toString() ?? '';
                      final phone = party['phone']?.toString() ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGreen,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(phone),
                        onTap: () {
                          setState(() {
                            _selectedParty = party;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _setCollectionReminder() async {
    if (_selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a party')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.createCollectionReminder(
        partyName: _selectedParty!['name']?.toString() ?? '',
        partyPhone: _selectedParty!['phone']?.toString() ?? '',
        partyEmail: _selectedParty!['email']?.toString() ?? '',
        outstandingAmount: 0.0, // Can be calculated from trips
        dueDate: DateFormat('yyyy-MM-dd').format(_reminderDate),
        daysPastDue: _daysBefore,
        invoiceNumber: '',
        notes: '',
      );

      setState(() => _isLoading = false);

      if (result != null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder set successfully')),
          );
          widget.onReminderAdded();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set reminder')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _setGeneralReminder() async {
    if (_generalNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter notes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.createCollectionReminder(
        type: 'general',
        partyName: 'All Parties',
        partyPhone: '',
        partyEmail: '',
        outstandingAmount: 0.0,
        dueDate: DateFormat('yyyy-MM-dd').format(_reminderDate),
        daysPastDue: _daysBefore,
        invoiceNumber: '',
        notes: _generalNotes,
      );

      setState(() => _isLoading = false);

      if (result != null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('General reminder set successfully')),
          );
          widget.onReminderAdded();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to set reminder')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collection Reminder',
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
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Collection Reminder'),
              Tab(text: 'General Reminder'),
            ],
          ),

          // Tab Content
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCollectionReminderTab(),
                _buildGeneralReminderTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionReminderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Party Field
          const Text(
            'Party *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showPartySelection,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedParty != null
                        ? _selectedParty!['name']?.toString() ?? 'Select Party'
                        : 'Select or enter party name',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedParty != null ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reminder Date Field
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder Date *',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _reminderDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _reminderDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_reminderDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    DropdownButtonFormField<int>(
                      value: _daysBefore,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day')),
                        DropdownMenuItem(value: 3, child: Text('3 days')),
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _daysBefore = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Set Reminder Button
          ElevatedButton(
            onPressed: _isLoading ? null : _setCollectionReminder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Set Reminder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGeneralReminderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Notes Field
          const Text(
            'Notes *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter reminder notes for all parties',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _generalNotes = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Reminder Date Field
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder Date *',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _reminderDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _reminderDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_reminderDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 22),
                    DropdownButtonFormField<int>(
                      value: _daysBefore,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day')),
                        DropdownMenuItem(value: 3, child: Text('3 days')),
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _daysBefore = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Set Reminder Button
          ElevatedButton(
            onPressed: _isLoading ? null : _setGeneralReminder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Set Reminder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

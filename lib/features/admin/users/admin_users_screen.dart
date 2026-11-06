import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_session_manager.dart';
import '../reports/admin_reports_screen.dart';
import 'admin_zone_management_screen.dart';
import 'staff_partner_assignments_screen.dart';
import 'widgets/create_customer_dialog.dart';
import 'widgets/create_partner_dialog.dart';
import 'widgets/create_staff_dialog.dart';
import 'widgets/user_card.dart';
import 'widgets/user_detail_sheet.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    this.adminApi,
    this.sessionManager,
  });

  final AdminApi? adminApi;
  final AdminSessionManager? sessionManager;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  late final AdminApi _api;
  late final AdminSessionManager _session;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  String _selectedRole = 'all';
  String _selectedStatus = 'all';
  int? _selectedZoneFilter;
  List<AdminZone> _zones = [];

  int _currentPage = 1;
  static const int _pageSize = 20;

  bool _isLoading = true;
  String? _errorMessage;
  List<AdminUserSummary> _users = [];
  int _totalUsers = 0;
  int _totalPages = 0;

  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _api = widget.adminApi ?? AdminApi(sessionManager: _session);

    _searchController.addListener(_onSearchChanged);
    _fetchUsers().then((_) {
      if (mounted) _fetchZones();
    });
  }

  Future<void> _fetchZones() async {
    try {
      final zones = await _api.getZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
      });
      _fetchUsers();
    });
  }

  Future<void> _fetchUsers() async {
    final thisSeq = ++_requestSeq;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final searchVal = _searchController.text.trim();
    final roleVal = _selectedRole != 'all' ? _selectedRole : null;
    bool? activeVal;
    if (_selectedStatus == 'active') activeVal = true;
    if (_selectedStatus == 'inactive') activeVal = false;

    try {
      final pageData = await _api.getUsers(
        role: roleVal,
        search: searchVal.isNotEmpty ? searchVal : null,
        isActive: activeVal,
        zoneId: _selectedZoneFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      // Discard out-of-order stale responses
      if (!mounted || thisSeq != _requestSeq) return;

      setState(() {
        _users = pageData.items;
        _totalUsers = pageData.total;
        _totalPages = pageData.totalPages;
        _currentPage = pageData.page;
        _isLoading = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _requestSeq) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _requestSeq) return;
      setState(() {
        _errorMessage = 'Failed to load users. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _openCreateCustomerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateCustomerDialog(
        adminApi: _api,
        onSuccess: () {
          setState(() {
            _currentPage = 1;
          });
          _fetchUsers();
        },
      ),
    );
  }

  void _openCreatePartnerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreatePartnerDialog(
        adminApi: _api,
        onSuccess: () {
          setState(() {
            _currentPage = 1;
          });
          _fetchUsers();
        },
      ),
    );
  }

  void _openCreateStaffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateStaffDialog(
        adminApi: _api,
        onSuccess: () {
          setState(() {
            _currentPage = 1;
          });
          _fetchUsers();
        },
      ),
    );
  }

  void _openZoneManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminZoneManagementScreen(
          adminApi: _api,
          sessionManager: _session,
        ),
      ),
    );
    _fetchZones();
    _fetchUsers();
  }

  void _openReportsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminReportsScreen(
          adminApi: _api,
          sessionManager: _session,
        ),
      ),
    );
  }

  void _openStaffPartnerAssignments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffPartnerAssignmentsScreen(
          adminApi: _api,
        ),
      ),
    );
  }

  void _openUserDetailSheet(AdminUserSummary user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserDetailSheet(
        userSummary: user,
        adminApi: _api,
        sessionManager: _session,
        onStatusChanged: (updated) {
          setState(() {
            final index = _users.indexWhere((u) => u.id == updated.id);
            if (index != -1) {
              _users[index] = updated;
            }
          });
        },
        onUserDeleted: () {
          setState(() {
            _currentPage = 1;
          });
          _fetchUsers();
        },
      ),
    );
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _fetchUsers();
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
      _fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = math.min(width * 0.94, 600.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).padding.top + 10),
                        _buildHeader(context),
                        const SizedBox(height: 12),
                        _buildActionRow(),
                        const SizedBox(height: 12),
                        _buildSearchAndFilters(),
                        const SizedBox(height: 10),
                        Expanded(child: _buildUserListContent()),
                        if (!_isLoading &&
                            _errorMessage == null &&
                            _users.isNotEmpty) ...[
                          _buildPaginationFooter(),
                        ],
                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120755B5),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _royalBlue,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'View, filter & manage accounts',
                style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Column(
      children: [
        // Row 1: Partner & Staff creation
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  key: const Key('admin_create_partner_button'),
                  onPressed: _openCreatePartnerDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.handshake_rounded, size: 16),
                  label: const Text(
                    'Create Partner',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  key: const Key('admin_create_staff_button'),
                  onPressed: _openCreateStaffDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.badge_rounded, size: 16),
                  label: const Text(
                    'Create Staff',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Customer creation & Zones
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  key: const Key('admin_create_customer_button'),
                  onPressed: _openCreateCustomerDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055B8),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text(
                    'Create Customer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  key: const Key('admin_manage_zones_button'),
                  onPressed: _openZoneManagement,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _royalBlue,
                    side: const BorderSide(color: _fieldBorderBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.location_on_rounded, size: 16),
                  label: const Text(
                    'Manage Zones',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: Assignments & Reports
        Row(
          children: [
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  key: const Key('admin_assignments_button'),
                  onPressed: _openStaffPartnerAssignments,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _royalBlue,
                    side: const BorderSide(color: _fieldBorderBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                  label: const Text(
                    'Manage Staff-Partner Assignments',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  key: const Key('admin_reports_nav_button'),
                  onPressed: _openReportsScreen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                    side: const BorderSide(color: Color(0xFFE1BEE7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.bar_chart_rounded, size: 16),
                  label: const Text(
                    'Reports',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search input
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FCFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _fieldBorderBlue, width: 1),
            ),
            child: TextField(
              key: const Key('admin_user_search_field'),
              controller: _searchController,
              style: const TextStyle(color: _deepBlue, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, mobile, ID, code...',
                hintStyle:
                    const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _royalBlue, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF78909C), size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter Dropdowns Row 1: Role & Status
          Row(
            children: [
              // Role Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('admin_user_role_filter'),
                      value: _selectedRole,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 20),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(
                            value: 'customer', child: Text('Customer')),
                        DropdownMenuItem(
                            value: 'partner', child: Text('Partner')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedRole) {
                          setState(() {
                            _selectedRole = val;
                            _currentPage = 1;
                          });
                          _fetchUsers();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Status Filter
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('admin_user_status_filter'),
                      value: _selectedStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 20),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Status')),
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedStatus) {
                          setState(() {
                            _selectedStatus = val;
                            _currentPage = 1;
                          });
                          _fetchUsers();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Filter Row 2: Zone Filter (when zones are available)
          if (_zones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FCFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _fieldBorderBlue, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  key: const Key('admin_user_zone_filter'),
                  value: _selectedZoneFilter,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _royalBlue, size: 20),
                  style: const TextStyle(
                      color: _deepBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  hint: const Text('Filter by Zone (All Zones)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Zones'),
                    ),
                    ..._zones.map(
                      (z) => DropdownMenuItem<int?>(
                        value: z.id,
                        child: Text('Zone: ${z.name}'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedZoneFilter = val;
                      _currentPage = 1;
                    });
                    _fetchUsers();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserListContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _royalBlue),
            SizedBox(height: 14),
            Text(
              'Loading users...',
              style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F5FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded,
                    size: 32, color: _royalBlue),
              ),
              const SizedBox(height: 14),
              const Text(
                'No users found',
                style: TextStyle(
                    color: _deepBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try adjusting your search query or filters',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _users[index];
        return UserCard(
          user: user,
          onTap: () => _openUserDetailSheet(user),
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    final hasPrev = _currentPage > 1;
    final hasNext = _currentPage < _totalPages;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          InkWell(
            onTap: hasPrev ? _goToPreviousPage : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: hasPrev ? _royalBlue : const Color(0xFFB0BEC5),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Prev',
                    style: TextStyle(
                      color: hasPrev ? _royalBlue : const Color(0xFFB0BEC5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Page counter
          Flexible(
            child: Text(
              'Page $_currentPage of $_totalPages ($_totalUsers total)',
              style: const TextStyle(
                color: _deepBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Next button
          InkWell(
            onTap: hasNext ? _goToNextPage : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: hasNext ? _royalBlue : const Color(0xFFB0BEC5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasNext ? _royalBlue : const Color(0xFFB0BEC5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

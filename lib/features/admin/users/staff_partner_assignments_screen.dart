import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/services/admin_api.dart';

class StaffPartnerAssignmentsScreen extends StatefulWidget {
  const StaffPartnerAssignmentsScreen({
    super.key,
    required this.adminApi,
  });

  final AdminApi adminApi;

  @override
  State<StaffPartnerAssignmentsScreen> createState() =>
      _StaffPartnerAssignmentsScreenState();
}

class _StaffPartnerAssignmentsScreenState
    extends State<StaffPartnerAssignmentsScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  List<AdminUserSummary> _staff = [];
  List<AdminUserSummary> _partners = [];
  List<AdminStaffPartnerAssignment> _assignments = [];
  int? _selectedStaffId;
  int? _selectedPartnerId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _updatingAssignmentId;
  String? _errorMessage;
  String? _actionErrorMessage;
  String _statusFilter = 'all';
  int _assignmentRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<List<AdminUserSummary>> _loadUsers(String role) async {
    final users = <AdminUserSummary>[];
    var page = 1;
    var totalPages = 0;
    do {
      final result = await widget.adminApi.getUsers(
        role: role,
        isActive: true,
        page: page,
        pageSize: 100,
      );
      users.addAll(result.items);
      totalPages = result.totalPages;
      page++;
    } while (page <= totalPages);
    return users;
  }

  Future<void> _loadAssignments({bool isFilterChange = false}) async {
    final requestId = ++_assignmentRequestId;
    if (isFilterChange) {
      setState(() {
        _assignments = [];
        _actionErrorMessage = null;
      });
    }
    try {
      final assignments = await widget.adminApi.getStaffPartnerAssignments(
        isActive: _statusFilter == 'all'
            ? null
            : (_statusFilter == 'active'),
      );
      if (!mounted || requestId != _assignmentRequestId) return;
      setState(() {
        _assignments = assignments;
        _actionErrorMessage = null;
      });
    } on AdminApiException catch (error) {
      if (!mounted || requestId != _assignmentRequestId) return;
      if (isFilterChange) {
        setState(() {
          _assignments = [];
          _actionErrorMessage = error.message;
        });
      }
    } catch (_) {
      if (!mounted || requestId != _assignmentRequestId) return;
      if (isFilterChange) {
        setState(() {
          _assignments = [];
          _actionErrorMessage = 'Failed to load assignments';
        });
      }
    }
  }

  Future<void> _loadData() async {
    final requestId = ++_assignmentRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _actionErrorMessage = null;
    });
    try {
      final staff = await _loadUsers('staff');
      final partners = await _loadUsers('partner');
      final assignments = await widget.adminApi.getStaffPartnerAssignments(
        isActive: _statusFilter == 'all'
            ? null
            : (_statusFilter == 'active'),
      );
      if (!mounted || requestId != _assignmentRequestId) return;
      setState(() {
        _staff = staff;
        _partners = partners;
        _assignments = assignments;
        _isLoading = false;
        if (!_staff.any((user) => user.id == _selectedStaffId)) {
          _selectedStaffId = null;
        }
        if (!_partners.any((user) => user.id == _selectedPartnerId)) {
          _selectedPartnerId = null;
        }
      });
    } on AdminApiException catch (error) {
      if (!mounted || requestId != _assignmentRequestId) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _createAssignment() async {
    final staffId = _selectedStaffId;
    final partnerId = _selectedPartnerId;
    if (staffId == null || partnerId == null || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _actionErrorMessage = null;
    });
    try {
      final assignment = await widget.adminApi.createStaffPartnerAssignment(
        staffId: staffId,
        partnerId: partnerId,
      );
      if (!mounted) return;
      setState(() {
        if (_statusFilter == 'all' ||
            (_statusFilter == 'active' && assignment.isActive)) {
          _assignments = [assignment, ..._assignments];
        }
        _selectedStaffId = null;
        _selectedPartnerId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner assigned to Staff successfully')),
      );
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showReassignDialog(
      AdminStaffPartnerAssignment assignment) async {
    int? selectedStaffId = _staff.any((u) => u.id == assignment.staffId)
        ? assignment.staffId
        : null;
    final partnerName =
        assignment.partner.businessName ?? assignment.partner.name;

    final targetStaffId = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reassign Partner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign $partnerName to a Staff member. Reassignment creates a new assignment period rather than reopening this inactive record.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF557A95)),
              ),
              const SizedBox(height: 16),
              if (_staff.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: const Text(
                    'No active Staff accounts are available.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF856404),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  key: const Key('reassign_staff_dropdown'),
                  initialValue: selectedStaffId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Staff Member',
                    border: OutlineInputBorder(),
                  ),
                  items: _staff
                      .map(
                        (user) => DropdownMenuItem<int>(
                          value: user.id,
                          child: Text(
                            user.staffId == null
                                ? '${user.name} (${user.mobile})'
                                : '${user.name} (${user.staffId})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (val) => setDialogState(() => selectedStaffId = val),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm_reassign_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: selectedStaffId == null || _staff.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(selectedStaffId),
              child: const Text('Confirm Reassign'),
            ),
          ],
        ),
      ),
    );

    if (targetStaffId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _actionErrorMessage = null;
    });

    try {
      final newAssignment = await widget.adminApi.createStaffPartnerAssignment(
        staffId: targetStaffId,
        partnerId: assignment.partnerId,
      );
      if (!mounted) return;
      setState(() {
        if (_statusFilter == 'all' ||
            (_statusFilter == 'active' && newAssignment.isActive)) {
          _assignments = [newAssignment, ..._assignments];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Partner reassigned successfully. New assignment period created.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      await _loadAssignments();
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() => _actionErrorMessage = error.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmToggleStatus(
      AdminStaffPartnerAssignment assignment) async {
    if (!assignment.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inactive assignments cannot be reactivated. Reassignment creates a new assignment period.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final partnerName =
        assignment.partner.businessName ?? assignment.partner.name;
    final staffName = assignment.staff.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Assignment'),
        content: Text(
          'Are you sure you want to deactivate the assignment between $staffName and $partnerName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _toggleAssignmentStatus(assignment, false);
  }

  Future<void> _toggleAssignmentStatus(
    AdminStaffPartnerAssignment assignment,
    bool targetActive,
  ) async {
    if (_updatingAssignmentId != null) return;
    setState(() {
      _updatingAssignmentId = assignment.id;
      _actionErrorMessage = null;
    });

    try {
      final updated =
          await widget.adminApi.updateStaffPartnerAssignmentStatus(
        assignmentId: assignment.id,
        isActive: targetActive,
      );
      if (!mounted) return;
      setState(() {
        final index = _assignments.indexWhere((a) => a.id == assignment.id);
        if (index != -1) {
          _assignments[index] = updated;
        }
        _updatingAssignmentId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetActive
                ? 'Assignment reactivated successfully'
                : 'Assignment deactivated successfully',
          ),
          backgroundColor:
              targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
      );
      await _loadAssignments();
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _updatingAssignmentId = null;
        _actionErrorMessage = error.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updatingAssignmentId = null;
        _actionErrorMessage = 'An unexpected error occurred';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _royalBlue,
        elevation: 0,
        title: const Text(
          'Staff Assignments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _royalBlue),
              )
            : _errorMessage != null && _staff.isEmpty && _partners.isEmpty
                ? _buildLoadError()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildAssignmentForm(),
                        const SizedBox(height: 12),
                        if (_actionErrorMessage != null) ...[
                          _buildActionErrorBanner(),
                          const SizedBox(height: 12),
                        ],
                        _buildListHeader(),
                        const SizedBox(height: 10),
                        if (_assignments.isEmpty)
                          _buildEmptyAssignments()
                        else
                          ..._assignments.map(_buildAssignmentCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildActionErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _actionErrorMessage!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFC62828)),
            onPressed: () => setState(() => _actionErrorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    final title = _statusFilter == 'active'
        ? 'Active assignments'
        : (_statusFilter == 'inactive'
            ? 'Inactive assignments'
            : 'Assignments');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_assignments.length}',
                  style: const TextStyle(
                    color: _royalBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCFD8DC)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('assignment_status_filter'),
              value: _statusFilter,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _royalBlue,
                size: 18,
              ),
              style: const TextStyle(
                color: _deepBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              onChanged: _isSubmitting || _updatingAssignmentId != null
                  ? null
                  : (val) {
                      if (val != null && val != _statusFilter) {
                        setState(() => _statusFilter = val);
                        _loadAssignments(isFilterChange: true);
                      }
                    },
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _deepBlue),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentForm() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Assign a Partner',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'A Partner can have at most one active Staff assignment. Assigning a different Staff member automatically closes the previous assignment period and creates a new one.',
              style: TextStyle(
                color: Color(0xFF557A95),
                fontSize: 12,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedStaffId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Staff member',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _staff
                  .map(
                    (user) => DropdownMenuItem<int>(
                      value: user.id,
                      child: Text(
                        user.staffId == null
                            ? '${user.name} (${user.mobile})'
                            : '${user.name} (${user.staffId})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedStaffId = value),
            ),
            if (_staff.isEmpty) ...[
              const SizedBox(height: 4),
              const Text(
                'No active Staff accounts are available.',
                style: TextStyle(color: Color(0xFF6782A0), fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedPartnerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Partner',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _partners
                  .map(
                    (user) => DropdownMenuItem<int>(
                      value: user.id,
                      child: Text(
                        '${user.businessName ?? user.name} (${user.name})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedPartnerId = value),
            ),
            if (_partners.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'No active Partner accounts are available.',
                style: TextStyle(color: Color(0xFF6782A0)),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
              TextButton.icon(
                onPressed: _isSubmitting ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry loading'),
              ),
            ],
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _selectedStaffId == null ||
                      _selectedPartnerId == null ||
                      _isSubmitting
                  ? null
                  : _createAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(_isSubmitting ? 'Assigning...' : 'Create assignment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAssignments() {
    final message = _statusFilter == 'active'
        ? 'There are no active Staff-Partner assignments.'
        : (_statusFilter == 'inactive'
            ? 'There are no inactive Staff-Partner assignments.'
            : 'There are no Staff-Partner assignments.');
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6782A0)),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color:
                  isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeactivationDate(DateTime? dt) {
    if (dt == null) return 'Unavailable';
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  Widget _buildAssignmentCard(AdminStaffPartnerAssignment assignment) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: assignment.isActive
                      ? const Color(0xFFD4F0FF)
                      : const Color(0xFFECEFF1),
                  child: Icon(
                    Icons.handshake_rounded,
                    color: assignment.isActive ? _royalBlue : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.partner.businessName ??
                            assignment.partner.name,
                        style: const TextStyle(
                          color: _deepBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Partner: ${assignment.partner.name}',
                        style: const TextStyle(
                          color: Color(0xFF557A95),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Staff: ${assignment.staff.name}',
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!assignment.isActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Deactivated: ${_formatDeactivationDate(assignment.deactivatedAt)}',
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 11,
                          ),
                        ),
                        if (assignment.deactivatedByName != null &&
                            assignment.deactivatedByName!.isNotEmpty)
                          Text(
                            'Deactivated by: ${assignment.deactivatedByName}',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 11,
                            ),
                          )
                        else if (assignment.deactivatedBy != null)
                          Text(
                            'Deactivated by: Admin #${assignment.deactivatedBy}',
                            style: const TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                _buildStatusBadge(assignment.isActive),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_updatingAssignmentId == assignment.id)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _royalBlue,
                    ),
                  )
                else if (assignment.isActive)
                  OutlinedButton.icon(
                    key: Key('deactivate_assignment_${assignment.id}'),
                    onPressed: _isSubmitting || _updatingAssignmentId != null
                        ? null
                        : () => _confirmToggleStatus(assignment),
                    icon: const Icon(
                      Icons.block_rounded,
                      size: 16,
                      color: Color(0xFFD32F2F),
                    ),
                    label: const Text(
                      'Deactivate',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE57373)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    key: Key('reassign_assignment_${assignment.id}'),
                    onPressed: _isSubmitting || _updatingAssignmentId != null
                        ? null
                        : () => _showReassignDialog(assignment),
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: _royalBlue,
                    ),
                    label: const Text(
                      'Reassign',
                      style: TextStyle(
                        color: _royalBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _royalBlue),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

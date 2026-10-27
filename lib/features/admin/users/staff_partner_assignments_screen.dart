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
  String? _errorMessage;

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final staff = await _loadUsers('staff');
      final partners = await _loadUsers('partner');
      final assignments = await widget.adminApi.getStaffPartnerAssignments(
        isActive: true,
      );
      if (!mounted) return;
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
      if (!mounted) return;
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
    });
    try {
      final assignment = await widget.adminApi.createStaffPartnerAssignment(
        staffId: staffId,
        partnerId: partnerId,
      );
      if (!mounted) return;
      setState(() {
        _assignments = [assignment, ..._assignments];
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
                        const SizedBox(height: 20),
                        const Text(
                          'Active assignments',
                          style: TextStyle(
                            color: _deepBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Assign a Partner',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedStaffId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Staff member',
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
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedStaffId = value),
            ),
            if (_staff.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'No active Staff accounts are available.',
                style: TextStyle(color: Color(0xFF6782A0)),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedPartnerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Partner',
                border: OutlineInputBorder(),
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
    return const Card(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'There are no active Staff-Partner assignments.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6782A0)),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(AdminStaffPartnerAssignment assignment) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFD4F0FF),
          child: Icon(Icons.handshake_rounded, color: _royalBlue),
        ),
        title: Text(
          assignment.partner.businessName ?? assignment.partner.name,
          style: const TextStyle(
            color: _deepBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${assignment.partner.name}  •  Staff: ${assignment.staff.name}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}

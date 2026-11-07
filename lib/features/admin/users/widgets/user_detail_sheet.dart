import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_session_manager.dart';
import 'edit_user_dialog.dart';

class UserDetailSheet extends StatefulWidget {
  const UserDetailSheet({
    super.key,
    required this.userSummary,
    required this.adminApi,
    required this.sessionManager,
    required this.onStatusChanged,
    this.onUserDeleted,
  });

  final AdminUserSummary userSummary;
  final AdminApi adminApi;
  final AdminSessionManager sessionManager;
  final ValueChanged<AdminUserSummary> onStatusChanged;
  final VoidCallback? onUserDeleted;

  @override
  State<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<UserDetailSheet> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  late AdminUserSummary _currentUser;
  AdminUserDetail? _detail;
  bool _isLoadingDetail = true;
  String? _detailError;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.userSummary;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });

    try {
      final detail = await widget.adminApi.getUserDetail(userId: _currentUser.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoadingDetail = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = e.message;
        _isLoadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailError = 'Failed to load user details. Please try again.';
        _isLoadingDetail = false;
      });
    }
  }

  void _openEditDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditUserDialog(
        user: _currentUser,
        detail: _detail,
        adminApi: widget.adminApi,
        onSuccess: (updated) {
          setState(() {
            _currentUser = updated;
          });
          widget.onStatusChanged(updated);
          _fetchDetail();
        },
      ),
    );
  }

  Future<void> _handleDeleteUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsOverflowButtonSpacing: 8,
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Account',
                style: TextStyle(color: _deepBlue, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_currentUser.name}\'s account (#${_currentUser.id})?\n\nNote: If this account is referenced in orders, invoices, payments, stock requests, or assignments, it will be safely deactivated to preserve historical audit records.',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_user_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final res = await widget.adminApi.deleteUser(userId: _currentUser.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      widget.onUserDeleted?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.wasDeactivated
              ? const Color(0xFFE65100)
              : const Color(0xFF2E7D32),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Action Blocked',
                  style: TextStyle(color: _deepBlue, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            e.message,
            style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete account. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _handleToggleStatus() async {
    final targetActive = !_currentUser.isActive;
    final actionName = targetActive ? 'activate' : 'deactivate';

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          targetActive ? 'Activate Account' : 'Deactivate Account',
          style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to $actionName ${_currentUser.name}\'s account?',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(targetActive ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final updated = await widget.adminApi.updateUserStatus(
        userId: _currentUser.id,
        isActive: targetActive,
      );

      if (!mounted) return;

      setState(() {
        _currentUser = updated;
      });
      widget.onStatusChanged(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetActive
                ? 'Account activated successfully'
                : 'Account deactivated successfully',
          ),
          backgroundColor: targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Action Blocked',
                  style: TextStyle(color: _deepBlue, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            e.message,
            style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update account status. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'partner':
        return const Color(0xFF00897B);
      case 'staff':
        return const Color(0xFFE65100);
      case 'admin':
        return const Color(0xFF6A1B9A);
      case 'customer':
      default:
        return const Color(0xFF0055B8);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(_currentUser.role);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD8DC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title bar with close
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: roleColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: roleColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser.name,
                          style: const TextStyle(
                            color: _deepBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withAlpha(24),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _currentUser.role.toUpperCase(),
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _currentUser.isActive
                                    ? const Color(0xFFE8F8EE)
                                    : const Color(0xFFFBE9E7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _currentUser.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  color: _currentUser.isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE3F2FD), height: 1),
              const SizedBox(height: 16),

              // Common details grid
              const Text(
                'Account Information',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FCFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBEBFF)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('User ID', '#${_currentUser.id}'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Mobile Number', _currentUser.mobile),
                    const SizedBox(height: 8),
                    _buildInfoRow('Role', _currentUser.role.toUpperCase()),
                    const SizedBox(height: 8),
                    _buildInfoRow('Status', _currentUser.isActive ? 'Active' : 'Inactive'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Created At', _formatDate(_currentUser.createdAt)),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Role-Specific Profile Section
              Text(
                '${_currentUser.role.capitalize()} Profile Details',
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              if (_isLoadingDetail) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: _royalBlue),
                  ),
                ),
              ] else if (_detailError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _detailError!,
                        style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _fetchDetail,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildRoleProfileDetails(_detail ?? AdminUserDetail(
                  id: _currentUser.id,
                  name: _currentUser.name,
                  mobile: _currentUser.mobile,
                  role: _currentUser.role,
                  isActive: _currentUser.isActive,
                  createdAt: _currentUser.createdAt,
                  businessName: _currentUser.businessName,
                  partnerCode: _currentUser.partnerCode,
                  zoneId: _currentUser.zoneId,
                  zoneName: _currentUser.zoneName,
                  staffId: _currentUser.staffId,
                )),
              ],

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE3F2FD), height: 1),
              const SizedBox(height: 16),

              // Action Buttons: Edit and Toggle Status
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        key: const Key('user_detail_edit_button'),
                        onPressed: _isUpdatingStatus ? null : _openEditDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _royalBlue,
                          side: const BorderSide(color: Color(0xFF9CDFFF), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        key: const Key('user_detail_status_button'),
                        onPressed: _isUpdatingStatus ? null : _handleToggleStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentUser.isActive
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE8F8EE),
                          foregroundColor: _currentUser.isActive
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF2E7D32),
                          elevation: 0,
                          side: BorderSide(
                            color: _currentUser.isActive
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFA5D6A7),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _currentUser.isActive
                                    ? Icons.block_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _currentUser.isActive ? 'Deactivate Account' : 'Activate Account',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Delete Account Button (Safely soft-deactivates if referenced)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  key: const Key('user_detail_delete_button'),
                  onPressed: _isUpdatingStatus ? null : _handleDeleteUser,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFFFCDD2), width: 1),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Delete Account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _deepBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleProfileDetails(AdminUserDetail detail) {
    final role = detail.role.toLowerCase();

    if (role == 'customer') {
      final cust = detail.customerProfile;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FCFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBEBFF)),
        ),
        child: Column(
          children: [
            _buildInfoRow('State', cust?.state?.isNotEmpty == true ? cust!.state! : 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow('City', cust?.city?.isNotEmpty == true ? cust!.city! : 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow('Segment', cust?.segment?.isNotEmpty == true ? cust!.segment! : 'N/A'),
          ],
        ),
      );
    } else if (role == 'partner') {
      final partner = detail.partnerProfile;
      final assignedZone = partner?.zoneName ?? detail.zoneName ?? _currentUser.zoneName ?? 'Not Assigned';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FCFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBEBFF)),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              'Business Name',
              partner?.businessName.isNotEmpty == true
                  ? partner!.businessName
                  : (detail.businessName ?? 'N/A'),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Partner Code',
              partner?.partnerCode?.isNotEmpty == true
                  ? partner!.partnerCode!
                  : (detail.partnerCode ?? 'N/A'),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Assigned Zone',
              assignedZone,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Partner Discount',
              '${(partner?.discountPercentage ?? detail.discountPercentage ?? _currentUser.discountPercentage ?? 0.0).toStringAsFixed(2)}%',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Business Address',
              partner?.businessAddress.isNotEmpty == true ? partner!.businessAddress : 'N/A',
            ),
          ],
        ),
      );
    } else if (role == 'staff') {
      final staff = detail.staffProfile;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FCFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBEBFF)),
        ),
        child: Column(
          children: [
            _buildInfoRow(
              'Staff ID',
              staff?.staffId.isNotEmpty == true ? staff!.staffId : (detail.staffId ?? 'N/A'),
            ),
          ],
        ),
      );
    } else {
      // Admin
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FCFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBEBFF)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Full System Administrator Privileges',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Has complete administrative management permissions.',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
            ),
          ],
        ),
      );
    }
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

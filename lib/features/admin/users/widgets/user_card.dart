import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
  });

  final AdminUserSummary user;
  final VoidCallback onTap;

  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'partner':
        return const Color(0xFF00897B); // Teal
      case 'staff':
        return const Color(0xFFE65100); // Amber/Orange
      case 'admin':
        return const Color(0xFF6A1B9A); // Purple
      case 'customer':
      default:
        return const Color(0xFF0055B8); // Blue
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'partner':
        return Icons.handshake_rounded;
      case 'staff':
        return Icons.groups_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'customer':
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(user.role);
    final roleIcon = _getRoleIcon(user.role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Role Avatar Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: roleColor.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Main info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: Color(0xFF78909C),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              user.mobile,
                              style: const TextStyle(
                                color: Color(0xFF557A95),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Role-specific summary identifiers
                      if (user.partnerCode != null && user.partnerCode!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Partner Code: ${user.partnerCode}',
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (user.staffId != null && user.staffId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Staff ID: ${user.staffId}',
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (user.businessName != null && user.businessName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.businessName!,
                          style: const TextStyle(
                            color: Color(0xFF557A95),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (user.role.toLowerCase() == 'partner' &&
                          user.zoneName != null &&
                          user.zoneName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Color(0xFF00897B),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                'Zone: ${user.zoneName}',
                                style: const TextStyle(
                                  color: Color(0xFF00897B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? const Color(0xFFE8F8EE)
                        : const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: user.isActive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE57373),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.isActive
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 12,
                        color: user.isActive
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: user.isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFB0BEC5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

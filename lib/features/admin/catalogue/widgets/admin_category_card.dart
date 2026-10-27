import 'package:flutter/material.dart';

import '../../../../core/models/admin_catalogue_models.dart';

class AdminCategoryCard extends StatelessWidget {
  const AdminCategoryCard({
    super.key,
    required this.category,
    this.onTap,
    this.onToggleStatus,
    this.isUpdatingStatus = false,
  });

  final AdminCategory category;
  final VoidCallback? onTap;
  final VoidCallback? onToggleStatus;
  final bool isUpdatingStatus;

  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  @override
  Widget build(BuildContext context) {
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
                // Category Avatar Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0087D4).withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Color(0xFF0087D4),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Main info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Name & Status & Status Action
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: category.isActive
                                  ? const Color(0xFFE8F8EE)
                                  : const Color(0xFFFBE9E7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: category.isActive
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE57373),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  category.isActive
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 11,
                                  color: category.isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  category.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: category.isActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status Action Button
                          if (onToggleStatus != null) ...[
                            const SizedBox(width: 6),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: Key('category_status_button_${category.id}'),
                                borderRadius: BorderRadius.circular(8),
                                onTap: isUpdatingStatus ? null : onToggleStatus,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: category.isActive
                                        ? const Color(0xFFFDE8E8)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: category.isActive
                                          ? const Color(0xFFE57373)
                                          : const Color(0xFF81C784),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: isUpdatingStatus
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: _royalBlue,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              category.isActive
                                                  ? Icons.pause_circle_outline_rounded
                                                  : Icons.play_circle_outline_rounded,
                                              size: 11,
                                              color: category.isActive
                                                  ? const Color(0xFFC62828)
                                                  : const Color(0xFF2E7D32),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              category.isActive ? 'Deactivate' : 'Activate',
                                              style: TextStyle(
                                                color: category.isActive
                                                    ? const Color(0xFFC62828)
                                                    : const Color(0xFF2E7D32),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Row 2: Product Count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F2FD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${category.productCount} ${category.productCount == 1 ? 'Product' : 'Products'}',
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (category.description != null && category.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          category.description!,
                          style: const TextStyle(
                            color: Color(0xFF557A95),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

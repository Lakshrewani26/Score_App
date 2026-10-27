import 'package:flutter/material.dart';

import '../../../../core/models/admin_order_models.dart';

class AdminStockRequestCard extends StatelessWidget {
  const AdminStockRequestCard({
    super.key,
    required this.stockRequest,
    required this.onTap,
  });

  final AdminStockRequestSummary stockRequest;
  final VoidCallback onTap;

  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return const Color(0xFFFFF3E0);
      case 'approved':
        return const Color(0xFFE8F8EE);
      case 'rejected':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFECEFF1);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return const Color(0xFFE65100);
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBg = _getStatusBgColor(stockRequest.status);
    final statusFg = _getStatusTextColor(stockRequest.status);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Request number and Status Badge
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: statusFg,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stockRequest.requestNumber,
                            style: const TextStyle(
                              color: _deepBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            stockRequest.displayDate,
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusFg.withAlpha(70), width: 1),
                      ),
                      child: Text(
                        stockRequest.displayStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF0F7FC)),
                const SizedBox(height: 8),

                // Line 2: Partner / Business info
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: Color(0xFF607D8B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stockRequest.businessName != null && stockRequest.businessName!.isNotEmpty
                            ? '${stockRequest.businessName} (${stockRequest.partnerName})'
                            : stockRequest.partnerName,
                        style: const TextStyle(
                          color: _royalBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Line 3: Item count and Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${stockRequest.itemCount} requested items • ${stockRequest.totalQuantity} total qty',
                      style: const TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            color: _royalBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFFB0BEC5),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

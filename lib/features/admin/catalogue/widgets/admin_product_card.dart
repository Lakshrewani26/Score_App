import 'package:flutter/material.dart';

import '../../../../core/models/admin_catalogue_models.dart';

class AdminProductCard extends StatelessWidget {
  const AdminProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final AdminProduct product;
  final VoidCallback onTap;

  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  Color _getVehicleColor(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case '2-wheeler':
        return const Color(0xFF00897B);
      case '3-wheeler':
        return const Color(0xFFE65100);
      case 'both':
      default:
        return const Color(0xFF0055B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleColor = _getVehicleColor(product.vehicleType);
    final priceLabel = product.price == null ? 'Price not set' : product.displayPrice;

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
                // Product Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: vehicleColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: vehicleColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Main info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Line 1: Name and Status Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: product.isActive
                                  ? const Color(0xFFE8F8EE)
                                  : const Color(0xFFFBE9E7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: product.isActive
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE57373),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  product.isActive
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 11,
                                  color: product.isActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  product.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: product.isActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Line 2: Code and Category
                      Row(
                        children: [
                          Text(
                            product.productCode,
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (product.categoryName != null && product.categoryName!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '•',
                              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                product.categoryName!,
                                style: const TextStyle(
                                  color: Color(0xFF557A95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Line 3: Vehicle Type & Price
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: vehicleColor.withAlpha(24),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              product.vehicleType,
                              style: TextStyle(
                                color: vehicleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              priceLabel,
                              style: TextStyle(
                                color: product.price == null ? const Color(0xFF78909C) : _deepBlue,
                                fontSize: 12,
                                fontWeight: product.price == null ? FontWeight.w500 : FontWeight.w700,
                                fontStyle: product.price == null ? FontStyle.italic : FontStyle.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFFB0BEC5),
                          ),
                        ],
                      ),
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

import 'package:flutter/material.dart';

import '../models/catalogue_models.dart';
import '../services/new_arrivals_service.dart';

enum NewArrivalsRole {
  customer,
  partner,
  staff,
}

/// Shared New Arrivals widget used across Customer, Partner, and Staff home screens.
///
/// Features:
/// - Dynamically loads the newest products via [NewArrivalsDataSource].
/// - Limits the displayed products to a maximum of 5.
/// - Displays loading, empty, and error/retry states.
/// - Provides fallback icons when product image is null, empty, or fails to load.
/// - Supports pull-to-refresh / programmatic refresh via [NewArrivalsSectionState.reload].
/// - Displays role-specific price information (MRP for Customer, List Price + MRP for Partner/Staff).
class NewArrivalsSection extends StatefulWidget {
  const NewArrivalsSection({
    super.key,
    required this.role,
    this.dataSource,
    this.onProductTap,
  });

  final NewArrivalsRole role;
  final NewArrivalsDataSource? dataSource;
  final void Function(CatalogueProduct product)? onProductTap;

  @override
  State<NewArrivalsSection> createState() => NewArrivalsSectionState();
}

class NewArrivalsSectionState extends State<NewArrivalsSection> {
  static const Color royalBlue = Color(0xFF083FA5);
  static const Color cardBorderBlue = Color(0xFFCBEBFF);

  late NewArrivalsDataSource _dataSource;
  List<CatalogueProduct> _products = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ApiNewArrivalsDataSource();
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant NewArrivalsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataSource != oldWidget.dataSource) {
      _dataSource = widget.dataSource ?? ApiNewArrivalsDataSource();
      _loadProducts();
    }
  }

  Future<void> reload() => _loadProducts();

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _dataSource.getNewArrivals(limit: 5);
      if (!mounted) return;
      setState(() {
        _products = items.take(5).toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _isLoading = false;
        _errorMessage = 'Failed to load new arrivals';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = widget.role == NewArrivalsRole.staff;
    final sectionHeight = isStaff ? 165.0 : 182.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'New Arrivals',
                style: TextStyle(
                  color: royalBlue,
                  fontSize: isStaff ? 17 : 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorderBlue, width: 1),
              ),
              child: const Text(
                'Newly Added',
                style: TextStyle(
                  color: royalBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isStaff ? 8 : 10),
        if (_isLoading)
          _buildLoadingState(sectionHeight)
        else if (_errorMessage != null)
          _buildErrorState(isStaff ? 130.0 : 140.0)
        else if (_products.isEmpty)
          _buildEmptyState(isStaff ? 120.0 : 130.0)
        else
          SizedBox(
            height: sectionHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (_, __) => SizedBox(width: isStaff ? 10 : 12),
              itemBuilder: (context, index) {
                return _buildProductCard(_products[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderBlue, width: 1.2),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: royalBlue,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(double height) {
    final isStaff = widget.role == NewArrivalsRole.staff;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: const Color(0xFF8A98A8),
              size: isStaff ? 28 : 32,
            ),
            SizedBox(height: isStaff ? 6 : 8),
            const Text(
              'No new arrivals available at this time.',
              style: TextStyle(
                color: Color(0xFF4A6B94),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFD32F2F),
              size: 28,
            ),
            const SizedBox(height: 6),
            const Text(
              'Failed to load new arrivals',
              style: TextStyle(
                color: Color(0xFF4A6B94),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _loadProducts,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: royalBlue, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: royalBlue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: royalBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(CatalogueProduct product) {
    final isStaff = widget.role == NewArrivalsRole.staff;
    final cardWidth = isStaff ? 136.0 : 142.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderBlue, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x180755B5),
            blurRadius: isStaff ? 10 : 12,
            spreadRadius: 0,
            offset: Offset(0, isStaff ? 3 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.onProductTap != null) {
                widget.onProductTap!(product);
              } else {
                _showProductDetailsSheet(context, product, widget.role);
              }
            },
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: isStaff ? 40 : 44,
                  child: CustomPaint(
                    painter: _ProductCardWavePainter(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: isStaff ? 4 : (widget.role == NewArrivalsRole.partner ? 6 : 10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProductImageOrPlaceholder(product.imageUrl, isStaff ? 64 : 70),
                      SizedBox(height: isStaff ? 2 : 4),
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: royalBlue,
                          fontSize: widget.role == NewArrivalsRole.customer ? 13.5 : 13,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: isStaff ? 2 : 4),
                      _buildPriceBadge(product),
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

  Widget _buildPriceBadge(CatalogueProduct product) {
    if (widget.role == NewArrivalsRole.customer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                product.displayPrice,
                style: const TextStyle(
                  color: royalBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              'MRP',
              style: TextStyle(
                color: Color(0xFF5B7898),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Partner and Staff roles
    if (product.listPrice != null) {
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFA5D6A7),
                width: 0.8,
              ),
            ),
            child: Text(
              product.displayListPrice,
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            'MRP: ${product.displayPrice}',
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFE082),
              width: 0.8,
            ),
          ),
          child: Text(
            product.displayPrice,
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductImageOrPlaceholder(String? imageUrl, double size) {
    final hasValidImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasValidImage) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDCEBFE),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          color: royalBlue,
          size: size * 0.45,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCEBFE),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.image_not_supported_rounded,
              color: royalBlue,
              size: size * 0.45,
            );
          },
        ),
      ),
    );
  }

  static void _showProductDetailsSheet(
    BuildContext context,
    CatalogueProduct product,
    NewArrivalsRole role,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorderBlue, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x290755B5),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Product Details',
                        style: TextStyle(
                          color: royalBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: royalBlue),
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFDCEBFE),
                  ),
                  child: ClipOval(
                    child: (product.imageUrl != null && product.imageUrl!.trim().isNotEmpty)
                        ? Image.network(
                            product.imageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported_rounded,
                                color: royalBlue,
                                size: 30,
                              );
                            },
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: royalBlue,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: royalBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Code: ${product.productCode}',
                    style: const TextStyle(
                      color: royalBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vehicle Type: ${product.vehicleType}',
                  style: const TextStyle(
                    color: Color(0xFF5B7898),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (product.categoryName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${product.categoryName}',
                    style: const TextStyle(
                      color: Color(0xFF5B7898),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (role == NewArrivalsRole.customer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${product.displayPrice} MRP',
                      style: const TextStyle(
                        color: royalBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else ...[
                  if (product.listPrice != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
                      ),
                      child: Text(
                        'List Price: ${product.displayListPrice}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MRP: ${product.displayPrice}',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE082), width: 1),
                      ),
                      child: Text(
                        'Price: ${product.displayPrice}',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
                if (product.description != null && product.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorderBlue, width: 1),
                    ),
                    child: Text(
                      product.description!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4A6B94),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0x120755B5)
      ..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.7,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.85,
        size.width,
        size.height * 0.7,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = const Color(0x1F0755B5)
      ..style = PaintingStyle.fill;
    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.9,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

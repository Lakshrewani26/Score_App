import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/models/partner_order_models.dart';
import '../../../core/services/catalogue_api.dart';
import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import 'staff_order_summary_screen.dart';

class StaffProductItem {
  final String id;
  final String name;
  final double mrp;
  final int initialQuantity;
  final CustomPainter illustrationPainter;

  const StaffProductItem({
    required this.id,
    required this.name,
    required this.mrp,
    required this.initialQuantity,
    required this.illustrationPainter,
  });
}

class StaffOrdersScreen extends StatefulWidget {
  const StaffOrdersScreen({
    super.key,
    this.partner,
    this.partnerId,
    this.catalogueApi,
    this.orderApi,
    this.sessionManager,
    this.initialProducts,
  });

  final StaffAssignedPartner? partner;
  final int? partnerId;
  final CatalogueApi? catalogueApi;
  final StaffApi? orderApi;
  final StaffSessionManager? sessionManager;
  final List<CatalogueProduct>? initialProducts;

  int? get effectivePartnerId => partner?.id ?? partnerId;

  @override
  State<StaffOrdersScreen> createState() => _StaffOrdersScreenState();
}

class _StaffOrdersScreenState extends State<StaffOrdersScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _blueAccent = Color(0xFF0068B9);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  final TextEditingController _searchController = TextEditingController();
  final Map<int, int> _quantities = {};
  final Map<int, CatalogueProduct> _productCache = {};

  late final CatalogueApi _catalogueApi;
  late final StaffApi _orderApi;
  late final StaffSessionManager _sessionManager;

  List<CatalogueProduct> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedVehicleType = 'All';

  @override
  void initState() {
    super.initState();
    _catalogueApi = widget.catalogueApi ?? CatalogueApi();
    _sessionManager = widget.sessionManager ?? StaffSessionManager.instance;
    _orderApi = widget.orderApi ?? StaffApi(sessionManager: _sessionManager);

    if (widget.initialProducts != null) {
      _products = List.from(widget.initialProducts!);
      for (final p in _products) {
        _productCache[p.id] = p;
        _quantities[p.id] = 0;
      }
    } else if (widget.effectivePartnerId != null) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final page = await _catalogueApi.loadProducts(
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _products = page.items;
        for (final p in _products) {
          _productCache[p.id] = p;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<CatalogueProduct> get _filteredProducts {
    var list = _products;
    if (_selectedVehicleType != 'All') {
      list = list.where((p) {
        final vt = p.vehicleType.toLowerCase();
        if (vt == 'both') return true;
        if (_selectedVehicleType == '2-Wheeler') {
          return vt.contains('2') || vt.contains('two');
        }
        if (_selectedVehicleType == '3-Wheeler') {
          return vt.contains('3') || vt.contains('three');
        }
        return true;
      }).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.productCode.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _incrementQuantity(int productId) {
    setState(() {
      _quantities[productId] = (_quantities[productId] ?? 0) + 1;
    });
  }

  void _decrementQuantity(int productId) {
    setState(() {
      final current = _quantities[productId] ?? 0;
      if (current > 0) {
        _quantities[productId] = current - 1;
      }
    });
  }

  void _onContinuePressed() {
    // If opened standalone with no products and no dealer (test fallback)
    if (_products.isEmpty && widget.effectivePartnerId == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const StaffOrderSummaryScreen(),
        ),
      );
      return;
    }

    final totalQuantity = _quantities.values.fold<int>(0, (sum, q) => sum + q);
    if (totalQuantity <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one product with quantity greater than zero.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cartItems = <CartItem>[];
    for (final entry in _quantities.entries) {
      if (entry.value > 0) {
        final product = _productCache[entry.key];
        if (product != null) {
          if (product.price == null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Product "${product.name}" has no valid price. Please remove or adjust.',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            return;
          }
          cartItems.add(CartItem(product: product, quantity: entry.value));
        }
      }
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one product with quantity greater than zero.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffOrderSummaryScreen(
          partner: widget.partner,
          partnerId: widget.effectivePartnerId,
          cartItems: cartItems,
          orderApi: _orderApi,
          sessionManager: _sessionManager,
          onCartUpdated: (updatedQuantities) {
            setState(() {
              _quantities.clear();
              _quantities.addAll(updatedQuantities);
            });
          },
          onOrderSuccess: () {
            setState(() {
              _quantities.clear();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final contentWidth = math.min(width * 0.92, 420.0);

            final filteredList = _filteredProducts;

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 12),
                              const Text(
                                'Add Order',
                                style: TextStyle(
                                  color: _royalBlue,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Select products and quantity',
                                style: TextStyle(
                                  color: _royalBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (widget.partner != null) ...[
                                const SizedBox(height: 8),
                                _buildDealerInfoBadge(),
                              ],
                              const SizedBox(height: 14),
                              _buildSearchField(),
                              if (_products.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildVehicleTypeFilter(),
                              ],
                              const SizedBox(height: 16),
                              if (_isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: _royalBlue,
                                    ),
                                  ),
                                )
                              else if (filteredList.isEmpty)
                                _buildEmptyState()
                              else
                                ...filteredList.map(
                                  (product) => _buildProductCard(product),
                                ),
                              const SizedBox(height: 12),
                              _buildContinueButton(context),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildDealerInfoBadge() {
    final partner = widget.partner!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.domain_rounded,
            color: _royalBlue,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Dealer: ${partner.businessName} (ID: ${partner.id})',
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeFilter() {
    return Row(
      children: [
        _buildFilterChip('All'),
        const SizedBox(width: 8),
        _buildFilterChip('2-Wheeler'),
        const SizedBox(width: 8),
        _buildFilterChip('3-Wheeler'),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedVehicleType == label;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedVehicleType = label;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _royalBlue : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _royalBlue : _cardBorderBlue,
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : _royalBlue,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, double width) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _royalBlue,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/images/app_logo_blended.png',
              width: math.min(width * 0.44, 160.0),
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation(0.96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderBlue, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: _royalBlue,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: 'Search products',
          hintStyle: TextStyle(
            color: Color(0xFF8A98A8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _blueAccent,
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _products.isEmpty
        ? 'Product ordering is not available yet.'
        : 'No products match your search.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(CatalogueProduct product) {
    final qty = _quantities[product.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD4F0FF),
              ),
              child: ClipOval(
                child: product.imageUrl != null &&
                        product.imageUrl!.trim().isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: _royalBlue,
                          size: 26,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: _royalBlue,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: _royalBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MRP: ${product.displayPrice}',
                    style: const TextStyle(
                      color: _blueAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildQuantityControl(product.id, qty),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControl(int productId, int quantity) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4F0FF), width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _decrementQuantity(productId),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF007BFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _incrementQuantity(productId),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF007BFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0061B4),
            Color(0xFF008DCC),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330061B4),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onContinuePressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

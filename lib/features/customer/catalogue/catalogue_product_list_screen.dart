import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/services/catalogue_api.dart';
import '../../../core/models/partner_order_models.dart';
import '../../partner/orders/partner_order_summary_screen.dart';

class CatalogueProductListScreen extends StatefulWidget {
  const CatalogueProductListScreen({
    super.key,
    required this.api,
    required this.vehicleType,
    required this.title,
    required this.heroCaption,
    this.fallbackBuilder,
    this.enablePartnerQuantitySelection = false,
    this.accentColor = const Color(0xFFDCEBFE),
    this.heroIcon,
  });

  final CatalogueApi api;
  final String vehicleType;
  final String title;
  final String heroCaption;
  final WidgetBuilder? fallbackBuilder;
  final bool enablePartnerQuantitySelection;
  final Color accentColor;
  final IconData? heroIcon;

  @override
  State<CatalogueProductListScreen> createState() =>
      _CatalogueProductListScreenState();
}

class _CatalogueProductListScreenState
    extends State<CatalogueProductListScreen> {
  static const Color _royalBlue = Color(0xFF083FA5);
  static const Color _cardBorderBlue = Color(0xFFCBEBFF);
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _reloadRequested = false;
  bool _categoriesLoaded = false;
  String? _errorMessage;
  String _searchTerm = '';
  int? _selectedCategoryId;
  int _page = 1;
  static const int _pageSize = 20;
  final Map<int, int> _quantitiesByProductId = {};
  final Map<int, CatalogueProduct> _productCache = {};
  ProductPagination? _pagination;
  List<CatalogueCategory> _categories = const [];
  List<CatalogueProduct> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogueProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleType != widget.vehicleType) {
      _page = 1;
      _pagination = null;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    if (_isLoading) {
      _reloadRequested = true;
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    while (mounted) {
      _reloadRequested = false;
      final requestedPage = _page;
      final requestedCategoryId = _selectedCategoryId;
      final requestedSearch = _searchTerm;
      final requestedVehicleType = widget.vehicleType;

      try {
        final categories =
            _categoriesLoaded ? _categories : await widget.api.loadCategories();
        final productPage = await widget.api.loadProducts(
          categoryId: requestedCategoryId,
          vehicleType: requestedVehicleType,
          search: requestedSearch.isNotEmpty ? requestedSearch : null,
          page: requestedPage,
          pageSize: _pageSize,
        );

        if (!mounted) {
          return;
        }
        if (_reloadRequested) {
          continue;
        }

        setState(() {
          _categories = categories;
          _categoriesLoaded = true;
          _products = productPage.items;
          for (final p in productPage.items) {
            _productCache[p.id] = p;
          }
          _pagination = productPage.pagination;
          _page = productPage.pagination.page;
        });
        break;
      } on CatalogueApiException catch (error, stackTrace) {
        if (_reloadRequested) {
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            'Catalogue load failed for $requestedVehicleType: '
            '${error.message} (HTTP ${error.statusCode ?? 'unknown'})\n'
            '$stackTrace',
          );
        }
        if (mounted) {
          setState(() => _errorMessage = error.message);
        }
        break;
      } catch (error, stackTrace) {
        if (_reloadRequested) {
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            'Catalogue load failed for $requestedVehicleType: '
            '$error\n$stackTrace',
          );
        }
        if (mounted) {
          setState(() => _errorMessage = 'Unable to load catalogue data.');
        }
        break;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchTerm = value;
      _page = 1;
    });
    _searchDebounce = Timer(_searchDebounceDuration, _loadData);
  }

  Future<void> _changePage(int page) async {
    final pagination = _pagination;
    if (_isLoading ||
        pagination == null ||
        page < 1 ||
        page > pagination.totalPages ||
        page == _page) {
      return;
    }

    _searchDebounce?.cancel();
    setState(() => _page = page);
    await _loadData();
  }

  Future<void> _openProductDetails(CatalogueProduct product) async {
    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProductDetailSheet(
          productId: product.id,
          api: widget.api,
        );
      },
    );
  }

  Widget _buildQuantityControls(int productId) {
    final quantity = _quantitiesByProductId[productId] ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: Key('quantity-minus-$productId'),
          onPressed: quantity == 0
              ? null
              : () => _setQuantity(productId, quantity - 1),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFDCEBFE),
            foregroundColor: _royalBlue,
            disabledForegroundColor: const Color(0xFF9AAFC7),
          ),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$quantity',
            key: Key('quantity-value-$productId'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _royalBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: Key('quantity-plus-$productId'),
          onPressed: () => _setQuantity(productId, quantity + 1),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFDCEBFE),
            foregroundColor: _royalBlue,
          ),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  void _setQuantity(int productId, int quantity) {
    if (quantity < 0) {
      return;
    }
    setState(() => _quantitiesByProductId[productId] = quantity);
  }

  Widget _buildPartnerOrderAvailability() {
    final selectedUnits = _quantitiesByProductId.values.fold<int>(
      0,
      (total, quantity) => total + quantity,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            'Selected units: $selectedUnits',
            key: const Key('partner-selected-units'),
            style: const TextStyle(
              color: _royalBlue,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('partner-continue-order-button'),
              onPressed: _onContinueClicked,
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onContinueClicked() {
    final selectedUnits = _quantitiesByProductId.values.fold<int>(
      0,
      (total, quantity) => total + quantity,
    );
    if (selectedUnits <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('partner-empty-cart-snackbar'),
          content: Text(
            'Please select at least one product with quantity greater than zero.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cartItems = <CartItem>[];
    for (final entry in _quantitiesByProductId.entries) {
      if (entry.value > 0) {
        final product = _productCache[entry.key];
        if (product != null) {
          if (product.price == null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                key: const Key('partner-null-price-snackbar'),
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
          key: Key('partner-empty-cart-snackbar'),
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
        builder: (_) => PartnerOrderSummaryScreen(
          cartItems: cartItems,
          onCartUpdated: (updatedQuantities) {
            setState(() {
              _quantitiesByProductId.clear();
              _quantitiesByProductId.addAll(updatedQuantities);
            });
          },
          onOrderSuccess: () {
            setState(() {
              _quantitiesByProductId.clear();
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 18),
                              _buildHeroCard(),
                              const SizedBox(height: 16),
                              _buildFilters(),
                              const SizedBox(height: 18),
                              _buildBody(),
                              const SizedBox(height: 24),
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

  Widget _buildHeaderRow(BuildContext context, double width) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (widget.fallbackBuilder != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: widget.fallbackBuilder!,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
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

  Widget _buildHeroCard() {
    final icon = widget.heroIcon ?? Icons.settings_input_component_rounded;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 155),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderBlue, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0755B5),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 55,
              child: CustomPaint(
                painter: _TwoWheelerCardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: _royalBlue,
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1.2,
                    height: 86,
                    color: const Color(0xFFCBEBFF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.heroCaption,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final categoryItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
      ..._categories.map(
        (category) => DropdownMenuItem<int?>(
          value: category.id,
          child: Text(category.name),
        ),
      ),
    ];

    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD6EAFF), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100755B5),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: _royalBlue,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    color: _royalBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search for parts...',
                    hintStyle: TextStyle(
                      color: Color(0xFF7B93AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD6EAFF), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              value: _selectedCategoryId,
              hint: const Text('Filter by category'),
              onChanged: (value) {
                if (value == _selectedCategoryId) {
                  return;
                }
                _searchDebounce?.cancel();
                setState(() {
                  _selectedCategoryId = value;
                  _page = 1;
                });
                _loadData();
              },
              items: categoryItems,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    late final Widget content;
    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: _royalBlue),
        ),
      );
    } else if (_errorMessage != null) {
      content = Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 36, color: _royalBlue),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_products.isEmpty) {
      content = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No products match your search.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royalBlue,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      content = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: widget.enablePartnerQuantitySelection ? 0.68 : 0.74,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openProductDetails(_products[index]),
            child: _buildProductCard(_products[index]),
          );
        },
      );
    }

    return Column(
      children: [
        content,
        if (_pagination != null && _errorMessage == null) ...[
          const SizedBox(height: 18),
          _buildPaginationControls(_pagination!),
        ],
        if (widget.enablePartnerQuantitySelection) ...[
          const SizedBox(height: 16),
          _buildPartnerOrderAvailability(),
        ],
      ],
    );
  }

  Widget _buildPaginationControls(ProductPagination pagination) {
    final currentPage = pagination.page;
    final totalPages = pagination.totalPages;
    final canGoPrevious = !_isLoading && currentPage > 1;
    final canGoNext = !_isLoading && totalPages > 0 && currentPage < totalPages;

    return Column(
      children: [
        Text(
          'Page $currentPage of $totalPages · ${pagination.total} products',
          key: const Key('catalogue-page-summary'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              key: const Key('catalogue-previous-page'),
              onPressed:
                  canGoPrevious ? () => _changePage(currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _royalBlue,
                side: const BorderSide(color: _cardBorderBlue),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('catalogue-next-page'),
              onPressed: canGoNext ? () => _changePage(currentPage + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _royalBlue,
                side: const BorderSide(color: _cardBorderBlue),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductCard(CatalogueProduct product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180755B5),
            blurRadius: 14,
            spreadRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44,
              child: CustomPaint(
                painter: _ProductCardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildImageOrPlaceholder(product.imageUrl),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _royalBlue,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              color: _royalBlue,
                              fontSize: 13,
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
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.enablePartnerQuantitySelection) ...[
                    const SizedBox(height: 6),
                    _buildQuantityControls(product.id),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder(String? imageUrl) {
    final hasValidImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasValidImage) {
      return Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDCEBFE),
        ),
        child:
            const Icon(Icons.inventory_2_outlined, color: _royalBlue, size: 34),
      );
    }

    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCEBFE),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 76,
          height: 76,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image_not_supported_rounded,
                color: _royalBlue, size: 32);
          },
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({required this.productId, required this.api});

  final int productId;
  final CatalogueApi api;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  late Future<CatalogueProduct> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = widget.api.getProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FutureBuilder<CatalogueProduct>(
            future: _productFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load product details.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              final product = snapshot.data!;
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildImage(product.imageUrl),
                  const SizedBox(height: 18),
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Color(0xFF083FA5),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.categoryName ?? 'General Category',
                    style: const TextStyle(
                      color: Color(0xFF5B7898),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.displayPrice,
                      style: const TextStyle(
                        color: Color(0xFF083FA5),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (product.description != null &&
                      product.description!.trim().isNotEmpty) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Color(0xFF083FA5),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description!,
                      style: const TextStyle(
                        color: Color(0xFF243B5A),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Description not available.',
                      style: TextStyle(
                        color: Color(0xFF243B5A),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _detailChip('Code', product.productCode),
                      _detailChip('Vehicle', product.vehicleType),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildImage(String? imageUrl) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasImage) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Icon(Icons.inventory_2_outlined,
              size: 52, color: Color(0xFF083FA5)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(Icons.image_not_supported_rounded,
                  size: 52, color: Color(0xFF083FA5)),
            ),
          );
        },
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF083FA5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFDED0FF).withAlpha(100)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.68,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.75,
        size.width,
        size.height * 0.3,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.35, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.2,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TwoWheelerCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFDED0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.15,
        size.width * 0.65,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.8,
        size.width,
        size.height * 0.3,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.35,
        size.width * 0.8,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.9,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

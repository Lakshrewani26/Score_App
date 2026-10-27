import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_catalogue_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_catalogue_api.dart';
import '../../../core/services/admin_session_manager.dart';
import 'widgets/admin_category_card.dart';
import 'widgets/admin_category_form_dialog.dart';
import 'widgets/admin_product_card.dart';
import 'widgets/admin_product_detail_sheet.dart';
import 'widgets/admin_product_form_dialog.dart';

enum AdminCatalogueTab { products, categories }

class AdminCatalogueScreen extends StatefulWidget {
  const AdminCatalogueScreen({
    super.key,
    this.adminApi,
    this.catalogueApi,
    this.sessionManager,
  });

  final AdminApi? adminApi;
  final AdminCatalogueApi? catalogueApi;
  final AdminSessionManager? sessionManager;

  @override
  State<AdminCatalogueScreen> createState() => _AdminCatalogueScreenState();
}

class _AdminCatalogueScreenState extends State<AdminCatalogueScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  late final AdminSessionManager _session;
  late final AdminCatalogueApi _catalogueApi;

  AdminCatalogueTab _activeTab = AdminCatalogueTab.products;

  // ---------------------------------------------------------------------------
  // Products Tab State
  // ---------------------------------------------------------------------------
  final TextEditingController _productSearchController =
      TextEditingController();
  Timer? _productSearchDebounceTimer;

  int? _selectedProductCategoryId;
  String _selectedVehicleType = 'all';
  String _selectedProductStatus = 'all';
  String _selectedPriceFilter = 'all';

  int _productPage = 1;
  static const int _productPageSize = 20;

  bool _isLoadingProducts = true;
  String? _productErrorMessage;
  List<AdminProduct> _products = [];
  int _totalProducts = 0;
  int _totalProductPages = 0;
  int _productRequestSeq = 0;

  List<AdminCategory> _categoriesForFilter = [];
  String? _categoryFilterErrorMessage;

  // ---------------------------------------------------------------------------
  // Categories Tab State
  // ---------------------------------------------------------------------------
  final TextEditingController _categorySearchController =
      TextEditingController();
  Timer? _categorySearchDebounceTimer;

  String _selectedCategoryStatus = 'all';

  bool _isLoadingCategories = true;
  String? _categoryErrorMessage;
  List<AdminCategory> _categories = [];
  int _categoryRequestSeq = 0;
  int? _pendingCategoryStatusId;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _catalogueApi = widget.catalogueApi ??
        widget.adminApi?.catalogue ??
        AdminCatalogueApi(sessionManager: _session);

    _productSearchController.addListener(_onProductSearchChanged);
    _categorySearchController.addListener(_onCategorySearchChanged);

    _loadInitialData();
  }

  @override
  void dispose() {
    _productSearchDebounceTimer?.cancel();
    _categorySearchDebounceTimer?.cancel();
    _productSearchController.removeListener(_onProductSearchChanged);
    _categorySearchController.removeListener(_onCategorySearchChanged);
    _productSearchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    _fetchCategoriesForFilter();
    _fetchProducts();
    _fetchCategories();
  }

  void _onProductSearchChanged() {
    _productSearchDebounceTimer?.cancel();
    _productSearchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _productPage = 1;
      });
      _fetchProducts();
    });
  }

  void _onCategorySearchChanged() {
    _categorySearchDebounceTimer?.cancel();
    _categorySearchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _fetchCategories();
    });
  }

  Future<void> _fetchCategoriesForFilter() async {
    try {
      final categories = await _catalogueApi.getAdminCategories();
      if (!mounted) return;
      setState(() {
        _categoriesForFilter = categories;
        _categoryFilterErrorMessage = null;
      });
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _categoryFilterErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryFilterErrorMessage =
            'Failed to load category filters. Please check your connection.';
      });
    }
  }

  Future<void> _fetchProducts() async {
    final thisSeq = ++_productRequestSeq;

    setState(() {
      _isLoadingProducts = true;
      _productErrorMessage = null;
    });

    final searchVal = _productSearchController.text.trim();
    final vehicleVal =
        _selectedVehicleType != 'all' ? _selectedVehicleType : null;
    final statusVal =
        _selectedProductStatus != 'all' ? _selectedProductStatus : null;

    bool? hasPriceVal;
    bool? priceMissingVal;
    if (_selectedPriceFilter == 'set') {
      hasPriceVal = true;
    } else if (_selectedPriceFilter == 'missing') {
      priceMissingVal = true;
    }

    try {
      final response = await _catalogueApi.getAdminProducts(
        page: _productPage,
        pageSize: _productPageSize,
        search: searchVal.isNotEmpty ? searchVal : null,
        categoryId: _selectedProductCategoryId,
        vehicleType: vehicleVal,
        status: statusVal,
        hasPrice: hasPriceVal,
        priceMissing: priceMissingVal,
      );

      if (!mounted || thisSeq != _productRequestSeq) return;

      setState(() {
        _products = response.items;
        _totalProducts = response.total;
        _totalProductPages = response.totalPages;
        _productPage = response.page;
        _isLoadingProducts = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _productRequestSeq) return;
      setState(() {
        _productErrorMessage = e.message;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _productRequestSeq) return;
      setState(() {
        _productErrorMessage =
            'Failed to load products. Please check your connection.';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    final thisSeq = ++_categoryRequestSeq;

    setState(() {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
    });

    final searchVal = _categorySearchController.text.trim();
    final statusVal =
        _selectedCategoryStatus != 'all' ? _selectedCategoryStatus : null;

    try {
      final categories = await _catalogueApi.getAdminCategories(
        search: searchVal.isNotEmpty ? searchVal : null,
        status: statusVal,
      );

      if (!mounted || thisSeq != _categoryRequestSeq) return;

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _categoryRequestSeq) return;
      setState(() {
        _categoryErrorMessage = e.message;
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _categoryRequestSeq) return;
      setState(() {
        _categoryErrorMessage =
            'Failed to load categories. Please check your connection.';
        _isLoadingCategories = false;
      });
    }
  }

  void _handleRefresh() {
    if (_activeTab == AdminCatalogueTab.products) {
      _fetchCategoriesForFilter();
      _fetchProducts();
    } else {
      _fetchCategories();
    }
  }

  void _openProductDetail(AdminProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminProductDetailSheet(
        product: product,
        catalogueApi: _catalogueApi,
        categories: _categoriesForFilter,
        onProductUpdated: (updatedProduct) {
          _fetchProducts();
        },
      ),
    );
  }

  void _openCreateProductDialog() {
    showDialog(
      context: context,
      builder: (_) => AdminProductFormDialog(
        catalogueApi: _catalogueApi,
        categories: _categoriesForFilter,
        onSuccess: (newProduct) {
          _fetchCategoriesForFilter();
          _fetchProducts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product created successfully'),
              backgroundColor: Color(0xFF00897B),
            ),
          );
        },
      ),
    );
  }

  void _openCreateCategoryDialog() {
    showDialog(
      context: context,
      builder: (_) => AdminCategoryFormDialog(
        catalogueApi: _catalogueApi,
        onSuccess: (newCategory) {
          _fetchCategoriesForFilter();
          _fetchCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category created successfully'),
              backgroundColor: Color(0xFF00897B),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleToggleCategoryStatus(AdminCategory category) async {
    if (_pendingCategoryStatusId != null) return;

    final targetActive = !category.isActive;
    final actionName = targetActive ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('category_status_confirm_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          targetActive ? 'Activate Category' : 'Deactivate Category',
          style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to $actionName "${category.name}"?',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('category_status_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Color(0xFF78909C), fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            key: const Key('category_status_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: targetActive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(targetActive ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _pendingCategoryStatusId = category.id;
    });

    try {
      await _catalogueApi.updateCategoryStatus(category.id, targetActive);

      if (!mounted) return;

      setState(() {
        _pendingCategoryStatusId = null;
      });

      _fetchCategoriesForFilter();
      _fetchCategories();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetActive
                ? 'Category activated successfully'
                : 'Category deactivated successfully',
          ),
          backgroundColor:
              targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingCategoryStatusId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingCategoryStatusId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update category status. Please try again.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
    }
  }

  void _goToPreviousProductPage() {
    if (_productPage > 1) {
      setState(() {
        _productPage--;
      });
      _fetchProducts();
    }
  }

  void _goToNextProductPage() {
    if (_productPage < _totalProductPages) {
      setState(() {
        _productPage++;
      });
      _fetchProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = math.min(width * 0.94, 600.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).padding.top + 10),
                        _buildHeader(context),
                        const SizedBox(height: 12),
                        _buildSectionSwitcher(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _activeTab == AdminCatalogueTab.products
                              ? _buildProductsSection()
                              : _buildCategoriesSection(),
                        ),
                        if (_activeTab == AdminCatalogueTab.products &&
                            !_isLoadingProducts &&
                            _productErrorMessage == null &&
                            _products.isNotEmpty) ...[
                          _buildPaginationFooter(),
                        ],
                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 8),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Back Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('admin_catalogue_back_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120755B5),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _royalBlue,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Title & Subtitle
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catalogue Management',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Manage products and categories',
                style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Refresh action
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('admin_catalogue_refresh_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: _handleRefresh,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120755B5),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _royalBlue,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSwitcher() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0755B5),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              key: const Key('tab_products'),
              title: 'Products',
              icon: Icons.inventory_2_rounded,
              isSelected: _activeTab == AdminCatalogueTab.products,
              onTap: () {
                if (_activeTab != AdminCatalogueTab.products) {
                  setState(() {
                    _activeTab = AdminCatalogueTab.products;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              key: const Key('tab_categories'),
              title: 'Categories',
              icon: Icons.category_rounded,
              isSelected: _activeTab == AdminCatalogueTab.categories,
              onTap: () {
                if (_activeTab != AdminCatalogueTab.categories) {
                  setState(() {
                    _activeTab = AdminCatalogueTab.categories;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required Key key,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? _royalBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? Colors.white : const Color(0xFF557A95),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF557A95),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Products Section UI
  // ---------------------------------------------------------------------------
  Widget _buildProductsSection() {
    return Column(
      children: [
        _buildProductActionBar(),
        const SizedBox(height: 10),
        _buildProductFilters(),
        const SizedBox(height: 10),
        Expanded(child: _buildProductListContent()),
      ],
    );
  }

  Widget _buildProductActionBar() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        key: const Key('add_product_button'),
        onPressed: _openCreateProductDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: _royalBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text(
          'Add Product',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildProductFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FCFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _fieldBorderBlue, width: 1),
            ),
            child: TextField(
              key: const Key('product_search_input'),
              controller: _productSearchController,
              style: const TextStyle(color: _deepBlue, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search products by name or code...',
                hintStyle:
                    const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _royalBlue, size: 18),
                suffixIcon: _productSearchController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('product_search_clear_button'),
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF78909C), size: 16),
                        onPressed: () {
                          _productSearchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter Dropdowns Row 1: Category & Vehicle Type
          Row(
            children: [
              // Category Filter
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      key: const Key('product_category_filter_dropdown'),
                      value: _selectedProductCategoryId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 18),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Categories',
                              overflow: TextOverflow.ellipsis),
                        ),
                        ..._categoriesForFilter
                            .map((c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.name,
                                      overflow: TextOverflow.ellipsis),
                                )),
                      ],
                      onChanged: (val) {
                        if (val != _selectedProductCategoryId) {
                          setState(() {
                            _selectedProductCategoryId = val;
                            _productPage = 1;
                          });
                          _fetchProducts();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Vehicle Type Filter
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('product_vehicle_type_filter_dropdown'),
                      value: _selectedVehicleType,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 18),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('All Vehicles',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: '2-Wheeler',
                            child: Text('2-Wheeler',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: '3-Wheeler',
                            child: Text('3-Wheeler',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'Both',
                            child:
                                Text('Both', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedVehicleType) {
                          setState(() {
                            _selectedVehicleType = val;
                            _productPage = 1;
                          });
                          _fetchProducts();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_categoryFilterErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _categoryFilterErrorMessage!,
                      key: const Key('category_filter_error'),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('category_filter_retry_button'),
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                    tooltip: 'Retry category filters',
                    onPressed: _fetchCategoriesForFilter,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _royalBlue,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Filter Dropdowns Row 2: Status & Price Filter
          Row(
            children: [
              // Status Filter
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('product_status_filter_dropdown'),
                      value: _selectedProductStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 18),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('All Status',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'active',
                            child: Text('Active',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive',
                                overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedProductStatus) {
                          setState(() {
                            _selectedProductStatus = val;
                            _productPage = 1;
                          });
                          _fetchProducts();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Price Filter
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('product_price_filter_dropdown'),
                      value: _selectedPriceFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _royalBlue, size: 18),
                      style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('All Prices',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'set',
                            child: Text('Price Set',
                                overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'missing',
                            child: Text('Price Missing',
                                overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedPriceFilter) {
                          setState(() {
                            _selectedPriceFilter = val;
                            _productPage = 1;
                          });
                          _fetchProducts();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductListContent() {
    if (_isLoadingProducts) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _royalBlue),
            SizedBox(height: 14),
            Text(
              'Loading products...',
              style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_productErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _productErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('product_retry_button'),
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F5FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 30, color: _royalBlue),
              ),
              const SizedBox(height: 14),
              const Text(
                'No products found',
                style: TextStyle(
                    color: _deepBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try adjusting your search query or filters',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = _products[index];
        return AdminProductCard(
          product: product,
          onTap: () => _openProductDetail(product),
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    final hasPrev = _productPage > 1;
    final hasNext = _productPage < _totalProductPages;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          InkWell(
            key: const Key('product_prev_page_button'),
            onTap: hasPrev ? _goToPreviousProductPage : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: hasPrev ? _royalBlue : const Color(0xFFB0BEC5),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Prev',
                    style: TextStyle(
                      color: hasPrev ? _royalBlue : const Color(0xFFB0BEC5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Page counter
          Flexible(
            child: Text(
              'Page $_productPage of $_totalProductPages ($_totalProducts total)',
              style: const TextStyle(
                color: _deepBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Next button
          InkWell(
            key: const Key('product_next_page_button'),
            onTap: hasNext ? _goToNextProductPage : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      color: hasNext ? _royalBlue : const Color(0xFFB0BEC5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: hasNext ? _royalBlue : const Color(0xFFB0BEC5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Categories Section UI
  // ---------------------------------------------------------------------------
  Widget _buildCategoriesSection() {
    return Column(
      children: [
        _buildCategoryActionBar(),
        const SizedBox(height: 10),
        _buildCategoryFilters(),
        const SizedBox(height: 10),
        Expanded(child: _buildCategoryListContent()),
      ],
    );
  }

  Widget _buildCategoryActionBar() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        key: const Key('add_category_button'),
        onPressed: _openCreateCategoryDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: _royalBlue,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        label: const Text(
          'Add Category',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FCFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _fieldBorderBlue, width: 1),
              ),
              child: TextField(
                key: const Key('category_search_input'),
                controller: _categorySearchController,
                style: const TextStyle(color: _deepBlue, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  hintStyle:
                      const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _royalBlue, size: 18),
                  suffixIcon: _categorySearchController.text.isNotEmpty
                      ? IconButton(
                          key: const Key('category_search_clear_button'),
                          icon: const Icon(Icons.clear_rounded,
                              color: Color(0xFF78909C), size: 16),
                          onPressed: () {
                            _categorySearchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Category Status Filter
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FCFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _fieldBorderBlue, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('category_status_filter_dropdown'),
                value: _selectedCategoryStatus,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _royalBlue, size: 18),
                style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (val) {
                  if (val != null && val != _selectedCategoryStatus) {
                    setState(() {
                      _selectedCategoryStatus = val;
                    });
                    _fetchCategories();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryListContent() {
    if (_isLoadingCategories) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _royalBlue),
            SizedBox(height: 14),
            Text(
              'Loading categories...',
              style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_categoryErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _categoryErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('category_retry_button'),
                onPressed: _fetchCategories,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F5FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_outlined,
                    size: 30, color: _royalBlue),
              ),
              const SizedBox(height: 14),
              const Text(
                'No categories found',
                style: TextStyle(
                    color: _deepBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try adjusting your search query or filters',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return AdminCategoryCard(
          category: category,
          isUpdatingStatus: _pendingCategoryStatusId == category.id,
          onToggleStatus: () => _handleToggleCategoryStatus(category),
        );
      },
    );
  }
}

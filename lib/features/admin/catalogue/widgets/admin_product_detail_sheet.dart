import 'package:flutter/material.dart';

import '../../../../core/models/admin_catalogue_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_catalogue_api.dart';
import 'admin_product_form_dialog.dart';

class AdminProductDetailSheet extends StatefulWidget {
  const AdminProductDetailSheet({
    super.key,
    required this.product,
    this.catalogueApi,
    this.categories,
    this.onProductUpdated,
  });

  final AdminProduct product;
  final AdminCatalogueApi? catalogueApi;
  final List<AdminCategory>? categories;
  final ValueChanged<AdminProduct>? onProductUpdated;

  @override
  State<AdminProductDetailSheet> createState() => _AdminProductDetailSheetState();
}

class _AdminProductDetailSheetState extends State<AdminProductDetailSheet> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  late AdminProduct _product;
  bool _isLoadingDetail = false;
  bool _isUpdatingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    if (widget.catalogueApi != null) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    if (widget.catalogueApi == null) return;

    setState(() {
      _isLoadingDetail = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.catalogueApi!.getAdminProductDetail(_product.id);
      if (!mounted) return;
      setState(() {
        _product = detail;
        _isLoadingDetail = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load full product details.';
        _isLoadingDetail = false;
      });
    }
  }

  void _openEditDialog() {
    if (widget.catalogueApi == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AdminProductFormDialog(
        product: _product,
        catalogueApi: widget.catalogueApi!,
        categories: widget.categories,
        onSuccess: (updatedProduct) {
          if (!mounted) return;
          setState(() {
            _product = updatedProduct;
          });
          widget.onProductUpdated?.call(updatedProduct);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: Color(0xFF00897B),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleToggleStatus() async {
    if (widget.catalogueApi == null || _isUpdatingStatus) return;

    final targetActive = !_product.isActive;
    final actionName = targetActive ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('product_status_confirm_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          targetActive ? 'Activate Product' : 'Deactivate Product',
          style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to $actionName "${_product.name}" (${_product.productCode})?',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('product_status_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF78909C), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            key: const Key('product_status_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
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
      final updated = await widget.catalogueApi!.updateProductStatus(
        _product.id,
        targetActive,
      );

      if (!mounted) return;

      setState(() {
        _product = updated;
        _isUpdatingStatus = false;
      });

      widget.onProductUpdated?.call(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetActive
                ? 'Product activated successfully'
                : 'Product deactivated successfully',
          ),
          backgroundColor:
              targetActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update product status. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

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
    final vehicleColor = _getVehicleColor(_product.vehicleType);
    final priceLabel = _product.price == null ? 'Price not set' : _product.displayPrice;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCFD8DC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Top bar with title and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Product Details',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  key: const Key('product_detail_close_button'),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE3F2FD)),
          // Body content
          Flexible(
            child: _isLoadingDetail
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _royalBlue),
                          SizedBox(height: 12),
                          Text(
                            'Fetching product details...',
                            style: TextStyle(
                              color: Color(0xFF557A95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 40, color: Colors.redAccent),
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _fetchDetail,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _royalBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image if present
                            if (_product.imageUrl != null &&
                                _product.imageUrl!.trim().isNotEmpty) ...[
                              Center(
                                child: Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FCFF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFCBEBFF),
                                      width: 1.2,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    _product.imageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 40,
                                        color: Color(0xFFB0BEC5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            // Title & badges row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _product.name,
                                    style: const TextStyle(
                                      color: _deepBlue,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Active / Inactive badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _product.isActive
                                        ? const Color(0xFFE8F8EE)
                                        : const Color(0xFFFBE9E7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _product.isActive
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFE57373),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _product.isActive
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 12,
                                        color: _product.isActive
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFC62828),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _product.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: _product.isActive
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFC62828),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Price display
                            Text(
                              priceLabel,
                              style: TextStyle(
                                color: _product.price == null
                                    ? const Color(0xFF78909C)
                                    : _deepBlue,
                                fontSize: 16,
                                fontWeight: _product.price == null
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                fontStyle: _product.price == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Details card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FCFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFCBEBFF),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildFieldRow(
                                    'Product ID',
                                    '#${_product.id}',
                                  ),
                                  const Divider(height: 16, color: Color(0xFFE3F2FD)),
                                  _buildFieldRow(
                                    'Product Code',
                                    _product.productCode,
                                    isCode: true,
                                  ),
                                  const Divider(height: 16, color: Color(0xFFE3F2FD)),
                                  _buildFieldRow(
                                    'Vehicle Type',
                                    _product.vehicleType,
                                    valueColor: vehicleColor,
                                  ),
                                  const Divider(height: 16, color: Color(0xFFE3F2FD)),
                                  _buildFieldRow(
                                    'Category',
                                    _product.categoryName ?? 'ID: ${_product.categoryId}',
                                  ),
                                  const Divider(height: 16, color: Color(0xFFE3F2FD)),
                                  _buildFieldRow(
                                    'Category Status',
                                    _product.categoryIsActive ? 'Active' : 'Inactive',
                                  ),
                                  if (_product.imageUrl != null &&
                                      _product.imageUrl!.trim().isNotEmpty) ...[
                                    const Divider(height: 16, color: Color(0xFFE3F2FD)),
                                    _buildFieldRow(
                                      'Image URL',
                                      _product.imageUrl!,
                                      isUrl: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Description section
                            const Text(
                              'Description',
                              style: TextStyle(
                                color: _deepBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FCFF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFCBEBFF),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _product.description != null &&
                                        _product.description!.trim().isNotEmpty
                                    ? _product.description!
                                    : 'No description provided',
                                style: TextStyle(
                                  color: _product.description != null &&
                                          _product.description!.trim().isNotEmpty
                                      ? const Color(0xFF37474F)
                                      : const Color(0xFF90A4AE),
                                  fontSize: 13,
                                  fontStyle: _product.description == null ||
                                          _product.description!.trim().isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1, color: Color(0xFFE3F2FD)),
                            const SizedBox(height: 16),

                            // Action Buttons: Edit Product & Activate/Deactivate
                            Row(
                              children: [
                                // Edit Product button
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton.icon(
                                      key: const Key('product_detail_edit_button'),
                                      onPressed:
                                          _isUpdatingStatus ? null : _openEditDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _royalBlue,
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: const Icon(Icons.edit_rounded, size: 18),
                                      label: const Text(
                                        'Edit Product',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Toggle status button
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: OutlinedButton.icon(
                                      key: const Key('product_detail_status_button'),
                                      onPressed:
                                          _isUpdatingStatus ? null : _handleToggleStatus,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _product.isActive
                                            ? const Color(0xFFD32F2F)
                                            : const Color(0xFF2E7D32),
                                        backgroundColor: _product.isActive
                                            ? const Color(0xFFFFEBEE)
                                            : const Color(0xFFE8F8EE),
                                        side: BorderSide(
                                          color: _product.isActive
                                              ? const Color(0xFFFFCDD2)
                                              : const Color(0xFFA5D6A7),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: _isUpdatingStatus
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              _product.isActive
                                                  ? Icons.block_rounded
                                                  : Icons.check_circle_outline_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        _product.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(
    String label,
    String value, {
    Color? valueColor,
    bool isCode = false,
    bool isUrl = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _deepBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: isCode ? 'monospace' : null,
            ),
            maxLines: isUrl ? 2 : null,
            overflow: isUrl ? TextOverflow.ellipsis : null,
          ),
        ),
      ],
    );
  }
}

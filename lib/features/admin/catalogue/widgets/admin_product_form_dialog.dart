import 'package:flutter/material.dart';

import '../../../../core/models/admin_catalogue_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_catalogue_api.dart';

/// Reusable dialog form for creating or editing an [AdminProduct].
class AdminProductFormDialog extends StatefulWidget {
  const AdminProductFormDialog({
    super.key,
    this.product,
    required this.catalogueApi,
    this.categories,
    required this.onSuccess,
  });

  /// The existing product to edit, or null when creating a new product.
  final AdminProduct? product;

  /// Typed API client for catalogue mutations.
  final AdminCatalogueApi catalogueApi;

  /// Optional preloaded categories list. If null or empty, will be fetched.
  final List<AdminCategory>? categories;

  /// Callback invoked after a successful create or update mutation.
  final ValueChanged<AdminProduct> onSuccess;

  bool get isEditing => product != null;

  @override
  State<AdminProductFormDialog> createState() => _AdminProductFormDialogState();
}

class _AdminProductFormDialogState extends State<AdminProductFormDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;

  int? _selectedCategoryId;
  String _selectedVehicleType = '2-Wheeler';

  List<AdminCategory> _availableCategories = [];
  bool _isLoadingCategories = false;
  bool _isSubmitting = false;
  String? _serverErrorMessage;

  static const List<String> _vehicleTypeOptions = [
    '2-Wheeler',
    '3-Wheeler',
    'Both',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _codeController = TextEditingController(text: p?.productCode ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    // Null price displays as empty field — never 0!
    _priceController = TextEditingController(
      text: p?.price != null ? p!.price.toString() : '',
    );
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');

    _selectedCategoryId = p?.categoryId;
    if (p != null && _vehicleTypeOptions.contains(p.vehicleType)) {
      _selectedVehicleType = p.vehicleType;
    }

    if (widget.categories != null && widget.categories!.isNotEmpty) {
      _availableCategories = List.from(widget.categories!);
      if (_selectedCategoryId == null && !widget.isEditing) {
        _selectedCategoryId = _availableCategories.first.id;
      }
    } else {
      _fetchCategories();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await widget.catalogueApi.getAdminCategories();
      if (!mounted) return;
      setState(() {
        _availableCategories = cats;
        _isLoadingCategories = false;
        if (_selectedCategoryId == null && cats.isNotEmpty && !widget.isEditing) {
          _selectedCategoryId = cats.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _serverErrorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId! <= 0) {
      setState(() {
        _serverErrorMessage = 'Please select a product category.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final codeVal = _codeController.text.trim();
    final nameVal = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final descVal = _descriptionController.text.trim();
    final imgVal = _imageUrlController.text.trim();

    num? parsedPrice;
    if (priceText.isNotEmpty) {
      parsedPrice = num.tryParse(priceText);
    }

    try {
      AdminProduct resultProduct;

      if (widget.isEditing) {
        final existing = widget.product!;
        final shouldClearPrice = existing.price != null && priceText.isEmpty;
        final shouldClearDesc =
            (existing.description != null && existing.description!.trim().isNotEmpty) &&
                descVal.isEmpty;
        final shouldClearImg =
            (existing.imageUrl != null && existing.imageUrl!.trim().isNotEmpty) &&
                imgVal.isEmpty;

        final updateRequest = AdminProductUpdateRequest(
          productCode: codeVal,
          name: nameVal,
          categoryId: _selectedCategoryId,
          vehicleType: _selectedVehicleType,
          price: parsedPrice,
          clearPrice: shouldClearPrice,
          description: descVal.isNotEmpty ? descVal : null,
          clearDescription: shouldClearDesc,
          imageUrl: imgVal.isNotEmpty ? imgVal : null,
          clearImageUrl: shouldClearImg,
        );

        resultProduct = await widget.catalogueApi.updateProduct(
          existing.id,
          updateRequest,
        );
      } else {
        final createRequest = AdminProductCreateRequest(
          productCode: codeVal,
          name: nameVal,
          categoryId: _selectedCategoryId!,
          vehicleType: _selectedVehicleType,
          price: parsedPrice,
          description: descVal.isNotEmpty ? descVal : null,
          imageUrl: imgVal.isNotEmpty ? imgVal : null,
          isActive: true,
        );

        resultProduct = await widget.catalogueApi.createProduct(createRequest);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess(resultProduct);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = 'An unexpected error occurred. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit Product' : 'Add New Product';
    final actionLabel = widget.isEditing ? 'Save Changes' : 'Create Product';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _royalBlue.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                        color: _royalBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.isEditing
                                ? 'Update product specifications and pricing'
                                : 'Enter product catalogue specifications',
                            style: const TextStyle(
                              color: Color(0xFF557A95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE3F2FD)),
                const SizedBox(height: 14),

                // Server error banner
                if (_serverErrorMessage != null) ...[
                  Container(
                    key: const Key('product_form_error_banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE9E7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE57373), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: Color(0xFFC62828)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverErrorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Product Code
                _buildFieldLabel('Product Code *'),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('product_form_code_input'),
                  controller: _codeController,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                  decoration: _inputDecoration(
                    hintText: 'e.g. BRK-101',
                    prefixIcon: Icons.qr_code_rounded,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Product code is required';
                    }
                    if (trimmed.length > 50) {
                      return 'Max 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Product Name
                _buildFieldLabel('Product Name *'),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('product_form_name_input'),
                  controller: _nameController,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'e.g. Front Disc Brake Pad Set',
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Product name is required';
                    }
                    if (trimmed.length > 200) {
                      return 'Max 200 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                _buildFieldLabel('Category *'),
                const SizedBox(height: 5),
                _isLoadingCategories
                    ? Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FCFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _fieldBorderBlue, width: 1),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _royalBlue,
                            ),
                          ),
                        ),
                      )
                    : DropdownButtonFormField<int>(
                        key: const Key('product_form_category_dropdown'),
                        initialValue: _availableCategories
                                .any((c) => c.id == _selectedCategoryId)
                            ? _selectedCategoryId
                            : null,
                        isExpanded: true,
                        decoration: _inputDecoration(
                          prefixIcon: Icons.category_outlined,
                        ),
                        hint: const Text(
                          'Select Category',
                          style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                        ),
                        style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _availableCategories
                            .map((cat) => DropdownMenuItem<int>(
                                  value: cat.id,
                                  child: Text(
                                    cat.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select category' : null,
                      ),
                const SizedBox(height: 12),

                // Vehicle Type Dropdown
                _buildFieldLabel('Vehicle Type *'),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  key: const Key('product_form_vehicle_type_dropdown'),
                  initialValue: _selectedVehicleType,
                  isExpanded: true,
                  decoration: _inputDecoration(prefixIcon: Icons.two_wheeler_rounded),
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: _vehicleTypeOptions
                      .map((vt) => DropdownMenuItem(
                            value: vt,
                            child: Text(vt, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedVehicleType = val;
                      });
                    }
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Select vehicle type' : null,
                ),
                const SizedBox(height: 12),

                // Price (Nullable!)
                _buildFieldLabel('Price (₹) (Optional)'),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('product_form_price_input'),
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Leave blank if not set',
                    prefixIcon: Icons.currency_rupee_rounded,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null; // Nullable price is valid!
                    }
                    final parsed = num.tryParse(trimmed);
                    if (parsed == null) {
                      return 'Enter a valid number';
                    }
                    if (parsed < 0) {
                      return 'Cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Description
                _buildFieldLabel('Description (Optional)'),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('product_form_description_input'),
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Enter product description, specifications, or fitment notes...',
                    prefixIcon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(height: 12),

                // Image URL
                _buildFieldLabel('Image URL (Optional)'),
                const SizedBox(height: 5),
                TextFormField(
                  key: const Key('product_form_image_url_input'),
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'https://example.com/images/part.png',
                    prefixIcon: Icons.image_outlined,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isNotEmpty && trimmed.length > 2048) {
                      return 'URL must be 2048 characters or less';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('product_form_cancel_button'),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('product_form_submit_button'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _royalBlue,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                actionLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _deepBlue,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _royalBlue, size: 18)
          : null,
      filled: true,
      fillColor: const Color(0xFFF7FCFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorderBlue, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _royalBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

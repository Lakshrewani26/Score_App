import 'package:flutter/material.dart';

import '../../../../core/models/admin_catalogue_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_catalogue_api.dart';

/// Reusable dialog form for creating an [AdminCategory].
class AdminCategoryFormDialog extends StatefulWidget {
  const AdminCategoryFormDialog({
    super.key,
    required this.catalogueApi,
    required this.onSuccess,
  });

  /// Typed API client for catalogue mutations.
  final AdminCatalogueApi catalogueApi;

  /// Callback invoked after a successful category creation.
  final ValueChanged<AdminCategory> onSuccess;

  @override
  State<AdminCategoryFormDialog> createState() => _AdminCategoryFormDialogState();
}

class _AdminCategoryFormDialogState extends State<AdminCategoryFormDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _isActive = true;
  bool _isSubmitting = false;
  String? _serverErrorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _serverErrorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final nameVal = _nameController.text.trim();
    final descVal = _descriptionController.text.trim();

    try {
      final request = AdminCategoryCreateRequest(
        name: nameVal,
        description: descVal.isNotEmpty ? descVal : null,
        isActive: _isActive,
      );

      final resultCategory = await widget.catalogueApi.createCategory(request);

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess(resultCategory);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = 'An unexpected network error occurred. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Category',
                            style: TextStyle(
                              color: _deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Create a product category for catalogue',
                            style: TextStyle(
                              color: Color(0xFF557A95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('category_form_close_button'),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Server Error Banner
                if (_serverErrorMessage != null) ...[
                  Container(
                    key: const Key('category_form_error_banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF9A9A), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 20),
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

                // Category Name Field
                _buildFieldLabel('Category Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('category_name_input'),
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  maxLength: 150,
                  style: const TextStyle(color: _deepBlue, fontSize: 13),
                  decoration: _inputDecoration(
                    hintText: 'e.g. Brake System, Electrical Components',
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  validator: (val) {
                    final cleaned = val?.trim() ?? '';
                    if (cleaned.isEmpty) {
                      return 'Category name is required';
                    }
                    if (cleaned.length > 150) {
                      return 'Category name cannot exceed 150 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Category Description Field (Optional)
                _buildFieldLabel('Description (Optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('category_description_input'),
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  style: const TextStyle(color: _deepBlue, fontSize: 13),
                  decoration: _inputDecoration(
                    hintText: 'Brief summary of components in this category...',
                  ),
                ),
                const SizedBox(height: 12),

                // Active Status Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FCFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _fieldBorderBlue, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isActive ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                        color: _isActive ? const Color(0xFF2E7D32) : const Color(0xFF78909C),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Status',
                              style: TextStyle(
                                color: _deepBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _isActive ? 'Category will be active immediately' : 'Category will be created as inactive',
                              style: const TextStyle(
                                color: Color(0xFF557A95),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        key: const Key('category_form_active_switch'),
                        value: _isActive,
                        activeThumbColor: const Color(0xFF0087D4),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                setState(() {
                                  _isActive = val;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('category_form_cancel_button'),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCFD8DC)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                        key: const Key('category_form_submit_button'),
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
                            : const Text(
                                'Create Category',
                                style: TextStyle(
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
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: _royalBlue, size: 18) : null,
      filled: true,
      fillColor: const Color(0xFFF7FCFF),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
      ),
    );
  }
}

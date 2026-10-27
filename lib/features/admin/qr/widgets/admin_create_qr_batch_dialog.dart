import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';
import '../../../../core/models/admin_qr_models.dart';
import '../../../../core/models/admin_settings_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_qr_api.dart';

class AdminCreateQrBatchDialog extends StatefulWidget {
  final String initialCategory;
  final AdminQrApi qrApi;
  final AdminApi? adminApi;

  const AdminCreateQrBatchDialog({
    super.key,
    required this.initialCategory,
    required this.qrApi,
    this.adminApi,
  });

  static Future<AdminQrBatch?> show(
    BuildContext context, {
    required String initialCategory,
    required AdminQrApi qrApi,
    AdminApi? adminApi,
  }) {
    return showDialog<AdminQrBatch>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminCreateQrBatchDialog(
        initialCategory: initialCategory,
        qrApi: qrApi,
        adminApi: adminApi,
      ),
    );
  }

  @override
  State<AdminCreateQrBatchDialog> createState() => _AdminCreateQrBatchDialogState();
}

class _AdminCreateQrBatchDialogState extends State<AdminCreateQrBatchDialog> {
  static const _deepBlue = Color(0xFF002766);
  static const _royalBlue = Color(0xFF0055B8);
  static const _borderBlue = Color(0xFFCBEBFF);

  final _formKey = GlobalKey<FormState>();
  late String _selectedType;
  final _quantityController = TextEditingController(text: '10');
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  List<AdminProduct> _availableProducts = [];
  List<AdminPointsRule> _availableRules = [];
  int? _selectedProductId;
  int? _selectedRuleId;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialCategory.toLowerCase();
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    try {
      if (widget.adminApi != null) {
        // Load products if product QR
        if (_selectedType == 'product') {
          final prodRes = await widget.adminApi!.catalogue.getAdminProducts(pageSize: 50);
          if (mounted) {
            setState(() {
              _availableProducts = prodRes.items;
              if (_availableProducts.isNotEmpty) {
                _selectedProductId = _availableProducts.first.id;
              }
            });
          }
        }

        // Load points rules
        final ruleCategory = _selectedType == 'product'
            ? 'product_qr_scan'
            : _selectedType == 'invoice'
                ? 'invoice_qr_scan'
                : null;

        if (ruleCategory != null) {
          final rulesRes = await widget.adminApi!.settings.getPointsRules(
            category: ruleCategory,
            isActive: true,
          );
          if (mounted) {
            setState(() {
              _availableRules = rulesRes.items;
              if (_availableRules.isNotEmpty) {
                _selectedRuleId = _availableRules.first.id;
              }
            });
          }
        }
      }
    } catch (_) {
      // Non-fatal if offline / mock test
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == 'product' && _selectedProductId == null && _availableProducts.isNotEmpty) {
      setState(() => _errorMessage = 'Please select a target product');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final qty = int.tryParse(_quantityController.text.trim()) ?? 10;
    final payload = AdminQrBatchPayload(
      qrType: _selectedType,
      quantity: qty,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      productId: _selectedType == 'product' ? _selectedProductId : null,
      pointsRuleId: _selectedRuleId,
    );

    try {
      final createdBatch = await widget.qrApi.createBatch(payload);
      if (!mounted) return;
      Navigator.of(context).pop(createdBatch);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to generate batch. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: _royalBlue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate ${_getCategoryTitle(_selectedType)} Batch',
                            style: const TextStyle(
                              color: _deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Allocate cryptographically unique tokens',
                            style: TextStyle(color: Color(0xFF557A95), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF90A4AE)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE8F0F8)),
                const SizedBox(height: 16),

                // Error Message Card
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // QR Type Selector Tabs
                const Text(
                  'QR Category *',
                  style: TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChip('product', 'Product QR'),
                      const SizedBox(width: 8),
                      _buildTypeChip('invoice', 'Invoice QR'),
                      const SizedBox(width: 8),
                      _buildTypeChip('partner', 'Partner QR'),
                      const SizedBox(width: 8),
                      _buildTypeChip('staff', 'Staff QR'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quantity
                const Text(
                  'Quantity to Generate *',
                  style: TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('qr_batch_quantity_field'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 50',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borderBlue),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Quantity is required';
                    final n = int.tryParse(val.trim());
                    if (n == null || n < 1 || n > 500) return 'Enter quantity between 1 and 500';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Product Selection (if product QR)
                if (_selectedType == 'product' && _availableProducts.isNotEmpty) ...[
                  const Text(
                    'Target Product *',
                    style: TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    key: const Key('qr_batch_product_dropdown'),
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _borderBlue),
                      ),
                    ),
                    items: _availableProducts.map((p) {
                      return DropdownMenuItem<int>(
                        value: p.id,
                        child: Text(
                          '${p.name} (${p.productCode})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedProductId = val),
                  ),
                  const SizedBox(height: 14),
                ],

                // Points Rule Binding
                if (_availableRules.isNotEmpty) ...[
                  const Text(
                    'Points Reward Rule (Optional)',
                    style: TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    key: const Key('qr_batch_points_rule_dropdown'),
                    isExpanded: true,
                    initialValue: _selectedRuleId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _borderBlue),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No rule binding (standard)'),
                      ),
                      ..._availableRules.map((r) {
                        return DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(
                            '${r.ruleName} (+${r.pointsAwarded ?? 0} pts)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedRuleId = val),
                  ),
                  const SizedBox(height: 14),
                ],

                // Description
                const Text(
                  'Batch Description / Notes',
                  style: TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('qr_batch_description_field'),
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Factory Batch Oct-2026 for Packaging',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borderBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
                    ),
                    ElevatedButton(
                      key: const Key('submit_create_qr_batch_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _royalBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Generate Batch',
                              style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _deepBlue,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFFF0F6FD),
      selectedColor: _royalBlue,
      showCheckmark: false,
      onSelected: _isSubmitting
          ? null
          : (val) {
              if (val) {
                setState(() => _selectedType = type);
                _loadPrerequisites();
              }
            },
    );
  }

  String _getCategoryTitle(String type) {
    switch (type.toLowerCase()) {
      case 'product':
        return 'Product QR';
      case 'invoice':
        return 'Invoice QR';
      case 'partner':
        return 'Partner QR';
      case 'staff':
        return 'Staff QR';
      default:
        return 'QR Code';
    }
  }
}

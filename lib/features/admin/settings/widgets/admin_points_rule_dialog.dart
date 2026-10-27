import 'package:flutter/material.dart';

import '../../../../core/models/admin_settings_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_settings_api.dart';

class AdminPointsRuleDialog extends StatefulWidget {
  const AdminPointsRuleDialog({
    super.key,
    this.rule,
    required this.settingsApi,
  });

  final AdminPointsRule? rule;
  final AdminSettingsApi settingsApi;

  @override
  State<AdminPointsRuleDialog> createState() => _AdminPointsRuleDialogState();
}

class _AdminPointsRuleDialogState extends State<AdminPointsRuleDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsAwardedController;
  late final TextEditingController _pointsRequiredController;
  late final TextEditingController _minValController;
  late final TextEditingController _maxValController;

  late String _selectedCategory;
  late bool _isActive;
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameController = TextEditingController(text: r?.ruleName ?? '');
    _descriptionController = TextEditingController(text: r?.ruleDescription ?? '');
    _pointsAwardedController = TextEditingController(
      text: r?.pointsAwarded != null ? r!.pointsAwarded.toString() : '',
    );
    _pointsRequiredController = TextEditingController(
      text: r?.pointsRequired != null ? r!.pointsRequired.toString() : '',
    );
    _minValController = TextEditingController(
      text: r?.minTransactionValue != null ? r!.minTransactionValue.toString() : '',
    );
    _maxValController = TextEditingController(
      text: r?.maxTransactionValue != null ? r!.maxTransactionValue.toString() : '',
    );

    _selectedCategory = r?.category ?? 'product_qr_scan';
    _isActive = r?.isActive ?? true;
    _effectiveFrom = r?.effectiveFrom;
    _effectiveTo = r?.effectiveTo;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsAwardedController.dispose();
    _pointsRequiredController.dispose();
    _minValController.dispose();
    _maxValController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate
        ? (_effectiveFrom ?? now)
        : (_effectiveTo ?? _effectiveFrom ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _royalBlue,
              onPrimary: Colors.white,
              onSurface: _deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _effectiveFrom = picked;
          if (_effectiveTo != null && _effectiveTo!.isBefore(picked)) {
            _effectiveTo = null;
          }
        } else {
          _effectiveTo = picked;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Cross-field validations
    final minValText = _minValController.text.trim();
    final maxValText = _maxValController.text.trim();
    final minVal = minValText.isNotEmpty ? double.tryParse(minValText) : null;
    final maxVal = maxValText.isNotEmpty ? double.tryParse(maxValText) : null;

    if (minVal != null && maxVal != null && minVal > maxVal) {
      setState(() {
        _errorMessage = 'Min transaction value cannot exceed max transaction value.';
      });
      return;
    }

    if (_effectiveFrom != null &&
        _effectiveTo != null &&
        _effectiveFrom!.isAfter(_effectiveTo!)) {
      setState(() {
        _errorMessage = 'Effective start date cannot be after end date.';
      });
      return;
    }

    final ptsAwardedText = _pointsAwardedController.text.trim();
    final ptsReqText = _pointsRequiredController.text.trim();
    final ptsAwarded = ptsAwardedText.isNotEmpty ? int.tryParse(ptsAwardedText) : null;
    final ptsReq = ptsReqText.isNotEmpty ? int.tryParse(ptsReqText) : null;

    final payload = AdminPointsRulePayload(
      ruleName: _nameController.text.trim(),
      ruleDescription: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      pointsAwarded: ptsAwarded,
      pointsRequired: ptsReq,
      minTransactionValue: minVal,
      maxTransactionValue: maxVal,
      effectiveFrom: _effectiveFrom,
      effectiveTo: _effectiveTo,
      isActive: _isActive,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditing) {
        await widget.settingsApi.updatePointsRule(widget.rule!.id, payload);
      } else {
        await widget.settingsApi.createPointsRule(payload);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to save rule. Please try again.';
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
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
                          _isEditing ? 'Edit Points Rule' : 'Create Points Rule',
                          style: const TextStyle(
                            color: _deepBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Update owner-controlled rule configuration'
                              : 'Define a new business policy for points',
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
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0EDF8)),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withAlpha(120)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Rule Name
                      _buildFieldLabel('Rule Name *'),
                      TextFormField(
                        key: const Key('rule_name_field'),
                        controller: _nameController,
                        enabled: !_isSubmitting,
                        decoration: _inputDecoration('e.g. 2-Wheeler Scan Reward'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Rule name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category Dropdown
                      _buildFieldLabel('Rule Category *'),
                      DropdownButtonFormField<String>(
                        key: const Key('rule_category_dropdown'),
                        isExpanded: true,
                        initialValue: _selectedCategory,
                        items: const [
                          DropdownMenuItem(
                            value: 'product_qr_scan',
                            child: Text('Product QR Scan (Customer Earning)'),
                          ),
                          DropdownMenuItem(
                            value: 'invoice_qr_scan',
                            child: Text('Invoice QR Scan (Partner Earning)'),
                          ),
                          DropdownMenuItem(
                            value: 'redemption',
                            child: Text('Points Redemption'),
                          ),
                          DropdownMenuItem(
                            value: 'customer_to_partner_transfer',
                            child: Text('Customer → Partner Transfer'),
                          ),
                          DropdownMenuItem(
                            value: 'partner_to_staff_transfer',
                            child: Text('Partner → Staff Transfer'),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                        decoration: _inputDecoration(''),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      _buildFieldLabel('Rule Description (Explanatory text)'),
                      TextFormField(
                        key: const Key('rule_description_field'),
                        controller: _descriptionController,
                        enabled: !_isSubmitting,
                        maxLines: 2,
                        decoration: _inputDecoration('Describe how and when this rule applies...'),
                      ),
                      const SizedBox(height: 14),

                      // Points Awarded & Points Required
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Points Awarded'),
                                TextFormField(
                                  key: const Key('points_awarded_field'),
                                  controller: _pointsAwardedController,
                                  enabled: !_isSubmitting,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('e.g. 50'),
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final parsed = int.tryParse(v.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'Must be >= 0';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Points Required'),
                                TextFormField(
                                  key: const Key('points_required_field'),
                                  controller: _pointsRequiredController,
                                  enabled: !_isSubmitting,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('e.g. 100'),
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final parsed = int.tryParse(v.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'Must be >= 0';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Min & Max Transaction Values
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Min Trans. Value (₹)'),
                                TextFormField(
                                  key: const Key('min_trans_value_field'),
                                  controller: _minValController,
                                  enabled: !_isSubmitting,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('e.g. 500.00'),
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final parsed = double.tryParse(v.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'Must be >= 0';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Max Trans. Value (₹)'),
                                TextFormField(
                                  key: const Key('max_trans_value_field'),
                                  controller: _maxValController,
                                  enabled: !_isSubmitting,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration('e.g. 50000.00'),
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final parsed = double.tryParse(v.trim());
                                      if (parsed == null || parsed < 0) {
                                        return 'Must be >= 0';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Effective Date Range
                      _buildFieldLabel('Effective Dates (Optional)'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('effective_from_button'),
                              onPressed: _isSubmitting ? null : () => _pickDate(isStartDate: true),
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(
                                _effectiveFrom == null
                                    ? 'Start Date'
                                    : '${_effectiveFrom!.day}/${_effectiveFrom!.month}/${_effectiveFrom!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _borderBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('effective_to_button'),
                              onPressed: _isSubmitting ? null : () => _pickDate(isStartDate: false),
                              icon: const Icon(Icons.event_rounded, size: 16),
                              label: Text(
                                _effectiveTo == null
                                    ? 'End Date'
                                    : '${_effectiveTo!.day}/${_effectiveTo!.month}/${_effectiveTo!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _borderBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          if (_effectiveFrom != null || _effectiveTo != null) ...[
                            IconButton(
                              tooltip: 'Clear Dates',
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _effectiveFrom = null;
                                        _effectiveTo = null;
                                      });
                                    },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Active Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _borderBlue),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rule Active Status',
                                    style: TextStyle(
                                      color: _deepBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Inactive rules cannot be used by transactions',
                                    style: TextStyle(
                                      color: Color(0xFF78909C),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              key: const Key('rule_active_switch'),
                              value: _isActive,
                              activeThumbColor: const Color(0xFF2E7D32),
                              activeTrackColor: const Color(0xFFC8E6C9),
                              onChanged: _isSubmitting
                                  ? null
                                  : (val) {
                                      setState(() => _isActive = val);
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: Color(0xFFE0EDF8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    key: const Key('save_rule_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _royalBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Create Rule',
                            style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: _deepBlue,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderBlue),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderBlue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _royalBlue, width: 1.5),
      ),
    );
  }
}

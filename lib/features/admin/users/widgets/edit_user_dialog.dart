import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';
import '../../../../core/services/admin_api.dart';

class EditUserDialog extends StatefulWidget {
  const EditUserDialog({
    super.key,
    required this.user,
    this.detail,
    required this.adminApi,
    this.token,
    required this.onSuccess,
  });

  final AdminUserSummary user;
  final AdminUserDetail? detail;
  final AdminApi adminApi;
  final String? token;
  final ValueChanged<AdminUserSummary> onSuccess;

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;

  // Customer fields
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _segmentController;

  // Partner fields
  late final TextEditingController _businessNameController;
  late final TextEditingController _businessAddressController;
  late final TextEditingController _partnerCodeController;
  int? _selectedZoneId;
  List<AdminZone> _availableZones = [];
  bool _isLoadingZones = false;

  // Staff fields
  late final TextEditingController _staffIdController;

  bool _isSubmitting = false;
  String? _serverErrorMessage;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    final d = widget.detail;

    _nameController = TextEditingController(text: u.name);
    _mobileController = TextEditingController(text: u.mobile);

    // Customer
    final cust = d?.customerProfile;
    _stateController = TextEditingController(text: cust?.state ?? '');
    _cityController = TextEditingController(text: cust?.city ?? '');
    _segmentController = TextEditingController(text: cust?.segment ?? '');

    // Partner
    final partner = d?.partnerProfile;
    _businessNameController = TextEditingController(
      text: partner?.businessName ?? d?.businessName ?? u.businessName ?? '',
    );
    _businessAddressController = TextEditingController(
      text: partner?.businessAddress ?? '',
    );
    _partnerCodeController = TextEditingController(
      text: partner?.partnerCode ?? d?.partnerCode ?? u.partnerCode ?? '',
    );
    _selectedZoneId = partner?.zoneId ?? d?.zoneId ?? u.zoneId;

    // Staff
    final staff = d?.staffProfile;
    _staffIdController = TextEditingController(
      text: staff?.staffId ?? d?.staffId ?? u.staffId ?? '',
    );

    if (u.role.toLowerCase() == 'partner') {
      _fetchZones();
    }
  }

  Future<void> _fetchZones() async {
    setState(() {
      _isLoadingZones = true;
    });
    try {
      final zones = await widget.adminApi.getZones(isActive: true, token: widget.token);
      if (!mounted) return;
      setState(() {
        _availableZones = zones;
        _isLoadingZones = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingZones = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _segmentController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _partnerCodeController.dispose();
    _staffIdController.dispose();
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

    final role = widget.user.role.toLowerCase();

    try {
      UpdateUserPayload payload;

      if (role == 'customer') {
        payload = UpdateUserPayload(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          state: _stateController.text.trim().isNotEmpty
              ? _stateController.text.trim()
              : null,
          city: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          segment: _segmentController.text.trim().isNotEmpty
              ? _segmentController.text.trim()
              : null,
        );
      } else if (role == 'partner') {
        final initialZoneId = widget.detail?.partnerProfile?.zoneId ??
            widget.detail?.zoneId ??
            widget.user.zoneId;
        final zoneChanged = _selectedZoneId != initialZoneId;

        payload = UpdateUserPayload(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          businessName: _businessNameController.text.trim(),
          businessAddress: _businessAddressController.text.trim().isNotEmpty
              ? _businessAddressController.text.trim()
              : null,
          partnerCode: _partnerCodeController.text.trim().isNotEmpty
              ? _partnerCodeController.text.trim()
              : null,
          zoneId: zoneChanged ? _selectedZoneId : null,
          clearZone: zoneChanged && _selectedZoneId == null ? true : null,
        );
      } else if (role == 'staff') {
        payload = UpdateUserPayload(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          staffId: _staffIdController.text.trim().isNotEmpty
              ? _staffIdController.text.trim()
              : null,
        );
      } else {
        payload = UpdateUserPayload(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
        );
      }

      final updatedUser = await widget.adminApi.updateUser(
        userId: widget.user.id,
        payload: payload,
        token: widget.token,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess(updatedUser.toSummary());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account details updated successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverErrorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role.toLowerCase();

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
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _royalBlue.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
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
                            'Edit ${widget.user.role.toUpperCase()} Account',
                            style: const TextStyle(
                              color: _deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Update details for ${widget.user.name}',
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF78909C)),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Server error banner
                if (_serverErrorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFD32F2F),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverErrorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Full Name
                _buildTextField(
                  key: const Key('edit_user_name_field'),
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'User full name',
                  icon: Icons.person_outline_rounded,
                  maxLength: 150,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Mobile Number
                _buildTextField(
                  key: const Key('edit_user_mobile_field'),
                  controller: _mobileController,
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  icon: Icons.smartphone_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length < 10) {
                      return 'Please enter a valid mobile number (min 10 digits)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Customer-specific fields
                if (role == 'customer') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          key: const Key('edit_customer_state_field'),
                          controller: _stateController,
                          label: 'State',
                          hint: 'e.g. Maharashtra',
                          icon: Icons.map_outlined,
                          maxLength: 100,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          key: const Key('edit_customer_city_field'),
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g. Pune',
                          icon: Icons.location_city_rounded,
                          maxLength: 100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    key: const Key('edit_customer_segment_field'),
                    controller: _segmentController,
                    label: 'Segment (Optional)',
                    hint: 'e.g. Retail, Workshop, Fleet',
                    icon: Icons.category_outlined,
                    maxLength: 50,
                  ),
                ],

                // Partner-specific fields
                if (role == 'partner') ...[
                  _buildTextField(
                    key: const Key('edit_partner_business_name_field'),
                    controller: _businessNameController,
                    label: 'Business / Shop Name',
                    hint: 'e.g. Metro Auto Spares',
                    icon: Icons.storefront_rounded,
                    maxLength: 200,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Business name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    key: const Key('edit_partner_business_address_field'),
                    controller: _businessAddressController,
                    label: 'Business Address',
                    hint: 'Full physical address',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildZoneDropdown(),
                  const SizedBox(height: 12),
                  _buildTextField(
                    key: const Key('edit_partner_code_field'),
                    controller: _partnerCodeController,
                    label: 'Partner Code (Optional)',
                    hint: 'e.g. PART001',
                    icon: Icons.tag_rounded,
                    maxLength: 50,
                  ),
                ],

                // Staff-specific fields
                if (role == 'staff') ...[
                  _buildTextField(
                    key: const Key('edit_staff_id_field'),
                    controller: _staffIdController,
                    label: 'Staff ID',
                    hint: 'e.g. EMP001',
                    icon: Icons.badge_outlined,
                    maxLength: 50,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Staff ID is required';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF557A95),
                          side: const BorderSide(color: Color(0xFFCFD8DC)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('submit_edit_user_button'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _royalBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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

  Widget _buildZoneDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Zone (Admin Only)',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (_isLoadingZones)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading zones...',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorderBlue, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded, color: _royalBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      key: const Key('edit_partner_zone_dropdown'),
                      value: _selectedZoneId,
                      isExpanded: true,
                      hint: const Text(
                        'Select Zone (Optional)',
                        style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None / Unassigned',
                              style: TextStyle(color: Color(0xFF78909C))),
                        ),
                        ..._availableZones.map((zone) => DropdownMenuItem<int?>(
                              value: zone.id,
                              child: Text(
                                zone.name,
                                style: const TextStyle(
                                    color: _deepBlue, fontWeight: FontWeight.w600),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedZoneId = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: _deepBlue, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            prefixIcon: Icon(icon, color: _royalBlue, size: 20),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF7FCFF),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _fieldBorderBlue, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _royalBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';
import '../../../../core/services/admin_api.dart';

class CreatePartnerDialog extends StatefulWidget {
  const CreatePartnerDialog({
    super.key,
    required this.adminApi,
    this.token,
    required this.onSuccess,
  });

  final AdminApi adminApi;
  final String? token;
  final VoidCallback onSuccess;

  @override
  State<CreatePartnerDialog> createState() => _CreatePartnerDialogState();
}

class _CreatePartnerDialogState extends State<CreatePartnerDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _partnerCodeController = TextEditingController();

  int? _selectedZoneId;
  List<AdminZone> _availableZones = [];
  bool _isLoadingZones = true;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _serverErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchZones();
  }

  Future<void> _fetchZones() async {
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
    _passwordController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _partnerCodeController.dispose();
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

    try {
      final payload = CreatePartnerPayload(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
        businessName: _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        partnerCode: _partnerCodeController.text.trim().isNotEmpty
            ? _partnerCodeController.text.trim()
            : null,
        zoneId: _selectedZoneId,
      );

      await widget.adminApi.createPartner(
        payload: payload,
        token: widget.token,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner account created successfully'),
          backgroundColor: Color(0xFF00897B),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: Color(0xFF00897B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Partner',
                            style: TextStyle(
                              color: _deepBlue,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Add a new business partner account',
                            style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Server error banner
                if (_serverErrorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  const SizedBox(height: 10),
                ],

                // Full Name
                _buildTextField(
                  key: const Key('partner_name_field'),
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Contact person name',
                  icon: Icons.person_outline_rounded,
                  maxLength: 150,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 5),

                // Mobile Number
                _buildTextField(
                  key: const Key('partner_mobile_field'),
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
                const SizedBox(height: 5),

                // Password
                _buildTextField(
                  key: const Key('partner_password_field'),
                  controller: _passwordController,
                  label: 'Temporary Password',
                  hint: 'Minimum 6 characters',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF78909C),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Password is required';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 5),

                // Business Name
                _buildTextField(
                  key: const Key('partner_business_name_field'),
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
                const SizedBox(height: 5),

                // Business Address
                _buildTextField(
                  key: const Key('partner_business_address_field'),
                  controller: _businessAddressController,
                  label: 'Business Address',
                  hint: 'Full physical address',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Business address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 5),

                // Zone Dropdown (Admin-side attribute)
                _buildZoneDropdown(),
                const SizedBox(height: 5),

                // Partner Code (Optional)
                _buildTextField(
                  key: const Key('partner_code_field'),
                  controller: _partnerCodeController,
                  label: 'Partner Code (Optional)',
                  hint: 'e.g. PART001',
                  icon: Icons.tag_rounded,
                  maxLength: 50,
                ),
                const SizedBox(height: 10),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF78909C), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('submit_create_partner_button'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                                'Create Partner',
                                style: TextStyle(fontWeight: FontWeight.w700),
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
        else if (_availableZones.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Text(
              'No active zones available (optional)',
              style: TextStyle(color: Color(0xFFF57F17), fontSize: 13),
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
                      key: const Key('partner_zone_dropdown'),
                      value: _selectedZoneId,
                      isExpanded: true,
                      hint: const Text(
                        'Select Zone (Optional)',
                        style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None / Unassigned', style: TextStyle(color: Color(0xFF78909C))),
                        ),
                        ..._availableZones.map((zone) => DropdownMenuItem<int?>(
                              value: zone.id,
                              child: Text(
                                zone.name,
                                style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w600),
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
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        TextFormField(
          key: key,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(color: _deepBlue, fontSize: 14),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            prefixIcon: Icon(icon, color: _royalBlue, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorderBlue, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _royalBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

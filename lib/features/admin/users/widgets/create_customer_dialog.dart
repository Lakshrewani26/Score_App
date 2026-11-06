import 'package:flutter/material.dart';

import '../../../../core/models/admin_models.dart';
import '../../../../core/services/admin_api.dart';

class CreateCustomerDialog extends StatefulWidget {
  const CreateCustomerDialog({
    super.key,
    required this.adminApi,
    this.token,
    required this.onSuccess,
  });

  final AdminApi adminApi;
  final String? token;
  final VoidCallback onSuccess;

  @override
  State<CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<CreateCustomerDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _segmentController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _serverErrorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _segmentController.dispose();
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
      final payload = CreateCustomerPayload(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
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

      await widget.adminApi.createCustomer(
        payload: payload,
        token: widget.token,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSuccess();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer account created successfully'),
          backgroundColor: Color(0xFF0055B8),
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
                        color: const Color(0xFF0055B8).withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Color(0xFF0055B8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Customer',
                            style: TextStyle(
                              color: _deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Add a new customer account',
                            style: TextStyle(
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
                  key: const Key('customer_name_field'),
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Customer name',
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
                  key: const Key('customer_mobile_field'),
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

                // Password
                _buildTextField(
                  key: const Key('customer_password_field'),
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
                const SizedBox(height: 12),

                // State & City
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        key: const Key('customer_state_field'),
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
                        key: const Key('customer_city_field'),
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

                // Segment
                _buildTextField(
                  key: const Key('customer_segment_field'),
                  controller: _segmentController,
                  label: 'Segment (Optional)',
                  hint: 'e.g. Retail, Workshop, Fleet',
                  icon: Icons.category_outlined,
                  maxLength: 50,
                ),
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
                        key: const Key('submit_create_customer_button'),
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0055B8),
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
                                'Create Customer',
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

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: const TextStyle(color: _deepBlue, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            prefixIcon: Icon(icon, color: _royalBlue, size: 20),
            suffixIcon: suffixIcon,
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

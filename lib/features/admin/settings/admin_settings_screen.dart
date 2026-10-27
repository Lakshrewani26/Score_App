import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_settings_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_session_manager.dart';
import '../../../core/services/admin_settings_api.dart';
import 'widgets/admin_points_rule_dialog.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({
    super.key,
    this.adminApi,
    this.settingsApi,
    this.sessionManager,
  });

  final AdminApi? adminApi;
  final AdminSettingsApi? settingsApi;
  final AdminSessionManager? sessionManager;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);
  late final AdminSessionManager _session;
  late final AdminSettingsApi _settingsApi;

  final TextEditingController _searchController = TextEditingController();

  // State
  AdminSystemInfo? _systemInfo;
  bool _isLoadingSystemInfo = true;
  String? _systemInfoError;

  List<AdminPointsRule> _rules = [];
  bool _isLoadingRules = true;
  String? _rulesError;

  // Filters
  String _selectedCategory = 'all';
  String _selectedStatus = 'all'; // 'all', 'active', 'inactive'
  String _searchQuery = '';

  int _rulesRequestCounter = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _settingsApi = widget.settingsApi ??
        widget.adminApi?.settings ??
        AdminSettingsApi(sessionManager: _session);

    _loadSystemInfo();
    _loadRules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemInfo() async {
    setState(() {
      _isLoadingSystemInfo = true;
      _systemInfoError = null;
    });

    try {
      final info = await _settingsApi.getSystemInfo();
      if (!mounted) return;
      setState(() {
        _systemInfo = info;
        _isLoadingSystemInfo = false;
        _systemInfoError = null;
      });
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSystemInfo = false;
        _systemInfoError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSystemInfo = false;
        _systemInfoError = 'Unable to load system info';
      });
    }
  }

  Future<void> _loadRules() async {
    final reqId = ++_rulesRequestCounter;
    setState(() {
      _isLoadingRules = true;
      _rulesError = null;
    });

    try {
      bool? isActiveFilter;
      if (_selectedStatus == 'active') {
        isActiveFilter = true;
      } else if (_selectedStatus == 'inactive') {
        isActiveFilter = false;
      }

      final response = await _settingsApi.getPointsRules(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        isActive: isActiveFilter,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
      );

      if (!mounted || reqId != _rulesRequestCounter) return;

      setState(() {
        _rules = response.items;
        _isLoadingRules = false;
        _rulesError = null;
      });
    } on AdminApiException catch (e) {
      if (!mounted || reqId != _rulesRequestCounter) return;
      setState(() {
        _isLoadingRules = false;
        _rulesError = e.message;
      });
    } catch (_) {
      if (!mounted || reqId != _rulesRequestCounter) return;
      setState(() {
        _isLoadingRules = false;
        _rulesError = 'Unable to load points rules. Tap retry.';
      });
    }
  }

  Future<void> _handleCreateRule() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AdminPointsRuleDialog(
        settingsApi: _settingsApi,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Points rule created successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _loadRules();
    }
  }

  Future<void> _handleEditRule(AdminPointsRule rule) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => AdminPointsRuleDialog(
        rule: rule,
        settingsApi: _settingsApi,
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Points rule updated successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _loadRules();
    }
  }

  Future<void> _handleToggleStatus(AdminPointsRule rule) async {
    final willDeactivate = rule.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          willDeactivate ? 'Deactivate Rule?' : 'Activate Rule?',
          style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w800),
        ),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate "${rule.ruleName}"? Deactivated rules will not be eligible to authorize new transactions.'
              : 'Are you sure you want to activate "${rule.ruleName}"? It will become active for eligible transactions.',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            key: const Key('confirm_status_toggle_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate
                  ? const Color(0xFFE51B24)
                  : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(willDeactivate ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _settingsApi.updatePointsRuleStatus(rule.id, !rule.isActive);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willDeactivate ? 'Rule deactivated' : 'Rule activated',
          ),
          backgroundColor: willDeactivate
              ? const Color(0xFF455A64)
              : const Color(0xFF2E7D32),
        ),
      );
      _loadRules();
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red),
      );
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
            final height = constraints.maxHeight;
            final contentWidth = math.min(width * 0.94, 660.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                RefreshIndicator(
                  color: _royalBlue,
                  onRefresh: () async {
                    await Future.wait([_loadSystemInfo(), _loadRules()]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                    height: MediaQuery.of(context).padding.top +
                                        16),
                                _buildHeader(context),
                                const SizedBox(height: 16),
                                _buildSystemInfoSection(),
                                const SizedBox(height: 20),
                                _buildPointsRulesHeader(),
                                const SizedBox(height: 12),
                                _buildFiltersCard(),
                                const SizedBox(height: 14),
                                _buildRulesSection(),
                                const SizedBox(height: 40),
                              ],
                            ),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('admin_settings_back_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderBlue, width: 1.3),
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Settings',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Security policies, app info & points rules',
                style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInfoSection() {
    if (_isLoadingSystemInfo) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _royalBlue),
          ),
        ),
      );
    }

    if (_systemInfoError != null || _systemInfo == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _systemInfoError ?? 'System info unavailable',
                style: const TextStyle(color: Color(0xFF37474F), fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _loadSystemInfo,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final info = _systemInfo!;
    final isDbConnected = info.databaseStatus.toLowerCase() == 'connected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: _royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Information',
                      style: TextStyle(
                        color: _deepBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Runtime deployment metadata & database health',
                      style: TextStyle(
                        color: Color(0xFF557A95),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: _royalBlue),
                tooltip: 'Refresh Info',
                onPressed: _loadSystemInfo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE8F0F8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Application', info.appName)),
              Expanded(
                child: _buildInfoItemWithBadge(
                  'Environment',
                  info.environment.toUpperCase(),
                  info.environment.toLowerCase() == 'production'
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF0055B8),
                  info.environment.toLowerCase() == 'production'
                      ? const Color(0xFFE8F8EE)
                      : const Color(0xFFE8F2FD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildInfoItem('API Version', info.apiVersion)),
              Expanded(
                child: _buildInfoItemWithBadge(
                  'Database',
                  isDbConnected ? 'Connected' : 'Degraded',
                  isDbConnected ? const Color(0xFF2E7D32) : Colors.red,
                  isDbConnected
                      ? const Color(0xFFE8F8EE)
                      : const Color(0xFFFFEBEE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0EDF8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: Color(0xFF78909C)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sensitive credentials and secrets are managed via server deployment.',
                    style: TextStyle(
                      color: Color(0xFF557A95),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItemWithBadge(
      String label, String badgeText, Color textColor, Color bgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: textColor.withAlpha(80), width: 0.8),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointsRulesHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points System Rules',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Owner-controlled earning, redemption & transfer policies',
                style: TextStyle(
                  color: Color(0xFF557A95),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          key: const Key('create_points_rule_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _royalBlue,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _handleCreateRule,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create Rule',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            key: const Key('rules_search_field'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search rules by name or description...',
              hintStyle:
                  const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: _royalBlue, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadRules();
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled: true,
              fillColor: const Color(0xFFF7FAFD),
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
            ),
            onSubmitted: (val) {
              setState(() => _searchQuery = val);
              _loadRules();
            },
          ),
          const SizedBox(height: 12),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryFilterChip('all', 'All Categories'),
                _buildCategoryFilterChip('product_qr_scan', 'Product QR'),
                _buildCategoryFilterChip('invoice_qr_scan', 'Invoice QR'),
                _buildCategoryFilterChip('redemption', 'Redemption'),
                _buildCategoryFilterChip(
                    'customer_to_partner_transfer', 'Cust → Partner'),
                _buildCategoryFilterChip(
                    'partner_to_staff_transfer', 'Part → Staff'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusFilterChip('all', 'All Status'),
                const SizedBox(width: 8),
                _buildStatusFilterChip('active', 'Active Only'),
                const SizedBox(width: 8),
                _buildStatusFilterChip('inactive', 'Inactive Only'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : _deepBlue,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
        backgroundColor: const Color(0xFFF0F6FD),
        selectedColor: _royalBlue,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? _royalBlue : _borderBlue,
          ),
        ),
        onSelected: (_) {
          if (_selectedCategory == value) return;
          setState(() => _selectedCategory = value);
          _loadRules();
        },
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF557A95),
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      selectedColor: _deepBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? _deepBlue : _borderBlue),
      ),
      onSelected: (_) {
        if (_selectedStatus == value) return;
        setState(() => _selectedStatus = value);
        _loadRules();
      },
    );
  }

  Widget _buildRulesSection() {
    if (_isLoadingRules) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _royalBlue),
            ),
            SizedBox(height: 12),
            Text(
              'Loading points system rules...',
              style: TextStyle(color: Color(0xFF557A95), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_rulesError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 36),
            const SizedBox(height: 10),
            Text(
              _rulesError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _deepBlue, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadRules,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_rules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: Column(
          children: [
            const Icon(Icons.rule_folder_outlined,
                size: 44, color: Color(0xFF90A4AE)),
            const SizedBox(height: 10),
            const Text(
              'No points rules found',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search or filters, or create a new rule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF78909C), fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _handleCreateRule,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Rule'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _rules.map((rule) => _buildRuleCard(rule)).toList(),
    );
  }

  Widget _buildRuleCard(AdminPointsRule rule) {
    final catColor = _getCategoryColor(rule.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rule.isActive ? _borderBlue : const Color(0xFFE0E0E0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Category badge & Active status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: catColor.withAlpha(90), width: 0.8),
                ),
                child: Text(
                  rule.categoryLabel,
                  style: TextStyle(
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rule.isActive
                      ? const Color(0xFFE8F8EE)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rule.isActive
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 13,
                      color: rule.isActive
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF757575),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rule.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: rule.isActive
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF757575),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rule Name
          Text(
            rule.ruleName,
            style: const TextStyle(
              color: _deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (rule.ruleDescription != null &&
              rule.ruleDescription!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rule.ruleDescription!,
              style: const TextStyle(
                color: Color(0xFF557A95),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Key metrics row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5EFF8)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (rule.pointsAwarded != null)
                  _buildMetricPill(
                    'Awarded',
                    '+${rule.pointsAwarded} pts',
                    const Color(0xFF2E7D32),
                  ),
                if (rule.pointsRequired != null)
                  _buildMetricPill(
                    'Required',
                    '${rule.pointsRequired} pts',
                    _royalBlue,
                  ),
                if (rule.minTransactionValue != null ||
                    rule.maxTransactionValue != null)
                  _buildMetricPill(
                    'Eligible Value',
                    _formatRange(
                        rule.minTransactionValue, rule.maxTransactionValue),
                    const Color(0xFF455A64),
                  ),
                if (rule.effectiveFrom != null || rule.effectiveTo != null)
                  _buildMetricPill(
                    'Period',
                    _formatDateRange(rule.effectiveFrom, rule.effectiveTo),
                    const Color(0xFF5E35B1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Audit & Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                rule.createdByName != null
                    ? 'Author: ${rule.createdByName}'
                    : 'Audit ID: #${rule.id}',
                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    key: Key('edit_rule_${rule.id}'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _borderBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleEditRule(rule),
                    icon: const Icon(Icons.edit_rounded,
                        size: 14, color: _royalBlue),
                    label: const Text('Edit',
                        style: TextStyle(color: _royalBlue, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: Key('toggle_status_rule_${rule.id}'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: rule.isActive
                            ? const Color(0xFFFFCDD2)
                            : const Color(0xFFC8E6C9),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleToggleStatus(rule),
                    icon: Icon(
                      rule.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 14,
                      color: rule.isActive
                          ? const Color(0xFFE51B24)
                          : const Color(0xFF2E7D32),
                    ),
                    label: Text(
                      rule.isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(
                        color: rule.isActive
                            ? const Color(0xFFE51B24)
                            : const Color(0xFF2E7D32),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF90A4AE),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'product_qr_scan':
        return const Color(0xFF0055B8);
      case 'invoice_qr_scan':
        return const Color(0xFF00897B);
      case 'redemption':
        return const Color(0xFF5E35B1);
      case 'customer_to_partner_transfer':
        return const Color(0xFFE65100);
      case 'partner_to_staff_transfer':
        return const Color(0xFF283593);
      default:
        return const Color(0xFF0055B8);
    }
  }

  String _formatRange(double? min, double? max) {
    if (min != null && max != null) {
      return '₹${min.toStringAsFixed(0)} - ₹${max.toStringAsFixed(0)}';
    } else if (min != null) {
      return '>= ₹${min.toStringAsFixed(0)}';
    } else if (max != null) {
      return '<= ₹${max.toStringAsFixed(0)}';
    }
    return 'None';
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
    } else if (start != null) {
      return 'From ${start.day}/${start.month}/${start.year}';
    } else if (end != null) {
      return 'Until ${end.day}/${end.month}/${end.year}';
    }
    return 'Always';
  }
}

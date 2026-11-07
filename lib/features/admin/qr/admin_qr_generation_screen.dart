import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_qr_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_qr_excel_exporter.dart';
import '../../../core/services/admin_qr_api.dart';
import 'widgets/admin_create_qr_batch_dialog.dart';
import 'widgets/admin_print_product_qr_dialog.dart';
import 'widgets/admin_view_qr_codes_dialog.dart';

class AdminQrGenerationScreen extends StatefulWidget {
  final AdminApi? adminApi;
  final AdminQrApi? qrApi;

  const AdminQrGenerationScreen({
    super.key,
    this.adminApi,
    this.qrApi,
  });

  @override
  State<AdminQrGenerationScreen> createState() =>
      _AdminQrGenerationScreenState();
}

class _AdminQrGenerationScreenState extends State<AdminQrGenerationScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);

  late final AdminApi _adminApi;
  late final AdminQrApi _qrApi;
  final _excelExporter = AdminQrExcelExporter();

  bool _isLoading = true;
  String? _errorMessage;
  List<AdminQrBatch> _batches = [];
  String _selectedTypeFilter = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _exportingBatchIds = {};

  @override
  void initState() {
    super.initState();
    _adminApi = widget.adminApi ?? AdminApi();
    _qrApi = widget.qrApi ?? _adminApi.qr;
    _loadBatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _qrApi.getBatches(
        qrType: _selectedTypeFilter == 'all' ? null : _selectedTypeFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _batches = res.items;
          _isLoading = false;
        });
      }
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Failed to load QR batches');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGenerateBatch(String category) async {
    final newBatch = await AdminCreateQrBatchDialog.show(
      context,
      initialCategory: category,
      qrApi: _qrApi,
      adminApi: _adminApi,
    );

    if (newBatch != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Generated ${newBatch.quantity} QR codes in ${newBatch.batchNumber}'),
          backgroundColor: const Color(0xFF2E7D32),
          action: SnackBarAction(
            label: 'Export Excel',
            textColor: Colors.white,
            onPressed: () => _handleExportExcel(newBatch),
          ),
        ),
      );
      _loadBatches();
    }
  }

  Future<void> _handleExportExcel(AdminQrBatch batch) async {
    setState(() => _exportingBatchIds.add(batch.id));
    try {
      final savedPath =
          await _excelExporter.exportBatch(qrApi: _qrApi, batch: batch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null
              ? 'Excel export canceled'
              : 'Excel file saved: ${batch.batchNumber}_qr_codes.xlsx'),
          backgroundColor: savedPath == null
              ? const Color(0xFF616161)
              : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save Excel file: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportingBatchIds.remove(batch.id));
    }
  }

  void _handleViewCodes(AdminQrBatch batch) {
    AdminViewQrCodesDialog.show(context, batch: batch, qrApi: _qrApi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('print_product_qr_labels_button'),
        onPressed: () {
          AdminPrintProductQrDialog.show(
            context,
            qrApi: _qrApi,
            adminApi: _adminApi,
          );
        },
        backgroundColor: _royalBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.print_outlined),
        label: const Text(
          'Print QR Labels',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
                  onRefresh: _loadBatches,
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
                                _buildPhaseNotice(),
                                const SizedBox(height: 20),
                                _buildSectionTitle(),
                                const SizedBox(height: 12),
                                _buildQrCategories(context),
                                const SizedBox(height: 24),
                                _buildRecentBatchesHeader(),
                                const SizedBox(height: 12),
                                _buildFiltersCard(),
                                const SizedBox(height: 14),
                                _buildBatchesSection(),
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
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBEBFF), width: 1.3),
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
                'QR Code Generation',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage QR codes for Score',
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

  Widget _buildPhaseNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _royalBlue, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foundation Phase Notice',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'QR generation, unique-token allocation, batch export, and printing will be implemented in a subsequent phase.',
                  style: TextStyle(
                    color: Color(0xFF37474F),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Categories',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Tap any category to configure parameters and generate batch',
          style: TextStyle(
            color: Color(0xFF557A95),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCategories(BuildContext context) {
    final categories = [
      (
        'Product QR',
        'product',
        'Product packaging and individual unit serial QR codes',
        Icons.inventory_2_rounded,
        const Color(0xFF0055B8),
      ),
      (
        'Invoice QR',
        'invoice',
        'Invoice verification and billing transaction QR codes',
        Icons.receipt_long_rounded,
        const Color(0xFF0087D4),
      ),
      (
        'Staff QR',
        'staff',
        'Staff identification, attendance, and assignment QR codes',
        Icons.badge_rounded,
        const Color(0xFF009688),
      ),
      (
        'Partner QR',
        'partner',
        'Dealer, distributor, and workshop partner affiliation QR codes',
        Icons.handshake_rounded,
        const Color(0xFF5E35B1),
      ),
    ];

    return Column(
      children: categories.map((cat) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategoryCard(
            context: context,
            title: cat.$1,
            type: cat.$2,
            description: cat.$3,
            icon: cat.$4,
            color: cat.$5,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required String type,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('category_card_$type'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleGenerateBatch(type),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2FD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Generate',
                              style: TextStyle(
                                color: Color(0xFF0055B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF607D8B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF90A4AE),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentBatchesHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated Batches & Excel Exports',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Export batch spreadsheets or view individual QR tokens',
          style: TextStyle(
            color: Color(0xFF557A95),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('batches_search_field'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search batch number or notes...',
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
                        _loadBatches();
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
            ),
            onSubmitted: (val) {
              setState(() => _searchQuery = val);
              _loadBatches();
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All Types'),
                const SizedBox(width: 8),
                _buildFilterChip('product', 'Product'),
                const SizedBox(width: 8),
                _buildFilterChip('invoice', 'Invoice'),
                const SizedBox(width: 8),
                _buildFilterChip('partner', 'Partner'),
                const SizedBox(width: 8),
                _buildFilterChip('staff', 'Staff'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _selectedTypeFilter == type;
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
      onSelected: (val) {
        if (val) {
          setState(() => _selectedTypeFilter = type);
          _loadBatches();
        }
      },
    );
  }

  Widget _buildBatchesSection() {
    if (_isLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: _royalBlue),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadBatches, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_batches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderBlue),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 40, color: Color(0xFF90A4AE)),
              SizedBox(height: 8),
              Text(
                'No QR Batches Generated Yet',
                style: TextStyle(
                    color: _deepBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Tap one of the category cards above to generate your first batch.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _batches.map((batch) => _buildBatchCard(batch)).toList(),
    );
  }

  Widget _buildBatchCard(AdminQrBatch batch) {
    final isExporting = _exportingBatchIds.contains(batch.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0755B5),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  batch.typeLabel,
                  style: const TextStyle(
                    color: _royalBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  batch.batchNumber,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${batch.activeCount}/${batch.quantity} ACTIVE',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (batch.description != null && batch.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              batch.description!,
              style: const TextStyle(color: Color(0xFF557A95), fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F4F8)),
          const SizedBox(height: 10),

          // Action Buttons: Export to Excel & View Codes
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${batch.createdAt.day}/${batch.createdAt.month}/${batch.createdAt.year}',
                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Excel Export Button
                  ElevatedButton.icon(
                    key: Key('export_excel_batch_${batch.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed:
                        isExporting ? null : () => _handleExportExcel(batch),
                    icon: isExporting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.table_view_rounded, size: 14),
                    label: const Text(
                      'Export Excel',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // View Codes Button
                  OutlinedButton.icon(
                    key: Key('view_codes_batch_${batch.id}'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _borderBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleViewCodes(batch),
                    icon: const Icon(Icons.qr_code_rounded,
                        size: 14, color: _royalBlue),
                    label: const Text(
                      'View Codes',
                      style: TextStyle(
                          color: _royalBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5),
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
}

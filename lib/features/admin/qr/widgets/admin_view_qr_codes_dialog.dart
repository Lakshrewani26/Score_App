import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/models/admin_qr_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_qr_excel_exporter.dart';
import '../../../../core/services/admin_qr_api.dart';

class AdminViewQrCodesDialog extends StatefulWidget {
  final AdminQrBatch batch;
  final AdminQrApi qrApi;

  const AdminViewQrCodesDialog({
    super.key,
    required this.batch,
    required this.qrApi,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminQrBatch batch,
    required AdminQrApi qrApi,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AdminViewQrCodesDialog(batch: batch, qrApi: qrApi),
    );
  }

  @override
  State<AdminViewQrCodesDialog> createState() => _AdminViewQrCodesDialogState();
}

class _AdminViewQrCodesDialogState extends State<AdminViewQrCodesDialog> {
  static const _deepBlue = Color(0xFF002766);
  static const _royalBlue = Color(0xFF0055B8);
  static const _borderBlue = Color(0xFFCBEBFF);

  bool _isLoading = true;
  bool _isExporting = false;
  final _excelExporter = AdminQrExcelExporter();
  String? _errorMessage;
  List<AdminQrCode> _codes = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.qrApi.getBatchCodes(
        widget.batch.id,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _codes = res.items;
          _isLoading = false;
        });
      }
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Failed to load QR codes');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isExporting = true);
    try {
      final savedPath = await _excelExporter.exportBatch(
          qrApi: widget.qrApi, batch: widget.batch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null
              ? 'Excel export canceled'
              : 'Excel file saved: ${widget.batch.batchNumber}_qr_codes.xlsx'),
          backgroundColor: savedPath == null
              ? const Color(0xFF616161)
              : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
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
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleToggleCodeStatus(AdminQrCode code) async {
    final nextStatus = code.isActive ? 'voided' : 'active';
    try {
      await widget.qrApi.updateCodeStatus(code.id, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR code marked as ${nextStatus.toUpperCase()}'),
          backgroundColor: nextStatus == 'active'
              ? const Color(0xFF2E7D32)
              : const Color(0xFF455A64),
        ),
      );
      _loadCodes();
    } on AdminApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.batch.batchNumber,
                          style: const TextStyle(
                            color: _deepBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.batch.typeLabel} • ${widget.batch.quantity} codes generated',
                          style: const TextStyle(
                              color: Color(0xFF557A95), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF90A4AE)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Export Buttons Bar
              Row(
                children: [
                  // Excel Export Button (Highlighted)
                  ElevatedButton.icon(
                    key: const Key('export_excel_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isExporting ? null : _handleExportExcel,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.table_view_rounded, size: 16),
                    label: const Text(
                      'Export to Excel (.xlsx)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Box
              TextField(
                key: const Key('qr_code_token_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by QR token...',
                  hintStyle:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _royalBlue, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadCodes();
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  filled: true,
                  fillColor: const Color(0xFFF7FAFD),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _borderBlue),
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val);
                  _loadCodes();
                },
              ),
              const SizedBox(height: 12),

              // Code List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _royalBlue),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _codes.isEmpty
                            ? const Center(
                                child: Text('No QR codes found'),
                              )
                            : ListView.separated(
                                itemCount: _codes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final code = _codes[index];
                                  return _buildCodeCard(code);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard(AdminQrCode code) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderBlue),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8F0F8)),
            ),
            child: Center(
              child: QrImageView(
                data: code.codeData,
                version: QrVersions.auto,
                size: 58.0,
                padding: const EdgeInsets.all(2),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Code Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  code.token,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (code.pointsAwarded != null) ...[
                      Text(
                        '+${code.pointsAwarded} pts',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(' • ',
                          style: TextStyle(color: Color(0xFFB0BEC5))),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: code.isActive
                            ? const Color(0xFFE8F8EE)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code.status.toUpperCase(),
                        style: TextStyle(
                          color: code.isActive
                              ? const Color(0xFF2E7D32)
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Void/Activate Action
          IconButton(
            key: Key('toggle_code_${code.id}'),
            icon: Icon(
              code.isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
              color: code.isActive ? Colors.red : const Color(0xFF2E7D32),
            ),
            tooltip: code.isActive ? 'Void code' : 'Reactivate code',
            onPressed: () => _handleToggleCodeStatus(code),
          ),
        ],
      ),
    );
  }
}

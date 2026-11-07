import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/admin_catalogue_models.dart';
import '../../../../core/models/admin_qr_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_qr_api.dart';

/// Dialog allowing Admin to select products and print/download physical identification
/// labels containing product name, product code, and unique QR identification numbers.
/// Explicitly does NOT generate or display any QR code images or scannable graphics.
class AdminPrintProductQrDialog extends StatefulWidget {
  const AdminPrintProductQrDialog({
    super.key,
    required this.qrApi,
    required this.adminApi,
  });

  final AdminQrApi qrApi;
  final AdminApi adminApi;

  static Future<void> show(
    BuildContext context, {
    required AdminQrApi qrApi,
    required AdminApi adminApi,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminPrintProductQrDialog(
        qrApi: qrApi,
        adminApi: adminApi,
      ),
    );
  }

  @override
  State<AdminPrintProductQrDialog> createState() => _AdminPrintProductQrDialogState();
}

class _AdminPrintProductQrDialogState extends State<AdminPrintProductQrDialog> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);

  bool _isLoadingProducts = true;
  String? _productLoadError;
  List<AdminProduct> _products = [];
  final Set<int> _selectedProductIds = {};

  bool _isGenerating = false;
  String? _actionError;
  List<ProductQrLabelItem>? _labels;

  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productLoadError = null;
    });

    try {
      final res = await widget.adminApi.catalogue.getAdminProducts(pageSize: 100);
      if (mounted) {
        setState(() {
          _products = res.items.where((p) => p.isActive).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productLoadError = 'Failed to load catalogue products';
        });
      }
    }
  }

  List<AdminProduct> get _filteredProducts {
    if (_searchFilter.isEmpty) return _products;
    final q = _searchFilter.toLowerCase();
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.productCode.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _handleFetchLabels() async {
    if (_selectedProductIds.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _actionError = null;
    });

    try {
      final res = await widget.qrApi.getProductQrLabels(_selectedProductIds.toList());
      if (mounted) {
        setState(() {
          _labels = res.items;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _actionError = 'Failed to fetch product QR labels: $e';
        });
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_selectedProductIds.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _actionError = null;
    });

    try {
      final pdfBytes =
          await widget.qrApi.downloadProductQrLabelsPdf(_selectedProductIds.toList());
      if (!mounted) return;
      setState(() => _isGenerating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully generated PDF with ${_selectedProductIds.length} product QR labels (${pdfBytes.lengthInBytes} bytes)'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _actionError = 'Failed to generate PDF: $e';
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
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderBlue),
                    ),
                    child: const Icon(Icons.print_outlined, color: _royalBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product QR Number Printing',
                          style: TextStyle(
                            color: _deepBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Select products to generate physical QR number labels (Text format)',
                          style: TextStyle(
                            color: Color(0xFF557A95),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notice Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.label_important_outline_rounded,
                        size: 18, color: _royalBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Generates text-based identification labels with existing unique QR numbers. No scannable QR images are generated.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_actionError != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _actionError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Content Body
              Expanded(
                child: _labels != null ? _buildLabelsPreview() : _buildProductSelection(),
              ),

              const SizedBox(height: 14),

              // Action Footer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_labels != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _labels = null),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to Product Selection'),
                    )
                  else
                    Text(
                      '${_selectedProductIds.length} of ${_products.length} products selected',
                      style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_labels == null) ...[
                        ElevatedButton.icon(
                          onPressed:
                              (_selectedProductIds.isEmpty || _isGenerating)
                                  ? null
                                  : _handleFetchLabels,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _royalBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Preview Labels'),
                        ),
                      ],
                      ElevatedButton.icon(
                        onPressed: (_selectedProductIds.isEmpty || _isGenerating)
                            ? null
                            : _handleDownloadPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon:
                            const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Download PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSelection() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_productLoadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_productLoadError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadProducts, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _filteredProducts;

    return Column(
      children: [
        // Search & Selection controls
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products by name or code...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _borderBlue),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedProductIds.addAll(_products.map((p) => p.id));
                });
              },
              child: const Text('Select All', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedProductIds.clear();
                });
              },
              child: const Text('Clear', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No products match the filter'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final isSelected = _selectedProductIds.contains(p.id);

                    return CheckboxListTile(
                      value: isSelected,
                      dense: true,
                      activeColor: _royalBlue,
                      title: Text(
                        p.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Code: ${p.productCode} | Price: ₹${p.price?.toStringAsFixed(2) ?? "N/A"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedProductIds.add(p.id);
                          } else {
                            _selectedProductIds.remove(p.id);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLabelsPreview() {
    final labels = _labels ?? [];

    if (labels.isEmpty) {
      return const Center(child: Text('No labels retrieved.'));
    }

    return ListView.builder(
      itemCount: labels.length,
      itemBuilder: (context, index) {
        final item = labels[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _deepBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CODE: ${item.productCode}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'UNIQUE QR IDENTIFICATION NUMBER:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      item.qrNumber,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _royalBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: _royalBlue),
                    tooltip: 'Copy QR number',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.qrNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied QR number to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

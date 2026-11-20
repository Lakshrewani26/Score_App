import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/services/catalogue_api.dart';
import '../../../core/widgets/score_logo.dart';

class CatalogueCategoryListScreen extends StatefulWidget {
  const CatalogueCategoryListScreen({
    super.key,
    required this.api,
    required this.vehicleType,
    required this.title,
    required this.heroCaption,
    required this.onCategorySelected,
    this.fallbackBuilder,
    this.accentColor = const Color(0xFFDCEBFE),
    this.heroIcon,
  });

  final CatalogueApi api;
  final String vehicleType;
  final String title;
  final String heroCaption;
  final void Function(BuildContext context, CatalogueCategory category)
      onCategorySelected;
  final WidgetBuilder? fallbackBuilder;
  final Color accentColor;
  final IconData? heroIcon;

  @override
  State<CatalogueCategoryListScreen> createState() =>
      _CatalogueCategoryListScreenState();
}

class _CatalogueCategoryListScreenState
    extends State<CatalogueCategoryListScreen> {
  static const Color _royalBlue = Color(0xFF083FA5);
  static const Color _cardBorderBlue = Color(0xFFCBEBFF);

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<CatalogueCategory> _allCategories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories =
          await widget.api.loadCategories(vehicleType: widget.vehicleType);
      if (!mounted) return;
      setState(() {
        _allCategories = categories;
        _isLoading = false;
      });
    } on CatalogueApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load categories. Please try again.';
        _isLoading = false;
      });
    }
  }

  List<CatalogueCategory> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) {
      return _allCategories;
    }
    final query = _searchQuery.trim().toLowerCase();
    return _allCategories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final contentWidth = math.min(width * 0.94, 960.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 18),
                              _buildHeroCard(),
                              const SizedBox(height: 16),
                              _buildSearchBar(),
                              const SizedBox(height: 18),
                              _buildBody(width),
                              const SizedBox(height: 32),
                            ],
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

  Widget _buildHeaderRow(BuildContext context, double width) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (widget.fallbackBuilder != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: widget.fallbackBuilder!),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _royalBlue,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const Center(
            child: ScoreLogo.medium(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final icon = widget.heroIcon ?? Icons.category_rounded;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 155),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderBlue, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0755B5),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 55,
              child: CustomPaint(
                painter: _CategoryCardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: _royalBlue,
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1.2,
                    height: 86,
                    color: const Color(0xFFCBEBFF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.heroCaption,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _AccentBars(),
                      ],
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

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD6EAFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: _royalBlue,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Search categories...',
                hintStyle: TextStyle(
                  color: Color(0xFF7B93AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF7B93AF),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(double screenWidth) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: _royalBlue),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final categories = _filteredCategories;

    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: _royalBlue.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No categories match "$_searchQuery"'
                  : 'No categories found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: const Text(
                  'Clear search',
                  style: TextStyle(
                    color: _royalBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final int crossAxisCount;
    if (screenWidth < 600) {
      crossAxisCount = 2;
    } else if (screenWidth < 900) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          accentColor: widget.accentColor,
          heroIcon: widget.heroIcon,
          onTap: () => widget.onCategorySelected(context, category),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.accentColor,
    required this.heroIcon,
    required this.onTap,
  });

  final CatalogueCategory category;
  final Color accentColor;
  final IconData? heroIcon;
  final VoidCallback onTap;

  static const Color _royalBlue = Color(0xFF083FA5);
  static const Color _cardBorderBlue = Color(0xFFCBEBFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            heroIcon ?? Icons.category_rounded,
                            color: _royalBlue,
                            size: 30,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD6EAFF),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.image_outlined,
                                size: 11,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'No Image',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 1,
                color: const Color(0xFFE2E8F0),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _royalBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'View parts',
                            style: TextStyle(
                              color: Color(0xFF0075BE),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: Color(0xFF0075BE),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentBars extends StatelessWidget {
  const _AccentBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _AccentBar(color: Color(0xFF0755B5)),
        SizedBox(width: 5),
        _AccentBar(color: Color(0xFFFF1B28)),
        SizedBox(width: 5),
        _AccentBar(color: Color(0xFF0875BF)),
      ],
    );
  }
}

class _AccentBar extends StatelessWidget {
  const _AccentBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _CategoryCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFDED0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.15,
        size.width * 0.65,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.8,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.25,
        size.width,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

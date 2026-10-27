class CatalogueCategory {
  const CatalogueCategory({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;

  factory CatalogueCategory.fromJson(Map<String, dynamic> json) {
    return CatalogueCategory(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
    );
  }
}

class ProductPagination {
  const ProductPagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory ProductPagination.fromJson(Map<String, dynamic> json) {
    return ProductPagination(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

class CatalogueProduct {
  const CatalogueProduct({
    required this.id,
    required this.categoryId,
    required this.productCode,
    required this.name,
    required this.vehicleType,
    this.categoryName,
    this.description,
    this.price,
    this.imageUrl,
  });

  final int id;
  final int categoryId;
  final String? categoryName;
  final String productCode;
  final String name;
  final String? description;
  final String vehicleType;
  final num? price;
  final String? imageUrl;

  factory CatalogueProduct.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    num? parsedPrice;
    if (rawPrice != null && rawPrice.toString().trim().isNotEmpty) {
      parsedPrice = num.parse(rawPrice.toString());
    }

    return CatalogueProduct(
      id: json['id'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      categoryName: json['category_name'] as String?,
      productCode: (json['product_code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      vehicleType: (json['vehicle_type'] ?? 'Both').toString(),
      price: parsedPrice,
      imageUrl: json['image_url'] as String?,
    );
  }

  String get displayPrice {
    if (price == null) {
      return 'Price to be confirmed';
    }

    final rounded = price!.toStringAsFixed(2);
    final integerPart = rounded.split('.').first;
    final decimalPart = rounded.split('.').last;
    final thousands = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );

    return '₹ $thousands.$decimalPart';
  }
}

class ProductPage {
  const ProductPage({
    required this.items,
    required this.pagination,
  });

  final List<CatalogueProduct> items;
  final ProductPagination pagination;

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? const <dynamic>[]);
    return ProductPage(
      items: itemsJson
          .map((item) => CatalogueProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      pagination: ProductPagination.fromJson(json['pagination'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
    );
  }
}

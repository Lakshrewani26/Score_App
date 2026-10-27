class AdminProduct {
  final int id;
  final String productCode;
  final String name;
  final int categoryId;
  final String? categoryName;
  final bool categoryIsActive;
  final String vehicleType;
  final num? price;
  final String? description;
  final String? imageUrl;
  final bool isActive;

  const AdminProduct({
    required this.id,
    required this.productCode,
    required this.name,
    required this.categoryId,
    this.categoryName,
    this.categoryIsActive = true,
    required this.vehicleType,
    this.price,
    this.description,
    this.imageUrl,
    required this.isActive,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    num? parsedPrice;
    if (rawPrice != null && rawPrice.toString().trim().isNotEmpty) {
      parsedPrice = num.tryParse(rawPrice.toString());
    }

    return AdminProduct(
      id: json['id'] as int? ?? 0,
      productCode: (json['product_code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      categoryId: json['category_id'] as int? ?? 0,
      categoryName: json['category_name'] as String?,
      categoryIsActive: json['category_is_active'] as bool? ?? true,
      vehicleType: (json['vehicle_type'] ?? 'Both').toString(),
      price: parsedPrice,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_code': productCode,
        'name': name,
        'category_id': categoryId,
        if (categoryName != null) 'category_name': categoryName,
        'category_is_active': categoryIsActive,
        'vehicle_type': vehicleType,
        'price': price,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_active': isActive,
      };

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminProduct &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productCode == other.productCode &&
          name == other.name &&
          categoryId == other.categoryId &&
          categoryName == other.categoryName &&
          categoryIsActive == other.categoryIsActive &&
          vehicleType == other.vehicleType &&
          price == other.price &&
          description == other.description &&
          imageUrl == other.imageUrl &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      productCode.hashCode ^
      name.hashCode ^
      categoryId.hashCode ^
      categoryName.hashCode ^
      categoryIsActive.hashCode ^
      vehicleType.hashCode ^
      price.hashCode ^
      description.hashCode ^
      imageUrl.hashCode ^
      isActive.hashCode;
}

typedef AdminProductResponse = AdminProduct;

class AdminProductPagination {
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const AdminProductPagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory AdminProductPagination.fromJson(Map<String, dynamic> json) {
    return AdminProductPagination(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminProductPagination &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          page == other.page &&
          pageSize == other.pageSize &&
          totalPages == other.totalPages;

  @override
  int get hashCode =>
      total.hashCode ^ page.hashCode ^ pageSize.hashCode ^ totalPages.hashCode;
}

class AdminProductListResponse {
  final List<AdminProduct> items;
  final AdminProductPagination pagination;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const AdminProductListResponse({
    required this.items,
    required this.pagination,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory AdminProductListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    final paginationJson = json['pagination'] as Map<String, dynamic>?;
    final pagination = paginationJson != null
        ? AdminProductPagination.fromJson(paginationJson)
        : AdminProductPagination(
            total: json['total'] as int? ?? 0,
            page: json['page'] as int? ?? 1,
            pageSize: json['page_size'] as int? ?? 20,
            totalPages: json['total_pages'] as int? ?? 0,
          );

    return AdminProductListResponse(
      items: rawItems
          .map((item) => AdminProduct.fromJson(item as Map<String, dynamic>))
          .toList(),
      pagination: pagination,
      total: json['total'] as int? ?? pagination.total,
      page: json['page'] as int? ?? pagination.page,
      pageSize: json['page_size'] as int? ?? pagination.pageSize,
      totalPages: json['total_pages'] as int? ?? pagination.totalPages,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'pagination': pagination.toJson(),
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminProductListResponse &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          page == other.page &&
          pageSize == other.pageSize &&
          totalPages == other.totalPages &&
          pagination == other.pagination;

  @override
  int get hashCode =>
      total.hashCode ^
      page.hashCode ^
      pageSize.hashCode ^
      totalPages.hashCode ^
      pagination.hashCode;
}

class AdminCategory {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final int productCount;

  const AdminCategory({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.productCount = 0,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      productCount: json['product_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'is_active': isActive,
        'product_count': productCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          isActive == other.isActive &&
          productCount == other.productCount;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      isActive.hashCode ^
      productCount.hashCode;
}

typedef AdminCategoryResponse = AdminCategory;

class AdminProductCreateRequest {
  final String productCode;
  final String name;
  final int categoryId;
  final String vehicleType;
  final num? price;
  final String? description;
  final String? imageUrl;
  final bool isActive;

  const AdminProductCreateRequest({
    required this.productCode,
    required this.name,
    required this.categoryId,
    required this.vehicleType,
    this.price,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'product_code': productCode.trim(),
      'name': name.trim(),
      'category_id': categoryId,
      'vehicle_type': vehicleType,
      'is_active': isActive,
    };
    if (price != null) {
      map['price'] = price;
    }
    if (description != null && description!.trim().isNotEmpty) {
      map['description'] = description!.trim();
    }
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      map['image_url'] = imageUrl!.trim();
    }
    return map;
  }
}

class AdminProductUpdateRequest {
  final String? productCode;
  final String? name;
  final int? categoryId;
  final String? vehicleType;
  final num? price;
  final bool clearPrice;
  final String? description;
  final bool clearDescription;
  final String? imageUrl;
  final bool clearImageUrl;
  final bool? isActive;

  const AdminProductUpdateRequest({
    this.productCode,
    this.name,
    this.categoryId,
    this.vehicleType,
    this.price,
    this.clearPrice = false,
    this.description,
    this.clearDescription = false,
    this.imageUrl,
    this.clearImageUrl = false,
    this.isActive,
  }) : assert(!(clearPrice && price != null), 'Cannot provide both price and clearPrice: true');

  /// Convenience factory to explicitly clear the product price.
  factory AdminProductUpdateRequest.clearPrice({
    String? productCode,
    String? name,
    int? categoryId,
    String? vehicleType,
    String? description,
    bool clearDescription = false,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isActive,
  }) {
    return AdminProductUpdateRequest(
      productCode: productCode,
      name: name,
      categoryId: categoryId,
      vehicleType: vehicleType,
      clearPrice: true,
      description: description,
      clearDescription: clearDescription,
      imageUrl: imageUrl,
      clearImageUrl: clearImageUrl,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (productCode != null) {
      map['product_code'] = productCode!.trim();
    }
    if (name != null) {
      map['name'] = name!.trim();
    }
    if (categoryId != null) {
      map['category_id'] = categoryId;
    }
    if (vehicleType != null) {
      map['vehicle_type'] = vehicleType;
    }
    if (price != null) {
      map['price'] = price;
    } else if (clearPrice) {
      map['price'] = null;
    }
    if (description != null) {
      map['description'] = description!.trim();
    } else if (clearDescription) {
      map['description'] = null;
    }
    if (imageUrl != null) {
      map['image_url'] = imageUrl!.trim();
    } else if (clearImageUrl) {
      map['image_url'] = null;
    }
    if (isActive != null) {
      map['is_active'] = isActive;
    }
    return map;
  }
}

class ProductStatusUpdateRequest {
  final bool isActive;

  const ProductStatusUpdateRequest({required this.isActive});

  factory ProductStatusUpdateRequest.fromJson(Map<String, dynamic> json) {
    return ProductStatusUpdateRequest(
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_active': isActive,
      };
}

typedef AdminProductStatusUpdateRequest = ProductStatusUpdateRequest;

class AdminCategoryCreateRequest {
  final String name;
  final String? description;
  final bool isActive;

  const AdminCategoryCreateRequest({
    required this.name,
    this.description,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'is_active': isActive,
    };
    if (description != null && description!.trim().isNotEmpty) {
      map['description'] = description!.trim();
    }
    return map;
  }
}

class CategoryStatusUpdateRequest {
  final bool isActive;

  const CategoryStatusUpdateRequest({required this.isActive});

  factory CategoryStatusUpdateRequest.fromJson(Map<String, dynamic> json) {
    return CategoryStatusUpdateRequest(
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_active': isActive,
      };
}

typedef AdminCategoryStatusUpdateRequest = CategoryStatusUpdateRequest;

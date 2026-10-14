class CarModel {
  final String id;
  final String brand;
  final String model;
  final String category; // 'economy' | 'suv' | 'luxury' | 'electric' | 'van'
  final int year;
  final double pricePerDay;
  final int seats;
  final String transmission; // 'automatic' | 'manual'
  final String fuelType; // 'gasoline' | 'diesel' | 'hybrid' | 'electric'
  final String? imageUrl;
  final List<String> features;
  final double rating;
  final String pickupLocation;
  final bool hasAC;
  final bool hasGPS;
  final int? partnerListingId;
  final String? partnerName;

  const CarModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.category,
    required this.year,
    required this.pricePerDay,
    required this.seats,
    required this.transmission,
    required this.fuelType,
    this.imageUrl,
    required this.features,
    required this.rating,
    required this.pickupLocation,
    this.hasAC = true,
    this.hasGPS = false,
    this.partnerListingId,
    this.partnerName,
  });

  static String _stringFromDynamic(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return value.toString();
  }

  static int _intFromDynamic(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    }
    return fallback;
  }

  static double _doubleFromDynamic(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _boolFromDynamic(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == '1' || text == 'true' || text == 'yes') return true;
      if (text == '0' || text == 'false' || text == 'no') return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  String get fullName => '$brand $model $year';
  String get name => fullName;
  String get type => category; // alias used by controller filter
  int get bags => switch (category) {
        'van' => 6,
        'suv' => 4,
        'luxury' || 'electric' => 3,
        _ => 2,
      };
  double get insuranceFee => pricePerDay * 0.15;

  factory CarModel.fromJson(Map<String, dynamic> json) => CarModel(
        id: _stringFromDynamic(json['id']),
        brand: _stringFromDynamic(json['brand']),
        model: _stringFromDynamic(json['model']),
        category: _stringFromDynamic(json['category']),
        year: _intFromDynamic(json['year']),
        pricePerDay: _doubleFromDynamic(json['price_per_day']),
        seats: _intFromDynamic(json['seats']),
        transmission: _stringFromDynamic(json['transmission']),
        fuelType: _stringFromDynamic(json['fuel_type']),
        imageUrl: json['image_url'] == null
            ? null
            : _stringFromDynamic(json['image_url']),
        features:
            (json['features'] as List? ?? []).map((e) => e.toString()).toList(),
        rating: _doubleFromDynamic(json['rating']),
        pickupLocation: _stringFromDynamic(json['pickup_location']),
        hasAC: _boolFromDynamic(json['has_ac'], true),
        hasGPS: _boolFromDynamic(json['has_gps'], false),
        partnerListingId: json['partner_listing_id'] == null
            ? null
            : _intFromDynamic(json['partner_listing_id']),
        partnerName: json['partner_name']?.toString(),
      );
}

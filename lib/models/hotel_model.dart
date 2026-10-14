class HotelModel {
  static const _fallbackImageUrl =
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=900&auto=format&fit=crop';

  final String id;
  final String name;
  final String city;
  final String country;
  final String address;
  final double rating;
  final int reviewCount;
  final double pricePerNight;
  final String? imageUrl;
  final List<String> amenities;
  final String description;
  final int stars;
  final double? latitude;
  final double? longitude;
  final int? partnerListingId;
  final String? partnerName;

  const HotelModel({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.pricePerNight,
    this.imageUrl,
    required this.amenities,
    required this.description,
    required this.stars,
    this.latitude,
    this.longitude,
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

  int get starRating => stars;
  bool get isFeatured => stars >= 5;

  factory HotelModel.fromJson(Map<String, dynamic> json) => HotelModel(
        id: _stringFromDynamic(json['id']),
        name: _stringFromDynamic(json['name']),
        city: _stringFromDynamic(json['city']),
        country: _stringFromDynamic(json['country']),
        address: _stringFromDynamic(json['address']),
        rating: _doubleFromDynamic(json['rating']),
        reviewCount: _intFromDynamic(json['review_count']),
        pricePerNight: _doubleFromDynamic(json['price_per_night']),
        imageUrl: json['image_url'] == null ||
                _stringFromDynamic(json['image_url']).trim().isEmpty
            ? _fallbackImageUrl
            : _stringFromDynamic(json['image_url']),
        amenities: (json['amenities'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        description: _stringFromDynamic(json['description']),
        stars: _intFromDynamic(json['stars']),
        latitude: json['latitude'] == null
            ? null
            : _doubleFromDynamic(json['latitude']),
        longitude: json['longitude'] == null
            ? null
            : _doubleFromDynamic(json['longitude']),
        partnerListingId: json['partner_listing_id'] == null
            ? null
            : _intFromDynamic(json['partner_listing_id']),
        partnerName: json['partner_name']?.toString(),
      );
}

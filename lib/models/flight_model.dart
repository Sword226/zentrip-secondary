class AirportOption {
  final String code;
  final String city;
  final String airportName;
  final String country;
  final String region;

  const AirportOption({
    required this.code,
    required this.city,
    required this.airportName,
    required this.country,
    this.region = '',
  });

  String get label => '$city [$code]';

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$city $code $airportName $country $region'
        .toLowerCase()
        .contains(normalized);
  }

  static const supported = <AirportOption>[
    AirportOption(
      code: 'MJI',
      city: 'Tripoli',
      airportName: 'Mitiga International Airport',
      country: 'Libya',
      region: 'Western Libya',
    ),
    AirportOption(
      code: 'MRA',
      city: 'Misrata',
      airportName: 'Misrata International Airport',
      country: 'Libya',
      region: 'Central Libya',
    ),
    AirportOption(
      code: 'BEN',
      city: 'Benghazi',
      airportName: 'Benina International Airport',
      country: 'Libya',
      region: 'Eastern Libya',
    ),
    AirportOption(
      code: 'SEB',
      city: 'Sebha',
      airportName: 'Sebha Airport',
      country: 'Libya',
      region: 'Southern Libya',
    ),
    AirportOption(
      code: 'CAI',
      city: 'Cairo',
      airportName: 'Cairo International Airport',
      country: 'Egypt',
      region: 'North Africa',
    ),
    AirportOption(
      code: 'TUN',
      city: 'Tunis',
      airportName: 'Tunis-Carthage International Airport',
      country: 'Tunisia',
      region: 'North Africa',
    ),
    AirportOption(
      code: 'IST',
      city: 'Istanbul',
      airportName: 'Istanbul Airport',
      country: 'Turkiye',
      region: 'Europe',
    ),
    AirportOption(
      code: 'JED',
      city: 'Jeddah',
      airportName: 'King Abdulaziz International Airport',
      country: 'Saudi Arabia',
      region: 'Middle East',
    ),
    AirportOption(
      code: 'DXB',
      city: 'Dubai',
      airportName: 'Dubai International Airport',
      country: 'United Arab Emirates',
      region: 'Middle East',
    ),
  ];

  static AirportOption? byCode(String code) {
    for (final airport in supported) {
      if (airport.code == code) return airport;
    }
    return null;
  }

  static AirportOption? byCity(String city) {
    for (final airport in supported) {
      if (airport.city.toLowerCase() == city.trim().toLowerCase()) {
        return airport;
      }
    }
    return null;
  }
}

class FlightModel {
  final String id;
  final String airline;
  final String airlineCode;
  final String flightNumber;
  final String originCode;
  final String originCity;
  final String destinationCode;
  final String destinationCity;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int durationMinutes;
  final bool isDirect;
  final int stops;
  final double economyPrice;
  final double? businessPrice;
  final int seatsAvailable;
  final String? airlineLogoUrl;
  final int? partnerListingId;
  final bool isActive;

  const FlightModel({
    required this.id,
    required this.airline,
    required this.airlineCode,
    required this.flightNumber,
    required this.originCode,
    required this.originCity,
    required this.destinationCode,
    required this.destinationCity,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.isDirect,
    required this.stops,
    required this.economyPrice,
    this.businessPrice,
    required this.seatsAvailable,
    this.airlineLogoUrl,
    this.partnerListingId,
    this.isActive = true,
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

  static String _airportCode(dynamic code, dynamic city) {
    final value = _stringFromDynamic(code).trim();
    return value.isNotEmpty
        ? value
        : AirportOption.byCity(_stringFromDynamic(city))?.code ?? '';
  }

  static String _airportCity(dynamic city, dynamic code) {
    final value = _stringFromDynamic(city).trim();
    return value.isNotEmpty
        ? value
        : AirportOption.byCode(_stringFromDynamic(code).trim().toUpperCase())
                ?.city ??
            '';
  }

  String get duration {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return '${h}h ${m}m';
  }

  factory FlightModel.fromJson(Map<String, dynamic> json) => FlightModel(
        id: _stringFromDynamic(json['id']),
        airline: _stringFromDynamic(json['airline']),
        airlineCode: _stringFromDynamic(json['airline_code']),
        flightNumber: _stringFromDynamic(json['flight_number']),
        originCode: _airportCode(json['origin_code'], json['origin_city']),
        originCity: _airportCity(json['origin_city'], json['origin_code']),
        destinationCode:
            _airportCode(json['destination_code'], json['destination_city']),
        destinationCity:
            _airportCity(json['destination_city'], json['destination_code']),
        departureTime:
            DateTime.tryParse(_stringFromDynamic(json['departure_time'])) ??
                DateTime.now(),
        arrivalTime:
            DateTime.tryParse(_stringFromDynamic(json['arrival_time'])) ??
                DateTime.now(),
        durationMinutes: _intFromDynamic(json['duration_minutes']),
        isDirect: _boolFromDynamic(json['is_direct'], true),
        stops: _intFromDynamic(json['stops'], 0),
        economyPrice: _doubleFromDynamic(json['economy_price']),
        businessPrice: json['business_price'] == null
            ? null
            : _doubleFromDynamic(json['business_price']),
        seatsAvailable: _intFromDynamic(json['seats_available'], 0),
        airlineLogoUrl: json['airline_logo_url'] == null
            ? null
            : _stringFromDynamic(json['airline_logo_url']),
        partnerListingId: json['partner_listing_id'] == null
            ? null
            : _intFromDynamic(json['partner_listing_id']),
        isActive: _boolFromDynamic(
              json['is_active'] ?? json['active'],
              !_isInactiveStatus(json['status']),
            ) &&
            !_isInactiveStatus(json['status']),
      );

  static bool _isInactiveStatus(dynamic value) {
    final status = _stringFromDynamic(value).trim().toLowerCase();
    return const {'inactive', 'paused', 'draft', 'cancelled', 'canceled'}
        .contains(status);
  }

  bool matchesSearch({
    required String originCode,
    required String destinationCode,
    required String originCity,
    required String destinationCity,
    required DateTime departureDate,
    required int passengers,
  }) {
    final originMatches = _matchesAirport(
      originCode,
      originCity,
      this.originCode,
      this.originCity,
    );
    final destinationMatches = _matchesAirport(
      destinationCode,
      destinationCity,
      this.destinationCode,
      this.destinationCity,
    );
    return isActive &&
        originMatches &&
        destinationMatches &&
        departureTime.year == departureDate.year &&
        departureTime.month == departureDate.month &&
        departureTime.day == departureDate.day &&
        seatsAvailable >= passengers;
  }

  static bool _matchesAirport(
    String requestedCode,
    String requestedCity,
    String flightCode,
    String flightCity,
  ) {
    final normalizedCode = requestedCode.trim().toUpperCase();
    final codeMatches = normalizedCode.isNotEmpty &&
        flightCode.trim().isNotEmpty &&
        flightCode.trim().toUpperCase() == normalizedCode;
    final normalizedCity = requestedCity.trim().toLowerCase();
    final cityMatches = normalizedCity.isNotEmpty &&
        flightCity.trim().toLowerCase() == normalizedCity;
    return codeMatches || cityMatches;
  }
}

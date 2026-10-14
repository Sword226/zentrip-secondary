import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum CurrentLocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unableToDetermine,
}

class CurrentLocationException implements Exception {
  final CurrentLocationError reason;

  const CurrentLocationException(this.reason);
}

class CurrentPlace {
  final Position position;
  final String? city;

  const CurrentPlace({required this.position, this.city});
}

class CurrentLocationService {
  const CurrentLocationService();

  Future<Position> getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const CurrentLocationException(
            CurrentLocationError.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const CurrentLocationException(
            CurrentLocationError.permissionDeniedForever);
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const CurrentLocationException(
            CurrentLocationError.permissionDenied);
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } on CurrentLocationException {
      rethrow;
    } catch (_) {
      throw const CurrentLocationException(
          CurrentLocationError.unableToDetermine);
    }
  }

  Future<CurrentPlace> getCurrentPlace() async {
    final position = await getPosition();
    try {
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) return CurrentPlace(position: position);

      final placemark = placemarks.first;
      final city = [
        placemark.locality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
      ]
          .whereType<String>()
          .map((value) => value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      return CurrentPlace(
        position: position,
        city: city.isEmpty ? null : city,
      );
    } catch (_) {
      return CurrentPlace(position: position);
    }
  }
}

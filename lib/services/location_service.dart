import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/school.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  bool _isTracking = false;

  Position? get currentPosition => _currentPosition;

  // Check and request location permissions
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      return position;
    } catch (e) {
      return null;
    }
  }

  // Start continuous location tracking
  void startLocationTracking(Function(Position) onLocationUpdate) {
    if (_isTracking) return;

    checkAndRequestPermissions().then((hasPermission) {
      if (!hasPermission) {
        return;
      }

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStream = Geolocator.getPositionStream(
              locationSettings: locationSettings)
          .listen((Position position) {
        _currentPosition = position;
        onLocationUpdate(position);
      });

      _isTracking = true;
    });
  }

  // Stop location tracking
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }

  // Calculate distance between two points in meters
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // Check if parent is inside pickup zone
  bool isInsidePickupZone(Position position, School school) {
    double distance = calculateDistance(
      position.latitude,
      position.longitude,
      school.pickupLocation.lat,
      school.pickupLocation.lng,
    );
    return distance <= school.pickupRadius;
  }

  // Dispose
  void dispose() {
    stopLocationTracking();
  }
}


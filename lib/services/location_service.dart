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
    // Prevent starting if already tracking
    if (_isTracking) {
      print('⚠️ Location tracking already active, skipping start');
      return;
    }

    // Ensure any existing stream is cancelled first
    _positionStream?.cancel();
    _positionStream = null;

    checkAndRequestPermissions().then((hasPermission) {
      if (!hasPermission) {
        _isTracking = false;
        return;
      }

      try {
        const LocationSettings locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        );

        _positionStream = Geolocator.getPositionStream(
                locationSettings: locationSettings)
            .listen(
          (Position position) {
            _currentPosition = position;
            onLocationUpdate(position);
          },
          onError: (error) {
            print('⚠️ Location stream error: $error');
            // Reset tracking state on error so it can be restarted
            _isTracking = false;
            _positionStream = null;
          },
          cancelOnError: false, // Keep stream alive despite errors
        );

        _isTracking = true;
        print('✅ Location tracking started');
      } catch (e) {
        print('❌ Error starting location tracking: $e');
        _isTracking = false;
        _positionStream = null;
      }
    });
  }

  // Stop location tracking
  void stopLocationTracking() {
    if (!_isTracking && _positionStream == null) {
      // Already stopped, nothing to do
      return;
    }

    try {
      _positionStream?.cancel();
      _positionStream = null;
      _isTracking = false;
      print('✅ Location tracking stopped');
    } catch (e) {
      print('⚠️ Error stopping location tracking: $e');
      // Force reset state even if cancel fails
      _positionStream = null;
      _isTracking = false;
    }
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

  // Dispose - ensure complete cleanup
  void dispose() {
    print('🧹 Disposing LocationService');
    stopLocationTracking();
    _currentPosition = null;
  }
}


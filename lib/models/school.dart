class PickupLocation {
  final double lat;
  final double lng;

  PickupLocation({
    required this.lat,
    required this.lng,
  });

  factory PickupLocation.fromFirestore(Map<String, dynamic> data) {
    return PickupLocation(
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

class School {
  final String id;
  final String name;
  final PickupLocation pickupLocation;
  final double pickupRadius;
  final bool pickupActive;

  School({
    required this.id,
    required this.name,
    required this.pickupLocation,
    required this.pickupRadius,
    required this.pickupActive,
  });

  factory School.fromFirestore(Map<String, dynamic> data, String id) {
    return School(
      id: id,
      name: data['name'] ?? '',
      pickupLocation: PickupLocation.fromFirestore(
        data['pickupLocation'] ?? {'lat': 0.0, 'lng': 0.0},
      ),
      pickupRadius: (data['pickupRadius'] ?? 0.0).toDouble(),
      pickupActive: data['pickupActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'pickupLocation': pickupLocation.toFirestore(),
      'pickupRadius': pickupRadius,
      'pickupActive': pickupActive,
    };
  }
}


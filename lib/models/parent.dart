class Parent {
  final String id;
  final String name;
  final String vehicleDescription;
  final String contactInfo;

  Parent({
    required this.id,
    required this.name,
    required this.vehicleDescription,
    required this.contactInfo,
  });

  factory Parent.fromFirestore(Map<String, dynamic> data, String id) {
    return Parent(
      id: id,
      name: data['name'] ?? '',
      vehicleDescription: data['vehicleDescription'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'vehicleDescription': vehicleDescription,
      'contactInfo': contactInfo,
    };
  }
}


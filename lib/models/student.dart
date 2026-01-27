class Student {
  final String id;
  final String name;
  final String schoolId;
  final String parentId;
  final String? photo;

  Student({
    required this.id,
    required this.name,
    required this.schoolId,
    required this.parentId,
    this.photo,
  });

  factory Student.fromFirestore(Map<String, dynamic> data, String id) {
    return Student(
      id: id,
      name: data['name'] ?? '',
      schoolId: data['schoolId'] ?? '',
      parentId: data['parentId'] ?? '',
      photo: data['photo'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'schoolId': schoolId,
      'parentId': parentId,
      if (photo != null) 'photo': photo,
    };
  }
}


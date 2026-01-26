class Student {
  final String id;
  final String name;
  final String schoolId;
  final String parentId;

  Student({
    required this.id,
    required this.name,
    required this.schoolId,
    required this.parentId,
  });

  factory Student.fromFirestore(Map<String, dynamic> data, String id) {
    return Student(
      id: id,
      name: data['name'] ?? '',
      schoolId: data['schoolId'] ?? '',
      parentId: data['parentId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'schoolId': schoolId,
      'parentId': parentId,
    };
  }
}


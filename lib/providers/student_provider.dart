import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/student.dart';
import '../models/school.dart';

class StudentProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Student> _students = [];
  final List<Student> _selectedStudents = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Student> get students => _students;
  List<Student> get selectedStudents => _selectedStudents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadStudents(String parentId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _firestoreService.getStudentsByParentId(parentId).listen(
      (students) {
        _students = students;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void toggleStudentSelection(Student student) {
    if (_selectedStudents.contains(student)) {
      _selectedStudents.remove(student);
    } else {
      _selectedStudents.add(student);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedStudents.clear();
    notifyListeners();
  }

  Future<School?> getSchoolForStudent(Student student) async {
    return await _firestoreService.getSchool(student.schoolId);
  }
}


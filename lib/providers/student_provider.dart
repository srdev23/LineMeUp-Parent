import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../models/student.dart';
import '../models/school.dart';

class StudentProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Student> _students = [];
  final List<Student> _selectedStudents = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _studentsSubscription;
  bool _disposed = false;

  List<Student> get students => _students;
  List<Student> get selectedStudents => _selectedStudents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void loadStudents(String parentId) {
    // Cancel existing subscription if any
    _studentsSubscription?.cancel();
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _studentsSubscription = _firestoreService.getStudentsByParentId(parentId).listen(
      (students) {
        if (_disposed) return;
        _students = students;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        if (_disposed) return;
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }
  
  void cleanup() {
    if (_disposed) return;
    
    // Cancel subscription
    _studentsSubscription?.cancel();
    _studentsSubscription = null;
    
    // Clear all data
    _students.clear();
    _selectedStudents.clear();
    _isLoading = false;
    _errorMessage = null;
    
    // Reset disposed flag so provider can be used again
    _disposed = false;
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _studentsSubscription?.cancel();
    _studentsSubscription = null;
    super.dispose();
  }

  void toggleStudentSelection(Student student) {
    // Use student ID for comparison to avoid duplicates
    final index = _selectedStudents.indexWhere((s) => s.id == student.id);
    if (index >= 0) {
      _selectedStudents.removeAt(index);
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


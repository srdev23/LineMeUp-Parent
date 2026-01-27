import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../providers/pickup_provider.dart';
import 'pickup_home_screen.dart';
import 'login_screen.dart';

class StudentSelectionScreen extends StatefulWidget {
  const StudentSelectionScreen({super.key});

  @override
  State<StudentSelectionScreen> createState() => _StudentSelectionScreenState();
}

class _StudentSelectionScreenState extends State<StudentSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentProvider =
          Provider.of<StudentProvider>(context, listen: false);
      
      // Clear any previous selections
      studentProvider.clearSelection();

      if (authProvider.currentParent != null) {
        studentProvider.loadStudents(authProvider.currentParent!.id);
      }
    });
  }

  Future<void> _proceedToPickup() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (studentProvider.selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student')),
      );
      return;
    }

    // Get school for the first selected student
    final school = await studentProvider
        .getSchoolForStudent(studentProvider.selectedStudents.first);

    if (school == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load school information')),
      );
      return;
    }

    // Initialize pickup provider
    final pickupProvider =
        Provider.of<PickupProvider>(context, listen: false);
    pickupProvider.initialize(
      authProvider.currentParent!,
      studentProvider.selectedStudents,
      school,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PickupHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (!mounted) return;
              
              // Navigate away FIRST
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
              
              // Then cleanup and sign out
              try {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final studentProvider =
                    Provider.of<StudentProvider>(context, listen: false);
                
                studentProvider.cleanup();
                await authProvider.signOut();
              } catch (e) {
                print('Logout error: $e');
              }
            },
          ),
        ],
      ),
      body: Consumer<StudentProvider>(
        builder: (context, studentProvider, child) {
          if (studentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (studentProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    studentProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      if (authProvider.currentParent != null) {
                        studentProvider
                            .loadStudents(authProvider.currentParent!.id);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (studentProvider.students.isEmpty) {
            return const Center(
              child: Text('No students found'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: studentProvider.students.length,
                  itemBuilder: (context, index) {
                    final student = studentProvider.students[index];
                    final isSelected = studentProvider.selectedStudents
                        .any((s) => s.id == student.id);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: student.photo != null && student.photo!.isNotEmpty
                            ? CachedNetworkImageProvider(student.photo!)
                            : null,
                        child: student.photo == null || student.photo!.isEmpty
                            ? Text(
                                student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),
                      title: Text(student.name),
                      subtitle: Text('School ID: ${student.schoolId}'),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          studentProvider.toggleStudentSelection(student);
                        },
                      ),
                      onTap: () {
                        studentProvider.toggleStudentSelection(student);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _proceedToPickup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Continue to Pickup'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


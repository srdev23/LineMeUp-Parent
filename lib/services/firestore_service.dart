import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parent.dart';
import '../models/student.dart';
import '../models/school.dart';
import '../models/queue_item.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get parent by ID
  Future<Parent?> getParent(String parentId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('parents').doc(parentId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return Parent.fromFirestore(data, doc.id);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get students by parent ID
  Stream<List<Student>> getStudentsByParentId(String parentId) {
    return _firestore
        .collection('students')
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              return Student.fromFirestore(
                  Map<String, dynamic>.from(data), doc.id);
            })
            .toList());
  }

  // Get school by ID
  Future<School?> getSchool(String schoolId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('schools').doc(schoolId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return School.fromFirestore(data, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Stream school updates
  Stream<School?> streamSchool(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          final data = doc.data() as Map<String, dynamic>;
          return School.fromFirestore(data, doc.id);
        });
  }

  // Get or create queue item
  Future<QueueItem?> getOrCreateQueueItem({
    required String schoolId,
    required String parentId,
    required List<String> studentIds,
    required double lat,
    required double lng,
  }) async {
    try {
      // Check if queue item exists
      QuerySnapshot querySnapshot = await _firestore
          .collection('queueItems')
          .where('schoolId', isEqualTo: schoolId)
          .where('parentId', isEqualTo: parentId)
          .where('status', whereIn: ['WAITING', 'READY'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing queue item
        DocumentSnapshot doc = querySnapshot.docs.first;
        await doc.reference.update({
          'location': {'lat': lat, 'lng': lng},
          'arrivalTime': FieldValue.serverTimestamp(),
        });
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return QueueItem.fromFirestore(data, doc.id);
        }
        return null;
      } else {
        // Create new queue item
        DocumentReference docRef = _firestore.collection('queueItems').doc();
        QueueItem newItem = QueueItem(
          id: docRef.id,
          schoolId: schoolId,
          parentId: parentId,
          studentIds: studentIds,
          arrivalTime: DateTime.now(),
          status: QueueStatus.waiting,
          location: QueueLocation(lat: lat, lng: lng),
        );
        await docRef.set(newItem.toFirestore());
        return newItem;
      }
    } catch (e) {
      return null;
    }
  }

  // Stream queue item for parent
  Stream<QueueItem?> streamQueueItem(String schoolId, String parentId) {
    return _firestore
        .collection('queueItems')
        .where('schoolId', isEqualTo: schoolId)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      
      // Get the most recent active queue item (prefer WAITING/READY over PICKED_UP)
      QueueItem? activeItem;
      QueueItem? pickedUpItem;
      DateTime? latestActiveTime;
      DateTime? latestPickedUpTime;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final itemData = Map<String, dynamic>.from(data as Map);
        QueueItem item = QueueItem.fromFirestore(itemData, doc.id);
        
        if (item.status == QueueStatus.pickedUp) {
          // Track most recent picked up item
          if (latestPickedUpTime == null || 
              item.arrivalTime.isAfter(latestPickedUpTime)) {
            pickedUpItem = item;
            latestPickedUpTime = item.arrivalTime;
          }
        } else {
          // Track most recent active item (WAITING or READY)
          if (latestActiveTime == null || 
              item.arrivalTime.isAfter(latestActiveTime)) {
            activeItem = item;
            latestActiveTime = item.arrivalTime;
          }
        }
      }
      
      // Return active item if exists, otherwise return picked up item
      return activeItem ?? pickedUpItem;
    });
  }

  // Get queue position
  Future<int> getQueuePosition(String schoolId, DateTime arrivalTime) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('queueItems')
          .where('schoolId', isEqualTo: schoolId)
          .where('status', whereIn: ['WAITING', 'READY'])
          .orderBy('arrivalTime', descending: false)
          .get();

      int position = 1;
      for (var doc in querySnapshot.docs) {
        if (doc.data() == null) continue;
        final data = doc.data() as Map<String, dynamic>;
        QueueItem item = QueueItem.fromFirestore(data, doc.id);
        if (item.arrivalTime.isBefore(arrivalTime) ||
            item.arrivalTime.isAtSameMomentAs(arrivalTime)) {
          position++;
        } else {
          break;
        }
      }
      return position;
    } catch (e) {
      return 0;
    }
  }

  // Update queue item status
  Future<void> updateQueueItemStatus(
      String queueItemId, QueueStatus status) async {
    try {
      await _firestore.collection('queueItems').doc(queueItemId).update({
        'status': status.value,
      });
    } catch (e) {
      // Handle error
    }
  }

  // Mark as picked up when leaving zone
  Future<void> markAsPickedUp(String queueItemId) async {
    try {
      await _firestore.collection('queueItems').doc(queueItemId).update({
        'status': QueueStatus.pickedUp.value,
      });
    } catch (e) {
      // Handle error
    }
  }

  // Create new queue item (manual join)
  Future<QueueItem?> createQueueItem({
    required String schoolId,
    required String parentId,
    required List<String> studentIds,
    required double lat,
    required double lng,
  }) async {
    try {
      // Check if queue item already exists
      QuerySnapshot querySnapshot = await _firestore
          .collection('queueItems')
          .where('schoolId', isEqualTo: schoolId)
          .where('parentId', isEqualTo: parentId)
          .where('status', whereIn: ['WAITING', 'READY'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Already in queue, return existing
        DocumentSnapshot doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return QueueItem.fromFirestore(data, doc.id);
        }
        return null;
      }

      // Create new queue item
      DocumentReference docRef = _firestore.collection('queueItems').doc();
      QueueItem newItem = QueueItem(
        id: docRef.id,
        schoolId: schoolId,
        parentId: parentId,
        studentIds: studentIds,
        arrivalTime: DateTime.now(),
        status: QueueStatus.waiting,
        location: QueueLocation(lat: lat, lng: lng),
      );
      await docRef.set(newItem.toFirestore());
      return newItem;
    } catch (e) {
      return null;
    }
  }

  // Update queue item location in real-time
  Future<void> updateQueueItemLocation(
    String queueItemId,
    double lat,
    double lng,
  ) async {
    try {
      await _firestore.collection('queueItems').doc(queueItemId).update({
        'location': {'lat': lat, 'lng': lng},
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // Delete queue item (exit queue)
  Future<void> deleteQueueItem(String queueItemId) async {
    try {
      await _firestore.collection('queueItems').doc(queueItemId).delete();
    } catch (e) {
      // Handle error
    }
  }
}


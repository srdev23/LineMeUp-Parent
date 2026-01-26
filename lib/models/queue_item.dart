import 'package:cloud_firestore/cloud_firestore.dart';

enum QueueStatus {
  waiting,
  ready,
  pickedUp,
}

extension QueueStatusExtension on QueueStatus {
  String get value {
    switch (this) {
      case QueueStatus.waiting:
        return 'WAITING';
      case QueueStatus.ready:
        return 'READY';
      case QueueStatus.pickedUp:
        return 'PICKED_UP';
    }
  }

  static QueueStatus fromString(String value) {
    switch (value) {
      case 'WAITING':
        return QueueStatus.waiting;
      case 'READY':
        return QueueStatus.ready;
      case 'PICKED_UP':
        return QueueStatus.pickedUp;
      default:
        return QueueStatus.waiting;
    }
  }
}

class QueueLocation {
  final double lat;
  final double lng;

  QueueLocation({
    required this.lat,
    required this.lng,
  });

  factory QueueLocation.fromFirestore(Map<String, dynamic> data) {
    return QueueLocation(
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

class QueueItem {
  final String id;
  final String schoolId;
  final String parentId;
  final List<String> studentIds;
  final DateTime arrivalTime;
  final QueueStatus status;
  final QueueLocation? location;

  QueueItem({
    required this.id,
    required this.schoolId,
    required this.parentId,
    required this.studentIds,
    required this.arrivalTime,
    required this.status,
    this.location,
  });

  factory QueueItem.fromFirestore(Map<String, dynamic> data, String id) {
    return QueueItem(
      id: id,
      schoolId: data['schoolId'] ?? '',
      parentId: data['parentId'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
      arrivalTime: (data['arrivalTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: QueueStatusExtension.fromString(data['status'] ?? 'WAITING'),
      location: data['location'] != null
          ? QueueLocation.fromFirestore(data['location'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'parentId': parentId,
      'studentIds': studentIds,
      'arrivalTime': Timestamp.fromDate(arrivalTime),
      'status': status.value,
      if (location != null) 'location': location!.toFirestore(),
    };
  }
}


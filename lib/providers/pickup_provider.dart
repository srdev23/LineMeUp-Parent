import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../models/parent.dart';
import '../models/student.dart';
import '../models/school.dart';
import '../models/queue_item.dart';

enum PickupState {
  pickupNotActive,
  waitingInsideZoneInactive,
  waitingActiveNotQueued,
  queued,
  ready,
  pickedUp,
}

class PickupProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  Parent? _parent;
  List<Student> _selectedStudents = [];
  School? _school;
  QueueItem? _queueItem;
  PickupState _pickupState = PickupState.pickupNotActive;
  int _queuePosition = 0;
  bool _isInsideZone = false;
  final bool _isLoading = false;
  String? _errorMessage;

  Parent? get parent => _parent;
  List<Student> get selectedStudents => _selectedStudents;
  School? get school => _school;
  QueueItem? get queueItem => _queueItem;
  PickupState get pickupState => _pickupState;
  int get queuePosition => _queuePosition;
  bool get isInsideZone => _isInsideZone;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void initialize(Parent parent, List<Student> students, School school) {
    _parent = parent;
    _selectedStudents = students;
    _school = school;
    _startMonitoring();
  }

  void _startMonitoring() {
    if (_school == null || _parent == null) return;

    // Stream school updates
    _firestoreService.streamSchool(_school!.id).listen((school) {
      if (school != null) {
        _school = school;
        _updatePickupState();
        notifyListeners();
      }
    });

    // Stream queue item updates
    _firestoreService
        .streamQueueItem(_school!.id, _parent!.id)
        .listen((queueItem) {
      _queueItem = queueItem;
      if (queueItem != null) {
        _updateQueuePosition();
      }
      _updatePickupState();
      notifyListeners();
    });

    // Start location tracking
    _locationService.startLocationTracking((position) {
      _onLocationUpdate(position);
    });
  }

  void _onLocationUpdate(Position position) {
    if (_school == null) return;

    bool wasInsideZone = _isInsideZone;
    _isInsideZone =
        _locationService.isInsidePickupZone(position, _school!);

    if (_isInsideZone && !wasInsideZone) {
      // Entered zone
      _onEnteredZone(position);
    } else if (!_isInsideZone && wasInsideZone && _queueItem != null) {
      // Left zone
      _onLeftZone();
    } else if (_isInsideZone && _queueItem != null) {
      // Update location in queue item
      _updateQueueItemLocation(position);
    }

    _updatePickupState();
    notifyListeners();
  }

  Future<void> _onEnteredZone(Position position) async {
    if (_school == null || _parent == null || _selectedStudents.isEmpty) {
      return;
    }

    if (_school!.pickupActive) {
      // Create or update queue item
      List<String> studentIds =
          _selectedStudents.map((s) => s.id).toList();
      _queueItem = await _firestoreService.getOrCreateQueueItem(
        schoolId: _school!.id,
        parentId: _parent!.id,
        studentIds: studentIds,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (_queueItem != null) {
        _updateQueuePosition();
      }
    }
  }

  Future<void> _onLeftZone() async {
    if (_queueItem != null &&
        _queueItem!.status == QueueStatus.pickedUp) {
      // Already picked up, stop tracking
      _locationService.stopLocationTracking();
    } else if (_queueItem != null &&
        _queueItem!.status == QueueStatus.ready) {
      // Mark as picked up when leaving zone after ready
      await _firestoreService.markAsPickedUp(_queueItem!.id);
      _locationService.stopLocationTracking();
    }
  }

  Future<void> _updateQueueItemLocation(Position position) async {
    // Location updates are handled automatically by Firestore listeners
    // This can be used for manual updates if needed
  }

  Future<void> _updateQueuePosition() async {
    if (_queueItem == null || _school == null) {
      _queuePosition = 0;
      return;
    }

    _queuePosition = await _firestoreService.getQueuePosition(
      _school!.id,
      _queueItem!.arrivalTime,
    );
  }

  void _updatePickupState() {
    if (_school == null) {
      _pickupState = PickupState.pickupNotActive;
      return;
    }

    if (!_school!.pickupActive) {
      if (_isInsideZone) {
        _pickupState = PickupState.waitingInsideZoneInactive;
      } else {
        _pickupState = PickupState.pickupNotActive;
      }
      return;
    }

    if (_queueItem == null) {
      if (_isInsideZone) {
        _pickupState = PickupState.waitingActiveNotQueued;
      } else {
        _pickupState = PickupState.pickupNotActive;
      }
      return;
    }

    switch (_queueItem!.status) {
      case QueueStatus.waiting:
        _pickupState = PickupState.queued;
        break;
      case QueueStatus.ready:
        _pickupState = PickupState.ready;
        break;
      case QueueStatus.pickedUp:
        _pickupState = PickupState.pickedUp;
        break;
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}


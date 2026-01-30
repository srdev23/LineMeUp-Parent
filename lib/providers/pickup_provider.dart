import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
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
  bool? _previousPickupActive; // Track previous pickup active state
  QueueItem? _queueItem;
  PickupState _pickupState = PickupState.pickupNotActive;
  PickupState _previousPickupState = PickupState.pickupNotActive;
  int _queuePosition = 0;
  int _previousQueuePosition = 0;
  bool _isInsideZone = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;
  StreamSubscription? _schoolSubscription;
  StreamSubscription? _queueSubscription;

  Parent? get parent => _parent;
  List<Student> get selectedStudents => _selectedStudents;
  School? get school => _school;
  QueueItem? get queueItem => _queueItem;
  PickupState get pickupState => _pickupState;
  int get queuePosition => _queuePosition;
  bool get isInsideZone => _isInsideZone;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Button visibility getters
  bool get canJoinQueue {
    return _school != null &&
        _school!.pickupActive &&
        _isInsideZone &&
        _queueItem == null &&
        _selectedStudents.isNotEmpty;
  }

  bool get canMarkPickedUp {
    return _queueItem != null &&
        (_queueItem!.status == QueueStatus.waiting ||
            _queueItem!.status == QueueStatus.ready);
  }

  void initialize(Parent parent, List<Student> students, School school) {
    // Reset state first to clear any previous session data
    _resetState();
    
    _parent = parent;
    _selectedStudents = List.from(students); // Create a copy to avoid reference issues
    _school = school;
    _previousPickupActive = school.pickupActive; // Initialize previous state
    _disposed = false; // Reset disposed flag for new session
    _startMonitoring();
  }
  
  void _resetState({bool keepDisposed = false}) {
    // Stop any existing monitoring
    _locationService.stopLocationTracking();
    _schoolSubscription?.cancel();
    _queueSubscription?.cancel();
    _schoolSubscription = null;
    _queueSubscription = null;
    
    // Clear all state
    _parent = null;
    _selectedStudents.clear();
    _school = null;
    _previousPickupActive = null;
    _queueItem = null;
    _pickupState = PickupState.pickupNotActive;
    _previousPickupState = PickupState.pickupNotActive;
    _queuePosition = 0;
    _previousQueuePosition = 0;
    _isInsideZone = false;
    _isLoading = false;
    _errorMessage = null;
    
    // Only reset disposed flag if not cleaning up
    if (!keepDisposed) {
      _disposed = false;
    }
    
    notifyListeners();
  }

  void _startMonitoring() {
    if (_school == null || _parent == null) return;
    
    // Don't start if already monitoring
    if (_schoolSubscription != null || _queueSubscription != null) {
      return;
    }

    // Stream school updates
    _schoolSubscription = _firestoreService.streamSchool(_school!.id).listen(
      (school) {
        if (_disposed) return;
        if (school != null) {
          // Check if pickup active status changed
          bool currentActive = school.pickupActive;
          
          // Notify if pickup status changed (only if we had a previous state)
          if (_previousPickupActive != null && _previousPickupActive != currentActive) {
            _handlePickupStatusChange(currentActive);
          }
          
          _school = school;
          
          // Update previous state for next comparison
          _previousPickupActive = currentActive;
          
          _updatePickupState();
          notifyListeners();
        }
      },
      onError: (error) {
        // Silently handle errors (e.g., permission denied after logout)
        if (_disposed) return;
      },
    );

    // Stream queue item updates
    _queueSubscription = _firestoreService
        .streamQueueItem(_school!.id, _parent!.id)
        .listen(
      (queueItem) {
        if (_disposed) return;
        _queueItem = queueItem;
        if (queueItem != null) {
          // Skip notification on stream updates - we'll handle it in state change
          _updateQueuePosition(skipNotification: true);
        }
        _updatePickupState();
        notifyListeners();
      },
      onError: (error) {
        // Silently handle errors (e.g., permission denied after logout)
        if (_disposed) return;
      },
    );

    // Start location tracking
    _locationService.startLocationTracking((position) {
      if (_disposed) return;
      _onLocationUpdate(position);
    });
  }

  void _onLocationUpdate(Position position) {
    if (_school == null) return;

    _isInsideZone =
        _locationService.isInsidePickupZone(position, _school!);

    // Update location in queue item in real-time if in queue
    if (_queueItem != null && _isInsideZone) {
      _updateQueueItemLocation(position);
    }

    _updatePickupState();
    notifyListeners();
  }

  Future<void> _updateQueueItemLocation(Position position) async {
    if (_queueItem == null) return;

    try {
      await _firestoreService.updateQueueItemLocation(
        _queueItem!.id,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      // Silently handle location update errors
      print('Error updating queue item location: $e');
    }
  }

  Future<void> _updateQueuePosition({bool skipNotification = false}) async {
    if (_queueItem == null || _school == null) {
      _previousQueuePosition = _queuePosition;
      _queuePosition = 0;
      return;
    }

    _previousQueuePosition = _queuePosition;
    _queuePosition = await _firestoreService.getQueuePosition(
      _school!.id,
      _queueItem!.arrivalTime,
      _queueItem!.id, // Exclude current item from position calculation
    );
    
    // Only trigger notification if explicitly requested and position changed
    if (!skipNotification && 
        _pickupState == PickupState.queued && 
        _queuePosition != _previousQueuePosition && 
        _queuePosition > 0 &&
        _previousQueuePosition > 0) { // Only notify if we had a previous position
      _handleStateChangeNotification();
    }
  }

  void _updatePickupState() {
    PickupState newState;
    
    if (_school == null) {
      newState = PickupState.pickupNotActive;
    } else if (!_school!.pickupActive) {
      if (_isInsideZone) {
        newState = PickupState.waitingInsideZoneInactive;
      } else {
        newState = PickupState.pickupNotActive;
      }
    } else if (_queueItem == null) {
      // If not in queue, show "approaching" when outside zone
      if (_isInsideZone) {
        newState = PickupState.waitingActiveNotQueued;
      } else {
        newState = PickupState.waitingActiveNotQueued;
      }
    } else {
      // In queue - show queue status
      switch (_queueItem!.status) {
        case QueueStatus.waiting:
          newState = PickupState.queued;
          break;
        case QueueStatus.ready:
          newState = PickupState.ready;
          break;
        case QueueStatus.pickedUp:
          newState = PickupState.pickedUp;
          break;
      }
    }

    // Check if state changed and trigger notifications
    if (newState != _pickupState) {
      _previousPickupState = _pickupState;
      _pickupState = newState;
      _handleStateChangeNotification();
    }
  }

  void _handleStateChangeNotification() {
    // Only show notifications for important state changes
    if (_previousPickupState == _pickupState) return;

    String title;
    String body;

    switch (_pickupState) {
      case PickupState.ready:
        title = '🎉 Ready for Pickup!';
        body = 'Your child is ready. Please proceed to the pickup area.';
        break;
      case PickupState.queued:
        // Only show notification when first joining queue (transitioning TO queued state)
        if (_previousPickupState != PickupState.queued) {
          // Ensure position is calculated before showing notification
          if (_queuePosition <= 0) {
            // Position not ready yet, skip notification - it will be handled by position update
            return;
          }
          title = '✅ Joined Queue';
          body = 'You\'re now in line. Position: #$_queuePosition';
        } else if (_queuePosition != _previousQueuePosition && 
                   _queuePosition > 0 && 
                   _previousQueuePosition > 0) {
          // Only notify for position changes if we already had a position
          title = '📍 Queue Update';
          body = 'Your position: #$_queuePosition';
        } else {
          return; // Don't notify for minor updates
        }
        break;
      case PickupState.pickedUp:
        title = '✅ Pickup Complete';
        body = 'Thank you for using LineMeUp!';
        break;
      default:
        return; // Don't notify for other states
    }

    // Show notification
    NotificationService().showStatusNotification(
      title: title,
      body: body,
    );
  }

  void _handlePickupStatusChange(bool isActive) {
    String title;
    String body;

    if (isActive) {
      title = '✅ Pickup Service Started';
      body = 'The pickup service is now active. You can join the queue when you arrive.';
    } else {
      title = '⏸️ Pickup Service Paused';
      body = 'The pickup service is temporarily inactive. Please wait for it to resume.';
    }

    // Show notification
    NotificationService().showStatusNotification(
      title: title,
      body: body,
    );
  }

  // Manual queue management methods
  Future<bool> joinQueue() async {
    if (!canJoinQueue || _parent == null || _school == null) {
      _errorMessage = 'Cannot join queue at this time';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        _errorMessage = 'Unable to get your location';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      List<String> studentIds = _selectedStudents.map((s) => s.id).toList();
      QueueItem? queueItem = await _firestoreService.createQueueItem(
        schoolId: _school!.id,
        parentId: _parent!.id,
        studentIds: studentIds,
        lat: position.latitude,
        lng: position.longitude,
      );

      _isLoading = false;

      if (queueItem != null) {
        _queueItem = queueItem;
        // Update position first, then state
        // This ensures position is set before notification is triggered
        await _updateQueuePosition(skipNotification: true);
        _updatePickupState(); // This will trigger notification with correct position
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to join queue';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error joining queue: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsPickedUp() async {
    if (!canMarkPickedUp || _queueItem == null) {
      _errorMessage = 'Cannot mark as picked up at this time';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.markAsPickedUp(_queueItem!.id);
      
      // Immediately update local state to reflect the change
      final updatedItem = QueueItem(
        id: _queueItem!.id,
        schoolId: _queueItem!.schoolId,
        parentId: _queueItem!.parentId,
        studentIds: _queueItem!.studentIds,
        arrivalTime: _queueItem!.arrivalTime,
        status: QueueStatus.pickedUp,
        location: _queueItem!.location,
      );
      
      _queueItem = updatedItem;
      _queuePosition = 0; // Reset queue position when picked up
      _isLoading = false;
      _updatePickupState();
      _errorMessage = null;
      
      // Force notify listeners to ensure UI updates
      notifyListeners();
      
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error marking as picked up: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> exitQueue() async {
    if (_queueItem == null) {
      return false;
    }

    try {
      await _firestoreService.deleteQueueItem(_queueItem!.id);
      _queueItem = null;
      _queuePosition = 0;
      _updatePickupState();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error exiting queue: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Cleanup method to stop tracking without disposing the provider
  // This should be called before sign out to prevent errors
  void cleanup() {
    if (_disposed) return;
    
    // Reset all state to prevent stale data in next session
    // Keep disposed flag false so provider can be reused
    _resetState(keepDisposed: false);
    
    // Don't call super.dispose() here - let Provider framework handle it
  }

  @override
  void dispose() {
    _disposed = true;
    _locationService.dispose();
    _schoolSubscription?.cancel();
    _queueSubscription?.cancel();
    _schoolSubscription = null;
    _queueSubscription = null;
    super.dispose();
  }
}


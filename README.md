# Parent Pickup Mobile App

A Flutter mobile application for parents to manage school pickup queue using Firebase and GPS tracking.

## Features

- **Phone Authentication**: SMS OTP-based authentication via Firebase
- **GPS Tracking**: Automatic detection when parent enters pickup zone
- **Queue Management**: Automatic queue joining based on arrival time
- **Real-time Updates**: Live status updates via Firestore
- **Push Notifications**: FCM notifications for pickup status changes

## Setup Instructions

### 1. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - Authentication (Phone Authentication)
   - Cloud Firestore
   - Cloud Messaging (FCM)

3. Add your app to Firebase:
   - **Android**: Download `google-services.json` and place it in `android/app/`
   - **iOS**: Download `GoogleService-Info.plist` and place it in `ios/Runner/`

4. Configure Firestore collections:
   - Create collections: `schools`, `parents`, `students`, `queueItems`
   - Set up security rules (see Firebase Security Rules section)

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Configuration Files

**Android**: Place `google-services.json` in `android/app/`

**iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`

### 4. Run the App

```bash
flutter run
```

## Firestore Collections Structure

### schools
```
{
  id: string,
  name: string,
  pickupLocation: { lat: number, lng: number },
  pickupRadius: number,
  pickupActive: boolean
}
```

### parents
```
{
  id: string,
  name: string,
  vehicleDescription: string,
  contactInfo: string (phone number)
}
```

### students
```
{
  id: string,
  name: string,
  schoolId: string,
  parentId: string
}
```

### queueItems
```
{
  id: string,
  schoolId: string,
  parentId: string,
  studentIds: string[],
  arrivalTime: Timestamp,
  status: "WAITING" | "READY" | "PICKED_UP",
  location?: { lat: number, lng: number }
}
```

## Firebase Security Rules (Example)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Parents can read their own data
    match /parents/{parentId} {
      allow read: if request.auth != null;
    }
    
    // Students can be read by authenticated users
    match /students/{studentId} {
      allow read: if request.auth != null;
    }
    
    // Schools can be read by authenticated users
    match /schools/{schoolId} {
      allow read: if request.auth != null;
    }
    
    // Queue items
    match /queueItems/{queueItemId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                       request.resource.data.parentId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.parentId == request.auth.uid;
    }
  }
}
```

## App Flow

1. **Splash Screen**: Checks authentication state
2. **Login Screen**: Phone number input and OTP verification
3. **Student Selection**: Select students for pickup
4. **Pickup Home**: Main screen showing real-time pickup status

## GPS & Pickup Zone

- App continuously monitors GPS location
- Automatically detects when parent enters pickup zone
- Creates queue item when inside zone and pickup is active
- Updates status based on Firestore changes
- Marks as picked up when parent leaves zone

## Permissions

- **Location**: Required for GPS tracking
- **Phone**: Required for SMS OTP authentication

## Notes

- Parents must be pre-registered in Firestore
- No signup flow in the app
- Queue position is calculated based on arrival time
- Status updates automatically via Firestore listeners

## Troubleshooting

1. **Firebase not initialized**: Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
2. **Location not working**: Check that location permissions are granted
3. **OTP not received**: Verify Firebase Phone Authentication is enabled and phone number format is correct (include country code)

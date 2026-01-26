# Setup Guide

## Prerequisites

1. Flutter SDK installed (3.10.4 or higher)
2. Firebase project created
3. Android Studio / Xcode for platform-specific setup

## Step-by-Step Setup

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use an existing one
3. Enable the following services:
   - **Authentication**: Enable Phone Authentication
   - **Cloud Firestore**: Create database (start in test mode, then add security rules)
   - **Cloud Messaging**: Enable FCM

### 2. Add Android App to Firebase

1. In Firebase Console, click "Add app" → Android
2. Register app with package name: `com.schoolpickup.parent_pickup`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### 3. Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Register app with bundle ID: `com.schoolpickup.parent_pickup`
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Firestore Security Rules

Update your Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /parents/{parentId} {
      allow read: if request.auth != null;
    }
    
    match /students/{studentId} {
      allow read: if request.auth != null;
    }
    
    match /schools/{schoolId} {
      allow read: if request.auth != null;
    }
    
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

### 6. Firestore Indexes

Create a composite index in Firestore:
- Collection: `queueItems`
- Fields: `schoolId` (Ascending), `parentId` (Ascending), `arrivalTime` (Ascending)

### 7. Test Data Setup

Add test data to Firestore:

**parents collection:**
```json
{
  "name": "John Doe",
  "vehicleDescription": "Blue Toyota Camry",
  "contactInfo": "+1234567890"
}
```

**schools collection:**
```json
{
  "name": "Example School",
  "pickupLocation": {
    "lat": 37.7749,
    "lng": -122.4194
  },
  "pickupRadius": 100,
  "pickupActive": true
}
```

**students collection:**
```json
{
  "name": "Jane Doe",
  "schoolId": "<school-id>",
  "parentId": "<parent-id>"
}
```

### 8. Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios
```

## Troubleshooting

### Firebase Not Initialized
- Ensure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in the correct location
- Run `flutter clean` and `flutter pub get`

### Location Permissions
- Android: Permissions are in `AndroidManifest.xml`
- iOS: Permissions are in `Info.plist`
- Test on a real device (location doesn't work well on emulators)

### OTP Not Received
- Verify phone number format includes country code (e.g., +1234567890)
- Check Firebase Authentication → Phone Authentication is enabled
- Verify phone number in Firestore `parents.contactInfo` matches exactly

### Build Errors
- Run `flutter clean`
- Delete `pubspec.lock` and run `flutter pub get`
- For iOS: `cd ios && pod install && cd ..`


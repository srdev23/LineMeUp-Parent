# Setup Guide

**📱 Platform-Specific Setup:**
- **Android:** Follow instructions below ⬇️
- **iOS:** See [IOS_SETUP.md](IOS_SETUP.md) for complete iOS setup (requires Mac) 🍎

---

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
2. Register app with package name: `com.linemeup.parent`
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### 3. Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Register app with bundle ID: `com.linemeup.parent`
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

### 9. Building APK for real devices

**Important:** Real phones use **ARM** (arm64-v8a / armeabi-v7a). Emulators often use **x86_64**. If you build while an emulator is selected or use `--target-platform android-x64`, the APK will only contain x86_64 and will **crash on real devices** with:

`Could not find 'libflutter.so'. Looked for: [arm64-v8a], but only found: [x86_64].`

**To build an APK that runs on real phones:**

```bash
# Option A: Fat APK (all architectures) – use for local install
flutter clean
flutter pub get
flutter build apk
# Install: build/app/outputs/flutter-apk/app-release.apk

# Option B: ARM-only APK (smaller, real devices only)
flutter build apk --target-platform android-arm64,android-arm
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Do **not** use `--target-platform android-x64` when building for phones.

## 🔔 Notification Setup & Testing

### Testing Notifications Work

After signing in, you should see a test notification: **"LineMeUp Notifications - Notifications are set up and ready!"**

If you don't see this, follow the troubleshooting steps below.

### Real Device vs Emulator Differences

**Emulators** are more lenient with FCM configuration.
**Real Android devices** require:
- Proper AndroidManifest.xml metadata ✅ (added)
- FCM token generation and storage ✅ (added)
- Battery optimization disabled (see below)
- Background app restrictions disabled (see below)

### Checking FCM Token in Logs

After sign-in, check the logs for:
```
🔑 FCM Token: [token prefix]...
✅ FCM token saved successfully for parent: [parentId]
```

If you see `⚠️ FCM token is null`, there's a Firebase configuration issue.

### Battery Optimization (Critical for Real Devices!)

Many Android manufacturers (Xiaomi, Huawei, OnePlus, Oppo, Vivo, Samsung) have **aggressive battery optimization** that kills FCM.

#### Disable Battery Optimization:

**Method 1: App Settings**
1. Open **Settings** → **Apps** → **LineMeUp**
2. Tap **Battery** or **Power usage**
3. Select **"No restrictions"** or **"Don't optimize"**
4. Enable **"Allow background activity"**

**Method 2: Developer Options** (if available)
1. Enable **Developer Options** (tap Build Number 7 times)
2. Go to **Settings** → **Developer Options**
3. Enable **"Stay awake when charging"** (for testing)
4. Disable **"Background check"**

#### Manufacturer-Specific Settings:

**Xiaomi/MIUI:**
- Settings → Apps → Manage apps → LineMeUp
- Enable **"Autostart"**
- Battery saver → **"No restrictions"**
- Other permissions → **"Display pop-up windows while running in background"**

**Huawei/EMUI:**
- Settings → Battery → App launch → LineMeUp
- Set to **"Manual"**
- Enable all three options: Auto-launch, Secondary launch, Run in background

**OnePlus/OxygenOS:**
- Settings → Battery → Battery optimization → LineMeUp
- Select **"Don't optimize"**

**Oppo/ColorOS:**
- Settings → Battery → Power saving → LineMeUp
- Disable **power saving**

**Samsung/One UI:**
- Settings → Apps → LineMeUp → Battery
- Select **"Unrestricted"**
- Settings → Battery → Background usage limits
- Remove LineMeUp from **"Sleeping apps"** and **"Deep sleeping apps"**

### Testing Notifications from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → **Cloud Messaging**
3. Click **"Send your first message"**
4. Fill in:
   - **Notification title:** "Test"
   - **Notification text:** "Testing notifications"
5. Click **Next** → **Select target:**
   - Choose **"User segment"** → **"All users"**
   - OR use **"Single device"** with the FCM token from logs
6. Click **Review** → **Publish**

You should receive the notification within seconds.

### Common Issues & Solutions

#### Issue: "No FCM token generated"
**Solution:**
- Verify `google-services.json` is in `android/app/`
- Rebuild: `flutter clean && flutter pub get && flutter run`

#### Issue: "Notifications work on emulator but not real device"
**Solution:**
- Check battery optimization settings (see above)
- Verify app has notification permission: Settings → Apps → LineMeUp → Notifications → **Enabled**
- Check network connectivity (FCM requires internet)

#### Issue: "FCM token saved but still no notifications"
**Solution:**
- Test from Firebase Console (see above)
- Check Firestore: parents collection → your document → verify `fcmToken` field exists
- Check logs for: `📨 Foreground message received` or `📨 Background message handler triggered`

#### Issue: "Notifications delayed by minutes/hours"
**Solution:**
- This is battery optimization! Follow manufacturer-specific settings above
- Enable **"High priority"** when sending from Firebase Console

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

### App crashes on real device: "Could not find libflutter.so" / "only found: [x86_64]"
- The APK was built for emulator (x86_64) only. Rebuild for real devices:
  - `flutter clean && flutter pub get && flutter build apk`
  - Or: `flutter build apk --target-platform android-arm64,android-arm`
- Then install the new APK on your phone (uninstall the old one first if needed).


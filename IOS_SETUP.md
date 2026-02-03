# iOS Setup Guide for LineMeUp

## 🚨 Important: You Need a Mac!

**iOS development requires:**
- A Mac computer (MacBook, iMac, Mac Mini, or Mac Studio)
- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later
- CocoaPods (iOS dependency manager)

**You CANNOT build iOS apps on Windows!** However, you can:
1. Transfer your project to a Mac
2. Use a cloud Mac service (MacStadium, AWS Mac instances)
3. Use a Mac in your organization

---

## Step-by-Step iOS Setup

### 1. Prerequisites on Mac

**Install Xcode:**
```bash
# From Mac App Store (free, ~12GB)
# Search for "Xcode" and install

# Or via command line (if you have Xcode Command Line Tools)
xcode-select --install
```

**Install CocoaPods:**
```bash
sudo gem install cocoapods
```

**Verify Flutter is set up for iOS:**
```bash
flutter doctor
```

You should see:
```
[✓] Xcode - develop for iOS and macOS
[✓] CocoaPods version X.X.X
```

---

### 2. Download GoogleService-Info.plist from Firebase

**On Firebase Console:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click ⚙️ **Settings** → **Project settings**
4. Scroll to **"Your apps"** section
5. Find your iOS app (or click **"Add app"** → iOS if you haven't added it yet)
6. Click **"Download GoogleService-Info.plist"**

**Adding iOS App to Firebase (if needed):**
1. Click **"Add app"** → iOS icon
2. **iOS bundle ID:** Must match your Xcode project (e.g., `com.yourcompany.linemeup`)
   - Find it in Xcode: Open project → Runner → General → Bundle Identifier
3. **App nickname:** "LineMeUp Parent App iOS" (optional)
4. **App Store ID:** Leave blank (for now)
5. Click **"Register app"**
6. Download **GoogleService-Info.plist**

---

### 3. Add GoogleService-Info.plist to iOS Project

**CRITICAL: File must be in the correct location!**

**Option A: Using Xcode (Recommended):**
1. Open project in Xcode:
   ```bash
   cd path/to/parent_app
   open ios/Runner.xcworkspace
   ```
   ⚠️ **Open `.xcworkspace`, NOT `.xcodeproj`!**

2. In Xcode, right-click **"Runner"** folder in left sidebar
3. Select **"Add Files to Runner..."**
4. Select the downloaded **GoogleService-Info.plist**
5. **IMPORTANT:** Check ✅ **"Copy items if needed"**
6. Click **"Add"**

**Option B: Manual Copy:**
```bash
# Copy the file to ios/Runner/ directory
cp ~/Downloads/GoogleService-Info.plist ios/Runner/

# Verify it's there
ls -la ios/Runner/GoogleService-Info.plist
```

Then add it in Xcode as described in Option A.

---

### 4. Install iOS Dependencies

**On your Mac, in the project directory:**

```bash
# Navigate to project
cd parent_app

# Get Flutter dependencies
flutter pub get

# Navigate to iOS folder
cd ios

# Install CocoaPods dependencies
pod install

# If you get errors, try:
pod repo update
pod install --repo-update

# Return to project root
cd ..
```

This will create:
- `ios/Podfile` (if it doesn't exist)
- `ios/Podfile.lock`
- `ios/Pods/` directory
- `ios/Runner.xcworkspace` (use this, not .xcodeproj!)

---

### 5. Configure Xcode Project Settings

**Open the workspace:**
```bash
open ios/Runner.xcworkspace
```

**In Xcode:**

**A. General Settings:**
1. Select **"Runner"** in left sidebar (blue icon)
2. Select **"Runner"** target (not project)
3. **General** tab:
   - **Display Name:** LineMeUp
   - **Bundle Identifier:** com.yourcompany.linemeup (use your domain)
   - **Version:** 1.0.0
   - **Build:** 1
   - **Deployment Target:** 13.0 or higher

**B. Signing & Capabilities:**
1. **Signing & Capabilities** tab
2. **Signing:**
   - ✅ **Automatically manage signing**
   - **Team:** Select your Apple Developer account
     - If no team: Click **"Add Account..."** → Sign in with Apple ID
     - For testing: Free Apple ID works for 7 days
     - For App Store: Need paid Apple Developer account ($99/year)

3. **Add Capabilities** (click **+ Capability**):
   - ✅ **Push Notifications** (for FCM)
   - ✅ **Background Modes** → Check:
     - ✅ Remote notifications
     - ✅ Background fetch
   - ✅ **Location** (if not already there)

**C. Minimum iOS Version:**
1. Select **Runner** target
2. **Build Settings** tab
3. Search for **"iOS Deployment Target"**
4. Set to **13.0** (minimum for Firebase)

---

### 6. Configure APNs (Apple Push Notification Service)

**For notifications to work on iOS, you MUST set up APNs in Firebase:**

**A. Create APNs Key (Recommended):**

1. Go to [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)
2. Click **"+"** to create a new key
3. **Key Name:** "LineMeUp APNs Key"
4. Check ✅ **"Apple Push Notifications service (APNs)"**
5. Click **"Continue"** → **"Register"**
6. **Download** the `.p8` key file (you can only download once!)
7. Note the **Key ID** and **Team ID**

**B. Upload APNs Key to Firebase:**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. **Settings** → **Cloud Messaging** tab
4. Scroll to **"Apple app configuration"**
5. Click **"Upload"** under **"APNs Authentication Key"**
6. Upload the `.p8` file
7. Enter **Key ID** and **Team ID**
8. Click **"Upload"**

✅ **Now iOS notifications will work!**

---

### 7. Build and Run

**On iOS Simulator:**
```bash
# List available simulators
flutter emulators

# Launch a simulator
flutter emulators --launch apple_ios_simulator

# Run the app
flutter run
```

**On Physical iPhone:**
1. Connect iPhone to Mac via USB
2. Trust the computer on iPhone (popup)
3. In Xcode: Window → Devices and Simulators → Verify device appears
4. Run:
   ```bash
   flutter devices  # Should show your iPhone
   flutter run      # Select your iPhone
   ```

5. **If "Untrusted Developer" error on iPhone:**
   - Settings → General → VPN & Device Management
   - Tap your Apple ID → **"Trust [Your Apple ID]"**

---

### 8. Testing on iOS

**Test Checklist:**

1. **Phone Authentication:**
   - Sign in with phone number
   - Should receive SMS code
   - Sign in should work

2. **Notifications:**
   - After sign-in, should see welcome notification
   - Test from Firebase Console:
     - Cloud Messaging → Send test message
     - Use FCM token from logs (iOS tokens are different from Android!)

3. **Location:**
   - App should request location permission
   - Location should update in pickup queue

4. **Background Notifications:**
   - Close app (swipe up)
   - Send notification from Firebase Console
   - Should appear on lock screen

---

## Common iOS Issues & Solutions

### "No such module 'Firebase'"
**Solution:**
```bash
cd ios
pod install
cd ..
flutter clean
flutter run
```

### "Command PhaseScriptExecution failed"
**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
cd ..
flutter clean
flutter run
```

### "Signing for Runner requires a development team"
**Solution:**
- Open Xcode → Runner target → Signing & Capabilities
- Select your Apple ID under "Team"
- Or add account: Xcode → Preferences → Accounts → "+"

### Notifications not working on iOS
**Checklist:**
1. ✅ APNs key uploaded to Firebase? (see Step 6)
2. ✅ Push Notifications capability enabled in Xcode?
3. ✅ Background Modes → Remote notifications enabled?
4. ✅ App has notification permission? (Should prompt on first launch)
5. ✅ FCM token generated? (Check logs: `🔑 FCM Token:`)
6. ✅ Device is not in Do Not Disturb mode?

### "GoogleService-Info.plist not found"
**Solution:**
- Verify file is in `ios/Runner/` directory
- In Xcode, check file is in "Runner" target (right sidebar)
- Clean and rebuild:
  ```bash
  flutter clean
  flutter run
  ```

### Different Bundle ID in Firebase and Xcode
**Solution:**
- They MUST match exactly!
- Check Firebase: Project Settings → iOS app → Bundle ID
- Check Xcode: Runner target → General → Bundle Identifier
- Update one to match the other, then re-download GoogleService-Info.plist

---

## iOS vs Android Differences

| Feature | Android | iOS |
|---------|---------|-----|
| **Build Platform** | Windows/Mac/Linux | **Mac ONLY** |
| **IDE** | Android Studio / VS Code | Xcode (required) |
| **Dependencies** | Gradle | CocoaPods |
| **Firebase Config** | google-services.json | GoogleService-Info.plist |
| **Push Notifications** | FCM only | FCM + APNs key required |
| **Permissions** | AndroidManifest.xml | Info.plist |
| **App Signing** | Keystore | Apple Developer account |
| **Testing Device** | Any Android device | iPhone/iPad only |
| **Free Testing** | Unlimited | 7 days (free Apple ID) |

---

## Quick Reference Commands

```bash
# Check Flutter iOS setup
flutter doctor -v

# Clean everything
flutter clean
cd ios && rm -rf Pods Podfile.lock && pod cache clean --all && cd ..

# Install pods
cd ios && pod install && cd ..

# Run on iOS simulator
flutter run

# Run on physical iPhone
flutter run -d [device-id]

# Build iOS app (release)
flutter build ios --release

# Open in Xcode
open ios/Runner.xcworkspace
```

---

## Next Steps After iOS Setup

1. ✅ Test phone authentication
2. ✅ Test notifications (foreground, background, killed app)
3. ✅ Test location tracking
4. ✅ Test sign-out and re-sign-in
5. ✅ Test all pickup flows (join queue, position updates, pickup complete)

---

## Deploying to App Store (Future)

**Requirements:**
- Paid Apple Developer account ($99/year)
- App screenshots and descriptions
- Privacy policy (required for location/notifications)
- Compliance with App Store guidelines

**Steps:**
1. Create app in [App Store Connect](https://appstoreconnect.apple.com)
2. Configure bundle ID, app name, descriptions
3. Build archive in Xcode: Product → Archive
4. Submit for review via App Store Connect
5. Wait for approval (usually 1-3 days)

---

## Getting Help

**iOS Build Issues:**
- Check `flutter doctor -v`
- Check Xcode build logs (⌘+9 in Xcode)
- Clean derived data: Xcode → Preferences → Locations → Derived Data → Delete

**Firebase Issues:**
- Verify GoogleService-Info.plist is correct
- Verify bundle ID matches Firebase
- Check Firebase Console → Cloud Messaging for errors

**Permission Issues:**
- Check Info.plist has all required keys
- Check app prompts for permissions
- Test permissions: Settings → LineMeUp on iPhone

---

Good luck with iOS testing! 🍎📱

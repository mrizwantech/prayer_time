# Firebase Setup Guide

## Google Services Configuration

### What is `google-services.json`?
- **Required file** for Firebase integration on Android
- Contains Firebase project credentials and API keys
- **NOT committed to version control** for security (added to `.gitignore`)

### Why Not in Git?
- Sensitive credentials inside
- Different Firebase projects for different environments (dev/prod)
- Prevents accidental exposure in public repositories

## Setup Instructions for New Developers

### Getting `google-services.json`

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **azanify-da213**
3. Click **Settings** ⚙️ → **Project settings**
4. Go to **Service accounts** tab
5. Click **"Download google-services.json"** button
6. Place the file at: `android/app/google-services.json`

### Verify Setup
```bash
# Check if the file exists
dir android\app\google-services.json
```

## For Release Build

✅ **Include** `google-services.json` when building APK/AAB:
```bash
flutter build apk --release
flutter build appbundle --release
```

- The file gets compiled into the final build
- End users won't see the raw JSON file
- Firebase services will work (Analytics, Crashlytics, AdMob, etc.)

## Firebase Project Details
- **Project ID**: azanify-da213
- **Package Name**: com.mrizwantech.azanify
- **Enabled Services**:
  - Firebase Analytics
  - Firebase Crashlytics
  - Google AdMob

## Important
⚠️ Never commit `google-services.json` to version control
✅ Each developer needs their own local copy
✅ The API key is Android-restricted (safe by design)

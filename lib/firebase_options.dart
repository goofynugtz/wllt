// Web Firebase configuration for Flutter Web builds.
//
// HOW TO POPULATE:
//   1. Go to Firebase Console → Project Settings → Your apps → Add app → Web
//   2. Copy the firebaseConfig values and paste them below.
//   OR run: dart pub global activate flutterfire_cli && flutterfire configure
//
// Android / iOS: these platforms read from google-services.json /
// GoogleService-Info.plist automatically — no changes needed there.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  // TODO: Replace placeholder values with your Firebase Web app's config.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: 'REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    authDomain: 'REPLACE_WITH_AUTH_DOMAIN',
    storageBucket: 'REPLACE_WITH_STORAGE_BUCKET',
  );
}

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
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCG1g_zRTon6FFCTclvlinzYl1irNsTH4',
    appId: '1:211606633990:web:0b1699e674c3f914f00d87',
    messagingSenderId: '211606633990',
    projectId: 'wllt-ac320',
    authDomain: 'wllt-ac320.firebaseapp.com',
    storageBucket: 'wllt-ac320.firebasestorage.app',
  );
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _auth;

  AuthService({
    GoogleSignIn? googleSignIn,
    FirebaseAuth? auth,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Signs in with Google OAuth then exchanges for a Firebase credential.
  /// Returns null if the user dismissed the account picker.
  /// Throws [FirebaseAuthException] on auth failure.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// Disconnects the current Google account and opens the account picker,
  /// allowing the user to choose a different Google account.
  Future<UserCredential?> switchAccount() async {
    await _googleSignIn.disconnect();
    return signInWithGoogle();
  }

  Future<void> signOut() => Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);

  User? get currentUser => _auth.currentUser;
}

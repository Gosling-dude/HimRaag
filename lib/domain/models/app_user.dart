import 'package:equatable/equatable.dart';

enum UserSignInMethod { google, guest }

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.signInMethod,
    this.displayName,
    this.email,
    this.photoUrl,
    this.preferredLanguage = 'hi',
    this.createdAt,
  });

  final String uid;
  final UserSignInMethod signInMethod;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String preferredLanguage;
  final DateTime? createdAt;

  bool get isGuest => signInMethod == UserSignInMethod.guest;

  String get displayLabel =>
      displayName ?? (isGuest ? 'Guest' : email ?? 'User');

  AppUser copyWith({
    String? uid,
    UserSignInMethod? signInMethod,
    String? displayName,
    String? email,
    String? photoUrl,
    String? preferredLanguage,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      signInMethod: signInMethod ?? this.signInMethod,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        signInMethod,
        displayName,
        email,
        photoUrl,
        preferredLanguage,
        createdAt,
      ];
}

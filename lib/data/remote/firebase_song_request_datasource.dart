import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';

/// A listener's request for a song the catalog doesn't have yet.
class SongRequest {
  SongRequest({
    required this.id,
    required this.songTitle,
    required this.userId,
    this.artist = '',
    this.link = '',
    this.details = '',
    this.searchQuery = '',
    this.userName = '',
    this.userEmail = '',
    this.status = SongRequest.statusNew,
    this.createdAt,
  });

  static const String statusNew = 'new';
  static const String statusAdded = 'added';
  static const String statusDismissed = 'dismissed';

  final String id;
  final String songTitle;
  final String artist;
  final String link;
  final String details;

  /// What the listener had typed into Search when they asked, if anything.
  final String searchQuery;
  final String userId;
  final String userName;
  final String userEmail;
  final String status;
  final DateTime? createdAt;
}

/// `songRequests` collection. Signed-in listeners create requests (security
/// rules pin `userId` to their uid and `status` to "new"); only admins read
/// them and change their status.
class FirebaseSongRequestDatasource {
  FirebaseSongRequestDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirebaseConstants.songRequestsCollection);

  Future<void> submit({
    required String songTitle,
    required String userId,
    String artist = '',
    String link = '',
    String details = '',
    String searchQuery = '',
    String userName = '',
    String userEmail = '',
  }) async {
    await _col.add({
      'songTitle': songTitle.trim(),
      'artist': artist.trim(),
      'link': link.trim(),
      'details': details.trim(),
      // Rules cap this at 200 chars; a long search must not fail the request.
      'searchQuery': _clip(searchQuery.trim(), 200),
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'status': SongRequest.statusNew,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Most recent requests first (admin only).
  Future<List<SongRequest>> recent({int limit = 200}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return SongRequest(
        id: doc.id,
        songTitle: d['songTitle'] as String? ?? '',
        artist: d['artist'] as String? ?? '',
        link: d['link'] as String? ?? '',
        details: d['details'] as String? ?? '',
        searchQuery: d['searchQuery'] as String? ?? '',
        userId: d['userId'] as String? ?? '',
        userName: d['userName'] as String? ?? '',
        userEmail: d['userEmail'] as String? ?? '',
        status: d['status'] as String? ?? SongRequest.statusNew,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  Future<void> setStatus(String id, String status) =>
      _col.doc(id).update({'status': status});
}

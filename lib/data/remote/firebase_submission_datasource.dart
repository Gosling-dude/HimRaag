import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/content_constants.dart';
import '../../domain/models/submission.dart';

/// Reads/writes the `submissions` collection — the artist-contributor upload
/// workflow. Security rules restrict creation to the submitter and status
/// changes to admins.
class FirebaseSubmissionDatasource {
  FirebaseSubmissionDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(ContentConstants.submissionsCollection);

  Submission _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Submission(
      id: doc.id,
      submittedBy: d['submittedBy'] as String? ?? '',
      artistName: d['artistName'] as String? ?? '',
      title: d['title'] as String? ?? '',
      region: d['region'] as String? ?? '',
      language: d['language'] as String? ?? '',
      genre: d['genre'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      albumTitle: d['albumTitle'] as String? ?? '',
      audioUrl: d['audioUrl'] as String? ?? '',
      artworkUrl: d['artworkUrl'] as String? ?? '',
      lyrics: d['lyrics'] as String? ?? '',
      license: d['license'] as String? ?? '',
      attribution: d['attribution'] as String? ?? '',
      rightsNote: d['rightsNote'] as String? ?? '',
      reviewerNote: d['reviewerNote'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// All submissions for a contributor (artist dashboard), newest first.
  Future<List<Submission>> getByOwner(String uid) async {
    final snap = await _col
        .where('submittedBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Submissions awaiting review (admin queue).
  Future<List<Submission>> getByStatus(String status) async {
    final snap = await _col
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Create a new pending submission. [submittedBy] must equal the caller's uid
  /// for the security rules to permit the write.
  Future<String> create({
    required String submittedBy,
    required String artistName,
    required String title,
    required String region,
    required String language,
    required String genre,
    String albumTitle = '',
    String audioUrl = '',
    String artworkUrl = '',
    String lyrics = '',
    String license = '',
    String attribution = '',
    String rightsNote = '',
  }) async {
    final ref = await _col.add({
      'submittedBy': submittedBy,
      'artistName': artistName,
      'title': title,
      'region': region,
      'language': language,
      'genre': genre,
      'status': 'pending',
      'albumTitle': albumTitle,
      'audioUrl': audioUrl,
      'artworkUrl': artworkUrl,
      'lyrics': lyrics,
      'license': license,
      'attribution': attribution,
      'rightsNote': rightsNote,
      'reviewerNote': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Admin decision on a submission.
  Future<void> setStatus(String id, String status, {String reviewerNote = ''}) {
    return _col.doc(id).update({
      'status': status,
      'reviewerNote': reviewerNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

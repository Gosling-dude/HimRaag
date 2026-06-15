import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/content_constants.dart';

/// A single audit-trail entry.
class AuditEntry {
  AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actor,
    this.detail = '',
    this.createdAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String actor;
  final String detail;
  final DateTime? createdAt;
}

/// Append-only moderation/audit log (`auditLogs` collection). Every admin
/// mutation (approve/reject/edit/delete/import) records an entry. Security
/// rules make these readable only by admins and never updatable/deletable.
class FirebaseAuditDatasource {
  FirebaseAuditDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(ContentConstants.auditLogsCollection);

  Future<void> log({
    required String action,
    required String entityType,
    required String entityId,
    required String actor,
    String detail = '',
  }) async {
    await _col.add({
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'actor': actor,
      'detail': detail,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Recent audit entries, newest first.
  Future<List<AuditEntry>> recent({int limit = 100}) async {
    final snap =
        await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return AuditEntry(
        id: doc.id,
        action: d['action'] as String? ?? '',
        entityType: d['entityType'] as String? ?? '',
        entityId: d['entityId'] as String? ?? '',
        actor: d['actor'] as String? ?? '',
        detail: d['detail'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }
}

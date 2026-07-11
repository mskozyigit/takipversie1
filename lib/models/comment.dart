import 'package:cloud_firestore/cloud_firestore.dart';

class JobComment {
  final String id;
  final String jobId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime timestamp;

  const JobComment({
    required this.id,
    required this.jobId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.timestamp,
  });

  factory JobComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobComment(
      id: doc.id,
      jobId: data['jobId'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String,
      text: data['text'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/job.dart';

// -----------------------------------------------------------------------
// Worker Analytics Data (hafif versiyon — sadece kendi işleri)
// -----------------------------------------------------------------------

class WorkerAnalyticsData {
  final int totalJobs;
  final int notStarted;
  final int inProgress;
  final int workCompleted;
  final int closed;
  final int completedThisMonth;
  final double totalFees;
  final double avgFeePerJob;

  const WorkerAnalyticsData({
    required this.totalJobs,
    required this.notStarted,
    required this.inProgress,
    required this.workCompleted,
    required this.closed,
    required this.completedThisMonth,
    required this.totalFees,
    required this.avgFeePerJob,
  });

  double get completionRate =>
      totalJobs == 0 ? 0 : ((workCompleted + closed) / totalJobs * 100);
}

/// Worker'ın kendi iş istatistiklerini getiren provider.
/// Admin Analytics'in hafif versiyonu — sadece atanmış işleri sayar.
final workerAnalyticsProvider = FutureProvider<WorkerAnalyticsData>((ref) async {
  final authState = ref.watch(authProvider).value;
  if (authState == null) {
    return const WorkerAnalyticsData(
      totalJobs: 0, notStarted: 0, inProgress: 0,
      workCompleted: 0, closed: 0, completedThisMonth: 0,
      totalFees: 0, avgFeePerJob: 0,
    );
  }

  final uid = authState.appUser!.id;
  final orgId = authState.appUser!.organizationId;
  final firestore = FirebaseFirestore.instance;

  // Son 90 gündeki işleri çek
  final ninetyDaysAgo =
      DateTime.now().subtract(const Duration(days: 90));

  final snapshot = await firestore
      .collection('jobs')
      .where('organizationId', isEqualTo: orgId)
      .where('assignedWorkerId', isEqualTo: uid)
      .where('scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(ninetyDaysAgo))
      .get();

  final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

  final totalJobs = jobs.length;
  final notStarted =
      jobs.where((j) => j.status == JobStatus.notStarted).length;
  final inProgress =
      jobs.where((j) => j.status == JobStatus.inProgress).length;
  final workCompleted =
      jobs.where((j) => j.status == JobStatus.workCompleted).length;
  final closed =
      jobs.where((j) => j.status == JobStatus.closed).length;

  final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final completedThisMonth = jobs
      .where((j) =>
          (j.status == JobStatus.closed ||
              j.status == JobStatus.workCompleted) &&
          j.createdDate.isAfter(monthStart))
      .length;

  final totalFees =
      jobs.where((j) => j.fee != null).fold<double>(0, (sum, j) => sum + (j.fee!.toDouble()));
  final completedJobs = workCompleted + closed;
  final avgFeePerJob = completedJobs == 0 ? 0.0 : totalFees / completedJobs;

  return WorkerAnalyticsData(
    totalJobs: totalJobs,
    notStarted: notStarted,
    inProgress: inProgress,
    workCompleted: workCompleted,
    closed: closed,
    completedThisMonth: completedThisMonth,
    totalFees: totalFees,
    avgFeePerJob: avgFeePerJob,
  );
});

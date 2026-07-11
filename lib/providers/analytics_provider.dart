import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/job.dart';

// -----------------------------------------------------------------------
// Analytics Data Models
// -----------------------------------------------------------------------

class WorkerStats {
  final String workerId;
  final String workerName;
  final int completedJobs;
  final int totalJobs;
  final double avgCompletionMinutes;
  final double totalFee;

  const WorkerStats({
    required this.workerId,
    required this.workerName,
    required this.completedJobs,
    required this.totalJobs,
    required this.avgCompletionMinutes,
    required this.totalFee,
  });
}

class AnalyticsData {
  final int totalJobs;
  final int notStarted;
  final int inProgress;
  final int workCompleted;
  final int closed;
  final int completedToday;
  final int completedThisWeek;
  final int completedThisMonth;
  final double avgTravelMinutes;
  final double totalFees;
  final List<WorkerStats> perWorker;

  const AnalyticsData({
    required this.totalJobs,
    required this.notStarted,
    required this.inProgress,
    required this.workCompleted,
    required this.closed,
    required this.completedToday,
    required this.completedThisWeek,
    required this.completedThisMonth,
    required this.avgTravelMinutes,
    required this.totalFees,
    required this.perWorker,
  });
}

// -----------------------------------------------------------------------
// Analytics Provider
// -----------------------------------------------------------------------

final analyticsProvider = FutureProvider<AnalyticsData>((ref) async {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) {
    return const AnalyticsData(
      totalJobs: 0, notStarted: 0, inProgress: 0,
      workCompleted: 0, closed: 0, completedToday: 0,
      completedThisWeek: 0, completedThisMonth: 0,
      avgTravelMinutes: 0, totalFees: 0, perWorker: [],
    );
  }

  final orgId = authState.appUser.organizationId;
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();

  // Fetch all jobs for this organization (not just this month)
  final snapshot = await firestore
      .collection('jobs')
      .where('organizationId', isEqualTo: orgId)
      .get();

  final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

  // Compute stats
  final totalJobs = jobs.length;
  final notStarted = jobs.where((j) => j.status == JobStatus.notStarted).length;
  final inProgress = jobs.where((j) => j.status == JobStatus.inProgress).length;
  final workCompleted = jobs.where((j) => j.status == JobStatus.workCompleted).length;
  final closed = jobs.where((j) => j.status == JobStatus.closed).length;

  final todayStart = DateTime(now.year, now.month, now.day);
  final completedToday = jobs.where((j) =>
    j.status == JobStatus.closed && j.createdDate.isAfter(todayStart)).length;

  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final completedThisWeek = jobs.where((j) =>
    j.status == JobStatus.closed && j.createdDate.isAfter(weekStart)).length;

  final monthStart = DateTime(now.year, now.month, 1);
  final completedThisMonth = jobs.where((j) =>
    j.status == JobStatus.closed && j.createdDate.isAfter(monthStart)).length;

  // Average travel time
  final jobsWithTravel = jobs.where((j) => j.estimatedTravelTime != null).toList();
  final avgTravelMinutes = jobsWithTravel.isEmpty
      ? 0.0
      : jobsWithTravel.map((j) => j.estimatedTravelTime!.inMinutes.toDouble())
          .reduce((a, b) => a + b) / jobsWithTravel.length;

  // Total fees
  final totalFees = jobs.where((j) => j.fee != null).fold<double>(
      0, (sum, j) => sum + (j.fee ?? 0));

  // Per-worker stats
  final workerMap = <String, List<Job>>{};
  for (var job in jobs) {
    workerMap.putIfAbsent(job.assignedWorkerId, () => []);
    workerMap[job.assignedWorkerId]!.add(job);
  }

  final perWorker = workerMap.entries.map((entry) {
    final wJobs = entry.value;
    final done = wJobs.where((j) =>
      j.status == JobStatus.closed || j.status == JobStatus.workCompleted).toList();
    final completedCount = done.length;
    final totalCount = wJobs.length;
    final avgMin = done.isEmpty ? 0.0 : done.length * 30.0; // rough estimate
    final fee = wJobs.where((j) => j.fee != null).fold<double>(
        0, (sum, j) => sum + (j.fee ?? 0));
    return WorkerStats(
      workerId: entry.key,
      workerName: wJobs.first.assignedWorkerName,
      completedJobs: completedCount,
      totalJobs: totalCount,
      avgCompletionMinutes: avgMin,
      totalFee: fee,
    );
  }).toList();

  return AnalyticsData(
    totalJobs: totalJobs,
    notStarted: notStarted,
    inProgress: inProgress,
    workCompleted: workCompleted,
    closed: closed,
    completedToday: completedToday,
    completedThisWeek: completedThisWeek,
    completedThisMonth: completedThisMonth,
    avgTravelMinutes: avgTravelMinutes,
    totalFees: totalFees,
    perWorker: perWorker,
  );
});

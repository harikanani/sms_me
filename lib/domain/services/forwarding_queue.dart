import '../../data/local/app_database.dart';
import '../entities/forwarding_job.dart';

class ForwardingQueue {
  final AppDatabase _db;

  ForwardingQueue(this._db);

  Future<void> addJob(ForwardingJob job) async {
    await _db.saveJob(job);
  }

  Future<void> updateJobStatus(
    String jobId,
    ForwardingJobStatus status, {
    String? errorMessage,
  }) async {
    await _db.updateJobStatus(
      jobId,
      status,
      errorMessage: errorMessage,
      processedAt: DateTime.now(),
    );
  }

  Future<List<ForwardingJob>> getPendingJobs() async {
    return await _db.getPendingJobs();
  }

  Future<List<ForwardingJob>> getHistory() async {
    return await _db.getAllJobs();
  }
}

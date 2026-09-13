import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/entities/forwarding_job.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forwarding History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyListProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No forwarding history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _buildHistoryTile(context, job);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading history: $err')),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, ForwardingJob job) {
    final timeStr = _formatTime(job.createdAt);
    final statusWidget = _buildStatusWidget(job.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.sms.sender,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  job.matchedRuleName ?? (job.status == ForwardingJobStatus.ignored ? 'Ignored' : 'No rule matched'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          statusWidget,
        ],
      ),
    );
  }

  Widget _buildStatusWidget(ForwardingJobStatus status) {
    switch (status) {
      case ForwardingJobStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case ForwardingJobStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 22);
      case ForwardingJobStatus.ignored:
        return Icon(Icons.remove_circle_outline, color: Colors.grey[400], size: 22);
      case ForwardingJobStatus.duplicate:
        return const Icon(Icons.copy, color: Colors.amber, size: 22);
      case ForwardingJobStatus.pending:
      case ForwardingJobStatus.processing:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }

  static String _formatTime(DateTime dt) {
    final hourInt = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }
}

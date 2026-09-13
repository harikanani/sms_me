import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/forwarding_job.dart';

class AppDatabase {
  static const String _dbName = 'sms_forwarder.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // Fingerprints table for duplicate detection
        await db.execute('''
          CREATE TABLE fingerprints (
            fingerprint TEXT PRIMARY KEY,
            created_at TEXT NOT NULL
          )
        ''');

        // Forwarding jobs & history table
        await db.execute('''
          CREATE TABLE forwarding_jobs (
            id TEXT PRIMARY KEY,
            sms_id TEXT NOT NULL,
            sender TEXT NOT NULL,
            body TEXT NOT NULL,
            received_at TEXT NOT NULL,
            subscription_id INTEGER,
            status TEXT NOT NULL,
            matched_rule_name TEXT,
            error_message TEXT,
            created_at TEXT NOT NULL,
            processed_at TEXT
          )
        ''');
      },
    );
  }

  // --- Fingerprints ---
  Future<bool> isDuplicateFingerprint(String fingerprint) async {
    final db = await database;
    final res = await db.query(
      'fingerprints',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> saveFingerprint(String fingerprint) async {
    final db = await database;
    await db.insert(
      'fingerprints',
      {
        'fingerprint': fingerprint,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _cleanupOldFingerprints(db);
  }

  Future<void> _cleanupOldFingerprints(Database db) async {
    // Keep max 10,000 most recent fingerprints
    await db.execute('''
      DELETE FROM fingerprints 
      WHERE fingerprint NOT IN (
        SELECT fingerprint FROM fingerprints ORDER BY created_at DESC LIMIT 10000
      )
    ''');
  }

  // --- Forwarding Jobs ---
  Future<void> saveJob(ForwardingJob job) async {
    final db = await database;
    await db.insert(
      'forwarding_jobs',
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateJobStatus(
    String jobId,
    ForwardingJobStatus status, {
    String? errorMessage,
    DateTime? processedAt,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'status': status.name,
      'processed_at': (processedAt ?? DateTime.now()).toIso8601String(),
    };
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }
    await db.update(
      'forwarding_jobs',
      updates,
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<List<ForwardingJob>> getAllJobs({int limit = 100}) async {
    final db = await database;
    final res = await db.query(
      'forwarding_jobs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return res.map((map) => ForwardingJob.fromMap(map)).toList();
  }

  Future<List<ForwardingJob>> getPendingJobs() async {
    final db = await database;
    final res = await db.query(
      'forwarding_jobs',
      where: 'status = ?',
      whereArgs: [ForwardingJobStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return res.map((map) => ForwardingJob.fromMap(map)).toList();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';
import '../models/result_meme.dart';
import 'service_locator.dart';

/// The score band a result page's picture comes from (owner, 2026-09-28).
enum MemeBucket {
  under30('lt30'),
  from30('30-59'),
  from60('60-89'),
  passed('90-100'),

  /// Экзамен only: the timer ran out and the pass mark was not reached.
  outOfTime('out-of-time');

  const MemeBucket(this.id);

  /// The value in `result_memes.bucket` and the Storage folder name.
  final String id;
}

/// Chooses the light "meme" picture shown on the three result pages.
///
/// The pictures are the DriveUSA "Beep" set (design/memes/own), stored under
/// `result_memes/<bucket>/` in Storage and listed in the `result_memes`
/// collection. Anything that goes wrong — offline, an empty collection, a
/// missing file — returns null, and the page shows its bundled
/// success/fail picture instead.
class ResultMemeService {
  ResultMemeService({
    Future<List<ResultMeme>> Function(String bucket)? loadBucket,
    Future<String?> Function(String storagePath)? resolveUrl,
    Future<SharedPreferences> Function()? prefs,
    Random? random,
  })  : _loadBucket = loadBucket ?? _firestoreBucket,
        _resolveUrl = resolveUrl ?? _storageUrl,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _random = random ?? Random();

  static final ResultMemeService instance = ResultMemeService();

  final Future<List<ResultMeme>> Function(String bucket) _loadBucket;
  final Future<String?> Function(String storagePath) _resolveUrl;
  final Future<SharedPreferences> Function() _prefs;
  final Random _random;
  final Map<String, List<ResultMeme>> _cache = {};

  static const Duration _timeout = Duration(seconds: 6);

  /// The bucket for a finished run.
  ///
  /// A pass always gets a win picture, even when the Экзамен timer ran out on
  /// the last question (owner). Below the pass mark the score decides, except
  /// that an Экзамен that ran out of time gets the "out of time" set. A score
  /// of 90 % or more without a pass (not reachable with today's pass rules)
  /// stays in 60–89 so a "not passed" verdict never shows a win picture.
  static MemeBucket bucketFor({
    required int percent,
    required bool passed,
    bool outOfTime = false,
  }) {
    if (passed) return MemeBucket.passed;
    if (outOfTime) return MemeBucket.outOfTime;
    if (percent < 30) return MemeBucket.under30;
    if (percent < 60) return MemeBucket.from30;
    return MemeBucket.from60;
  }

  /// True when the Экзамен timer, not the learner, ended the run: the exam
  /// has a time limit and was completed at or after its end time
  /// (ExamProvider completes it when the limit passes). Практика runs on the
  /// same model with a limit of 0 and is never out of time.
  static bool ranOutOfTime(Exam exam) =>
      exam.timeLimit > 0 &&
      exam.completedAt != null &&
      !exam.completedAt!.isBefore(exam.endTime);

  /// Whole percent, rounded down, so 89.9 % stays below the 90 edge.
  static int percentOf(int correct, int total) =>
      total <= 0 ? 0 : (correct * 100) ~/ total;

  /// A download URL for one active picture in [bucket], not the one shown
  /// last time for that bucket when there is a choice; null when none can
  /// be had.
  Future<String?> pickUrl(MemeBucket bucket) async {
    try {
      final memes = _cache[bucket.id] ??
          (await _loadBucket(bucket.id).timeout(_timeout))
              .where((m) => m.active && m.storagePath.isNotEmpty)
              .toList();
      // An empty answer (say, offline with nothing cached) is not kept, so
      // the next result page asks again.
      if (memes.isEmpty) return null;
      _cache[bucket.id] = memes;

      final prefs = await _prefs();
      final lastKey = 'result_meme_last_${bucket.id}';
      final last = prefs.getString(lastKey);
      final choices =
          memes.length > 1 ? memes.where((m) => m.id != last).toList() : memes;
      final meme = choices[_random.nextInt(choices.length)];

      final url = await _resolveUrl(meme.storagePath).timeout(_timeout);
      if (url == null) return null;
      await prefs.setString(lastKey, meme.id);
      return url;
    } catch (_) {
      return null;
    }
  }

  static Future<List<ResultMeme>> _firestoreBucket(String bucket) async {
    final snap = await FirebaseFirestore.instance
        .collection('result_memes')
        .where('bucket', isEqualTo: bucket)
        .where('active', isEqualTo: true)
        .get();
    return snap.docs.map((d) => ResultMeme.fromMap(d.id, d.data())).toList();
  }

  static Future<String?> _storageUrl(String path) async {
    final result = await serviceLocator.storage.getDownloadURL(path);
    return result.isSuccess ? result.url : null;
  }
}

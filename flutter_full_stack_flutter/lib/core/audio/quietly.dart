import 'package:flutter/foundation.dart';

/// Runs [action] and, if it fails, notes it in the log and returns `null`.
///
/// Everything practice plays goes through this: a sound, a reading, a
/// playback is never worth stopping the learner for, and a phone that
/// cannot play one must still let them practise. [doing] says what was
/// being tried, for whoever reads the log.
Future<T?> quietly<T>(String doing, Future<T> Function() action) async {
  try {
    return await action();
  } on Object catch (error) {
    debugPrint('Could not $doing: $error');
    return null;
  }
}

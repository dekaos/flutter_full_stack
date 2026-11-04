import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file in this folder.
///
/// `rootBundle` caches the *future* of every asset it loads, and a widget
/// test creates those futures on its own fake clock. A later test that loads
/// the same asset - a lexicon, say - is handed that future, and waits on a
/// clock nobody advances any more: forever. It shows up far from its cause,
/// as a test that hangs, or a card that never fills, or a route whose
/// redirect never answers. Clearing the cache after every test makes each
/// one load its own.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  tearDown(rootBundle.clear);
  await testMain();
}

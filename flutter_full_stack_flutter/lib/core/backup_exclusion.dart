import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps a file out of the device's backups.
///
/// For what can be fetched again - a 355 MB language pack - and should
/// therefore not fill the learner's iCloud nor get the app rejected under
/// Apple's data storage guidelines, which is where
/// `getApplicationSupportDirectory` puts it otherwise.
///
/// iOS is the only platform that needs a call. Android excludes the same
/// folder declaratively, in `res/xml/data_extraction_rules.xml` and
/// `res/xml/backup_rules.xml`, because there it has to be decided before the
/// app runs: a backup can start while the app is not running at all.
class BackupExclusion {
  const BackupExclusion();

  static const _channel = MethodChannel(
    'br.com.stuhler.flutter_full_stack/backup',
  );

  /// Marks [path] - a file or a folder, whose contents it then covers - as
  /// not to be backed up. Idempotent.
  Future<void> exclude(String path) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('exclude', path);
  }
}

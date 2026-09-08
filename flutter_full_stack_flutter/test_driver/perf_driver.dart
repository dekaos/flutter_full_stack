import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes what `integration_test/perf_test.dart` measured to a file.
///
/// `flutter test integration_test` cannot do this: the timeline summary lives
/// in the binding's `reportData` on the device, and only the driver protocol
/// carries it back to the host. That is the whole reason this suite runs
/// through `flutter drive` while the behavioural e2e does not.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) {
      stderr.writeln('perf: the test reported no data');
      exit(1);
    }
    final file = File('build/perf_report.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    stdout.writeln('perf: wrote ${file.path}');
  },
);

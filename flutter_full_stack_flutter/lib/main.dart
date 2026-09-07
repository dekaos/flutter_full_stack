import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inter ships in assets/fonts/, so nothing should reach the network for a
  // typeface. With this off, a weight that is not bundled throws instead of
  // being downloaded quietly - which is the point: the failure is visible in
  // development rather than in a first run on a bad connection.
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const ProviderScope(child: App()));
}

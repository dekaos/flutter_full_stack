import 'package:flutter_full_stack_flutter/features/greetings/presentation/greetings_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/language_screen.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/practice_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// The language a practice route falls back to when the path is malformed.
const defaultPracticeLanguage = 'en';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // The app opens on the chooser. Which language you are practising
      // decides the prompts and which pack has to be on the device, so it is
      // the first question, not a setting buried behind practice.
      GoRoute(
        path: '/',
        name: 'languages',
        builder: (context, state) => const LanguageScreen(),
        routes: [
          // Practice is a *child* of the chooser, and that is what makes Back
          // work. As siblings, `go` replaces the stack and leaves nothing to
          // pop; `push` would fix the tap but not a link straight to
          // /practice/es, which would still open with no way back. Nesting
          // makes go_router build the whole stack either way, so the back
          // arrow is there even on a cold deep link.
          //
          // The language is in the path because a practice session is *of* a
          // language: it decides which lexicon is loaded and which 355 MB
          // pack has to be on the device.
          GoRoute(
            path: 'practice/:lang',
            name: 'practice',
            builder: (context, state) => PracticeScreen(
              lang: state.pathParameters['lang'] ?? defaultPracticeLanguage,
            ),
          ),
        ],
      ),
      // The Serverpod demo, no longer the landing screen but kept reachable:
      // it is what the end-to-end suite drives, and the only flow that
      // exercises the generated client against a live server.
      GoRoute(
        path: '/greetings',
        name: 'greetings',
        builder: (context, state) => const GreetingsScreen(),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';

/// The gradient a screen sits on.
///
/// This is not decoration: `GlassSurface` blurs whatever is behind it, so a
/// flat background makes glass look like flat translucent paint. The backdrop
/// is what gives it something to refract, which is why it lives in the design
/// system and reads its colours from [AppTokens].
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).appTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.backdropTop, tokens.backdropBottom],
        ),
      ),
      child: child,
    );
  }
}

import 'dart:async';

import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_pack.g.dart';

/// Kept alive because the downloads it runs must outlive the screen that
/// started them.
@Riverpod(keepAlive: true)
ModelStore modelStore(Ref ref) {
  final store = ModelStore();
  ref.onDispose(store.dispose);
  return store;
}

/// Whether [lang]'s pack is on the device, which is what practice needs to
/// open at all.
Future<bool> packOnDevice(ModelStore store, String lang) async {
  final lexicon = await Lexicon.load(lang);
  return await store.isDownloaded(lexicon.model);
}

/// Where one language's pack is.
sealed class LanguagePack {
  const LanguagePack();
}

/// On the device: practice can open.
final class PackReady extends LanguagePack {
  const PackReady();
}

/// On its way down.
final class PackDownloading extends LanguagePack {
  const PackDownloading([this.progress]);

  /// Null only until the store first says where the download is.
  final DownloadProgress? progress;
}

/// Not on the device, and not on its way.
final class PackMissing extends LanguagePack {
  const PackMissing({this.failure});

  /// Why the last try did not land, if one was made. What the learner is
  /// told, and what a tap tries again: a dropped download picks up where
  /// it stopped, and a damaged one starts afresh.
  final Object? failure;
}

/// One language's pack, as the chooser shows it - and the download that
/// brings it, which starts there.
///
/// The download itself is the store's, not this controller's: it outlives
/// the controller, and a controller built while one is running follows it
/// instead of offering it again.
@riverpod
class LanguagePackController extends _$LanguagePackController {
  late Lexicon _lexicon;

  @override
  Future<LanguagePack> build(String lang) async {
    final store = ref.watch(modelStoreProvider);
    final lexicon = await Lexicon.load(lang);
    _lexicon = lexicon;
    // A pack that lands or leaves by any other way still shows here.
    final changes = store.changes
        .where((name) => name == lexicon.model)
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(changes.cancel);

    if (store.isDownloading(lexicon.model)) {
      unawaited(_rejoin(store, lexicon));
      return PackDownloading(store.progressOf(lexicon.model));
    }
    return await store.isDownloaded(lexicon.model)
        ? const PackReady()
        : const PackMissing();
  }

  /// Downloads the pack - or joins the download already running - and says
  /// whether it landed.
  ///
  /// A failure is not thrown: it is what the card shows, and a tap on the
  /// card is the retry.
  Future<bool> download() async {
    // Asked before build has finished: it is build that knows the pack.
    if (!state.hasValue) await future;
    final store = ref.read(modelStoreProvider);
    state = AsyncData(PackDownloading(store.progressOf(_lexicon.model)));
    return await _follow(store, _lexicon);
  }

  Future<void> _rejoin(ModelStore store, Lexicon lexicon) async {
    // Waits for build to hand over the state this reports into.
    await future;
    await _follow(store, lexicon);
  }

  Future<bool> _follow(ModelStore store, Lexicon lexicon) async {
    try {
      await store.ensure(
        lexicon.model,
        sha256: lexicon.modelSha256,
        onProgress: (progress) {
          // Called for as long as the download runs, which can be long
          // after this controller is gone.
          if (ref.mounted) state = AsyncData(PackDownloading(progress));
        },
      );
    } on Object catch (error) {
      if (ref.mounted) state = AsyncData(PackMissing(failure: error));
      return false;
    }
    if (ref.mounted) state = const AsyncData(PackReady());
    return true;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licences Flutter does not collect on its own to the licences page.
///
/// Flutter gathers the `LICENSE` of every Dart package. It knows nothing of
/// what reaches the app some other way: the acoustic models, downloaded at
/// run time; ONNX Runtime, pulled in natively by `flutter_onnxruntime`; and
/// Inter, bundled as font files. See docs/pronunciation-models.md.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const [
        'wav2vec2-lv-60-espeak-cv-ft',
        'wav2vec2-xlsr-53-espeak-cv-ft',
      ],
      '$modelModificationNotice\n\n'
      '${await rootBundle.loadString('assets/licenses/apache-2.0.txt')}',
    );
    yield LicenseEntryWithLineBreaks(
      const ['ONNX Runtime'],
      await rootBundle.loadString('assets/licenses/onnxruntime.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Inter'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });
}

/// Apache-2.0 section 4(b): a modified file carries a notice saying so. The
/// language packs are not the upstream weights, so this says what changed.
@visibleForTesting
const modelModificationNotice =
    'The pronunciation language packs are derived from '
    'facebook/wav2vec2-lv-60-espeak-cv-ft (English) and '
    'facebook/wav2vec2-xlsr-53-espeak-cv-ft (Spanish), published on Hugging '
    'Face under the Apache License 2.0. They were modified: the weight norm '
    'of the '
    'positional convolution was folded into its weight, the model was '
    'exported to ONNX, and its matrix multiplications were quantised to '
    'int8.';

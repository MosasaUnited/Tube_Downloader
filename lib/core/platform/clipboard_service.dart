import 'package:flutter/services.dart';

/// Reads plain text from the system clipboard. A class (not a bare static
/// call) so cubits can be tested with a fake.
///
/// iOS shows a "pasted from…" banner on every read, so automatic reads are
/// off by default there (Settings › Clipboard Auto-Detection); the Paste
/// button always works.
class ClipboardService {
  Future<String?> readText() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

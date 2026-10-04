import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_file_extractor.dart';

void main() {
  test('a .txt list is returned as is, without a BOM', () {
    expect(
      LinkFileExtractor.extract(
        'links.TXT',
        '\uFEFFhttps://youtu.be/R6MlUcmOul8\nhttps://youtu.be/aqz-KE-bpKQ\n',
      ),
      'https://youtu.be/R6MlUcmOul8\nhttps://youtu.be/aqz-KE-bpKQ',
    );
  });

  test('a macOS .webloc gives its URL, with &amp; unescaped', () {
    const plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>URL</key>
  <string>https://www.youtube.com/watch?v=R6MlUcmOul8&amp;list=PLabcdefghij12</string>
</dict></plist>''';
    expect(
      LinkFileExtractor.extract('Tears of Steel.webloc', plist),
      'https://www.youtube.com/watch?v=R6MlUcmOul8&list=PLabcdefghij12',
    );
  });

  test('a binary .webloc falls back to the first URL in it', () {
    expect(
      LinkFileExtractor.extract(
        'clip.webloc',
        'bplist00\u0001\u0002_\u0010https://youtu.be/R6MlUcmOul8\u0008\u000b',
      ),
      'https://youtu.be/R6MlUcmOul8',
    );
  });

  test('a Windows .url shortcut gives its URL= line (CRLF)', () {
    expect(
      LinkFileExtractor.extract(
        'clip.url',
        '[InternetShortcut]\r\nURL=https://youtu.be/R6MlUcmOul8\r\nIconIndex=0\r\n',
      ),
      'https://youtu.be/R6MlUcmOul8',
    );
  });

  test('other files, and files without links, give nothing', () {
    expect(LinkFileExtractor.supports('movie.mp4'), isFalse);
    expect(LinkFileExtractor.supports('README'), isFalse);
    expect(LinkFileExtractor.extract('movie.mp4', 'https://x.y'), isNull);
    expect(LinkFileExtractor.extract('empty.txt', ' \n '), isNull);
    expect(
      LinkFileExtractor.extract('broken.url', '[InternetShortcut]'),
      isNull,
    );
  });
}

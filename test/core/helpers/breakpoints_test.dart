import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';

void main() {
  test('window classes by width (Material breakpoints)', () {
    expect(windowClassForWidth(390), WindowClass.compact);
    expect(windowClassForWidth(599.9), WindowClass.compact);
    expect(windowClassForWidth(600), WindowClass.medium);
    expect(windowClassForWidth(1023.9), WindowClass.medium);
    expect(windowClassForWidth(1024), WindowClass.expanded);
  });

  test('a short, wide desktop window is expanded, not a phone', () {
    // shortestSide would call 1200×500 a phone; width-based classes do not.
    expect(windowClassForWidth(1200), WindowClass.expanded);
  });
}

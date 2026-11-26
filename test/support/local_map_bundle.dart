import 'dart:io';

import 'package:flutter/services.dart';

/// Real bundled polygons with deterministic I/O under the widget-test fake clock.
/// Parsing, geographic paths, painting and hit tests use the production code.
class LocalMapBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

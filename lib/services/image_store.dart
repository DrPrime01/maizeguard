import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the on-device copies of captured leaf images.
///
/// `image_picker` writes to a cache directory the OS may clear at will, so
/// every accepted capture is copied into the app documents directory before
/// its path is recorded in the database.
class ImageStore {
  const ImageStore();

  static const String _folder = 'scan_images';

  Future<Directory> _directory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies [source] into permanent storage, named by the scan id.
  Future<File> persist(File source, String scanId) async {
    final dir = await _directory();
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final target = File(p.join(dir.path, '$scanId$extension'));
    return source.copy(target.path);
  }

  Future<void> deleteFor(String imagePath) async {
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

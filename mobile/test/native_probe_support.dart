import 'dart:io';

/// Probe projects need independent native output directories: the parent has
/// SQLite loaded. Seed only the immutable download cache, whose content hash is
/// checked again by sqlite3's build hook, so a crash test needs no new download.
void seedProbeNativeCache(Directory probe) {
  const relativeCache = '.dart_tool/hooks_runner/shared/sqlite3/build';
  final cache = Directory(relativeCache);
  if (!cache.existsSync()) return;
  for (final source in cache.listSync(recursive: true).whereType<File>()) {
    final name = source.path.toLowerCase();
    if (!name.endsWith('.dll') &&
        !name.endsWith('.so') &&
        !name.endsWith('.dylib')) {
      continue;
    }
    final relative = source.path.substring(cache.path.length);
    final target = File('${probe.path}/$relativeCache$relative');
    target.parent.createSync(recursive: true);
    source.copySync(target.path);
  }
}

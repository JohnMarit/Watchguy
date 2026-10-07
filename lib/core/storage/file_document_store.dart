import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'document_store.dart';

class FileDocumentStore implements DocumentStore {
  FileDocumentStore(this.root);

  final Directory root;
  final Map<String, StreamController<List<Map<String, dynamic>>>> _watches = {};

  File _file(String path) => File('${root.path}/$path.json');

  @override
  Future<void> delete(String path) async {
    final file = _file(path);
    if (file.existsSync()) file.deleteSync();
    _emit(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(String prefix) async {
    final directory = Directory('${root.path}/$prefix');
    if (!directory.existsSync()) return [];
    final docs = <Map<String, dynamic>>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      docs.add(jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>);
    }
    return docs;
  }

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    final file = _file(path);
    if (!file.existsSync()) return null;
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  @override
  Stream<List<Map<String, dynamic>>> watch(String prefix) {
    final controller = _watches.putIfAbsent(
      prefix,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );
    scheduleMicrotask(() async {
      if (!controller.isClosed) controller.add(await list(prefix));
    });
    return controller.stream;
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) async {
    final file = _file(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
    _emit(path);
  }

  void _emit(String path) {
    for (final entry in _watches.entries) {
      if (path.startsWith(entry.key)) {
        list(entry.key).then((docs) {
          if (!entry.value.isClosed) entry.value.add(docs);
        });
      }
    }
  }
}

import 'dart:async';

abstract class DocumentStore {
  Future<Map<String, dynamic>?> read(String path);
  Future<void> write(String path, Map<String, dynamic> data);
  Future<void> delete(String path);
  Future<List<Map<String, dynamic>>> list(String prefix);
  Stream<List<Map<String, dynamic>>> watch(String prefix);
}

class MemoryDocumentStore implements DocumentStore {
  final Map<String, Map<String, dynamic>> _docs = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> _watches = {};

  @override
  Future<void> delete(String path) async {
    _docs.remove(path);
    _emitFor(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(String prefix) async {
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return _docs.entries
        .where((entry) => entry.key.startsWith(normalized) && !entry.key.substring(normalized.length).contains('/'))
        .map((entry) => entry.value)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> read(String path) async => _docs[path];

  @override
  Stream<List<Map<String, dynamic>>> watch(String prefix) {
    final controller = _watches.putIfAbsent(prefix, () {
      final created = StreamController<List<Map<String, dynamic>>>.broadcast();
      return created;
    });
    scheduleMicrotask(() async {
      if (!controller.isClosed) controller.add(await list(prefix));
    });
    return controller.stream;
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) async {
    _docs[path] = data;
    _emitFor(path);
  }

  void _emitFor(String path) {
    for (final entry in _watches.entries) {
      final prefix = entry.key.endsWith('/') ? entry.key : '${entry.key}/';
      if (path.startsWith(prefix)) {
        list(entry.key).then((docs) {
          if (!entry.value.isClosed) entry.value.add(docs);
        });
      }
    }
  }
}

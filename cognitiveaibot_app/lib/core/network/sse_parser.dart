import 'dart:convert';

/// Turns a `text/event-stream` body into the JSON objects carried by its
/// `data:` lines, one per event, in order.
///
/// Handles events split across network chunks (including a multi-byte
/// character split between two chunks), `\r\n` line endings, multi-line
/// `data:` fields, comments (`: keep-alive`) and a final `[DONE]` marker.
/// An event whose data isn't a JSON object is skipped.
Stream<Map<String, dynamic>> parseSseJson(Stream<List<int>> bytes) async* {
  var buffer = '';
  await for (final text in bytes.cast<List<int>>().transform(utf8.decoder)) {
    buffer += text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var end = buffer.indexOf('\n\n');
    while (end != -1) {
      final block = buffer.substring(0, end);
      buffer = buffer.substring(end + 2);
      final event = _decode(block);
      if (event != null) yield event;
      end = buffer.indexOf('\n\n');
    }
  }
  // A last event without its blank line still counts once the stream ends.
  final event = _decode(buffer);
  if (event != null) yield event;
}

Map<String, dynamic>? _decode(String block) {
  final data = <String>[];
  for (final line in block.split('\n')) {
    if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
  if (data.isEmpty) return null;
  final payload = data.join('\n').trim();
  if (payload.isEmpty || payload == '[DONE]') return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

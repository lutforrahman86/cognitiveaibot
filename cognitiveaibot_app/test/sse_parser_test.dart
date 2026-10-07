import 'dart:convert';

import 'package:cognitiveaibot/core/network/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> chunks(List<String> parts) => Stream.fromIterable(parts.map(utf8.encode));

void main() {
  test('parses one JSON object per event', () async {
    final events = await parseSseJson(chunks([
      'data: {"type":"start"}\n\n',
      'data: {"type":"delta","text":"Hi"}\n\ndata: {"type":"done"}\n\n',
    ])).toList();
    expect(events.map((e) => e['type']), ['start', 'delta', 'done']);
    expect(events[1]['text'], 'Hi');
  });

  test('joins an event split across chunks, including a split multi-byte character', () async {
    final bytes = utf8.encode('data: {"type":"delta","text":"héllo ✓"}\n\n');
    final split = bytes.indexOf(0xC3) + 1; // inside "é"
    final events = await parseSseJson(Stream.fromIterable([bytes.sublist(0, split), bytes.sublist(split)])).toList();
    expect(events.single['text'], 'héllo ✓');
  });

  test(r'handles \r\n, comments, [DONE], bad JSON and a final event without a blank line', () async {
    final events = await parseSseJson(chunks([
      ': keep-alive\r\n\r\n',
      'data: not json\r\n\r\n',
      'data: {"n":1}\r\n\r\n',
      'data: [DONE]\n\n',
      'data: {"n":2}',
    ])).toList();
    expect(events.map((e) => e['n']), [1, 2]);
  });

  test('joins multi-line data fields', () async {
    final events = await parseSseJson(chunks(['data: {"a":\ndata: 1}\n\n'])).toList();
    expect(events.single['a'], 1);
  });
}

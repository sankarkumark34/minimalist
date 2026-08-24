import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist/src/models.dart';

void main() {
  test('SessionRecord round-trips through map', () {
    final record = SessionRecord(
      start: DateTime.fromMillisecondsSinceEpoch(1724500000000),
      durationMinutes: 25,
      blockedCount: 3,
      completed: true,
    );
    final restored = SessionRecord.fromMap(record.toMap());
    expect(restored.start, record.start);
    expect(restored.durationMinutes, 25);
    expect(restored.blockedCount, 3);
    expect(restored.completed, true);
  });
}

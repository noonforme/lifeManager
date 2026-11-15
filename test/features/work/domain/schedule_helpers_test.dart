import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

ShiftType _type(String id, String name) => ShiftType(
  id: ShiftTypeId(id),
  name: name,
  start: const LocalTime(7, 0),
  end: const LocalTime(19, 0),
  endDayOffset: 0,
);

void main() {
  test('letters use the first letter when it is unique', () {
    expect(typeLetters([_type('a', 'Day'), _type('b', 'night')]), {
      const ShiftTypeId('a'): 'D',
      const ShiftTypeId('b'): 'N',
    });
  });

  test('letters use two letters when initials clash, at most two '
      'characters', () {
    expect(
      typeLetters([_type('a', 'Day'), _type('b', 'Night'), _type('c', 'Ward')]),
      {
        const ShiftTypeId('a'): 'D',
        const ShiftTypeId('b'): 'N',
        const ShiftTypeId('c'): 'W',
      },
    );
    expect(typeLetters([_type('a', 'Night'), _type('b', 'Noon')]), {
      const ShiftTypeId('a'): 'NI',
      const ShiftTypeId('b'): 'NO',
    });
    // The first letter of the last word, then a number.
    expect(typeLetters([_type('a', 'Day 1'), _type('b', 'Day 2')]), {
      const ShiftTypeId('a'): 'D1',
      const ShiftTypeId('b'): 'D2',
    });
    expect(typeLetters([_type('a', 'Day'), _type('b', 'Day long')]), {
      const ShiftTypeId('a'): 'D1',
      const ShiftTypeId('b'): 'DL',
    });
    expect(typeLetters([_type('a', 'Day'), _type('b', 'Dawn')]), {
      const ShiftTypeId('a'): 'D1',
      const ShiftTypeId('b'): 'D2',
    });
    for (final letters in typeLetters([
      _type('a', 'Day'),
      _type('b', 'Day long'),
      _type('c', 'Dawn'),
      _type('d', 'Day 2'),
    ]).values) {
      expect(letters.length, lessThanOrEqualTo(2), reason: letters);
    }
  });

  test('nextShiftTypeId skips taken ids', () {
    expect(
      nextShiftTypeId([_type('type-1', 'Day'), _type('type-2', 'Night')]),
      const ShiftTypeId('type-3'),
    );
    expect(nextShiftTypeId(const []), const ShiftTypeId('type-1'));
  });
}

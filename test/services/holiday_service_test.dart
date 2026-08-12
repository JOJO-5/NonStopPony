import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/services/holiday_service.dart';

void main() {
  group('parseDateKey', () {
    test('横线格式 01-01', () {
      expect(HolidayService.parseDateKey('01-01', 2026), DateTime(2026, 1, 1));
    });
    test('点格式 1.1（无前导零）', () {
      expect(HolidayService.parseDateKey('1.1', 2026), DateTime(2026, 1, 1));
    });
    test('点格式 10.1', () {
      expect(HolidayService.parseDateKey('10.1', 2026), DateTime(2026, 10, 1));
    });
    test('非法格式抛 FormatException', () {
      expect(() => HolidayService.parseDateKey('abc', 2026),
          throwsFormatException);
    });
  });
}

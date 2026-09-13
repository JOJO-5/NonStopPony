import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alarm_clock/services/holiday_service.dart';

void main() {
  late Database db;
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await HolidayService.createTable(db);
    HolidayService.setDatabase(db);
  });
  tearDown(() => db.close());

  group('parseDateKey', () {
    test('rejects dates that would silently roll into another month', () {
      expect(() => HolidayService.parseDateKey('02-30', 2026), throwsFormatException);
      expect(() => HolidayService.parseDateKey('13-01', 2026), throwsFormatException);
    });
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
      expect(
        () => HolidayService.parseDateKey('abc', 2026),
        throwsFormatException,
      );
    });
  });

  group('syncYear', () {
    const valid = '{"code":0,"holiday":{"01-01":{"holiday":true,"name":"元旦"}}}';

    test('uses annual endpoint and only notifies after committed data is readable', () async {
      var notifications = 0;
      void changed() { notifications++; }
      HolidayService.changes.addListener(changed);
      addTearDown(() => HolidayService.changes.removeListener(changed));
      final result = await HolidayService.syncYear(2027, fetchBody: (uri) async {
        expect(uri.path, '/api/holiday/year/2027/');
        return valid;
      });
      expect(result.source, HolidayDataSource.network);
      expect(notifications, 1);
      expect(await HolidayService.isHoliday(DateTime(2027, 1, 1)), isTrue);
      await HolidayService.syncYear(2027, fetchBody: (_) async => '<html>blocked</html>');
      expect(notifications, 1);
      expect(await HolidayService.isHoliday(DateTime(2027, 1, 1)), isTrue);
    });

    test('uses bundled 2026 snapshot when network fails', () async {
      final result = await HolidayService.syncYear(
        2026,
        fetchBody: (_) async => throw StateError('offline'),
      );
      expect(result.source, HolidayDataSource.bundled);
      expect(result.count, 39);
      expect(await HolidayService.isHoliday(DateTime(2026, 10, 1)), isTrue);
    });

    test(
      'prefers existing cache after network failure and preserves it',
      () async {
        final first = await HolidayService.syncYear(
          2027,
          fetchBody: (_) async => valid,
        );
        expect(first.source, HolidayDataSource.network);
        final result = await HolidayService.syncYear(
          2027,
          fetchBody: (_) async => throw StateError('offline'),
        );
        expect(result.source, HolidayDataSource.cache);
        expect(result.count, 1);
        expect((await HolidayService.getYearHolidays(2027)).single.name, '元旦');
      },
    );

    test('reports unavailable for empty future year', () async {
      final result = await HolidayService.syncYear(
        2027,
        fetchBody: (_) async => '{"code":0,"holiday":{}}',
      );
      expect(result.source, HolidayDataSource.unavailable);
      expect(result.count, 0);
      expect(await HolidayService.getYearHolidays(2027), isEmpty);
    });

    test('invalid response cannot partially write entries', () async {
      final result = await HolidayService.syncYear(
        2027,
        fetchBody: (_) async =>
            '{"code":0,"holiday":{"01-01":{"holiday":true},"bad":{"holiday":false}}}',
      );
      expect(result.source, HolidayDataSource.unavailable);
      expect(await HolidayService.getYearHolidays(2027), isEmpty);
    });
  });
}

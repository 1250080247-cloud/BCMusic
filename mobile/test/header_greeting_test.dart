import 'package:flutter_test/flutter_test.dart';
import 'package:bcmusic/app_shell.dart';

void main() {
  group('Header greeting real-time tests', () {
    test('getGreetingTimeOfDay partitions 24 hours into morning, noon, afternoon, evening', () {
      // Sáng (05:00 - 10:59)
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 5, 0)), 'Chào buổi sáng');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 8, 30)), 'Chào buổi sáng');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 10, 59)), 'Chào buổi sáng');

      // Trưa (11:00 - 12:59)
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 11, 0)), 'Chào buổi trưa');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 12, 0)), 'Chào buổi trưa');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 12, 59)), 'Chào buổi trưa');

      // Chiều (13:00 - 17:59)
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 13, 0)), 'Chào buổi chiều');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 15, 45)), 'Chào buổi chiều');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 17, 59)), 'Chào buổi chiều');

      // Tối & Đêm (18:00 - 04:59)
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 18, 0)), 'Chào buổi tối');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 21, 15)), 'Chào buổi tối');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 23, 59)), 'Chào buổi tối');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 0, 0)), 'Chào buổi tối');
      expect(getGreetingTimeOfDay(DateTime(2026, 11, 10, 4, 59)), 'Chào buổi tối');
    });

    test('getHeaderGreeting combines real-time greeting with user display name', () {
      final morning = DateTime(2026, 11, 10, 8, 0);
      final noon = DateTime(2026, 11, 10, 12, 0);
      final afternoon = DateTime(2026, 11, 10, 16, 0);
      final evening = DateTime(2026, 11, 10, 20, 0);

      // Default name: Người nghe nhạc
      expect(getHeaderGreeting('Người nghe nhạc', morning), 'Chào buổi sáng, Người nghe nhạc');
      expect(getHeaderGreeting('Người nghe nhạc', noon), 'Chào buổi trưa, Người nghe nhạc');
      expect(getHeaderGreeting('Người nghe nhạc', afternoon), 'Chào buổi chiều, Người nghe nhạc');
      expect(getHeaderGreeting('Người nghe nhạc', evening), 'Chào buổi tối, Người nghe nhạc');

      // Custom account name
      expect(getHeaderGreeting('Bảo Châu', morning), 'Chào buổi sáng, Bảo Châu');
      expect(getHeaderGreeting('Minh', evening), 'Chào buổi tối, Minh');

      // Null or empty falls back to Người nghe nhạc
      expect(getHeaderGreeting(null, morning), 'Chào buổi sáng, Người nghe nhạc');
      expect(getHeaderGreeting('   ', evening), 'Chào buổi tối, Người nghe nhạc');
    });
  });
}

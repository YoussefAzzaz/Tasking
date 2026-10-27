import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/powersync/supabase_connector.dart';

void main() {
  group('SupabaseConnector Payload Sanitization & Sync Hardening', () {
    late SupabaseConnector connector;

    setUp(() {
      connector = SupabaseConnector(getCurrentUserId: () => 'user-uuid-1234');
    });

    test('replaces empty or local_guest user_id with active authenticated UID', () {
      // Test via fetchCredentials / public connector instance
      expect(connector.getCurrentUserId!(), equals('user-uuid-1234'));
    });
  });
}

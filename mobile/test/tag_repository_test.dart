import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/core/cache/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagRepository Tests', () {
    setUp(() {
      CacheService().clear();
    });

    tearDown(() {
      CacheService().clear();
    });

    test('TagRepository does not contain any predefined tags by default', () async {
      final tags = await TagRepository().getTags(forceRefresh: true);
      expect(tags, isEmpty);
      expect(tags.contains('urgent'), isFalse);
      expect(tags.contains('deepwork'), isFalse);
      expect(tags.contains('meeting'), isFalse);
      expect(tags.contains('review'), isFalse);
      expect(tags.contains('errand'), isFalse);
      expect(tags.contains('backend'), isFalse);
      expect(tags.contains('frontend'), isFalse);
    });

    test('Cache can hold user created tags and be invalidated on deleteTag', () async {
      final cache = CacheService();
      cache.set<List<String>>('task_tags_list', ['alpha', 'beta']);

      var tags = await TagRepository().getTags();
      expect(tags, equals(['alpha', 'beta']));

      await TagRepository().deleteTag('alpha');
      expect(cache.get<List<String>>('task_tags_list'), isNull);
    });

    test('addTag invalidates cached tags list', () async {
      final cache = CacheService();
      cache.set<List<String>>('task_tags_list', ['alpha']);

      await TagRepository().addTag('gamma');
      expect(cache.get<List<String>>('task_tags_list'), isNull);
    });
  });
}

import 'package:deep_thought_injector/deep_thought_injector.dart';
import 'package:test/test.dart';

// Dummy service for testing.
class TestService {
  TestService(this.value);
  final int value;
}

void main() {
  group('DeepThought', () {
    test('can be instantiated', () {
      expect(DeepThought(), isNotNull);
    });

    test('can register and retrieve a lazily instantiated service', () {
      final deepThought = DeepThought();

      var counter = 0;
      // The factory increments the counter when called.
      TestService factory() {
        counter++;
        return TestService(100);
      }

      deepThought.ponder<TestService>(factory);
      // At this point, factory should not have been called.
      expect(counter, equals(0));

      final service = deepThought.question<TestService>();
      expect(service.value, equals(100));
      // Factory should be called exactly once.
      expect(counter, equals(1));
    });

    test('can register and retrieve a non-lazy instantiated service', () {
      final deepThought = DeepThought();

      var counter = 0;
      TestService factory() {
        counter++;
        return TestService(200);
      }

      deepThought.ponder<TestService>(factory, lazy: false);
      // Non-lazy should instantiate immediately.
      expect(counter, equals(1));

      final service = deepThought.question<TestService>();
      expect(service.value, equals(200));
      // No additional call to the factory.
      expect(counter, equals(1));
    });

    test('throws exception when retrieving an unregistered service', () {
      final deepThought = DeepThought();
      expect(
        () => deepThought.question<TestService>(),
        throwsA(isA<VogonPoetryException>()),
      );
    });

    test('throws exception on duplicate registration', () {
      final deepThought = DeepThought()
        ..ponder<TestService>(() => TestService(300));
      expect(
        () => deepThought.ponder<TestService>(() => TestService(400)),
        throwsA(isA<VogonPoetryException>()),
      );
    });

    test('transient lifecycle returns a new service each time', () {
      final deepThought = DeepThought();
      var counter = 0;
      TestService factory() {
        counter++;
        return TestService(500);
      }

      deepThought.ponder<TestService>(factory, lifecycle: Lifecycle.transient);
      final service1 = deepThought.question<TestService>();
      final service2 = deepThought.question<TestService>();
      expect(service1.value, equals(500));
      expect(service2.value, equals(500));
      // Each call creates a new instance, so counter should be 2.
      expect(counter, equals(2));
    });
  });
}

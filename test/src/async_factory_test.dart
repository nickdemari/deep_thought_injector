import 'package:deep_thought_injector/deep_thought_injector.dart';
import 'package:test/test.dart';

// Dummy service for async initialization.
class AsyncService {
  AsyncService(this.value);
  final int value;
}

void main() {
  test('async factory returns a new service', () async {
    final deepThought = DeepThought();
    var counter = 0;

    Future<AsyncService> asyncFactory() async {
      counter++;
      return AsyncService(42);
    }

    await deepThought.ponderAsync<AsyncService>(asyncFactory);
    final service = await deepThought.questionAsync<AsyncService>();
    expect(service.value, equals(42));
    expect(counter, equals(1));
  });
}

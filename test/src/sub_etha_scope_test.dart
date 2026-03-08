import 'package:deep_thought_injector/deep_thought_injector.dart';
import 'package:test/test.dart';

void main() {
  group('SubEthaScope', () {
    group('async singleton race condition', () {
      test(
          'two concurrent locateAsync calls return identical instance '
          'and factory is invoked exactly once', () async {
        final scope = SubEthaScope();
        var counter = 0;

        await scope.registerAsync<String>(
          () async {
            counter++;
            return Future.delayed(
              const Duration(milliseconds: 50),
              () => 'answer-$counter',
            );
          },
        );

        final results = await Future.wait([
          scope.locateAsync<String>(),
          scope.locateAsync<String>(),
        ]);

        expect(results[0], same(results[1]));
        expect(counter, equals(1));
      });

      test(
          'three concurrent locateAsync calls all return the same instance '
          'and factory is called once', () async {
        final scope = SubEthaScope();
        var counter = 0;

        await scope.registerAsync<String>(
          () async {
            counter++;
            return Future.delayed(
              const Duration(milliseconds: 50),
              () => 'hitchhiker-$counter',
            );
          },
        );

        final results = await Future.wait([
          scope.locateAsync<String>(),
          scope.locateAsync<String>(),
          scope.locateAsync<String>(),
        ]);

        expect(results[0], same(results[1]));
        expect(results[1], same(results[2]));
        expect(counter, equals(1));
      });

      test(
          'async factory that throws propagates error to all concurrent '
          'waiters and allows retry on subsequent call', () async {
        final scope = SubEthaScope();
        var callCount = 0;

        await scope.registerAsync<String>(
          () async {
            callCount++;
            return Future.delayed(
              const Duration(milliseconds: 50),
              () {
                if (callCount == 1) {
                  throw const VogonPoetryException(
                    'Resistance is useless!',
                  );
                }
                return 'recovered-$callCount';
              },
            );
          },
        );

        // Both concurrent calls should receive the error.
        final futures = [
          scope.locateAsync<String>(),
          scope.locateAsync<String>(),
        ];

        expect(
          futures[0],
          throwsA(isA<VogonPoetryException>()),
        );
        expect(
          futures[1],
          throwsA(isA<VogonPoetryException>()),
        );

        // Subsequent call should retry and succeed.
        final retried = await scope.locateAsync<String>();
        expect(retried, equals('recovered-2'));
      });

      test(
          'already-resolved async singleton returns cached instance '
          'without re-invoking factory', () async {
        final scope = SubEthaScope();
        var counter = 0;

        await scope.registerAsync<String>(
          () async {
            counter++;
            return Future.delayed(
              const Duration(milliseconds: 50),
              () => 'cached-$counter',
            );
          },
        );

        // First resolution.
        final first = await scope.locateAsync<String>();
        expect(first, equals('cached-1'));

        // Second resolution should return cached instance.
        final second = await scope.locateAsync<String>();
        expect(second, same(first));
        expect(counter, equals(1));
      });

      test(
          'transient async services create a new instance per call '
          'with no Completer interference', () async {
        final scope = SubEthaScope();
        var counter = 0;

        await scope.registerAsync<String>(
          () async {
            counter++;
            return Future.delayed(
              const Duration(milliseconds: 50),
              () => 'transient-$counter',
            );
          },
          lifecycle: Lifecycle.transient,
        );

        final first = await scope.locateAsync<String>();
        final second = await scope.locateAsync<String>();

        expect(first, isNot(same(second)));
        expect(first, equals('transient-1'));
        expect(second, equals('transient-2'));
        expect(counter, equals(2));
      });
    });
  });
}

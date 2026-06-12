import 'package:deep_thought_injector/deep_thought_injector.dart';
import 'package:test/test.dart';

// Helper classes for circular dependency tests.
class ServiceA {
  ServiceA(this.dependency);
  final dynamic dependency;
}

class ServiceB {
  ServiceB(this.dependency);
  final dynamic dependency;
}

class ServiceC {
  ServiceC([this.dependency]);
  final dynamic dependency;
}

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

        await expectLater(
          futures[0],
          throwsA(isA<VogonPoetryException>()),
        );
        await expectLater(
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

    group('circular dependency detection', () {
      test(
          'direct circular dependency (A -> B -> A) throws '
          'VogonPoetryException with chain in message', () {
        final scope = SubEthaScope();

        scope.register<ServiceA>(
          () => ServiceA(scope.locate<ServiceB>()),
        );
        scope.register<ServiceB>(
          () => ServiceB(scope.locate<ServiceA>()),
        );

        expect(
          () => scope.locate<ServiceA>(),
          throwsA(
            isA<VogonPoetryException>().having(
              (e) => e.cause,
              'cause',
              allOf(
                contains('Circular dependency detected'),
                contains('ServiceA'),
                contains('ServiceB'),
              ),
            ),
          ),
        );
      });

      test(
          'transitive circular dependency (A -> B -> C -> A) throws '
          'VogonPoetryException with full chain', () {
        final scope = SubEthaScope();

        scope.register<ServiceA>(
          () => ServiceA(scope.locate<ServiceB>()),
        );
        scope.register<ServiceB>(
          () => ServiceB(scope.locate<ServiceC>()),
        );
        scope.register<ServiceC>(
          () => ServiceC(scope.locate<ServiceA>()),
        );

        expect(
          () => scope.locate<ServiceA>(),
          throwsA(
            isA<VogonPoetryException>().having(
              (e) => e.cause,
              'cause',
              allOf(
                contains('Circular dependency detected'),
                contains('ServiceA'),
                contains('ServiceB'),
                contains('ServiceC'),
              ),
            ),
          ),
        );
      });

      test(
          'non-circular linear chain (A -> B -> C) resolves '
          'successfully without false positives', () {
        final scope = SubEthaScope();

        scope.register<ServiceC>(ServiceC.new);
        scope.register<ServiceB>(
          () => ServiceB(scope.locate<ServiceC>()),
        );
        scope.register<ServiceA>(
          () => ServiceA(scope.locate<ServiceB>()),
        );

        final result = scope.locate<ServiceA>();
        expect(result, isA<ServiceA>());
        expect(result.dependency, isA<ServiceB>());
        expect(
          (result.dependency as ServiceB).dependency,
          isA<ServiceC>(),
        );
      });

      test(
          'cross-scope circular dependency is detected '
          'when child and parent form a cycle', () {
        final parent = SubEthaScope();
        final child = parent.createChildScope();

        // Parent's ServiceB depends on ServiceA (resolved from child).
        parent.register<ServiceB>(
          () => ServiceB(parent.locate<ServiceA>()),
        );

        // Child's ServiceA depends on ServiceB (resolved from parent).
        child.register<ServiceA>(
          () => ServiceA(child.locate<ServiceB>()),
        );

        expect(
          () => child.locate<ServiceA>(),
          throwsA(
            isA<VogonPoetryException>().having(
              (e) => e.cause,
              'cause',
              contains('Circular dependency detected'),
            ),
          ),
        );
      });

      test(
          'named services of the same type that depend on each other '
          'are detected as circular', () {
        final scope = SubEthaScope();

        scope.register<String>(
          () => scope.locate<String>(name: 'beta'),
          name: 'alpha',
        );
        scope.register<String>(
          () => scope.locate<String>(name: 'alpha'),
          name: 'beta',
        );

        expect(
          () => scope.locate<String>(name: 'alpha'),
          throwsA(
            isA<VogonPoetryException>().having(
              (e) => e.cause,
              'cause',
              contains('Circular dependency detected'),
            ),
          ),
        );

        // Non-circular named services should resolve fine.
        final scope2 = SubEthaScope();
        scope2.register<String>(() => 'hello', name: 'first');
        scope2.register<String>(() => 'world', name: 'second');

        expect(scope2.locate<String>(name: 'first'), equals('hello'));
        expect(scope2.locate<String>(name: 'second'), equals('world'));
      });

      test(
          'async circular dependency (A -> B -> A) throws '
          'VogonPoetryException with chain in message', () async {
        final scope = SubEthaScope();

        await scope.registerAsync<ServiceA>(
          () async => ServiceA(await scope.locateAsync<ServiceB>()),
        );
        await scope.registerAsync<ServiceB>(
          () async => ServiceB(await scope.locateAsync<ServiceA>()),
        );

        await expectLater(
          scope.locateAsync<ServiceA>(),
          throwsA(
            isA<VogonPoetryException>().having(
              (e) => e.cause,
              'cause',
              allOf(
                contains('Circular dependency detected'),
                contains('ServiceA'),
                contains('ServiceB'),
              ),
            ),
          ),
        );
      });
    });
  });
}

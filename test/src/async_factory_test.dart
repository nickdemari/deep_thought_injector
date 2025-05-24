import 'package:deep_thought_injector/service_injector.dart';
import 'package:test/test.dart';

// Dummy service for async initialization.
class AsyncService {
  AsyncService(this.value, {this.id = 'default'});
  final int value;
  final String id;
}

class DisposableAsyncService implements Disposable {
  DisposableAsyncService(this.id);
  final String id;
  bool isDisposed = false;
  static int factoryCallCount = 0;

  static Future<DisposableAsyncService> create(String id) async {
    factoryCallCount++;
    await Future.delayed(Duration.zero); // Simulate async work
    return DisposableAsyncService(id);
  }

  @override
  void dispose() {
    isDisposed = true;
    // print('DisposableAsyncService $id disposed');
  }
}


void main() {
  late ServiceInjector injector;

  setUp(() {
    injector = ServiceInjector();
    DisposableAsyncService.factoryCallCount = 0; // Reset static counter
  });

  tearDown(() {
    try {
      injector.dispose();
    } catch (_) {
      // Ignore
    }
  });

  group('Async Factory Registrations', () {
    test('lazy singleton async factory', () async {
      var factoryCallCount = 0;
      Future<AsyncService> asyncFactory() async {
        factoryCallCount++;
        await Future.delayed(Duration.zero);
        return AsyncService(42);
      }

      injector.registerAsync<AsyncService>(asyncFactory, lifecycle: Lifecycle.singleton); // lazy is default
      expect(factoryCallCount, 0);

      final service1 = await injector.getAsync<AsyncService>();
      expect(service1.value, 42);
      expect(factoryCallCount, 1);

      final service2 = await injector.getAsync<AsyncService>();
      expect(identical(service1, service2), isTrue);
      expect(factoryCallCount, 1); // Not called again
    });

    test('eager singleton async factory', () async {
      var factoryCallCount = 0;
      Future<AsyncService> asyncFactory() async {
        factoryCallCount++;
        await Future.delayed(Duration.zero);
        return AsyncService(43);
      }

      await injector.registerAsync<AsyncService>(asyncFactory, lifecycle: Lifecycle.singleton, lazy: false);
      expect(factoryCallCount, 1); // Called immediately

      final service = await injector.getAsync<AsyncService>();
      expect(service.value, 43);
      expect(factoryCallCount, 1); // Not called again
    });

    test('transient async factory', () async {
      var factoryCallCount = 0;
      Future<AsyncService> asyncFactory() async {
        factoryCallCount++;
        await Future.delayed(Duration.zero);
        return AsyncService(44);
      }

      injector.registerAsync<AsyncService>(asyncFactory, lifecycle: Lifecycle.transient);
      
      final service1 = await injector.getAsync<AsyncService>();
      expect(service1.value, 44);
      expect(factoryCallCount, 1);

      final service2 = await injector.getAsync<AsyncService>();
      expect(service2.value, 44);
      expect(factoryCallCount, 2); // Called again
      expect(identical(service1, service2), isFalse);
    });

    test('scoped async factory', () async {
      injector.registerAsync<DisposableAsyncService>(
        () => DisposableAsyncService.create('root_scoped'),
        lifecycle: Lifecycle.scoped
      );

      final rootService = await injector.getAsync<DisposableAsyncService>();
      expect(DisposableAsyncService.factoryCallCount, 1);
      expect(rootService.id, 'root_scoped');

      final childScope = injector.createChildScope();
      final childServiceSame = await childScope.getAsync<DisposableAsyncService>();
      expect(identical(rootService, childServiceSame), isTrue);
      expect(DisposableAsyncService.factoryCallCount, 1); // Not called again

      // Override in child
      childScope.registerAsync<DisposableAsyncService>(
        () => DisposableAsyncService.create('child_override_scoped'),
        lifecycle: Lifecycle.scoped
      );
      final childServiceOverridden = await childScope.getAsync<DisposableAsyncService>();
      expect(identical(rootService, childServiceOverridden), isFalse);
      expect(childServiceOverridden.id, 'child_override_scoped');
      expect(DisposableAsyncService.factoryCallCount, 2); // Called for the new registration
      
      injector.dispose();
      expect(rootService.isDisposed, isTrue);
      expect(childServiceOverridden.isDisposed, isTrue);
    });
    
    test('named async factory', () async {
      injector.registerAsync<AsyncService>(() async => AsyncService(1, id: 'A'), name: 'serviceA');
      injector.registerAsync<AsyncService>(() async => AsyncService(2, id: 'B'), name: 'serviceB');

      final serviceA = await injector.getAsync<AsyncService>(name: 'serviceA');
      final serviceB = await injector.getAsync<AsyncService>(name: 'serviceB');

      expect(serviceA.id, 'A');
      expect(serviceB.id, 'B');
    });

    test('throws when getting non-existent async service', () async {
      await expectLater(
        injector.getAsync<AsyncService>(name: 'nonexistent'),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause, 
          'cause', 
          contains("Async service of type AsyncService (name: 'nonexistent') not found"))
        ),
      );
    });
    
    test('throws when getting sync-registered service with getAsync if factory was sync', () async {
      injector.register<AsyncService>(() => AsyncService(100), name: "syncService");
      // This is okay, locateAsync can fall back to sync factory
      final service = await injector.getAsync<AsyncService>(name: "syncService");
      expect(service.value, 100);
    });

    test('throws when getting async-registered service with get (sync)', () async {
      injector.registerAsync<AsyncService>(() async => AsyncService(100), name: "asyncOnly");
      expect(
         () => injector.get<AsyncService>(name: "asyncOnly"),
         throwsA(isA<InjectorException>().having(
           (e) => e.cause,
           'cause',
           contains("Service of type AsyncService (name: 'asyncOnly') was registered with an asynchronous factory. Use getAsync instead.")
         ))
      );
    });

    test('dispose calls dispose on async singleton DisposableAsyncService', () async {
       await injector.registerAsync<DisposableAsyncService>(
        () => DisposableAsyncService.create('async_single'),
        lifecycle: Lifecycle.singleton,
        lazy:false
      );
      final service = await injector.getAsync<DisposableAsyncService>();
      expect(service.isDisposed, isFalse);
      injector.dispose();
      expect(service.isDisposed, isTrue);
    });
  });
}

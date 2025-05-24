import 'package:deep_thought_injector/service_injector.dart';
import 'package:test/test.dart';

// Dummy service for testing.
class TestService {
  TestService(this.value);
  final int value;
}

class DisposableService implements Disposable {
  DisposableService(this.id);
  final String id;
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    // print('DisposableService $id disposed');
  }
}

void main() {
  late ServiceInjector injector;

  setUp(() {
    injector = ServiceInjector();
  });

  tearDown(() {
    // Ensure injectors are disposed if not explicitly done in a test
    // This prevents state leakage between tests if a test fails to dispose
    try {
      injector.dispose();
    } catch (_) {
      // Ignore if already disposed or not initialized
    }
  });

  group('ServiceInjector Core', () {
    test('can be instantiated', () {
      expect(injector, isNotNull);
    });

    test('register and get lazy singleton (default)', () {
      var factoryCallCount = 0;
      injector.register<TestService>(() {
        factoryCallCount++;
        return TestService(100);
      }); // Default is Lifecycle.singleton, lazy: true

      expect(factoryCallCount, 0);
      final service1 = injector.get<TestService>();
      expect(service1.value, 100);
      expect(factoryCallCount, 1);

      final service2 = injector.get<TestService>();
      expect(service2.value, 100);
      expect(factoryCallCount, 1); // Not called again
      expect(identical(service1, service2), isTrue);
    });

    test('register and get eager singleton', () {
      var factoryCallCount = 0;
      injector.register<TestService>(
        () {
          factoryCallCount++;
          return TestService(200);
        },
        lazy: false, // Eager
        lifecycle: Lifecycle.singleton,
      );

      expect(factoryCallCount, 1); // Called immediately
      final service = injector.get<TestService>();
      expect(service.value, 200);
      expect(factoryCallCount, 1); // Not called again
    });

    test('register and get transient', () {
      var factoryCallCount = 0;
      injector.register<TestService>(
        () {
          factoryCallCount++;
          return TestService(300);
        },
        lifecycle: Lifecycle.transient,
      );

      expect(factoryCallCount, 0);
      final service1 = injector.get<TestService>();
      expect(service1.value, 300);
      expect(factoryCallCount, 1);

      final service2 = injector.get<TestService>();
      expect(service2.value, 300);
      expect(factoryCallCount, 2); // Called again
      expect(identical(service1, service2), isFalse);
    });

    test('throws InjectorException when getting unregistered service', () {
      expect(
        () => injector.get<TestService>(),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          contains('Service of type TestService not found'),
        )),
      );
    });

    test('throws InjectorException on duplicate registration (unnamed)', () {
      injector.register<TestService>(() => TestService(1));
      expect(
        () => injector.register<TestService>(() => TestService(2)),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          contains('Service of type TestService is already registered'),
        )),
      );
    });

    test('throws InjectorException on duplicate registration (named)', () {
      injector.register<TestService>(() => TestService(1), name: 'service');
      expect(
        () => injector.register<TestService>(() => TestService(2), name: 'service'),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          contains("Service of type TestService (name: 'service') is already registered"),
        )),
      );
    });
  });

  group('Named Registrations', () {
    test('can register and get named services', () {
      injector.register<TestService>(() => TestService(10), name: 'serviceA');
      injector.register<TestService>(() => TestService(20), name: 'serviceB');

      final serviceA = injector.get<TestService>(name: 'serviceA');
      final serviceB = injector.get<TestService>(name: 'serviceB');

      expect(serviceA.value, 10);
      expect(serviceB.value, 20);
      expect(identical(serviceA, serviceB), isFalse);
    });

    test('getting unnamed service does not return named one', () {
      injector.register<TestService>(() => TestService(10), name: 'named');
      expect(
        () => injector.get<TestService>(),
        throwsA(isA<InjectorException>()),
      );
    });

    test('getting named service that is not registered throws', () {
      injector.register<TestService>(() => TestService(10)); // Unnamed
      expect(
        () => injector.get<TestService>(name: 'nonexistent'),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          contains("Service of type TestService (name: 'nonexistent') not found"),
        )),
      );
    });
  });

  group('Lifecycle.scoped', () {
    test('service is unique per scope', () {
      injector.register<DisposableService>(() => DisposableService('scoped'), lifecycle: Lifecycle.scoped);

      final rootService = injector.get<DisposableService>();
      final childScope1 = injector.createChildScope();
      final child1Service = childScope1.get<DisposableService>();

      expect(identical(rootService, child1Service), isTrue, reason: "Should resolve from parent if not in child");
      
      childScope1.register<DisposableService>(() => DisposableService('child1_scoped'), lifecycle: Lifecycle.scoped);
      final child1OverriddenService = childScope1.get<DisposableService>();
      expect(identical(rootService, child1OverriddenService), isFalse, reason: "Child should have its own instance after explicit registration");
      expect(child1OverriddenService.id, 'child1_scoped');


      final childScope2 = injector.createChildScope();
      final child2Service = childScope2.get<DisposableService>();
      // Should get from root injector as scope2 doesn't have its own registration
      expect(identical(child2Service, rootService), isTrue);
      expect(identical(child2Service, child1OverriddenService), isFalse);
      
      injector.dispose();
      expect(rootService.isDisposed, isTrue);
      expect(child1OverriddenService.isDisposed, isTrue);
    });

    test('non-lazy scoped service is created on registration in that scope', () {
      var factoryCallCount = 0;
      injector.register<TestService>(
        () {
          factoryCallCount++;
          return TestService(1);
        },
        lifecycle: Lifecycle.scoped,
        lazy: false,
      );
      expect(factoryCallCount, 1);
      injector.get<TestService>(); // Get it
      expect(factoryCallCount, 1); // Should not increment again for this scope
    });
    
    test('scoped service is disposed when its defining scope is disposed', () {
      final rootScoped = DisposableService('root_scoped');
      injector.register<DisposableService>(() => rootScoped, lifecycle: Lifecycle.scoped);
      injector.get<DisposableService>(); // Ensure created

      final childScope = injector.createChildScope();
      final childScoped = DisposableService('child_scoped');
      childScope.register<DisposableService>(() => childScoped, lifecycle: Lifecycle.scoped);
      childScope.get<DisposableService>(); // Ensure created

      expect(rootScoped.isDisposed, isFalse);
      expect(childScoped.isDisposed, isFalse);

      childScope.dispose(); // Dispose only child
      expect(rootScoped.isDisposed, isFalse); // Root's scoped service should not be disposed
      expect(childScoped.isDisposed, isTrue);

      injector.dispose(); // Dispose root (which should dispose its own scoped services)
      expect(rootScoped.isDisposed, isTrue);
    });
  });

  group('Disposal', () {
    test('dispose calls dispose on Disposable singletons', () {
      final service = DisposableService('singleton');
      injector.register<DisposableService>(() => service, lifecycle: Lifecycle.singleton);
      injector.get<DisposableService>(); // Ensure it's created if lazy

      expect(service.isDisposed, isFalse);
      injector.dispose();
      expect(service.isDisposed, isTrue);
    });

    test('dispose calls dispose on Disposable eager singletons', () {
      final service = DisposableService('eager_singleton');
      injector.register<DisposableService>(() => service, lifecycle: Lifecycle.singleton, lazy: false);
      
      expect(service.isDisposed, isFalse);
      injector.dispose();
      expect(service.isDisposed, isTrue);
    });

    test('dispose does not call dispose on transient services (as they are not held)', () {
      final service = DisposableService('transient');
      var factoryCallCount = 0;
      injector.register<DisposableService>(() {
        factoryCallCount++;
        return service; // Returning same instance for test, typically new one
      }, lifecycle: Lifecycle.transient);
      
      injector.get<DisposableService>();
      expect(factoryCallCount, 1);
      expect(service.isDisposed, isFalse);

      injector.dispose();
      expect(service.isDisposed, isFalse); // Transient instances are not managed by scope after creation
    });
    
    test('dispose disposes child scopes and their services', () {
      final childScope = injector.createChildScope();
      final childSingleton = DisposableService('child_singleton');
      childScope.register<DisposableService>(() => childSingleton, lifecycle: Lifecycle.singleton, lazy: false);

      final childScoped = DisposableService('child_scoped');
      childScope.register<DisposableService>(() => childScoped, name: 'scoped_in_child', lifecycle: Lifecycle.scoped, lazy: false);
      
      expect(childSingleton.isDisposed, isFalse);
      expect(childScoped.isDisposed, isFalse);

      injector.dispose(); // Disposing parent should dispose child and its services

      expect(childSingleton.isDisposed, isTrue);
      expect(childScoped.isDisposed, isTrue);
    });

    test('getting service after injector disposal throws', () {
      injector.register<TestService>(() => TestService(1));
      injector.dispose();
      expect(
        () => injector.get<TestService>(),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot locate service on a disposed scope. Service type: TestService',
        )),
      );
    });

    test('registering service after injector disposal throws', () {
      injector.register<TestService>(() => TestService(1)); // Register something first
      injector.dispose();
      expect(
        () => injector.register<TestService>(() => TestService(2)),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot register service on a disposed scope. Service type: TestService',
        )),
      );
    });

    test('createChildScope after injector disposal throws', () {
      injector.dispose();
      expect(
        () => injector.createChildScope(),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot create child scope on a disposed scope.',
        )),
      );
    });

    test('operations on an explicitly disposed child scope throw', () {
      final childInjector = injector.createChildScope(); // childInjector uses a child scope
      childInjector.register<TestService>(() => TestService(1));
      childInjector.get<TestService>(); // Works

      childInjector.dispose(); // Explicitly dispose child injector (and its scope)

      expect(
        () => childInjector.get<TestService>(),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot locate service on a disposed scope. Service type: TestService',
        )),
      );
      expect(
        () => childInjector.register<TestService>(() => TestService(2)),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot register service on a disposed scope. Service type: TestService',
        )),
      );
       expect(
        () => childInjector.createChildScope(),
        throwsA(isA<InjectorException>().having(
          (e) => e.cause,
          'cause',
          'Cannot create child scope on a disposed scope.',
        )),
      );
    });
  });
}

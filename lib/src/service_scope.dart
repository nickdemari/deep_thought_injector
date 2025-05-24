// src/service_scope.dart

import 'package:deep_thought_injector/src/injector_exception.dart';
import 'dart:async';

// New class for supporting named registrations.
class _ServiceIdentifier {
  final Type type;
  final String? name;
  const _ServiceIdentifier(this.type, [this.name]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ServiceIdentifier &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          name == other.name;
  @override
  int get hashCode => type.hashCode ^ (name?.hashCode ?? 0);

  @override
  String toString() => 'ServiceIdentifier(type: ${type.toString()}, name: $name)';
}

/// Defines the lifecycle of a registered service in a `ServiceScope`.
///
/// The lifecycle determines how instances of a service are created, shared,
/// and disposed.
enum Lifecycle {
  /// **Singleton:** A single instance of the service is created and shared.
  /// - If registered in the root scope, it's globally available.
  /// - If registered in a child scope, it's a singleton within that child scope
  ///   and its descendants (unless overridden).
  /// - Creation can be lazy (on first request, default) or eager (at registration, if `lazy: false`).
  /// - The instance is stored in the `_ServiceFactory`'s `instance` field.
  singleton,

  /// **Transient:** A new instance of the service is created every time it is requested.
  /// - This is suitable for services that are lightweight or stateful and should not be shared.
  transient,

  /// **Scoped:** A single instance of the service is created and shared per `ServiceScope`.
  /// - When a service is requested, the injector looks for it in the current scope.
  ///   If not found, it checks the parent scope, and so on, up to the root.
  /// - If the service is registered with `Lifecycle.scoped` in a scope `S`, all requests
  ///   for that service from scope `S` or its child scopes (that don't override it)
  ///   will receive the same instance associated with scope `S`.
  /// - The instance is stored in the `ServiceScope`'s `_scopedInstances` map.
  scoped,
}

/// Manages the registration, instantiation, and lifecycle of services within a
/// specific scope.
///
/// `ServiceScope` is the core mechanism behind the `ServiceInjector`. Each
/// `ServiceInjector` has a root `ServiceScope`. Child scopes can be created
/// to form a hierarchy, allowing for more granular control over service lifecycles
/// and visibility.
///
/// Key responsibilities:
/// - Storing service factories (`_factories`) and their associated lifecycles.
/// - Caching created instances for `Lifecycle.singleton` (in `_ServiceFactory`)
///   and `Lifecycle.scoped` (in `_scopedInstances`).
/// - Resolving service requests by looking in the current scope, then delegating
///   to a parent scope if not found.
/// - Managing child scopes (`_childScopes`).
/// - Disposing of services and child scopes.
class ServiceScope {
  final Map<_ServiceIdentifier, _ServiceFactory<dynamic>> _factories = {};
  final Map<_ServiceIdentifier, dynamic> _scopedInstances = {};
  final List<ServiceScope> _childScopes = [];
  final ServiceScope? parent;
  bool _isDisposed = false;
  // Simple lock object placeholder for thread safety.
  final _lock = Object();

  ServiceScope({this.parent});

  /// Creates a new `ServiceScope` that is a child of this scope.
  ///
  /// Child scopes inherit the ability to resolve services registered in their
  /// parent (and ancestor) scopes. They can also override registrations or
  /// register new services that are only visible within the child scope and its
  /// descendants.
  ///
  /// The child scope is added to this scope's `_childScopes` list and will
  /// be disposed when this scope is disposed.
  /// Throws [InjectorException] if the scope is already disposed.
  ServiceScope createChildScope() {
    if (_isDisposed) {
      throw InjectorException('Cannot create child scope on a disposed scope.');
    }
    final child = ServiceScope(parent: this);
    _childScopes.add(child);
    return child;
  }

  /// Registers a synchronous service factory with this scope.
  ///
  /// See `ServiceInjector.register` for detailed explanation of parameters.
  /// This method is typically called by `ServiceInjector`.
  /// Throws [InjectorException] if the scope is already disposed.
  void register<T>(
    T Function() factory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) {
    if (_isDisposed) {
      throw InjectorException('Cannot register service on a disposed scope. Service type: $T${name == null ? "" : " (name: \'$name\')"}');
    }
    final key = _ServiceIdentifier(T, name);
    if (_factories.containsKey(key)) {
      throw InjectorException(
          'Service of type $T${name == null ? "" : " (name: \'$name\')"} is already registered.');
    }
    final serviceFactory = _ServiceFactory<T>(
      syncFactory: factory,
      asyncFactory: null,
      lazy: lazy,
      lifecycle: lifecycle,
    );
    if (!lazy) {
      if (lifecycle == Lifecycle.singleton) {
        serviceFactory.instance = factory();
      } else if (lifecycle == Lifecycle.scoped) {
        _scopedInstances[key] = factory();
      }
    }
    print('[DEBUG ServiceScope.registerAsync] Registering key: ${key.toString()}, factory: $serviceFactory');
    _factories[key] = serviceFactory;
  }

  /// Registers an asynchronous service factory with this scope.
  ///
  /// See `ServiceInjector.registerAsync` for detailed explanation of parameters.
  /// This method is typically called by `ServiceInjector`.
  /// Throws [InjectorException] if the scope is already disposed.
  Future<void> registerAsync<T>(
    Future<T> Function() asyncFactory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) async {
    if (_isDisposed) {
      throw InjectorException('Cannot register async service on a disposed scope. Service type: $T${name == null ? "" : " (name: \'$name\')"}');
    }
    final key = _ServiceIdentifier(T, name);
    if (_factories.containsKey(key)) {
      throw InjectorException(
          'Service of type $T${name == null ? "" : " (name: \'$name\')"} is already registered.');
    }
    final serviceFactory = _ServiceFactory<T>(
      syncFactory: null,
      asyncFactory: asyncFactory,
      lazy: lazy,
      lifecycle: lifecycle,
    );
    if (!lazy) {
      if (lifecycle == Lifecycle.singleton) {
        serviceFactory.instance = await asyncFactory();
      } else if (lifecycle == Lifecycle.scoped) {
        _scopedInstances[key] = await asyncFactory();
      }
    }
    _factories[key] = serviceFactory;
  }

  /// Locates and returns a synchronous service instance of type `T`.
  ///
  /// This method is the core of service retrieval within a scope.
  ///
  /// - If the service is not found in `_factories` and a `parent` scope exists,
  ///   it delegates the request to `parent.locate<T>()`.
  /// - Throws `InjectorException` if the service is not found in this scope or any ancestors.
  /// - Throws `InjectorException` if a service registered with an async factory
  ///   is requested using this synchronous method.
  ///
  /// Behavior based on `Lifecycle`:
  /// - `Lifecycle.transient`: Always calls the `syncFactory` to create a new instance.
  /// - `Lifecycle.scoped`:
  ///   - If an instance for `key` exists in `_scopedInstances`, returns it.
  ///   - Otherwise, calls `syncFactory`, stores the new instance in `_scopedInstances`,
  ///     and returns it.
  /// - `Lifecycle.singleton`:
  ///   - If `serviceFactory.instance` is not null, returns it.
  ///   - Otherwise, calls `syncFactory`, stores the new instance in
  ///     `serviceFactory.instance`, and returns it.
  /// Throws [InjectorException] if the scope is already disposed.
  T locate<T>({String? name}) {
    if (_isDisposed) {
      throw InjectorException('Cannot locate service on a disposed scope. Service type: $T${name == null ? "" : " (name: \'$name\')"}');
    }
    final key = _ServiceIdentifier(T, name);
    print('[DEBUG ServiceScope.locate] Attempting to locate key: ${key.toString()}');
    print('[DEBUG ServiceScope.locate] Available keys in _factories: ${_factories.keys.map((k) => k.toString()).join(', ')}');
    final serviceFactory = _factories[key] as _ServiceFactory<T>?;
    print('[DEBUG ServiceScope.locate] Factory found: ${serviceFactory != null}');

    if (serviceFactory == null) {
      if (parent != null) {
        print('[DEBUG ServiceScope.locate] Not found in current scope, trying parent.');
        // Delegate to parent, parent will check its own _isDisposed status if it has one.
        // If parent is disposed, it should throw.
        return parent!.locate<T>(name: name);
      }
      // No factory in this scope and no parent, or service not found in parent chain.
      throw InjectorException('Service of type $T${name == null ? "" : " (name: \'$name\')"} not found.');
    }

    // Factory found in this scope.
    if (serviceFactory.asyncFactory != null) {
      throw InjectorException(
          'Service of type $T${name == null ? "" : " (name: \'$name\')"} was registered with an asynchronous factory. Use getAsync instead.');
    }
    if (serviceFactory.lifecycle == Lifecycle.transient) {
      return serviceFactory.syncFactory!();
    }
    if (serviceFactory.lifecycle == Lifecycle.scoped) {
      if (_scopedInstances.containsKey(key)) {
        return _scopedInstances[key] as T;
      }
      final instance = serviceFactory.syncFactory!();
      _scopedInstances[key] = instance;
      return instance;
    }
    // Singleton
    serviceFactory.instance ??= serviceFactory.syncFactory!();
    return serviceFactory.instance!;
  }

  /// Locates and returns an asynchronous service instance of type `T`.
  ///
  /// This method handles retrieval for services registered with either sync or
  /// async factories when an async result is acceptable.
  ///
  /// - If the service is not found in `_factories` and a `parent` scope exists,
  ///   it delegates the request to `parent.locateAsync<T>()`.
  /// - Throws `InjectorException` if the service is not found in this scope or any ancestors.
  ///
  /// Behavior based on `Lifecycle` and factory type:
  /// - **Async Factory Exists (`serviceFactory.asyncFactory != null`)**:
  ///   - `Lifecycle.transient`: Always calls and awaits `asyncFactory`.
  ///   - `Lifecycle.scoped`:
  ///     - If an instance for `key` exists in `_scopedInstances`, returns it.
  ///     - Otherwise, calls and awaits `asyncFactory`, stores the new instance in
  ///       `_scopedInstances`, and returns it.
  ///   - `Lifecycle.singleton`:
  ///     - If `serviceFactory.instance` is not null, returns it.
  ///     - Otherwise, calls and awaits `asyncFactory`, stores the new instance in
  ///       `serviceFactory.instance`, and returns it.
  /// - **Sync Factory Only (`serviceFactory.syncFactory != null`)**:
  ///   (This path is taken if `locateAsync` is called for a synchronously registered service)
  ///   - `Lifecycle.transient`: Calls `syncFactory` and wraps in `Future.value()`.
  ///   - `Lifecycle.scoped`:
  ///     - If an instance for `key` exists in `_scopedInstances`, returns it (wrapped).
  ///     - Otherwise, calls `syncFactory`, stores, and returns (wrapped).
  ///   - `Lifecycle.singleton`:
  ///     - If `serviceFactory.instance` is not null, returns it (wrapped).
  ///     - Otherwise, calls `syncFactory`, stores, and returns (wrapped).
  /// Throws [InjectorException] if the scope is already disposed.
  Future<T> locateAsync<T>({String? name}) async {
    if (_isDisposed) {
      throw InjectorException('Cannot locate async service on a disposed scope. Service type: $T${name == null ? "" : " (name: \'$name\')"}');
    }
    final key = _ServiceIdentifier(T, name);
    var serviceFactory = _factories[key] as _ServiceFactory<T>?;

    if (serviceFactory == null) {
      if (parent != null) {
         // Delegate to parent, parent will check its own _isDisposed status if it has one.
        return await parent!.locateAsync<T>(name: name);
      }
      // No factory in this scope and no parent, or service not found in parent chain.
      throw InjectorException('Service of type $T${name == null ? "" : " (name: \'$name\')"} not found.');
    }

    // Factory found in this scope.
    if (serviceFactory.asyncFactory != null) { // Service has an async factory
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        return await serviceFactory.asyncFactory!();
      }
      if (serviceFactory.lifecycle == Lifecycle.scoped) {
        if (_scopedInstances.containsKey(key)) {
          return _scopedInstances[key] as T;
        }
        final instance = await serviceFactory.asyncFactory!();
        _scopedInstances[key] = instance;
        return instance;
      }
      // Singleton
      serviceFactory.instance ??= await serviceFactory.asyncFactory!();
      return serviceFactory.instance!;
    } else { // Service has a sync factory (locateAsync called on a sync service)
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        return serviceFactory.syncFactory!();
      }
      if (serviceFactory.lifecycle == Lifecycle.scoped) {
        if (_scopedInstances.containsKey(key)) {
          return _scopedInstances[key] as T;
        }
        final instance = serviceFactory.syncFactory!();
        _scopedInstances[key] = instance;
        return instance;
      }
      // Singleton
      serviceFactory.instance ??= serviceFactory.syncFactory!();
      return serviceFactory.instance!;
    }
  }

  /// Disposes this `ServiceScope` and all its descendant child scopes.
  ///
  /// The disposal process involves several steps:
  /// 1. **Recursive Disposal of Child Scopes**: Calls `dispose()` on each child
  ///    scope registered in `_childScopes`. Errors during a child's disposal
  ///    are caught and printed (ideally logged via `ServiceInjector.logger`),
  ///    allowing other children to be disposed. `_childScopes` is cleared afterwards.
  /// 2. **Disposal of Scoped Instances**: Iterates through all instances stored in
  ///    `_scopedInstances`. If an instance implements `Disposable`, its `dispose()`
  ///    method is called. Errors are caught and printed. `_scopedInstances` is cleared.
  /// 3. **Disposal of Singleton Instances**: Iterates through all factories in
  ///    `_factories`. If a factory holds a singleton instance (`factory.instance != null`
  ///    and `factory.lifecycle == Lifecycle.singleton`) and that instance
  ///    implements `Disposable`, its `dispose()` method is called. Errors are
  ///    caught and printed. `_factories` is cleared.
  ///
  /// This ensures that resources held by services are properly released.
  /// After disposal, the scope should not be used.
  ///
  /// Note on Singleton Disposal: Only singleton instances that were *created by*
  /// this specific scope (i.e., their factory is in this scope's `_factories` map)
  /// are disposed here. Singletons resolved from a parent scope are the responsibility
  /// of that parent scope to dispose.
  ///
  /// The method uses `print` for error logging during disposal as a fallback.
  /// A more robust solution would use `ServiceInjector.logger`.
  void dispose() {
    if (_isDisposed) {
      return; // Already disposed
    }
    // Dispose child scopes first
    // Iterate over a copy of the list to avoid modification issues if child disposal affects the list
    for (final child in List<ServiceScope>.from(_childScopes)) {
      try {
        child.dispose();
      } catch (e, s) {
        // Consider using the ServiceInjector's static logger here if accessible
        // For now, print to console as a fallback.
        print('Error disposing child scope: $e\nStack trace:\n$s');
      }
    }
    _childScopes.clear();

    // Dispose scoped instances held directly in this scope
    for (final instanceEntry in _scopedInstances.entries) {
      if (instanceEntry.value is Disposable) {
        try {
          (instanceEntry.value as Disposable).dispose();
        } catch (e, s) {
          print(
              'Error disposing scoped instance of type ${instanceEntry.key.type} (name: ${instanceEntry.key.name}): $e\nStack trace:\n$s');
        }
      }
    }
    _scopedInstances.clear();

    // Dispose singleton instances held by factories in this scope
    for (final factoryEntry in _factories.entries) {
      final factory = factoryEntry.value;
      if (factory.instance != null &&
          factory.lifecycle == Lifecycle.singleton &&
          factory.instance is Disposable) {
        try {
          (factory.instance as Disposable).dispose();
        } catch (e, s) {
          print(
              'Error disposing singleton instance of type ${factoryEntry.key.type} (name: ${factoryEntry.key.name}): $e\nStack trace:\n$s');
        }
      }
    }
    _factories.clear();
    _isDisposed = true;
  }

  /// Overrides an existing registration or registers a new one with a pre-existing instance.
  /// Throws [InjectorException] if the scope is already disposed.
  ///
  /// This method directly places the provided `instance` into the `_factories` map
  /// as a non-lazy singleton. If a registration for the same type `T` (and `name`,
  /// if provided) already exists, it will be replaced.
  ///
  /// This is useful for:
  /// - Testing: Injecting mock instances.
  /// - Integrating with services initialized outside the injector.
  /// - Manually setting a specific instance for a scope.
  ///
  /// Note: The provided `instance` will be treated as a `Lifecycle.singleton`
  /// for the purpose of this scope and its children. If it's `Disposable`, it will
  /// be disposed when this scope is disposed.
  void override<T>(T instance, {String? name}) {
    final key = _ServiceIdentifier(T, name);
    _factories[key] = _ServiceFactory<T>(
      syncFactory: () => instance,
      asyncFactory: null,
      lazy: false,
      lifecycle: Lifecycle.singleton,
    )..instance = instance;
  }
}

/// Internal class representing a factory for creating service instances.
///
/// It holds the factory function (either synchronous or asynchronous),
/// the desired [lifecycle], and whether the service should be created lazily.
/// For singletons, it also caches the created [instance].
class _ServiceFactory<T> {
  _ServiceFactory({
    required this.syncFactory,
    required this.asyncFactory,
    required this.lazy,
    required this.lifecycle,
  });
  final T Function()? syncFactory;
  final Future<T> Function()? asyncFactory;
  final bool lazy;
  final Lifecycle lifecycle;
  T? instance;
}

/// An interface for services that need to perform cleanup when their scope is disposed.
///
/// Services registered with `ServiceInjector` can implement this interface.
/// When the `ServiceScope` (and thus the `ServiceInjector`) containing the service
/// is disposed, the `dispose()` method of any `Disposable` service instance
/// will be called.
///
/// This is useful for releasing resources, closing connections, unsubscribing
/// from streams, etc.
///
/// Example:
/// ```dart
/// class MyResourceService implements Disposable {
///   bool _isDisposed = false;
///
///   void useResource() {
///     if (_isDisposed) print('Resource already disposed!');
///     else print('Using resource...');
///   }
///
///   @override
///   void dispose() {
///     print('MyResourceService disposed.');
///     _isDisposed = true;
///     // Perform actual cleanup here (e.g., close files, network connections)
///   }
/// }
///
/// // Registration:
/// // injector.register<MyResourceService>(() => MyResourceService());
/// // injector.dispose(); // This will call myResourceService.dispose()
/// ```
abstract class Disposable {
  /// Called when the service's scope is being disposed.
  ///
  /// Implement this method to release any resources held by the service.
  void dispose();
}

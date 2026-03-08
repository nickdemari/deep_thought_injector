// src/sub_etha_scope.dart

import 'package:deep_thought_injector/src/vogon_poetry_exception.dart';
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
}

/// Updated enum to include 'scoped' lifecycle.
enum Lifecycle { singleton, transient, scoped }

/// The SubEthaScope is the heart of the Deep Thought Injector.
/// It now supports nested scopes and named registrations.
class SubEthaScope {
  final Map<_ServiceIdentifier, _ServiceFactory<dynamic>> _factories = {};
  final SubEthaScope? parent;
  // Simple lock object placeholder for thread safety.
  final _lock = Object();

  SubEthaScope({this.parent});

  /// Create a child scope with this scope as its parent.
  SubEthaScope createChildScope() => SubEthaScope(parent: this);

  /// Register a synchronous service.
  void register<T>(
    T Function() factory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) {
    final key = _ServiceIdentifier(T, name);
    if (_factories.containsKey(key)) {
      throw const VogonPoetryException(
          'Service of this type is already registered');
    }
    final serviceFactory = _ServiceFactory<T>(
      syncFactory: factory,
      asyncFactory: null,
      lazy: lazy,
      lifecycle: lifecycle,
    );
    if (!lazy && lifecycle == Lifecycle.singleton) {
      serviceFactory.instance = factory();
    }
    _factories[key] = serviceFactory;
  }

  /// Register an asynchronous service.
  Future<void> registerAsync<T>(
    Future<T> Function() asyncFactory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) async {
    final key = _ServiceIdentifier(T, name);
    if (_factories.containsKey(key)) {
      throw const VogonPoetryException(
          'Service of this type is already registered');
    }
    final serviceFactory = _ServiceFactory<T>(
      syncFactory: null,
      asyncFactory: asyncFactory,
      lazy: lazy,
      lifecycle: lifecycle,
    );
    if (!lazy && lifecycle == Lifecycle.singleton) {
      serviceFactory.instance = await asyncFactory();
    }
    _factories[key] = serviceFactory;
  }

  /// Locate a synchronous service.
  T locate<T>({String? name}) {
    final key = _ServiceIdentifier(T, name);
    final serviceFactory = _factories[key] as _ServiceFactory<T>?;
    if (serviceFactory == null && parent != null) {
      return parent!.locate<T>(name: name);
    }
    if (serviceFactory == null) {
      throw const VogonPoetryException('Service of this type not found');
    }
    if (serviceFactory.asyncFactory != null) {
      throw const VogonPoetryException(
          'Asynchronous factory registered. Use locateAsync instead.');
    }
    if (serviceFactory.lifecycle == Lifecycle.transient) {
      return serviceFactory.syncFactory!();
    }
    serviceFactory.instance ??= serviceFactory.syncFactory!();
    return serviceFactory.instance!;
  }

  /// Locate a service asynchronously.
  Future<T> locateAsync<T>({String? name}) async {
    final key = _ServiceIdentifier(T, name);
    var serviceFactory = _factories[key] as _ServiceFactory<T>?;
    if (serviceFactory == null && parent != null) {
      return await parent!.locateAsync<T>(name: name);
    }
    if (serviceFactory == null) {
      throw const VogonPoetryException('Service of this type not found');
    }
    if (serviceFactory.asyncFactory != null) {
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        return await serviceFactory.asyncFactory!();
      }
      // Fast path: already resolved.
      if (serviceFactory.instance != null) {
        return serviceFactory.instance!;
      }
      // Another caller is already resolving -- wait for its result.
      if (serviceFactory._asyncCompleter != null) {
        return serviceFactory._asyncCompleter!.future;
      }
      // First caller: claim resolution with a Completer BEFORE any await.
      final completer = Completer<T>();
      serviceFactory._asyncCompleter = completer;
      try {
        final result = await serviceFactory.asyncFactory!();
        serviceFactory.instance = result;
        completer.complete(result);
        return result;
      } catch (e, s) {
        // Allow retry on subsequent calls.
        completer.completeError(e, s);
        rethrow;
      } finally {
        // Clear completer so GC can reclaim / retry is possible.
        serviceFactory._asyncCompleter = null;
      }
    } else {
      // Fallback to synchronous factory if present.
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        return serviceFactory.syncFactory!();
      }
      serviceFactory.instance ??= serviceFactory.syncFactory!();
      return serviceFactory.instance!;
    }
  }

  /// Dispose registered services (if they implement Disposable) before resetting.
  void reset() {
    for (final factory in _factories.values) {
      if (factory.instance is Disposable) {
        (factory.instance as Disposable).dispose();
      }
    }
    _factories.clear();
  }

  /// Overrides an existing registration with an instance.
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

/// Updated factory class to support either a synchronous or asynchronous factory.
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

  /// Guards concurrent async singleton resolution.
  /// Set synchronously before the first await to prevent interleaving.
  Completer<T>? _asyncCompleter;
}

/// A disposable interface that service instances can implement.
abstract class Disposable {
  void dispose();
}

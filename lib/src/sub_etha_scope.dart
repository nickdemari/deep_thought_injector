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

/// Zone key for threading resolution stacks through async factory closures.
/// Zone values flow correctly across await boundaries without leaking to
/// independent callers, unlike instance fields.
final _resolutionStackZoneKey = Object();

/// The SubEthaScope is the heart of the Deep Thought Injector.
/// It now supports nested scopes and named registrations.
class SubEthaScope {
  final Map<_ServiceIdentifier, _ServiceFactory<dynamic>> _factories = {};
  final SubEthaScope? parent;

  // Dart's default Set (LinkedHashSet) preserves insertion order for chain
  // display. This field holds the active resolution stack so that re-entrant
  // locate/locateAsync calls from within SYNC factory closures can detect
  // cycles. For async, Zone values are used instead (see _resolutionStackZoneKey).
  Set<_ServiceIdentifier>? _currentResolutionStack;

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
  T locate<T>({
    String? name,
    Set<_ServiceIdentifier>? resolutionStack,
  }) {
    final key = _ServiceIdentifier(T, name);
    final stack =
        resolutionStack ?? _currentResolutionStack ?? <_ServiceIdentifier>{};

    if (stack.contains(key)) {
      final chain = [...stack, key]
          .map(
            (id) => id.name != null ? '${id.type}(${id.name})' : '${id.type}',
          )
          .join(' -> ');
      throw VogonPoetryException('Circular dependency detected: $chain');
    }
    stack.add(key);

    final serviceFactory = _factories[key] as _ServiceFactory<T>?;
    if (serviceFactory == null && parent != null) {
      return parent!.locate<T>(name: name, resolutionStack: stack);
    }
    if (serviceFactory == null) {
      throw const VogonPoetryException('Service of this type not found');
    }
    if (serviceFactory.asyncFactory != null) {
      throw const VogonPoetryException(
          'Asynchronous factory registered. Use locateAsync instead.');
    }

    final previousStack = _currentResolutionStack;
    _currentResolutionStack = stack;
    try {
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        return serviceFactory.syncFactory!();
      }
      serviceFactory.instance ??= serviceFactory.syncFactory!();
      return serviceFactory.instance!;
    } finally {
      _currentResolutionStack = previousStack;
    }
  }

  /// Locate a service asynchronously.
  ///
  /// Uses Zone values to thread resolution stacks through async factory
  /// closures. Zone values flow correctly across await boundaries without
  /// leaking to independent concurrent callers.
  Future<T> locateAsync<T>({
    String? name,
    Set<_ServiceIdentifier>? resolutionStack,
  }) async {
    final key = _ServiceIdentifier(T, name);

    // Resolve the active stack: explicit param > zone value > none.
    final activeStack = resolutionStack ??
        Zone.current[_resolutionStackZoneKey] as Set<_ServiceIdentifier>?;

    // Cycle check -- if key is already being resolved in the current chain.
    if (activeStack != null && activeStack.contains(key)) {
      final chain = [...activeStack, key]
          .map(
            (id) => id.name != null ? '${id.type}(${id.name})' : '${id.type}',
          )
          .join(' -> ');
      throw VogonPoetryException('Circular dependency detected: $chain');
    }

    final serviceFactory = _factories[key] as _ServiceFactory<T>?;

    if (serviceFactory == null && parent != null) {
      final stack = activeStack ?? <_ServiceIdentifier>{};
      stack.add(key);
      return parent!.locateAsync<T>(
        name: name,
        resolutionStack: stack,
      );
    }
    if (serviceFactory == null) {
      throw const VogonPoetryException('Service of this type not found');
    }

    if (serviceFactory.asyncFactory != null) {
      if (serviceFactory.lifecycle != Lifecycle.transient) {
        // Fast path: already resolved.
        if (serviceFactory.instance != null) {
          return serviceFactory.instance!;
        }
        // Another caller is already resolving -- wait for its result.
        if (serviceFactory._asyncCompleter != null) {
          return serviceFactory._asyncCompleter!.future;
        }
      }
    }

    // About to invoke a factory -- add to cycle detection stack.
    final stack = activeStack ?? <_ServiceIdentifier>{};
    stack.add(key);

    if (serviceFactory.asyncFactory != null) {
      if (serviceFactory.lifecycle == Lifecycle.transient) {
        // Run transient factory in a zone with the resolution stack.
        return await runZoned(
          () => serviceFactory.asyncFactory!(),
          zoneValues: {_resolutionStackZoneKey: stack},
        );
      }
      // First caller: claim resolution with a Completer BEFORE any await.
      final completer = Completer<T>();
      serviceFactory._asyncCompleter = completer;
      try {
        // Run the factory in a zone carrying the resolution stack so that
        // re-entrant locateAsync calls from within the closure detect cycles.
        final result = await runZoned(
          () => serviceFactory.asyncFactory!(),
          zoneValues: {_resolutionStackZoneKey: stack},
        );
        serviceFactory.instance = result;
        completer.complete(result);
        return result;
      } catch (e, s) {
        // Allow retry on subsequent calls. Propagate error to any concurrent
        // waiters, then silence the Completer's future to prevent unhandled
        // error reports when no concurrent waiters exist.
        completer.completeError(e, s);
        // Silence the Completer's future to prevent unhandled error reports
        // when no concurrent waiters exist. The catchError handler must
        // return a value of type T, but it will never be used since only
        // pre-existing .then listeners receive the error.
        unawaited(completer.future.then((_) {}, onError: (_) {}));
        rethrow;
      } finally {
        // Clear completer so GC can reclaim / retry is possible.
        serviceFactory._asyncCompleter = null;
      }
    } else {
      // Fallback to synchronous factory if present.
      // For sync factories called via locateAsync, use _currentResolutionStack
      // so that sync locate calls within the factory detect cycles.
      final previousStack = _currentResolutionStack;
      _currentResolutionStack = stack;
      try {
        if (serviceFactory.lifecycle == Lifecycle.transient) {
          return serviceFactory.syncFactory!();
        }
        serviceFactory.instance ??= serviceFactory.syncFactory!();
        return serviceFactory.instance!;
      } finally {
        _currentResolutionStack = previousStack;
      }
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

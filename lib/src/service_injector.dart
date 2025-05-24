// src/service_injector.dart

import 'package:deep_thought_injector/src/service_scope.dart';
import 'package:deep_thought_injector/src/injector_exception.dart';
import 'package:logging/logging.dart';
import 'service_scope.dart'; // now includes Lifecycle

/// The main dependency injection (DI) container for the `service_injector` library.
///
/// `ServiceInjector` is responsible for managing the registration and retrieval
/// of services (dependencies) throughout an application. It uses `ServiceScope`
/// internally to handle the actual storage and lifecycle management of services.
///
/// Similar in concept to service locators like `GetIt`, `ServiceInjector` allows
/// decoupling of code by providing a central place to obtain instances of
/// required classes without hard-coding their construction.
///
/// Key functionalities include:
/// - Registering services with different lifecycles (`singleton`, `transient`, `scoped`).
/// - Retrieving registered services.
/// - Creating hierarchical child scopes for more granular dependency management.
/// - Disposing of services and scopes to free resources.
///
/// Example:
/// ```dart
/// final injector = ServiceInjector();
///
/// // Register a service
/// injector.register<MyService>(() => MyService());
///
/// // Retrieve a service
/// final myService = injector.get<MyService>();
///
/// // Dispose the injector when no longer needed
/// injector.dispose();
/// ```
class ServiceInjector {
  /// Creates a new instance of `ServiceInjector`.
  ///
  /// Optionally, an existing [scope] can be provided to be used as the root
  /// scope for this injector. If no scope is provided, a new `ServiceScope`
  /// is created automatically. This is typically used for creating child injectors
  /// with shared or pre-configured scopes.
  ServiceInjector({ServiceScope? scope}) : _scope = scope ?? ServiceScope();
  final ServiceScope _scope;
  static Logger _logger = Logger('ServiceInjector');

  /// An optional callback function invoked by `get` and `getAsync` when an
  /// `InjectorException` is about to be thrown.
  ///
  /// This allows for integration with external error reporting services
  /// (e.g., Sentry, Firebase Crashlytics). Each `ServiceInjector` instance
  /// can have its own `errorNotifier`.
  ///
  /// The callback receives the `Exception` and `StackTrace` that triggered
  /// the error.
  ///
  /// Example:
  /// ```dart
  /// final injector = ServiceInjector();
  /// injector.errorNotifier = (e, s) {
  ///   myCrashReporter.recordError(e, s, reason: 'Service lookup failed');
  /// };
  /// ```
  void Function(Exception e, StackTrace s)? errorNotifier;

  /// Sets a custom static logger for all `ServiceInjector` instances.
  ///
  /// By default, `ServiceInjector` uses a static `Logger` instance named
  /// 'ServiceInjector' (from `package:logging/logging.dart`) to report
  /// internal issues, such as when a service lookup fails before throwing
  /// an `InjectorException`.
  ///
  /// This setter allows replacing the default static logger with a custom
  /// `Logger` instance. This is useful for integrating the injector's logging
  /// with an existing logging framework in an application.
  ///
  /// Since the logger is static, setting it will change the logger for all
  /// instances of `ServiceInjector` throughout the application.
  ///
  /// Example:
  /// ```dart
  /// ServiceInjector.logger = Logger('MyApp.ServiceInjector');
  /// ```
  static set logger(Logger customLogger) {
    _logger = customLogger;
  }

  /// Registers a service with the injector.
  ///
  /// This method allows you to define how a service of type `T` is created
  /// and managed by the injector.
  ///
  /// Parameters:
  /// - `factory`: A function that returns an instance of the service `T`.
  /// - `lazy`: If `true` (default for singletons and scoped), the service is
  ///   created only when first requested. If `false`, it's created immediately
  ///   at registration time (for singletons and scoped) or on first request for transient.
  ///   `lazy` is not applicable to `Lifecycle.transient` in terms of pre-creation.
  /// - `lifecycle`: Determines how the instance is managed:
  ///   - `Lifecycle.singleton`: (Default) A single instance is created.
  ///     - If `lazy: true` (default): Like `get_it.registerLazySingleton<T>(() => T())`.
  ///       The instance is created on the first call to `get<T>()`.
  ///     - If `lazy: false`: Like `get_it.registerSingleton<T>(T())` (if factory is `() => T()`).
  ///       The instance is created immediately during this registration call.
  ///   - `Lifecycle.transient`: A new instance is created every time `get<T>()` is called.
  ///     This is similar to `get_it.registerFactory<T>(() => T())`.
  ///   - `Lifecycle.scoped`: An instance is created once per scope. If requested from
  ///     a child scope that doesn't have its own registration for this type/name,
  ///     it will resolve from the parent scope where it was defined, reusing that
  ///     scope's instance.
  /// - `name`: An optional string to register a named instance. This allows multiple
  ///   registrations for the same type `T`.
  ///
  /// Examples:
  /// ```dart
  /// final injector = ServiceInjector();
  ///
  /// // Eager Singleton (created immediately)
  /// injector.register<ApiService>(() => ApiService(), lifecycle: Lifecycle.singleton, lazy: false);
  ///
  /// // Lazy Singleton (created on first call to get<ApiService>()) - default for singleton
  /// injector.register<DatabaseService>(() => DatabaseService(), lifecycle: Lifecycle.singleton);
  ///
  /// // Transient (new instance every time get<AnalyticsService>() is called)
  /// injector.register<AnalyticsService>(() => AnalyticsService(), lifecycle: Lifecycle.transient);
  ///
  /// // Scoped (instance unique to the injector's scope or a child scope)
  /// // If injector.createChildScope().get<ScopedService>() is called,
  /// // it will be a different instance than injector.get<ScopedService>() if ScopedService
  /// // was registered in the child scope, or the same if resolved from the parent.
  /// injector.register<ScopedService>(() => ScopedService(), lifecycle: Lifecycle.scoped);
  ///
  /// // Named registration
  /// injector.register<Logger>(() => Logger('Info'), name: 'InfoLogger');
  /// injector.register<Logger>(() => Logger('Error'), name: 'ErrorLogger');
  /// final infoLogger = injector.get<Logger>(name: 'InfoLogger');
  /// ```
  void register<T>(
    T Function() factory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) {
    _scope.register<T>(factory, lazy: lazy, lifecycle: lifecycle, name: name);
  }

  /// Registers an asynchronous service.
  ///
  /// Similar to `register<T>`, but for services that are created via an
  /// asynchronous factory function (`asyncFactory`).
  ///
  /// Parameters:
  /// - `asyncFactory`: A function that returns a `Future<T>`, eventually resolving
  ///   to an instance of the service.
  /// - `lazy`, `lifecycle`, `name`: Behave the same as in `register<T>`.
  ///   For non-lazy singletons/scoped, the `asyncFactory` is awaited during registration.
  Future<void> registerAsync<T>(
    Future<T> Function() asyncFactory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) async {
    await _scope.registerAsync<T>(asyncFactory,
        lazy: lazy, lifecycle: lifecycle, name: name);
  }

  /// Retrieves a registered service instance of type `T`.
  ///
  /// If a `name` is provided, it retrieves the named instance. Otherwise, it
  /// retrieves the default (unnamed) instance.
  ///
  /// The behavior of instance creation and reuse depends on the `Lifecycle`
  /// specified during registration:
  /// - `Singleton`: Returns the same instance every time.
  /// - `Transient`: Returns a new instance every time.
  /// - `Scoped`: Returns the instance associated with the current scope (or the
  ///   nearest parent scope that has it registered).
  ///
  /// Throws an `InjectorException` if the service of type `T` (and optionally `name`)
  /// is not found, or if an async service is requested with `get` (use `getAsync`).
  T get<T>({String? name}) {
    try {
      return _scope.locate<T>(name: name);
    } catch (e, s) {
      _logger.severe('Error locating service of type $T: $e\nStack Trace: $s');
      if (errorNotifier != null && e is Exception) {
        errorNotifier!(e, s);
      }
      throw InjectorException(
        'Service of type $T${name == null ? "" : " (name: \'$name\')"} not found. The cosmic poetry of error unfolds.',
        stackTrace: s,
      );
    }
  }

  /// Retrieves a registered asynchronous service instance of type `T`.
  ///
  /// This is used for services registered with `registerAsync<T>`.
  /// If a `name` is provided, it retrieves the named instance.
  ///
  /// Throws an `InjectorException` if the service is not found.
  Future<T> getAsync<T>({String? name}) async {
    try {
      return await _scope.locateAsync<T>(name: name);
    } catch (e, s) {
      _logger.severe(
          'Error locating service of type $T asynchronously: $e\nStack Trace: $s');
      if (errorNotifier != null && e is Exception) {
        errorNotifier!(e, s);
      }
      throw InjectorException(
        'Async service of type $T${name == null ? "" : " (name: \'$name\')"} not found. The cosmic poetry of error unfolds.',
        stackTrace: s,
      );
    }
  }

  /// Creates a new `ServiceInjector` instance that is a child of this injector.
  ///
  /// The child injector will have its own `ServiceScope` which is a child of
  /// this injector's root scope. This allows for hierarchical scoping of services.
  /// Services registered in a parent scope are accessible in child scopes,
  /// unless overridden in the child.
  ///
  /// When this parent injector is disposed via `dispose()`, all its child scopes
  /// (and thus child injectors created this way) will also be disposed.
  ///
  /// Example:
  /// ```dart
  /// final parentInjector = ServiceInjector();
  /// parentInjector.register<AppConfig>(() => AppConfig());
  ///
  /// final childInjector = parentInjector.createChildScope();
  /// childInjector.register<UserSession>(() => UserSession());
  ///
  /// // AppConfig is available from childInjector
  /// final config = childInjector.get<AppConfig>();
  ///
  /// // UserSession is not available from parentInjector
  /// // parentInjector.get<UserSession>(); // This would throw
  ///
  /// parentInjector.dispose(); // This will also dispose childInjector's scope
  /// ```
  ServiceInjector createChildScope() {
    return ServiceInjector(scope: _scope.createChildScope());
  }

  /// Disposes this injector and its underlying root `ServiceScope`.
  ///
  /// This action triggers the disposal process for all services managed by this
  /// injector's scope and all its descendant child scopes. If a service
  /// implements the `Disposable` interface, its `dispose()` method will be called.
  ///
  /// This is crucial for releasing resources, closing connections, or performing
  /// any cleanup tasks associated with the services. After disposal, the injector
  /// and its scopes should not be used further.
  void dispose() {
    _scope.dispose();
  }
}

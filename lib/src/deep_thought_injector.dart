// src/deep_thought.dart

import 'package:deep_thought_injector/src/sub_etha_scope.dart';
import 'package:deep_thought_injector/src/vogon_poetry_exception.dart';
import 'package:logging/logging.dart';
import 'sub_etha_scope.dart'; // now includes Lifecycle

/// The Deep Thought Injector is a dependency injection library
class DeepThought {
  /// Create a new instance of the Deep Thought Injector.
  DeepThought({SubEthaScope? scope}) : _scope = scope ?? SubEthaScope();
  final SubEthaScope _scope;
  static Logger _logger = Logger('DeepThought');

  /// An optional error notifier for integrations (e.g., Sentry, Crashlytics).
  void Function(Exception e, StackTrace s)? errorNotifier;

  /// Set a custom logger (e.g. to integrate with an enterprise logging framework).
  static set logger(Logger customLogger) {
    _logger = customLogger;
  }

  /// Register a service with the injector.
  void ponder<T>(
    T Function() factory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) {
    _scope.register<T>(factory, lazy: lazy, lifecycle: lifecycle, name: name);
  }

  /// Register an asynchronous service.
  Future<void> ponderAsync<T>(
    Future<T> Function() asyncFactory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) async {
    await _scope.registerAsync<T>(asyncFactory,
        lazy: lazy, lifecycle: lifecycle, name: name);
  }

  /// Locate a service in the injector.
  T question<T>({String? name}) {
    try {
      return _scope.locate<T>(name: name);
    } catch (e, s) {
      _logger.severe('Error locating service of type $T: $e\nStack Trace: $s');
      if (errorNotifier != null && e is Exception) {
        errorNotifier!(e, s);
      }
      throw VogonPoetryException(
        'Service of type $T not found. The cosmic poetry of error unfolds.',
        stackTrace: s,
      );
    }
  }

  /// Retrieve a service asynchronously.
  Future<T> questionAsync<T>({String? name}) async {
    try {
      return await _scope.locateAsync<T>(name: name);
    } catch (e, s) {
      _logger.severe(
          'Error locating service of type $T asynchronously: $e\nStack Trace: $s');
      if (errorNotifier != null && e is Exception) {
        errorNotifier!(e, s);
      }
      throw VogonPoetryException(
        'Async service of type $T not found. The cosmic poetry of error unfolds.',
        stackTrace: s,
      );
    }
  }

  /// Create a child scope for nested dependency injection.
  DeepThought createChildScope() {
    return DeepThought(scope: _scope.createChildScope());
  }
}

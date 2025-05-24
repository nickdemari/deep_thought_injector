// service_injector.dart

/// A flexible and easy-to-use dependency injection (DI) library for Dart and Flutter.
///
/// `service_injector` provides a way to decouple your application's components
/// by managing the instantiation and provision of services. It supports different
/// service lifecycles (singleton, transient, scoped) and allows for both eager
/// and lazy initialization.
///
/// Key features:
/// - **Service Registration**: Register services with various lifecycles.
/// - **Service Retrieval**: Easily get instances of your registered services.
/// - **Scoped Instances**: Create services that are unique to a specific scope (e.g., a user session).
/// - **Hierarchical Scopes**: Child scopes inherit and can override services from parent scopes.
/// - **Disposal**: Services implementing `Disposable` can be cleaned up when their scope is disposed.
/// - **Named Registrations**: Register multiple services of the same type using names.
///
/// Inspired by libraries like `get_it`, `service_injector` aims to offer a
/// straightforward API for managing dependencies in your Dart projects.
library service_injector;

export 'src/service_injector.dart';
export 'src/service_scope.dart';
export 'src/injector_exception.dart';

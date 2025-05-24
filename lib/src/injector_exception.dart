// src/injector_exception.dart

/// Base class for exceptions thrown by the `service_injector` library.
///
/// This exception is thrown when errors occur during service registration,
/// retrieval, or other operations within the `ServiceInjector` or `ServiceScope`.
/// It can optionally include an `errorCode` and a `stackTrace` for more
/// detailed error reporting.
class InjectorException implements Exception {
  /// A common error code indicating that a requested service was not found.
  static const int serviceNotFoundError = 1001;

  /// Creates an `InjectorException`.
  ///
  /// - [cause]: A human-readable message describing the error.
  /// - [errorCode]: An optional integer code for categorizing the error.
  /// - [stackTrace]: An optional stack trace associated with the error.
  const InjectorException(this.cause, {this.errorCode, this.stackTrace});

  /// The primary message describing the cause of the exception.
  final String cause;

  /// An optional integer code that provides further context about the error.
  ///
  /// For example, `serviceNotFoundError` indicates a lookup failure.
  final int? errorCode;

  /// The stack trace associated with this exception, if available.
  ///
  /// Useful for debugging the origin of the error.
  final StackTrace? stackTrace;

  @override
  String toString() {
    var base = errorCode != null
        ? 'InjectorException ($errorCode): $cause'
        : 'InjectorException: $cause';
    // Append stack trace if provided.
    if (stackTrace != null) {
      base += '\nStack Trace: $stackTrace';
    }
    return base;
  }
}

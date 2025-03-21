// src/vogon_poetry_exception.dart
/// An exception thrown by the Vogon Poetry subsystem.
class VogonPoetryException implements Exception {
  // Standard error code for service not found.
  static const int serviceNotFoundError = 1001;

  // Updated: Added an optional stackTrace for enhanced debugging.
  const VogonPoetryException(this.cause, {this.errorCode, this.stackTrace});

  /// The cause of the exception.
  final String cause;

  /// An optional error code for more context.
  final int? errorCode;

  /// An optional stack trace for debugging.
  final StackTrace? stackTrace;

  @override
  String toString() {
    var base = errorCode != null
        ? 'VogonPoetryException ($errorCode): $cause'
        : 'VogonPoetryException: $cause';
    // Append stack trace if provided.
    if (stackTrace != null) {
      base += '\nStack Trace: $stackTrace';
    }
    return base;
  }
}

/// Represents configuration settings for the `ServiceInjector`.
///
/// While `ServiceInjector` itself doesn't heavily rely on this configuration
/// directly for its core DI functionalities, `InjectorConfig` provides a
/// standardized way to pass application-level settings (like environment,
/// feature flags, or external service keys) to services that might need them.
///
/// It's particularly used by `DefaultRegistrations` to demonstrate how
/// configuration can influence service registration (e.g., the 'autoRegister'
/// feature for loggers).
///
/// A typical use case is to register an instance of `InjectorConfig` itself
/// with the `ServiceInjector`, making it available for other services to depend on.
class InjectorConfig {
  /// Creates a new `InjectorConfig`.
  ///
  /// - [environment]: A string indicating the current operating environment
  ///   (e.g., 'development', 'staging', 'production'). Defaults to 'production'.
  /// - [environmentOverrides]: A map for environment-specific dynamic configurations.
  ///   For example, this might hold feature flags or service endpoints that
  ///   differ per environment. The `DefaultRegistrations` class looks for an
  ///   'autoRegister' key here.
  /// - [secrets]: A map for storing sensitive information like API keys.
  ///   **Note**: In a real application, consider more secure ways to handle secrets.
  InjectorConfig({
    this.environment = 'production',
    this.environmentOverrides,
    this.secrets,
  });

  /// The current operating environment (e.g., 'development', 'staging', 'production').
  final String environment;

  /// Optional environment-specific dynamic configurations.
  ///
  /// This map can be used to store any configuration values that vary by
  /// environment, such as feature flags or alternative service URLs.
  /// The `DefaultRegistrations` utility uses this to look for an 'autoRegister'
  /// list of logger names.
  final Map<String, dynamic>? environmentOverrides;

  /// Optional map for storing secrets like API keys.
  ///
  /// **Security Warning**: Storing plain text secrets in source code or directly
  /// in memory like this is generally discouraged for production applications.
  /// Consider using environment variables, secure vaults, or platform-specific
  /// secret management solutions.
  final Map<String, String>? secrets;

  /// A factory method to create an `InjectorConfig` instance.
  ///
  /// This example demonstrates a simple way to construct the config, potentially
  /// drawing from environment variables or other sources in a more complete implementation.
  ///
  /// - [defaultEnv]: The default environment if not otherwise specified.
  /// - [overrides]: Pre-populates `environmentOverrides`.
  /// - [secrets]: Pre-populates `secrets`.
  ///
  /// In a full application, you might use `String.fromEnvironment` to get the
  /// environment or use a build system to inject these values.
  static InjectorConfig fromEnvironment({
    String defaultEnv = 'production',
    Map<String, dynamic>? overrides,
    Map<String, String>? secrets,
  }) {
    // For simplicity in this example, it just uses the provided defaults.
    // A real implementation might fetch actual environment variables here.
    return InjectorConfig(
      environment: defaultEnv, // In real app: const String.fromEnvironment('ENV', defaultValue: 'production')
      environmentOverrides: overrides,
      secrets: secrets,
    );
  }
}

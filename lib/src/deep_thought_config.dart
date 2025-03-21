/// Configuration for the Deep Thought service.
/// This class is used to configure the Deep Thought service.
/// The environment property is used to determine the current environment.
/// The environment can be 'development', 'staging', or 'production'.
/// The default environment is 'production'.
class DeepThoughtConfig {
  /// Create a new Deep Thought configuration.
  DeepThoughtConfig({
    this.environment = 'production',
    this.environmentOverrides,
    this.secrets,
  });

  /// The current environment (e.g. 'development', 'staging', 'production')
  final String environment;

  /// Optional environment-specific configuration overrides.
  final Map<String, dynamic>? environmentOverrides;

  /// Optional secret management (e.g. API keys).
  final Map<String, String>? secrets;

  /// Creates a config from environment variables.
  /// In a full implementation, you might use [const String.fromEnvironment] or other secure store.
  static DeepThoughtConfig fromEnvironment({
    String defaultEnv = 'production',
    Map<String, dynamic>? overrides,
    Map<String, String>? secrets,
  }) {
    // For simplicity, use defaultEnv; enhance as needed.
    return DeepThoughtConfig(
      environment: defaultEnv,
      environmentOverrides: overrides,
      secrets: secrets,
    );
  }
}

/// Provides a utility method to register a common set of default services
/// with a `ServiceInjector` instance.
///
/// This class simplifies the initial setup of an injector by pre-registering
/// services that are often needed, such as a default logger and an application
/// configuration object. It also includes a basic mechanism for registering
/// additional named loggers based on settings in the `InjectorConfig`.
import 'package:deep_thought_injector/service_injector.dart';
import 'package:deep_thought_injector/src/injector_config.dart';
import 'package:logging/logging.dart';

/// A utility class for registering a set of default services.
class DefaultRegistrations {
  /// Registers a collection of default services with the provided [injector].
  ///
  /// This method is designed to be called early in the application setup
  /// to ensure essential services are available through the injector.
  ///
  /// The following services are registered:
  ///
  /// 1.  **Default `Logger`**:
  ///     - Registers a `Logger` instance named 'DefaultLogger'.
  ///     - This logger can be retrieved via `injector.get<Logger>()`.
  ///     - If a `Logger` (unnamed) is already registered, this step is skipped.
  ///
  /// 2.  **`InjectorConfig`**:
  ///     - Registers an `InjectorConfig` instance, created using the
  ///       `InjectorConfig.fromEnvironment()` factory method.
  ///     - This is registered as a non-lazy singleton.
  ///     - It makes application configuration accessible to other services.
  ///     - If an `InjectorConfig` is already registered, this step is skipped.
  ///
  /// 3.  **Named Loggers via `autoRegister`**:
  ///     - Retrieves the registered `InjectorConfig`.
  ///     - Looks for a key named `'autoRegister'` within the config's
  ///       `environmentOverrides` map.
  ///     - If `autoRegister` is found and is a `List<String>`, each string in
  ///       the list is used as a name to register a new `Logger` instance.
  ///       For example, if `autoRegister: ['DatabaseLogger', 'NetworkLogger']`,
  ///       then `Logger('DatabaseLogger')` will be registered with the name
  ///       'DatabaseLogger', and `Logger('NetworkLogger')` with the name 'NetworkLogger'.
  ///     - This provides a simple, configuration-driven way to make specific
  ///       loggers available.
  ///     - If a named logger from this list is already registered, its registration
  ///       is skipped.
  ///
  /// **Error Handling**:
  /// The method includes `try-catch` blocks for each registration attempt. If a
  /// service (e.g., the default `Logger` or `InjectorConfig`) is already registered,
  /// the `InjectorException` is caught, and the registration is skipped, allowing
  /// manual pre-registration if needed. Errors during the processing of the
  /// `autoRegister` list (e.g., `InjectorConfig` not found, list malformed) are
  /// also caught and ignored, ensuring this utility method doesn't crash the app.
  ///
  /// Example Usage:
  /// ```dart
  /// final injector = ServiceInjector();
  /// DefaultRegistrations.register(injector);
  ///
  /// // Now you can get the default logger and config:
  /// final logger = injector.get<Logger>();
  /// final config = injector.get<InjectorConfig>();
  ///
  /// // If 'MyCustomLogger' was in config.environmentOverrides['autoRegister']:
  /// // final customLogger = injector.get<Logger>(name: 'MyCustomLogger');
  /// ```
  static void register(ServiceInjector injector) {
    // Register a default Logger if not already registered.
    try {
      injector.register<Logger>(() => Logger('DefaultLogger'));
    } catch (e) {
      // Ignore duplicate registration.
    }

    // Register a default InjectorConfig if not already registered.
    try {
      injector.register<InjectorConfig>(
        InjectorConfig.fromEnvironment,
        lazy: false,
      );
    } catch (e) {
      // Ignore duplicate registration.
    }

    // Automatically register dependencies based on configuration or annotations.
    try {
      final config = injector.get<InjectorConfig>();
      // Check if the configuration provides an 'autoRegister' list in its environmentOverrides.
      final autoRegs = config.environmentOverrides?['autoRegister'];
      if (autoRegs is List<String>) {
        for (final loggerName in autoRegs) {
          // Current 'autoRegister' mechanism:
          // - This feature is a simplified stand-in for more complex auto-wiring.
          // - It currently ONLY registers instances of `Logger`.
          // - Each string in the `autoRegister` list is used as the *name*
          //   for a new `Logger` instance.
          // - This does not involve scanning constructors or types beyond Logger.
          try {
            injector.register<Logger>(() => Logger(loggerName), name: loggerName);
          } catch (e) {
            // Ignore if a logger with this name is already registered.
          }
        }
      }
    } catch (e) {
      // Ignore errors if InjectorConfig isn't available, or if 'autoRegister'
      // config is absent or malformed.
    }

    // Note: The original "Future auto-wiring" comment has been removed as this
    // class is now focused on "DefaultRegistrations" rather than "AutoWiring".
    // More advanced auto-wiring could be a separate feature/class.
  }
}

import 'package:deep_thought_injector/service_injector.dart';
import 'package:deep_thought_injector/src/default_registrations.dart';
import 'package:deep_thought_injector/src/injector_config.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  late ServiceInjector injector;

  setUp(() {
    injector = ServiceInjector();
  });

  tearDown(() {
    try {
      injector.dispose();
    } catch (_) {
      // Ignore
    }
  });

  group('DefaultRegistrations.register', () {
    test('registers default Logger', () {
      DefaultRegistrations.register(injector);
      final logger = injector.get<Logger>();
      expect(logger, isA<Logger>());
      // DefaultRegistrations registers it as 'DefaultLogger'
      // If ServiceInjector.logger uses this name, this test might be more specific.
      // For now, just check if *a* Logger is available.
    });

    test('registers default InjectorConfig', () {
      DefaultRegistrations.register(injector);
      final config = injector.get<InjectorConfig>();
      expect(config, isA<InjectorConfig>());
      // Check some default values if they are stable
      expect(config.environment, 'production'); // As per InjectorConfig.fromEnvironment default
    });

    test('does not throw if default Logger is already registered', () {
      injector.register<Logger>(() => Logger('MyCustomRootLogger'));
      expect(() => DefaultRegistrations.register(injector), returnsNormally);
      final logger = injector.get<Logger>();
      expect(logger.name, 'MyCustomRootLogger'); // Ensures custom one is kept
    });

    test('does not throw if default InjectorConfig is already registered', () {
      final customConfig = InjectorConfig(environment: 'test');
      injector.register<InjectorConfig>(() => customConfig);
      expect(() => DefaultRegistrations.register(injector), returnsNormally);
      final config = injector.get<InjectorConfig>();
      expect(config.environment, 'test'); // Ensures custom one is kept
      expect(identical(config, customConfig), isTrue);
    });

    group('autoRegister feature for Loggers', () {
      test('registers named Loggers from autoRegister list', () {
        final mockConfig = InjectorConfig(
          environmentOverrides: {
            'autoRegister': ['NetLogger', 'UILogger'],
          },
        );
        injector.register<InjectorConfig>(() => mockConfig); // Register the mock config first
        DefaultRegistrations.register(injector);

        final netLogger = injector.get<Logger>(name: 'NetLogger');
        final uiLogger = injector.get<Logger>(name: 'UILogger');
        final defaultLogger = injector.get<Logger>();


        expect(netLogger, isA<Logger>());
        expect(netLogger.name, 'NetLogger');
        expect(uiLogger, isA<Logger>());
        expect(uiLogger.name, 'UILogger');
        expect(defaultLogger.name, 'DefaultLogger'); // Default logger from DefaultRegistrations

        expect(identical(netLogger, uiLogger), isFalse);
        expect(identical(netLogger, defaultLogger), isFalse);
      });

      test('handles empty autoRegister list gracefully', () {
        final mockConfig = InjectorConfig(
          environmentOverrides: {
            'autoRegister': <String>[],
          },
        );
        injector.register<InjectorConfig>(() => mockConfig);
        DefaultRegistrations.register(injector);

        expect(() => injector.get<Logger>(name: 'AnyLogger'), throwsA(isA<InjectorException>()));
        // Default logger should still be there
        expect(injector.get<Logger>(), isA<Logger>());
      });
      
      test('handles autoRegister list with duplicate names gracefully (first one wins)', () {
        final mockConfig = InjectorConfig(
          environmentOverrides: {
            'autoRegister': ['DupLogger', 'DupLogger'],
          },
        );
        injector.register<InjectorConfig>(() => mockConfig);
        DefaultRegistrations.register(injector);
        
        expect(() => injector.get<Logger>(name: 'DupLogger'), returnsNormally);
        // The internal try-catch in DefaultRegistrations.register should prevent crash
      });


      test('handles autoRegister when environmentOverrides is null', () {
        final mockConfig = InjectorConfig(environmentOverrides: null);
        injector.register<InjectorConfig>(() => mockConfig);
        DefaultRegistrations.register(injector);
        // No named loggers should be registered, no error should occur
        expect(() => injector.get<Logger>(name: 'AnyLoggerAuto'), throwsA(isA<InjectorException>()));
      });

      test('handles autoRegister when autoRegister key is not a List<String>', () {
        final mockConfig = InjectorConfig(
          environmentOverrides: {
            'autoRegister': 'NotAList', // Invalid type
          },
        );
        injector.register<InjectorConfig>(() => mockConfig);
        DefaultRegistrations.register(injector);
        // Should not register any named loggers and not throw
        expect(() => injector.get<Logger>(name: 'AnyLoggerAuto'), throwsA(isA<InjectorException>()));
      });
      
      test('handles autoRegister when InjectorConfig is not registered', () {
        // No InjectorConfig registered
        DefaultRegistrations.register(injector);
        // Should not throw, and no named loggers from autoRegister should exist
        expect(() => injector.get<Logger>(name: 'AnyLoggerAuto'), throwsA(isA<InjectorException>()));
        // Default logger should still be there
        final defaultLogger = injector.get<Logger>();
        expect(defaultLogger, isA<Logger>());
        expect(defaultLogger.name, 'DefaultLogger');
      });
    });
  });
}

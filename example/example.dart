// example/example.dart

import 'package:deep_thought_injector/service_injector.dart';
import 'package:logging/logging.dart';

// 0. Setup a logger for the example
final Logger _logger = Logger('InjectorExample');

// 1. Define some services
abstract class ApiService {
  String fetchData();
}

class RealApiService implements ApiService, Disposable {
  RealApiService() {
    _logger.info('RealApiService created');
  }

  @override
  String fetchData() => 'Data from RealApiService';

  @override
  void dispose() {
    _logger.info('RealApiService disposed');
  }
}

class MockApiService implements ApiService {
  @override
  String fetchData() => 'Data from MockApiService';
}

class SettingsService implements Disposable {
  final String _id;
  SettingsService() : _id = DateTime.now().microsecondsSinceEpoch.toString() {
    _logger.info('SettingsService created (id: $_id)');
  }

  String get theme => 'dark';

  @override
  void dispose() {
    _logger.info('SettingsService disposed (id: $_id)');
  }
}

// A simple view model or presenter like class
class FeatureViewModel implements Disposable {
  final ApiService apiService;
  final String id;
  static int _instanceCount = 0;

  FeatureViewModel({required this.apiService}) : id = 'ViewModel-${++_instanceCount}' {
    _logger.info('FeatureViewModel created (id: $id) with ${apiService.runtimeType}');
  }

  void init() {
    _logger.info('FeatureViewModel (id: $id) initialized: ${apiService.fetchData()}');
  }

  @override
  void dispose() {
    _logger.info('FeatureViewModel (id: $id) disposed');
  }
}

// An async factory example
Future<String> loadHeavyConfig() async {
  _logger.info('Async factory: Starting heavy config load...');
  await Future.delayed(const Duration(seconds: 1));
  _logger.info('Async factory: Heavy config loaded!');
  return 'LoadedConfigData';
}


void main() async {
  // Call _setupLogger() at the beginning of main if you want to see detailed logs
   _setupLogging(); // Renamed for consistency

  // 2. Create an instance of the ServiceInjector
  // This is similar to GetIt.instance
  final injector = ServiceInjector();

  // Optional: Setup error notifier
  injector.errorNotifier = (e, s) {
    _logger.severe('SERVICE INJECTOR ERROR', e, s);
  };
  
  // Optional: Setup default registrations (Logger, InjectorConfig)
  // DefaultRegistrations.register(injector); // Assuming DefaultRegistrations is available

  _logger.info('--- Registering services ---');

  // 3. Register services
  // Singleton (eagerly created, like get_it.registerSingleton())
  injector.register<ApiService>(() => RealApiService(), lifecycle: Lifecycle.singleton, lazy: false);

  // Lazy Singleton (like get_it.registerLazySingleton())
  injector.register<SettingsService>(() => SettingsService(), lifecycle: Lifecycle.singleton); // lazy is true by default

  // Factory/Transient (like get_it.registerFactory())
  injector.register<FeatureViewModel>(
    () => FeatureViewModel(apiService: injector.get<ApiService>()),
    lifecycle: Lifecycle.transient,
  );

  // Async factory registration for a singleton
  // The factory itself is async. ServiceInjector's registerAsync handles this.
  // The resolved type will be String.
  await injector.registerAsync<String>(() async {
    final config = await loadHeavyConfig();
    return config;
  }, name: 'appConfig', lifecycle: Lifecycle.singleton, lazy: false);


  _logger.info('--- Retrieving services ---');

  // 4. Retrieve services
  final apiService = injector.get<ApiService>();
  _logger.info('Retrieved ApiService: ${apiService.fetchData()}');

  final settings = injector.get<SettingsService>();
  _logger.info('Retrieved Settings theme: ${settings.theme}');
  final settings2 = injector.get<SettingsService>();
  _logger.info('Retrieved Settings again - is it the same instance? ${identical(settings, settings2)}'); // Should be true

  final viewModel1 = injector.get<FeatureViewModel>();
  viewModel1.init();
  final viewModel2 = injector.get<FeatureViewModel>();
  viewModel2.init();
  _logger.info('Retrieved ViewModels - are they the same instance? ${identical(viewModel1, viewModel2)}'); // Should be false

  final appConfig = await injector.getAsync<String>(name: 'appConfig');
  _logger.info('Retrieved async appConfig: $appConfig');


  _logger.info('--- Scoped services example ---');
  // 5. Using a child scope
  final scope1 = injector.createChildScope();
  scope1.register<FeatureViewModel>(
    () => FeatureViewModel(apiService: scope1.get<ApiService>()), // Gets ApiService from parent
    lifecycle: Lifecycle.scoped, // Scoped to scope1
  );
  // Override SettingsService for scope1 with a new instance, scoped to scope1
  scope1.register<SettingsService>(() => SettingsService(), lifecycle: Lifecycle.scoped); 

  final scopedViewModel1_scope1 = scope1.get<FeatureViewModel>();
  scopedViewModel1_scope1.init();
  final scopedViewModel2_scope1 = scope1.get<FeatureViewModel>();
  _logger.info('Scoped ViewModels in scope1 - are they the same instance? ${identical(scopedViewModel1_scope1, scopedViewModel2_scope1)}'); // Should be true

  final settings_scope1 = scope1.get<SettingsService>();
  _logger.info('Settings in scope1 theme: ${settings_scope1.theme}');
  _logger.info('Settings in scope1 - is it the same as root settings? ${identical(settings_scope1, settings)}'); // Should be false

  // Create another child scope from root
  final scope2 = injector.createChildScope();
  scope2.register<FeatureViewModel>(
    () => FeatureViewModel(apiService: scope2.get<ApiService>()),
    lifecycle: Lifecycle.scoped,
  );
  final scopedViewModel_scope2 = scope2.get<FeatureViewModel>();
  _logger.info('Scoped ViewModel in scope2 - is it the same as scope1's? ${identical(scopedViewModel_scope2, scopedViewModel1_scope1)}'); // Should be false


  _logger.info('--- Disposing ---');
  // 6. Dispose of the injector (and all its child scopes and services)
  // scope1 and scope2 will be disposed first as they are children of injector's root scope.
  injector.dispose();

  // Trying to get a service after disposal should fail
  try {
    final disposedService = injector.get<ApiService>(); // This will throw
    _logger.info('Retrieved service after dispose: ${disposedService.fetchData()}');
  } catch (e) {
    _logger.warning('Error getting service after dispose: $e'); // Expected
  }
  
  _logger.info('--- Example End ---');
}

// Helper to configure the logger (optional, for seeing output)
void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('\${record.level.name}: \${record.time}: \${record.loggerName}: \${record.message}');
    if (record.error != null) {
      print('Error: \${record.error}, StackTrace: \${record.stackTrace}');
    }
  });
}

// Make sure to add `logging` to your pubspec.yaml
// dependencies:
//   logging: ^1.0.0 # or latest version
//   deep_thought_injector:
//     path: ../ # If running example from within the project

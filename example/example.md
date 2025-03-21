# Example Usage of `DeepThoughtInjector`

This guide provides a step‑by‑step walkthrough on how to use the `DeepThoughtInjector` package in your Flutter application. `DeepThoughtInjector` is a whimsical yet powerful dependency injection and service locator package inspired by "The Hitchhiker's Guide to the Galaxy".

## Getting Started

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  deep_thought_injector: ^1.0.0
```

## Usage Example

Below is an example of how to define a service, register it, and then retrieve and use it:

```dart
// Define your service
class YourService {
  void doSomething() {
    print('Service is working');
  }
}

final deepThought = DeepThought();

// Register the service with a factory function (non‑lazy initialization)
deepThought.ponder<YourService>(() => YourService(), lazy: false);

// Retrieve the registered service and use it
final service = deepThought.question<YourService>();
service.doSomething();
```

## Transient Service Example

A transient service is one which produces a new instance every time it is retrieved. This example demonstrates the distinct instances:

```dart
// Define a transient service
class TransientService {
  void greet() {
    print('Hello from a transient service');
  }
}

final deepThought = DeepThought();

// Register the service with a transient lifecycle.
// Each call to question creates a new instance.
deepThought.ponder<TransientService>(
  () => TransientService(),
  lifecycle: Lifecycle.transient,
);

// Retrieve two distinct instances
final instance1 = deepThought.question<TransientService>();
final instance2 = deepThought.question<TransientService>();

print(identical(instance1, instance2)); // false, different instances are created.
```

## Asynchronous Service Example

This example shows how to define an asynchronous service, register it with `ponderAsync`, and retrieve it using `questionAsync`. Notice the use of try-catch blocks to handle potential initialization errors gracefully.

```dart
import 'package:logging/logging.dart';

// Define an asynchronous service
class AsyncExampleService {
  final int data;
  AsyncExampleService(this.data);

  void printData() {
    print('Async service data: $data');
  }
}

// Initialize a logger for production diagnostics.
final logger = Logger('AsyncExampleServiceExample');

final deepThought = DeepThought();

// Asynchronous factory for the service
Future<AsyncExampleService> asyncServiceFactory() async {
  await Future.delayed(Duration(milliseconds: 100));
  return AsyncExampleService(999);
}

Future<void> registerAndUseAsyncService() async {
  try {
    // Register the asynchronous service.
    await deepThought.ponderAsync<AsyncExampleService>(asyncServiceFactory);

    // Retrieve and use the asynchronous service.
    final asyncService = await deepThought.questionAsync<AsyncExampleService>();
    asyncService.printData();
  } catch (e, st) {
    logger.severe('Failed to register or retrieve AsyncExampleService', e, st);
  }
}

void main() async {
  await registerAndUseAsyncService();
}
```

In these examples the code emphasizes:

- **Explicit Error Handling:** Avoids silent failures by logging issues.
- **Lifecycle and Asynchronous Support:** Clearly distinguishes between transient and asynchronous registration.
- **Production Diagnostics:** Utilizes the `logging` package to enable better diagnostics in production environments.

This updated documentation should help developers integrate `DeepThoughtInjector` confidently into enterprise‑grade Flutter projects.


/// Abstract interface for push services
/// Allows unified handling of HTTP, WebSocket, OSC, and MQTT pushes
abstract class PushService {
  /// Initialize the service
  Future<void> initialize();

  /// Send a payload
  Future<void> send(Map<String, dynamic> payload);

  /// Check if service is enabled based on configuration
  bool get isEnabled;

  /// Service name for logging
  String get serviceName;

  /// Dispose resources
  void dispose();
}

/// What the network allows right now.
enum NetState { offline, wifi, cellular, other }

abstract interface class NetworkMonitor {
  Future<NetState> current();

  /// Emits on every change.
  Stream<NetState> watch();
}

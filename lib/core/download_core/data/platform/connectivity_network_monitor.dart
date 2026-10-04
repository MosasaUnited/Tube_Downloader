import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tube_downloader/core/download_core/domain/repos/network_monitor.dart';

/// [NetworkMonitor] on connectivity_plus. A connection type is not proof of
/// internet access — the transport's own failures cover that case.
class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetState> current() async =>
      _map(await _connectivity.checkConnectivity());

  @override
  Stream<NetState> watch() =>
      _connectivity.onConnectivityChanged.map(_map).distinct();

  static NetState _map(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetState.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) return NetState.cellular;
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetState.offline;
    }
    return NetState.other; // VPN, Bluetooth, other
  }
}

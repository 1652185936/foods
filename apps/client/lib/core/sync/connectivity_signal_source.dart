import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectivitySignalSource {
  Future<bool> isConnected();

  Stream<bool> get changes;
}

final class ConnectivityPlusSignalSource implements ConnectivitySignalSource {
  ConnectivityPlusSignalSource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isConnected() async {
    return _hasConnection(await _connectivity.checkConnectivity());
  }

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

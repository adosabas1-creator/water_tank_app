import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  bool? _lastKnownOnline;

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((result) {
        final online = !result.contains(ConnectivityResult.none);

        _lastKnownOnline = online;

        print('SYNC CONNECTIVITY STREAM RAW: $result');
        print('SYNC CONNECTIVITY STREAM ONLINE: $online');

        return online;
      });

  Future<bool> isOnline() async {
    // Once the connectivity stream has reported a state, prefer that
    // state over checkConnectivity(), whose result may be stale/inconsistent
    // on some Android devices.
    if (_lastKnownOnline == true) {
      print('SYNC CONNECTIVITY CACHED ONLINE: true');
      return true;
    }

    final result = await _connectivity.checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);

    _lastKnownOnline = online;

    print('SYNC CONNECTIVITY RAW: $result');
    print('SYNC CONNECTIVITY ONLINE: $online');

    return online;
  }
}

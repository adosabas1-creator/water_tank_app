import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((result) => !result.contains(ConnectivityResult.none));

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);
    print('CONNECTIVITY DEBUG: result=$result online=$online');
    return online;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../network/sync_service.dart';
import 'user_provider.dart';

/// يراقب تفاعل المستخدم ويسجّل الخروج بعد [timeout] من الخمول.
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.timeout = const Duration(minutes: 15),
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final Duration timeout;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;
    _timer = Timer(widget.timeout, _onTimeout);
  }

  Future<void> _onTimeout() async {
    if (_loggingOut || !mounted) return;
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null) return;

    _loggingOut = true;
    try {
      final sync = SyncService();
      var waited = 0;
      while (sync.isSyncInProgress && waited < 60) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        waited++;
      }

      await userProvider.logout();

      final nav = widget.navigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      debugPrint('Inactivity logout failed: $e');
    } finally {
      _loggingOut = false;
    }
  }

  void _onUserInteraction([_]) {
    if (_loggingOut) return;
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>().currentUser;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onUserInteraction,
      onPointerMove: _onUserInteraction,
      onPointerSignal: _onUserInteraction,
      child: widget.child,
    );
  }
}

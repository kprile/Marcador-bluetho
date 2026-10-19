import 'dart:async';

/// DOWN events only. Wait for a complete group so three clicks can undo safely.
class RemoteClicks {
  final void Function(int team) onPoint;
  final void Function() onUndo;
  Duration window;
  Timer? _timer;
  int _count=0;
  RemoteClicks({required this.onPoint, required this.onUndo,
    this.window=const Duration(milliseconds:420)});
  void press() {
    _timer?.cancel();
    _count++;
    if(_count>=3) { cancel();onUndo();return; }
    _timer=Timer(window,(){
      final count=_count;
      _timer=null;_count=0;
      if(count==1) onPoint(0);
      else if(count==2) onPoint(1);
    });
  }
  void cancel() { _timer?.cancel();_timer=null;_count=0; }
}

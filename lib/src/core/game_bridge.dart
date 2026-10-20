import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../bindings/bindings.dart';
import 'lexicon.dart';

class GameBridge extends ChangeNotifier {
  GameBridge._();

  static final GameBridge instance = GameBridge._();

  Catalog? catalog;
  PlayerState? state;

  final _spins = StreamController<SpinOutcome>.broadcast();
  final _wheels = StreamController<WheelOutcome>.broadcast();
  final _toasts = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _lines = [];

  Stream<SpinOutcome> get spins => _spins.stream;
  Stream<WheelOutcome> get wheels => _wheels.stream;
  Stream<String> get toasts => _toasts.stream;

  bool get ready => Lex.ready && catalog != null && state != null;

  Future<void> boot() async {
    final settled = Completer<void>();
    void check() {
      if (ready && !settled.isCompleted) {
        settled.complete();
      }
    }

    _lines.addAll([
      Lexicon.rustSignalStream.listen((pack) {
        Lex.load(pack.message);
        check();
      }),
      Catalog.rustSignalStream.listen((pack) {
        catalog = pack.message;
        check();
      }),
      StateUpdate.rustSignalStream.listen((pack) {
        state = pack.message.state;
        notifyListeners();
        check();
      }),
      SpinOutcome.rustSignalStream.listen((pack) {
        state = pack.message.state;
        _spins.add(pack.message);
      }),
      WheelOutcome.rustSignalStream.listen((pack) {
        state = pack.message.state;
        _wheels.add(pack.message);
        notifyListeners();
      }),
      Toast.rustSignalStream.listen((pack) => _toasts.add(pack.message.text)),
    ]);

    var storage = Lex.blank;
    try {
      storage = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      storage = Lex.blank;
    }
    BootRequest(storageDir: storage).sendSignalToRust();
    await settled.future;
  }

  void publish() => notifyListeners();

  void say(String text) => _toasts.add(text);

  void enter(int room) => EnterRoom(room: room).sendSignalToRust();

  void changeBet(int step) => ChangeBet(step: step).sendSignalToRust();

  void spin({bool auto = false}) => SpinRequest(auto: auto).sendSignalToRust();

  void spinWheel({required bool daily}) => WheelSpinRequest(daily: daily).sendSignalToRust();

  void refill() => const RefillRequest(accepted: true).sendSignalToRust();

  RoomDef? room(int index) {
    final rooms = catalog?.rooms;
    if (rooms == null || index < 0 || index >= rooms.length) {
      return null;
    }
    return rooms[index];
  }
}

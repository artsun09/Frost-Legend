import '../bindings/bindings.dart';

/// Text keys. Order mirrors `Txt` in `native/hub/src/lexicon.rs`.
enum T {
  appTitle,
  fontFamily,
  loading,
  tip1,
  tip2,
  tip3,
  allow,
  later,
  notifHint,
  play,
  chooseRealm,
  dailyWheel,
  settings,
  privacy,
  support,
  close,
  lobby,
  balance,
  bet,
  win,
  spin,
  auto,
  stop,
  freeSpins,
  collect,
  bonusWheel,
  spinWheel,
  youWon,
  totalWin,
  jackpot,
  levelUp,
  reward,
  refill,
  refillText,
  take,
  info,
  paytable,
  disclaimer,
  webError,
  retry,
  tapToContinue,
  lines,
  separator,
  sufK,
  sufM,
  sufB,
  times,
  plus,
  space,
  wild,
  scatter,
  dailyText,
  freeSpinsDone,
  locked,
  coins,
  spins,
  lvl,
  notEnough,
  lockedRoom,
  finishBonus,
  betLocked,
  spinNow,
  comeBack,
  bigWin,
  megaWin,
  epicWin,
  catchCollected,
  expands,
  lightning,
  of,
}

/// Asset keys. Order mirrors `Ast` in `native/hub/src/lexicon.rs`.
enum A {
  bg1,
  bg2,
  candies,
  fishes,
  fruits2,
  fruits,
  gems,
  headJoker,
  joker,
  lollipop,
  magic,
  manWinter,
  manWinterRod,
  manWinterRod2,
  badges,
  rod,
  bar,
  bells,
  wheelFire,
  wheelIce,
  wheelSweet,
  wheelZeus,
  zeus,
  gameName,
  hLoading,
  hNotif,
  icon,
  vLoading,
  vNotif,
}

/// External links. Order mirrors `links()` in `native/hub/src/lexicon.rs`.
enum L { privacy, support }

abstract final class Lex {
  static final String blank = String.fromCharCodes(const <int>[]);
  static List<String> _texts = const [];
  static List<String> _assets = const [];
  static List<String> _links = const [];

  static bool get ready => _texts.isNotEmpty;

  static void load(Lexicon lexicon) {
    _texts = lexicon.texts;
    _assets = lexicon.assets;
    _links = lexicon.links;
  }

  static String text(T key) => key.index < _texts.length ? _texts[key.index] : blank;

  static String assetAt(int index) => index < _assets.length ? _assets[index] : blank;

  static String asset(A key) => assetAt(key.index);

  static int get assetCount => _assets.length;

  static String link(L key) => key.index < _links.length ? _links[key.index] : blank;

  static String join(List<String> parts) => parts.join(text(T.space));
}

String tx(T key) => Lex.text(key);

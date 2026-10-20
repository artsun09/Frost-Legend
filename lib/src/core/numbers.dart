import 'lexicon.dart';

String grouped(int value) {
  final digits = value.abs().toString();
  final separator = tx(T.separator);
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(separator);
    }
    out.write(digits[i]);
  }
  return out.toString();
}

String compact(int value) {
  final steps = [
    (1000000000, T.sufB),
    (1000000, T.sufM),
    (1000, T.sufK),
  ];
  for (final (unit, suffix) in steps) {
    if (value >= unit) {
      final whole = value % unit < unit ~/ 10;
      final number = whole ? (value ~/ unit).toString() : (value / unit).toStringAsFixed(1);
      return number + tx(suffix);
    }
  }
  return value.toString();
}

String times(int value) => tx(T.times) + value.toString();

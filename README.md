# Frost Legend

Social casino slot game for Android (`com.stonepath.frostrealm`) built with
Flutter and a Rust core connected through [Rinf](https://rinf.cunarist.org).

- `native/hub` — Rust core: slot math (reels, paylines, features, wheels,
  jackpots, RTP tests), player progression, encrypted save file
  (ChaCha20-Poly1305) and every user-facing string.
- `lib/` — Flutter UI. It contains no string literals: texts, asset paths and
  links arrive from Rust in the `Lexicon` signal (`test/widget_test.dart`
  enforces this).
- `tools/sprite_probe` — offline helper that measured sprite sheets and wheel
  geometry and generated the launcher icons.

## Build

```sh
rinf gen                      # generates lib/src/bindings
cargo test --release -p hub   # math and vault tests
flutter build apk --release
```

Requires Flutter 3.44+, stable Rust with Android targets and the Android NDK.

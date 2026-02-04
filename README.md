# sudaku

<p align="center">
  <img src="./assets/icon.png" alt="Sudaku" width="128">
</p>

<p align="center">
  <a href="https://github.com/theoden8/sudaku/actions/workflows/build.yml">
    <img src="https://github.com/theoden8/sudaku/actions/workflows/build.yml/badge.svg" alt="Build">
  </a>
  <a href="https://f-droid.org/packages/com.gitea.theoden8.sudaku/">
    <img src="https://img.shields.io/f-droid/v/com.gitea.theoden8.sudaku" alt="F-Droid">
  </a>
</p>

<p align="center">
  <a href="https://f-droid.org/packages/com.gitea.theoden8.sudaku/">
    <img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="80">
  </a>
</p>

## About

Sudaku is a constraint-based sudoku assistant that lets you define logical rules and relationships between cells. Instead of manually propagating obvious implications when testing hypotheses, you can express patterns using constraints like `alldifferent`, `one-of`, and value elimination. The app automatically handles the mechanical work of propagating these rules, letting you focus on the logical reasoning.

This isn't a solver - you remain in full control of your logic and strategy. Sudaku simply automates the tedious bookkeeping that comes with exploring different possibilities.

## Screenshots

<p align="center">
  <img src="./screenshots/solving.jpg" alt="Solving" width="45%">
  &nbsp;&nbsp;
  <img src="./screenshots/selecting-constraint.jpg" alt="Selecting constraint" width="45%">
</p>

## Why Not Use a Solver?

Sudaku is designed as an assistant, not a solver. It doesn't brute-force solutions or impose strong arc consistency algorithms. You define the rules based on your own reasoning, and the app propagates the consequences of those rules. You remain in control of the solving strategy - and responsible for any logical mistakes you make.

## Technology

Built with [Flutter](https://flutter.dev/) for cross-platform support on Android, iOS, Linux, macOS, and Windows.

## Building

* **Android** (apk)

```bash
fvm flutter build apk --release --split-per-api
```

* **MacOS** (app)

```bash
fvm flutter create --platforms=windows,macos,linux .
fvm flutter build macos --release
# find . -name "*.app"
```

* **Linux** (appimage)

```bash
# requires appimagetool, appimage-builder
fvm flutter create --platforms=windows,macos,linux .
fvm flutter build linux --release
appimage-builder --skip-test
```

## Contributing

Contributions are welcome! Feel free to open issues for bugs or feature requests, or submit pull requests. Please note that this project is in early development.

## References

* http://magictour.free.fr/topn87 - hardest 87 9x9 puzzles
* http://magictour.free.fr/top1465 - hardest 1465 9x9 puzzles
* http://magictour.free.fr/top44 - hardest 44 16x16 puzzles
* http://pi.math.cornell.edu/~mec/Summer2009/Mahmood/Symmetry.html
* https://www.csplib.org/Problems/ - list of constraint satisfaction problems

## Support

[<img src="https://www.getmonero.org/press-kit/symbols/monero-symbol-480.png" alt="xmr" height="20" width="20">](https://getmonero.org) [XMR: 86tFFhT6hdUQAzcc2Za7i8ZggwQusf1ssgUNby2ApEvJDBodye8CQdJgXLaNMnun5YHm8im8MhnoK91XPWb99YdvDnfiYGZ](monero:86tFFhT6hdUQAzcc2Za7i8ZggwQusf1ssgUNby2ApEvJDBodye8CQdJgXLaNMnun5YHm8im8MhnoK91XPWb99YdvDnfiYGZ)

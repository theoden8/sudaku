<p align="center">
  <img src="./assets/featureGraphic.png" alt="Sudaku" width="100%">
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
    <img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="80" align="middle">
  </a>
  <a href="https://apps.apple.com/app/sudaku/id6758774395">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" width="170" align="middle">
  </a>
</p>

## About

Find a pattern, let your logic ripple across the grid, and focus on your next insight. Sudaku is your tireless sudoku workhorse - it handles all the grunt work while you do the thinking. Spot something? It fills in every obvious consequence. Express patterns using constraints like `alldifferent`, `one-of`, and value elimination. Your rules, your strategy, your glory. 9×9 and 16×16 puzzles included.

## Screenshots

<p align="center">
  <img src="./fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" alt="Screenshot 1" width="22%">
  <img src="./fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" alt="Screenshot 2" width="22%">
  <img src="./fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" alt="Screenshot 3" width="22%">
  <img src="./fastlane/metadata/android/en-US/images/phoneScreenshots/4.png" alt="Screenshot 4" width="22%">
</p>

## Technology

Built with [Flutter](https://flutter.dev/) for cross-platform support on Android, iOS, Linux, macOS, and Windows. Uses [sdsolve](https://github.com/theoden8/sdsolve) for constraint solver implementation.

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

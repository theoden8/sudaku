# sudaku

![](./assets/icon.png)

## about

[<img src="https://f-droid.org/badge/get-it-on.png"
      alt="Get it on F-Droid"
      height="80">](https://f-droid.org/packages/com.gitea.theoden8.sudaku/)

One of the most mechanical things about solving sudoku puzzles is manually choosing the values that are immediately implied as a consequence of risking/setting a cell. This app aims to alleviate this problem, by providing user with a language in which they can express a system of rules, from which autocompletions should be derived.

The system consists of a variety of constraints, such as alldifferent, one-of, and plain value elimination, which can be specified individually.

![solving](./screenshots/solving.jpg)

## why not use a solver

This program isn't designed to solve puzzles for you. It isn't designed to ask for your help to solve anything either. It doesn't perform brute-force for you or impose any serious arc consistency. You are still in control of your own logic and victim of your own mistakes.

![selecting-constraint](./screenshots/selecting-constraint.jpg)

## tools

* [flutter](https://flutter.dev/)

This is my first mobile application project, and I am being cautious about the language and features.

## building

* **Android** (apk)

```bash
flutter build apk --release --split-per-api
```

* **MacOS** (app)

```bash
flutter create --platforms=windows,macos,linux .
flutter build macos --release
# find . -name "*.app"
```

* **Linux** (appimage)

```bash
# requires appimagetool, appimage-builder
flutter create --platforms=windows,macos,linux .
flutter build linux --release
appimage-builder --skip-test
```

## contributing

Feel free to request a feature, post a bug, or make a pr. But keep in mind that this is an early stage of development.

## references

* http://magictour.free.fr/topn87 - hardest 87 9x9 puzzles
* http://magictour.free.fr/top1465 - hardest 1465 9x9 puzzles
* http://magictour.free.fr/top44 - hardest 44 16x16 puzzles
* http://pi.math.cornell.edu/~mec/Summer2009/Mahmood/Symmetry.html

## tipping

[<img src="https://www.getmonero.org/press-kit/symbols/monero-symbol-480.png" alt="xmr" height="20" width="20">](https://getmonero.org) [XMR](monero:86tFFhT6hdUQAzcc2Za7i8ZggwQusf1ssgUNby2ApEvJDBodye8CQdJgXLaNMnun5YHm8im8MhnoK91XPWb99YdvDnfiYGZ)

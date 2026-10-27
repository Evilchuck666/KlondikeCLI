# 🃏 KlondikeCLI

**Klondike solitaire in your terminal, written in plain C++17.**

KlondikeCLI is the classic Klondike solitaire played from the console: seven
tableau columns, four foundations, a stock and a waste pile. Each deal comes
from a number you type, so the same seed always gives the same game, on any
system. It keeps track of your moves and score, and refuses any move that
breaks the rules.

It started in 2016 as a university project for a Computer Engineering
programming course, and it shows: every class is documented with
preconditions, postconditions and invariants, and the stack is a hand-written
linked list.

## ✨ Features

- Classic Klondike rules: build the tableau down in alternating colours and
  the foundations up by suit, from Ace to King.
- Draw one card or three cards at a time.
- Seeded deals: the same positive integer always deals the same game.
- Move counter and score, shown after every move.
- Invalid moves are rejected with a message and do not count.
- No dependencies: a single executable for GNU/Linux, Windows and macOS.

## 🚀 Getting started

1. Download the package for your system from the
   [latest release](https://github.com/Evilchuck666/KlondikeCLI/releases/latest):

   | System | Download |
   | --- | --- |
   | GNU/Linux (x64) | [**KlondikeCLI-linux-x64.tar.gz**](https://github.com/Evilchuck666/KlondikeCLI/releases/latest/download/KlondikeCLI-linux-x64.tar.gz) |
   | Windows (x64) | [**KlondikeCLI-windows-x64.zip**](https://github.com/Evilchuck666/KlondikeCLI/releases/latest/download/KlondikeCLI-windows-x64.zip) |
   | macOS (Intel) | [**KlondikeCLI-macos-x64.tar.gz**](https://github.com/Evilchuck666/KlondikeCLI/releases/latest/download/KlondikeCLI-macos-x64.tar.gz) |
   | macOS (Apple Silicon) | [**KlondikeCLI-macos-arm64.tar.gz**](https://github.com/Evilchuck666/KlondikeCLI/releases/latest/download/KlondikeCLI-macos-arm64.tar.gz) |

   Checksums: [SHA256SUMS.txt](https://github.com/Evilchuck666/KlondikeCLI/releases/latest/download/SHA256SUMS.txt).

2. Extract it and run `KlondikeCLI` (`KlondikeCLI.exe` on Windows) from a
   terminal.
3. Type a seed (any positive integer) and choose whether to draw cards one by
   one or three by three.

On macOS the binary is not signed. If Gatekeeper blocks it, run
`xattr -d com.apple.quarantine KlondikeCLI` once.

## 🎮 How to play

### Reading the board

This is the opening deal for seed `42`:

```
GAME STATUS
DISCARDED CARDS:
               **
c1 c2 c3 c4 c5 c6 c7
2P ** ** ** ** ** ** f1
   6c ** ** ** ** ** f2
      JP ** ** ** ** f3
         2d ** ** ** f4
            9P ** ** f5
               4T ** f6
                  5c f7

PLAYING GAME - M:0 S:[0,0,0,0] H:[24,0] 0 POINTS
```

- **Top line:** the top card of the four foundations, then the stock and the
  waste pile. `DISCARDED CARDS` lists the cards you just drew.
- **Tableau:** columns are `c1`–`c7` and rows are `f1`, `f2`… (`f` for
  *fila*, row). Each column is read from `f1` downwards; `**` is a face-down
  card.
- **Status line:** `M` is the number of moves, `S` how many cards each
  foundation holds, `H` the cards left in the stock and in the waste pile,
  followed by the score.

### Cards

A card is its rank followed by its suit:

| Ranks | `A` `2` `3` `4` `5` `6` `7` `8` `9` `D` (10) `J` `Q` `K` |
| --- | --- |
| **Suits** | `P` spades · `c` hearts · `d` diamonds · `T` clubs |

Red suits are lowercase and black suits are uppercase. The letters come from
the Spanish names: *Picas*, *corazones*, *diamantes* and *Tréboles*.

### Menu

| Option | Action | You are asked for |
| --- | --- | --- |
| `1` | Draw one or three cards. When the stock is empty, turn the waste pile over to start again. | — |
| `2` | Move the top waste card to the tableau. | Destination column |
| `3` | Move the top waste card to its foundation. | — |
| `4` | Move a card, and every card on top of it, within the tableau. | Origin column and row, destination column |
| `5` | Move the last card of a column to its foundation. | Origin column |
| `6` | Move a card back from a foundation to the tableau. | Foundation (`1` spades, `2` hearts, `3` diamonds, `4` clubs), destination column |
| `9` | Show the menu again. | — |
| `0` | Give up the game. | — |

You win when all 52 cards are on the foundations.

### Scoring

| Event | Points |
| --- | --- |
| Waste → tableau | +5 |
| Waste or tableau → foundation | +10 |
| Turning over a face-down tableau card | +5 |
| Foundation → tableau | −15 |
| Turning the waste pile over, drawing one by one | −25 |
| Turning the waste pile over, drawing three by three | −10 |
| Every 10th move | −2 |

## 🛠️ Building from source

Requirements: CMake 3.15 or newer and a C++17 compiler (GCC, Clang or MSVC).

```sh
git clone https://github.com/Evilchuck666/KlondikeCLI.git
cd KlondikeCLI
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
./build/KlondikeCLI
```

## 📦 Releases

Releases are built by GitHub Actions (`.github/workflows/build.yml`) on
GNU/Linux, Windows, macOS Intel and macOS Apple Silicon. Each build plays a
short scripted game as a smoke test before it is packaged.

- **Actions → Build console app → Run workflow** with an empty version only
  builds the four packages and uploads them as workflow artifacts.
- The same with a version such as `1.0.0` also creates the `v1.0.0` tag and a
  GitHub release with the four packages and a `SHA256SUMS.txt` file. The
  version must match `project(KlondikeCLI VERSION …)` in `CMakeLists.txt`,
  and releases are only published from `master`.
- Pushes and pull requests build automatically only when the repository
  variable `KLONDIKECLI_CI` is set to `true`.

## 🧱 Project layout

| File | Purpose |
| --- | --- |
| `main.cpp` | Asks for the seed and draw mode, and runs the menu loop. |
| `Game.h` / `Game.cpp` | Game rules: stock, waste, foundations, moves and score. |
| `Board.h` / `Board.cpp` | The seven tableau columns: dealing, legal moves and printing. |
| `Deck.h` / `Deck.cpp` | The 52-card deck, shuffled with a seeded Fisher–Yates (Sattolo variant). |
| `Card.h` / `Card.cpp` | A card: suit, rank, colour and whether it is face up. |
| `Stack.h` / `Stack.cpp` | A linked-list stack of cards, used for the stock, waste and foundations. |

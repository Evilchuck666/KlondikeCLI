# KlondikeCLI technical guide

[Back to the project overview](README.md)

KlondikeCLI is Klondike solitaire for the terminal, written in plain C++17
with CMake and no external dependencies.

## Scoring

| Event | Points |
| --- | --- |
| Waste → tableau | +5 |
| Waste or tableau → foundation | +10 |
| Turning over a face-down tableau card | +5 |
| Foundation → tableau | −15 |
| Turning the waste pile over, drawing one by one | −25 |
| Turning the waste pile over, drawing three by three | −10 |
| Every 10th move | −2 |

## Building from source

Requirements: CMake 3.15 or newer and a C++17 compiler (GCC, Clang or MSVC).

```sh
git clone https://github.com/Evilchuck666/KlondikeCLI.git
cd KlondikeCLI
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
./build/KlondikeCLI
```

## Releases

Releases are built by GitHub Actions (`.github/workflows/release.yaml`) on
GNU/Linux, Windows, macOS Intel and macOS Apple Silicon. Each build plays a
short scripted game as a smoke test before it is packaged.

- **Actions → Build console app → Run workflow** with an empty version only
  builds the four packages and uploads them as workflow artifacts.
- The same with a version such as `1.0.0` also creates the `v1.0.0` tag and a
  GitHub release with the four packages and a `SHA256SUMS.txt` file. The
  version must match `project(KlondikeCLI VERSION …)` in `CMakeLists.txt`,
  and releases are only published from `main`.
- Pushes and pull requests build automatically only when the repository
  variable `KLONDIKECLI_CI` is set to `true`.

## Project layout

| File | Purpose |
| --- | --- |
| `main.cpp` | Asks for the seed and draw mode, and runs the menu loop. |
| `Game.h` / `Game.cpp` | Game rules: stock, waste, foundations, moves and score. |
| `Board.h` / `Board.cpp` | The seven tableau columns: dealing, legal moves and printing. |
| `Deck.h` / `Deck.cpp` | The 52-card deck, shuffled with a seeded Fisher–Yates (Sattolo variant). |
| `Card.h` / `Card.cpp` | A card: suit, rank, colour and whether it is face up. |
| `Stack.h` / `Stack.cpp` | A linked-list stack of cards, used for the stock, waste and foundations. |

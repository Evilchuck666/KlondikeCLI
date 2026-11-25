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
  GitHub release with the four packages and a `SHA256SUMS.txt` file, then
  updates the AUR package (see [Arch Linux package](#arch-linux-package)). The
  version must match `project(KlondikeCLI VERSION …)` in `CMakeLists.txt`,
  and releases are only published from `main`.
- Pushes and pull requests build automatically only when the repository
  variable `KLONDIKECLI_CI` is set to `true`.

## Install scripts and packaging

`install.sh` (GNU/Linux and macOS) and `install.ps1` (Windows) live at the
repository root. The Pages workflow (`.github/workflows/pages.yaml`) checks
them with `bash -n`, ShellCheck and the PowerShell parser, then publishes them
next to the website, which is where the one-line commands in the README
download them from. Both install the latest GitHub release and verify it
against `SHA256SUMS.txt`.

| System | What the installer does |
| --- | --- |
| Arch Linux and derivatives | Installs `klondikecli-bin` with the first AUR helper found (`paru`, `yay`, `pikaur`, `trizen`) if the package is on the AUR. Otherwise it downloads `packaging/arch/` from `main` and runs `makepkg --syncdeps --install`, installing `base-devel` first if `fakeroot` is missing. |
| Other GNU/Linux distributions | Installs the binary in `~/.local/bin`, the icon in `$XDG_DATA_HOME/icons` and a `.desktop` entry in `$XDG_DATA_HOME/applications`. |
| macOS | Installs the Intel or Apple Silicon binary in `~/.local/bin` and builds `~/Applications/KlondikeCLI.app` with `osacompile`. |
| Windows | Installs to `%LOCALAPPDATA%\Programs\KlondikeCLI`, adds it to the user PATH and creates Start menu and desktop shortcuts. |

`KLONDIKECLI_INSTALL_METHOD` overrides how `install.sh` installs:
`tarball` installs the release binary even on Arch Linux, `arch` forces the
package path and `auto` (the default) chooses based on the system.

```sh
curl -fsSL https://evilchuck666.github.io/KlondikeCLI/install.sh | KLONDIKECLI_INSTALL_METHOD=tarball bash
```

### Arch Linux package

`packaging/arch/` holds the `klondikecli-bin` PKGBUILD, which repackages the
GNU/Linux release binary together with a desktop entry and an icon. The
[AUR package](https://aur.archlinux.org/packages/klondikecli-bin) is
published by `.github/workflows/aur.yaml`, which `release.yaml` runs after
every release. In an Arch Linux container it:

1. Sets `pkgver` to the released version (and `pkgrel` back to `1`), runs
   `updpkgsums` and `makepkg --printsrcinfo`, and checks the tarball
   checksum against the release's `SHA256SUMS.txt`.
2. Builds the package, runs the same smoke test as the release builds, and
   runs `namcap`.
3. Commits the updated `PKGBUILD` and `.SRCINFO` to `main`.
4. Pushes `PKGBUILD`, `.SRCINFO`, `klondikecli.desktop` and
   `klondikecli.svg` to `ssh://aur@aur.archlinux.org/klondikecli-bin.git`.

To publish a release by hand (to retry a failed push, or after committing a
`pkgrel` bump for a packaging-only fix), use **Actions → Publish AUR package
→ Run workflow** with the released version. If the AUR already has the same
files, nothing is pushed.

The push needs the repository secret `AUR_SSH_PRIVATE_KEY`: a private SSH key
used only by CI, whose public key is added under **My Account → SSH Public
Key** in the AUR account that maintains the package (that field takes one
key per line).

If the package is not on the AUR, `install.sh` builds the PKGBUILD from
`main`, so `packaging/arch/` on `main` must always build.

## Project layout

| File | Purpose |
| --- | --- |
| `main.cpp` | Asks for the seed and draw mode, and runs the menu loop. |
| `Game.h` / `Game.cpp` | Game rules: stock, waste, foundations, moves and score. |
| `Board.h` / `Board.cpp` | The seven tableau columns: dealing, legal moves and printing. |
| `Deck.h` / `Deck.cpp` | The 52-card deck, shuffled with a seeded Fisher–Yates (Sattolo variant). |
| `Card.h` / `Card.cpp` | A card: suit, rank, colour and whether it is face up. |
| `Stack.h` / `Stack.cpp` | A linked-list stack of cards, used for the stock, waste and foundations. |
| `install.sh` / `install.ps1` | One-line installers for GNU/Linux and macOS, and for Windows. |
| `packaging/arch/` | The `klondikecli-bin` PKGBUILD for the AUR, with its desktop entry and icon. |

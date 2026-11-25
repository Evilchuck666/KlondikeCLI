#!/usr/bin/env bash
#
# KlondikeCLI installer for GNU/Linux and macOS.
#
#   curl -fsSL https://evilchuck666.github.io/KlondikeCLI/install.sh | bash
#   wget -qO- https://evilchuck666.github.io/KlondikeCLI/install.sh | bash
#
# - Arch Linux and derivatives: installs the klondikecli-bin package, with an
#   AUR helper when the package is on the AUR, otherwise with makepkg.
# - Other GNU/Linux distributions: installs the latest release binary in
#   ~/.local/bin and adds KlondikeCLI to the applications menu.
# - macOS: installs the latest release binary (Intel or Apple Silicon) in
#   ~/.local/bin and creates ~/Applications/KlondikeCLI.app.
#
# KLONDIKECLI_INSTALL_METHOD=auto|arch|tarball overrides the choice: "tarball"
# installs the release binary even on Arch Linux. The default is "auto".
#
# Everything runs from main(), called on the last line, so a partial download
# never runs half a script. Written for bash 3.2 (the macOS system bash).

if [ -z "${BASH_VERSION:-}" ]; then
    echo "error: run this installer with bash, e.g. curl -fsSL <url> | bash" >&2
    exit 1
fi

set -euo pipefail

readonly REPO="Evilchuck666/KlondikeCLI"
readonly RELEASE_URL="https://github.com/$REPO/releases/latest/download"
readonly PACKAGING_URL="https://raw.githubusercontent.com/$REPO/main/packaging/arch"
readonly SITE_URL="https://evilchuck666.github.io/KlondikeCLI"
readonly AUR_PACKAGE="klondikecli-bin"
readonly BIN_DIR="$HOME/.local/bin"
readonly DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

TMP_DIR=""

# ---------------------------------------------------------------------------
# Common helpers (all platforms)
# ---------------------------------------------------------------------------

info() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
    has_cmd "$1" || die "'$1' is required but was not found."
}

cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

make_tmp_dir() {
    TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t klondikecli)
    trap cleanup EXIT
}

# download URL DEST: returns non-zero (and leaves no file) on failure.
download() {
    local status=0
    if has_cmd curl; then
        curl -fsSL --retry 3 -o "$2" "$1" || status=$?
    elif has_cmd wget; then
        wget -q -O "$2" "$1" || status=$?
    else
        die "curl or wget is required to download KlondikeCLI."
    fi
    if [ "$status" -ne 0 ]; then
        rm -f "$2"
    fi
    return "$status"
}

sha256_of() {
    if has_cmd sha256sum; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}

# verify_checksum FILE NAME: checks FILE against the release's SHA256SUMS.txt.
verify_checksum() {
    local file=$1 name=$2 sums="$TMP_DIR/SHA256SUMS.txt" expected actual
    download "$RELEASE_URL/SHA256SUMS.txt" "$sums" || die "Could not download SHA256SUMS.txt."
    expected=$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' "$sums")
    [ -n "$expected" ] || die "$name is not listed in SHA256SUMS.txt."
    actual=$(sha256_of "$file")
    [ "$actual" = "$expected" ] || die "Checksum mismatch for $name (expected $expected, got $actual)."
    info "Checksum verified."
}

# install_release_binary PACKAGE: downloads KlondikeCLI-PACKAGE.tar.gz from the
# latest release, verifies it and installs the binary as $BIN_DIR/KlondikeCLI.
install_release_binary() {
    local name="KlondikeCLI-$1.tar.gz" archive
    archive="$TMP_DIR/$name"
    need_cmd tar
    has_cmd sha256sum || has_cmd shasum || die "sha256sum or shasum is required to verify the download."

    info "Downloading $name from the latest release..."
    download "$RELEASE_URL/$name" "$archive" || die "Could not download $RELEASE_URL/$name."
    verify_checksum "$archive" "$name"
    tar -xzf "$archive" -C "$TMP_DIR" || die "Could not extract $name."
    [ -f "$TMP_DIR/KlondikeCLI-$1/KlondikeCLI" ] || die "KlondikeCLI was not found in $name."

    # Install next to the target and rename, so a running copy is not disturbed.
    mkdir -p "$BIN_DIR"
    install -m 755 "$TMP_DIR/KlondikeCLI-$1/KlondikeCLI" "$BIN_DIR/.KlondikeCLI.new"
    mv -f "$BIN_DIR/.KlondikeCLI.new" "$BIN_DIR/KlondikeCLI"
    info "Installed $BIN_DIR/KlondikeCLI"
}

# Warns when $BIN_DIR is not in PATH, so "KlondikeCLI" would not be found.
check_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) return 0 ;;
    esac
    warn "$BIN_DIR is not in your PATH. To run KlondikeCLI from any terminal, add this line to your shell profile (~/.bashrc, ~/.zshrc...):"
    # shellcheck disable=SC2016 # The line is printed for the user, unexpanded.
    printf '\n    export PATH="$HOME/.local/bin:$PATH"\n\n' >&2
}

# run_interactive COMMAND...: commands that may ask questions (sudo, pacman,
# makepkg) read from the terminal, because when the installer is piped into
# bash its standard input is the script itself.
run_interactive() {
    if [ -t 0 ]; then
        "$@"
    elif { : </dev/tty; } 2>/dev/null; then
        "$@" </dev/tty
    else
        "$@" </dev/null
    fi
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

detect_os() {
    case "$(uname -s)" in
        Linux) echo linux ;;
        Darwin) echo macos ;;
        *) die "Unsupported system: $(uname -s). On Windows, use install.ps1 (see the README)." ;;
    esac
}

# Releases only include an x86_64 GNU/Linux binary.
linux_require_x86_64() {
    local machine
    machine=$(uname -m)
    case "$machine" in
        x86_64 | amd64) ;;
        *) die "There is no prebuilt KlondikeCLI for $machine yet. Build it from source: https://github.com/$REPO/blob/main/TECHNICAL_GUIDE.md#building-from-source" ;;
    esac
}

# ---------------------------------------------------------------------------
# GNU/Linux: Arch Linux and derivatives (klondikecli-bin package)
# ---------------------------------------------------------------------------

arch_is_based() {
    local id="" id_like=""
    if [ -r /etc/os-release ]; then
        # shellcheck source=/dev/null
        id=$(. /etc/os-release && printf '%s' "${ID:-}")
        # shellcheck source=/dev/null
        id_like=$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")
    fi
    case " $id $id_like " in
        *" arch "* | *" artix "* | *" manjaro "* | *" endeavouros "* | *" cachyos "* | \
            *" garuda "* | *" arcolinux "* | *" archcraft "* | *" parabola "* | *" rebornos "*)
            return 0
            ;;
    esac
    has_cmd pacman && has_cmd makepkg
}

# Prints the first AUR helper found.
arch_find_aur_helper() {
    local helper
    for helper in paru yay pikaur trizen; do
        if has_cmd "$helper"; then
            echo "$helper"
            return 0
        fi
    done
    return 1
}

arch_aur_has_package() {
    local reply="$TMP_DIR/aur-info.json"
    download "https://aur.archlinux.org/rpc/v5/info/$AUR_PACKAGE" "$reply" 2>/dev/null || return 1
    grep -q '"resultcount":[1-9]' "$reply"
}

# arch_install_with_helper HELPER
arch_install_with_helper() {
    info "Installing $AUR_PACKAGE from the AUR with $1..."
    run_interactive "$1" -S --needed "$AUR_PACKAGE" || die "$1 could not install $AUR_PACKAGE."
}

# makepkg needs fakeroot, which comes with the base-devel group.
arch_ensure_base_devel() {
    has_cmd fakeroot && return 0
    need_cmd sudo
    info "makepkg needs the base-devel group; installing it with pacman..."
    run_interactive sudo pacman -S --needed base-devel || die "Could not install base-devel."
}

# Downloads the PKGBUILD from this repository and builds it with makepkg.
arch_install_with_makepkg() {
    local build_dir="$TMP_DIR/$AUR_PACKAGE" file
    need_cmd makepkg
    arch_ensure_base_devel
    mkdir -p "$build_dir"
    info "Downloading the $AUR_PACKAGE PKGBUILD..."
    for file in PKGBUILD klondikecli.desktop klondikecli.svg; do
        download "$PACKAGING_URL/$file" "$build_dir/$file" || die "Could not download $PACKAGING_URL/$file."
    done
    info "Building and installing $AUR_PACKAGE with makepkg..."
    (cd "$build_dir" && run_interactive makepkg --syncdeps --install --needed --clean) ||
        die "makepkg could not build or install $AUR_PACKAGE."
}

arch_install() {
    local helper=""
    [ "$(id -u)" -ne 0 ] || die "On Arch Linux, run the installer as a normal user; it asks for sudo when needed."
    if helper=$(arch_find_aur_helper) && arch_aur_has_package; then
        arch_install_with_helper "$helper"
    else
        if [ -n "$helper" ]; then
            info "$AUR_PACKAGE is not available on the AUR; building it with makepkg instead."
        fi
        arch_install_with_makepkg
    fi
}

# ---------------------------------------------------------------------------
# GNU/Linux: other distributions (release binary in ~/.local/bin)
# ---------------------------------------------------------------------------

linux_icon_path() { echo "$DATA_DIR/icons/hicolor/scalable/apps/klondikecli.svg"; }

linux_install_icon() {
    local icon
    icon=$(linux_icon_path)
    mkdir -p "$(dirname "$icon")"
    download "$SITE_URL/favicon.svg" "$icon" ||
        warn "Could not download the icon; the menu entry will use a generic one."
}

linux_install_desktop_entry() {
    local apps_dir="$DATA_DIR/applications" icon
    icon=$(linux_icon_path)
    mkdir -p "$apps_dir"
    # Exec uses ~ (expanded by sh) so the path needs no quoting, even with
    # spaces in $HOME. The pause keeps the terminal open to show the result.
    cat >"$apps_dir/klondikecli.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=KlondikeCLI
GenericName=Solitaire
Comment=Klondike solitaire in your terminal
TryExec=$BIN_DIR/KlondikeCLI
Exec=sh -c "~/.local/bin/KlondikeCLI; echo; echo 'Press Enter to close.'; read line"
Icon=$icon
Terminal=true
Categories=Game;CardGame;
Keywords=klondike;cards;patience;card game;
EOF
    if has_cmd update-desktop-database; then
        update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    fi
    info "Added KlondikeCLI to your applications menu."
}

linux_install_generic() {
    install_release_binary linux-x64
    linux_install_icon
    linux_install_desktop_entry
}

# ---------------------------------------------------------------------------
# macOS (release binary in ~/.local/bin + ~/Applications/KlondikeCLI.app)
# ---------------------------------------------------------------------------

# hw.optional.arm64 is 1 on Apple Silicon even when the shell runs under
# Rosetta, where uname -m would say x86_64.
macos_package() {
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then
        echo macos-arm64
    else
        echo macos-x64
    fi
}

# A small AppleScript app that opens KlondikeCLI in a new Terminal window,
# so it shows up in Launchpad and Spotlight.
macos_create_app() {
    local app="$HOME/Applications/KlondikeCLI.app" escaped
    need_cmd osacompile
    escaped=$(printf '%s' "$BIN_DIR/KlondikeCLI" | sed 's/[\\"]/\\&/g')
    mkdir -p "$HOME/Applications"
    rm -rf "$app"
    osacompile -o "$app" \
        -e 'tell application "Terminal"' \
        -e "do script quoted form of \"$escaped\"" \
        -e 'activate' \
        -e 'end tell' || die "Could not create $app."
    info "Created $app"
}

macos_install() {
    install_release_binary "$(macos_package)"
    # curl does not quarantine files, but other tools might have.
    xattr -d com.apple.quarantine "$BIN_DIR/KlondikeCLI" 2>/dev/null || true
    macos_create_app
}

# ---------------------------------------------------------------------------
# Summary and entry point
# ---------------------------------------------------------------------------

# print_summary arch|linux|macos
print_summary() {
    echo
    info "KlondikeCLI is installed."
    case "$1" in
        arch)
            echo "    Open it from your applications menu, or run KlondikeCLI in a terminal."
            echo "    To uninstall: sudo pacman -Rns $AUR_PACKAGE"
            ;;
        linux)
            echo "    Open it from your applications menu, or run $BIN_DIR/KlondikeCLI in a terminal."
            echo "    To uninstall: rm '$BIN_DIR/KlondikeCLI' '$DATA_DIR/applications/klondikecli.desktop' '$(linux_icon_path)'"
            ;;
        macos)
            echo "    Open KlondikeCLI from Launchpad, Spotlight or ~/Applications, or run $BIN_DIR/KlondikeCLI in a terminal."
            echo "    The first time, macOS asks to let KlondikeCLI control Terminal: allow it."
            echo "    To uninstall: rm '$BIN_DIR/KlondikeCLI'; rm -r '$HOME/Applications/KlondikeCLI.app'"
            ;;
    esac
    if [ "$1" != arch ]; then
        check_path
    fi
}

main() {
    local os method="${KLONDIKECLI_INSTALL_METHOD:-auto}"
    case "$method" in
        auto | arch | tarball) ;;
        *) die "KLONDIKECLI_INSTALL_METHOD must be auto, arch or tarball (got '$method')." ;;
    esac

    os=$(detect_os)
    make_tmp_dir
    info "Installing KlondikeCLI from https://github.com/$REPO"

    case "$os" in
        linux)
            linux_require_x86_64
            if [ "$method" = arch ] || { [ "$method" = auto ] && arch_is_based; }; then
                arch_install
                print_summary arch
            else
                linux_install_generic
                print_summary linux
            fi
            ;;
        macos)
            [ "$method" != arch ] || die "KLONDIKECLI_INSTALL_METHOD=arch only works on Arch Linux."
            macos_install
            print_summary macos
            ;;
    esac
}

main "$@"

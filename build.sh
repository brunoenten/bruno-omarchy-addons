#!/bin/bash
# Build every package whose version isn't in the repo yet, sign it, and publish it with the
# repo database as assets of the "repo" release. Runs as root in an archlinux:base-devel container.
# Needs GH_TOKEN, GITHUB_REPOSITORY and GPG_PRIVATE_KEY.
set -euo pipefail

name=bruno-omarchy-addons
tag=repo
here=$(cd "$(dirname "$0")" && pwd)
out=/tmp/repo
gh() { command gh "$@" -R "$GITHUB_REPOSITORY"; }

gpg --batch --import <<<"$GPG_PRIVATE_KEY"
key=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/ { print $10; exit }')

id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder

mkdir -p "$out"
if gh release view "$tag" >/dev/null 2>&1; then
    gh release download "$tag" -D "$out" -p "$name.db" -p "$name.files" || true
    for db in db files; do
        [ ! -f "$out/$name.$db" ] || mv "$out/$name.$db" "$out/$name.$db.tar.gz"
    done
else
    gh release create "$tag" --title "Package repository" \
        --notes "pacman repository for bruno-omarchy-addons. See the README for setup."
fi
published=$(tar -tzf "$out/$name.db.tar.gz" 2>/dev/null | sed -n 's|/$||p' || true)

built=()
for pkgbuild in "$here"/*/PKGBUILD; do
    dir=$(dirname "$pkgbuild")
    version=$(source "$pkgbuild" && echo "$pkgname-${epoch:+$epoch:}$pkgver-$pkgrel")
    if grep -qxF "$version" <<<"$published"; then
        echo "== $version is published"
        continue
    fi
    echo "== building $version"
    work=/tmp/build/$(basename "$dir")
    rm -rf "$work" && mkdir -p "$work" && cp -r "$dir"/. "$work" && chown -R builder "$work"
    (cd "$work" && sudo -u builder makepkg --syncdeps --noconfirm --cleanbuild)
    for pkg in "$work"/*.pkg.tar.zst; do
        gpg --batch --yes --local-user "$key" --detach-sign "$pkg"
        cp "$pkg" "$pkg.sig" "$out"/
        built+=("$out/$(basename "$pkg")")
    done
done

if [ ${#built[@]} -eq 0 ]; then
    echo "== nothing to publish"
    exit 0
fi

repo-add --sign --key "$key" "$out/$name.db.tar.gz" "${built[@]}"
mkdir -p "$out/upload"
for db in db files; do
    cp "$out/$name.$db.tar.gz" "$out/upload/$name.$db"
    cp "$out/$name.$db.tar.gz.sig" "$out/upload/$name.$db.sig"
done

# Packages first, so the database never lists a file that isn't there yet.
for pkg in "${built[@]}"; do
    gh release upload "$tag" --clobber "$pkg" "$pkg.sig"
done
gh release upload "$tag" --clobber "$out/upload"/*

current=$(tar -xzOf "$out/$name.db.tar.gz" --wildcards '*/desc' | sed -n '/^%FILENAME%$/{n;p}')
gh release view "$tag" --json assets -q '.assets[].name' | while read -r asset; do
    case "$asset" in *.pkg.tar.*) ;; *) continue ;; esac
    if ! grep -qxF "${asset%.sig}" <<<"$current"; then
        echo "== removing $asset"
        gh release delete-asset "$tag" "$asset" --yes
    fi
done

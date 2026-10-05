# bruno-omarchy-addons

An unofficial pacman repository with my add-ons for [Omarchy](https://omarchy.org) and Arch Linux. Not affiliated with the Omarchy project.

| Package | |
| --- | --- |
| [plexi](https://github.com/brunoenten/plexi) | keyboard-driven Plex client for the terminal |

## Setup

Trust the signing key, then add the repository:

```sh
curl -fsSL https://raw.githubusercontent.com/brunoenten/bruno-omarchy-addons/main/key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 16114DD8DBCA434D6F5EB1236F6D038C8A17FE15
printf '\n[bruno-omarchy-addons]\nServer = https://github.com/brunoenten/bruno-omarchy-addons/releases/download/repo\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy
```

Then install packages as usual, for example `sudo pacman -S plexi`. `sudo pacman -Syu` keeps them up to date.

Packages and the database are signed with key `16114DD8DBCA434D6F5EB1236F6D038C8A17FE15`.

## Remove

Delete the `[bruno-omarchy-addons]` section from `/etc/pacman.conf`, then `sudo pacman-key --delete 16114DD8DBCA434D6F5EB1236F6D038C8A17FE15`.

## How it works

Each folder holds a `PKGBUILD`. On every push to `main`, GitHub Actions builds the package versions that aren't published yet, signs them, and uploads them with the repository database to the [`repo` release](https://github.com/brunoenten/bruno-omarchy-addons/releases/tag/repo).

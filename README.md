Build GrapheneOS on Hetzner cloud

... because doing it in Qubes or a VM on M1 is slow
and I don't have any other trusted system with reasonable
processing power and hundreds of GB of free space.

So... let's hope that the cloud is trustworthy enough
for this use case.

Steps
=====

1. Setup access token
    - `nix develop`
    - `hcloud context create default`
    - Generate token for your project in Hetzner Cloud Console.
2. Bootstrap a bare-bones NixOS VM (lustrate their Debian image):
    - `./hcloud-create.sh`
3. Connect to the VM:
    - `./hcloud-connect.sh a`
4. Upgrade server and connect again:
    - NOTE: We need the btrfs partition for the next steps and cpx31 should big enough to clone the sources (but not for the build).
    - NOTE: We are using larger servers instead of storing the data in a volume because volumes cost 4 times as much as snapshots
      and the server will be turned off most of the time. We are using 78G of 115G on the 2nd partition.
    - FIXME: Web-Interface has a "Rescale" option. Could we use that? -> `hcloud server change-type`
    - `hcloud server create-image --label name=a1 --description "bare-bones NixOS" --type snapshot a`
    - `hcloud server delete a`
    - `id=$(hcloud image list -l name=a1 -o 'columns=id' | tail -n1)`
    - `hcloud server create --location nbg1 --image "$id" --name a --type cpx31`
    - `sed -i 's/^\(\s*\)\(HostName\)/\1#\2/' .servers/a/config`
    - `echo "  HostName $(hcloud server ip a)" >>.servers/a/config`
    - `./hcloud-connect.sh a`
5. Create partition for btrfs:
    - `parted /dev/sda p name 14 grub name 15 ESP name 1 root mkpart p btrfs 41G 100% name 2 GOS p`
    - `nix-shell -p btrfs-progs --run "mkfs.btrfs -L GOS /dev/disk/by-partlabel/GOS"`
6. Apply config for host "hetzner-gos":
    - `nixos-rebuild switch -L --flake github:BBBSnowball/nixcfg#hetzner-gos`
      (add `--refresh` if you want to apply it again after pushing new commits)
7. Switch to user "gos":
    - `machinectl shell gos@`
    - `byobu`
    - `cd work`
8. Clone git:
    - `git clone https://github.com/BBBSnowball/robotnix.git work2`
    - `mv work2/{*,.git*} work/ && rmdir work2`
    - `cd work`
9. Fetch GrapheneOS sources:
    - `tag=$(./get-latest-release.sh)`
    - `docker build --file Dockerfile-initial-clone --tag gos-src-initial . --build-arg TAG_NAME="refs/tags/$tag"`
    - `#docker build --file Dockerfile-clone-tag --tag "gos-src-$tag" . --progress=plain --build-arg TAG_NAME="refs/tags/$tag"` (not yet, makes the snapshot a lot larger)
10. Upgrade server and connect again:
    - `hcloud server create-image --label name=a2 --description "GOS: sources" --type snapshot a`
    - `hcloud server delete a`
    - `id=$(hcloud image list -l name=a2 -o 'columns=id' | tail -n1)`
    - `hcloud server create --location nbg1 --image "$id" --name a --type ccx53`
    - `sed -i 's/^\(\s*\)\(HostName\)/\1#\2/' .servers/a/config`
    - `echo "  HostName $(hcloud server ip a)" >>.servers/a/config`
    - `./hcloud-connect.sh a`
11. Extend btrfs:
    - `#parted --fix --script /dev/sda p resizepart 2 100% p` -> won't work because it aborts on the next question
    - `parted /dev/sda p resizepart 2 100% p` (answer "fix" and "yes, change active partition")
    - `btrfs filesystem resize max /media/gos`
12. Run build:
    - `machinectl shell gos@`
    - `byobu`
    - `cd work`
    - `tag=$(./get-latest-release.sh)`
    - `./build.sh $tag`

FIXME: copy robotnix config to server
FIXME: change Dockerfiles to update sources without checkout and checkout at beginning of build
FIXME: use change-type instead of recreating the server via snapshot
FIXME: creating server from 100GB snapshot takes more than 30 min and taking a 360GB snapshot takes 20 min -> copy to storagebox might be not too much slower and cost much less
FIXME: build of unmodified GOS takes more like 1h instead of 3h, so maybe only cache the sources?
FIXME: create keys, download keys, upload keys to server again

...

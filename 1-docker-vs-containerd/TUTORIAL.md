# Installing containerd + nerdctl from binaries (no Docker)

This is the full, working install path for running containers with `containerd` and
`nerdctl` directly, without Docker. It sets up **rootless** containerd as the only
stack on the machine — you run `nerdctl` as yourself, no `sudo`, and there's no
separate root-owned daemon to accidentally collide with it.

It covers every piece that's actually required, including the ones that are easy to
miss: `runc`, the CNI plugins, and the rootless-specific helpers (`rootlesskit`,
`slirp4netns`, `containerd-rootless-setuptool.sh`).

## Why rootless, not rootful

An earlier version of this tutorial installed `containerd` as a root-owned systemd
service and told you to prefix every command with `sudo nerdctl`. That works, but it
has a sharp edge: if `nerdctl` is ever invoked in a context where it can't reach the
rootful socket, it silently bootstraps a second, independent **rootless** containerd
under your user account instead of erroring out. From then on you have two unrelated
daemons — root's and yours — each with their own images and containers of the same
name, and whichever one `sudo` happens to route you to on a given command determines
what you can see and stop. This is confusing to debug and easy to trigger by accident
(e.g. running plain `nerdctl` once before you've set up `sudo` access, or a script
that forgets the `sudo`).

Going rootless-only sidesteps the entire class of bug: there is only ever one
containerd, it runs as you, and `sudo nerdctl` simply isn't part of the workflow.

## What you need, and why

| Component               | Role                                                              |
|--------------------------|--------------------------------------------------------------------|
| `containerd`             | The daemon that manages images, containers, and storage           |
| `runc`                   | The low-level OCI runtime that actually creates container processes |
| `nerdctl`                | Docker-compatible CLI that talks to `containerd`                  |
| CNI plugins               | Container networking (so containers get an IP, can reach network) |
| `rootlesskit`/`rootlessctl` | Runs containerd inside an unprivileged user namespace           |
| `slirp4netns`             | Userspace network stack rootless containerd uses for outbound traffic |
| `buildkit`                | Optional — builds images from Dockerfiles (`nerdctl build`)       |

`containerd` on its own only manages the daemon and images — it delegates actually
starting a container process to `runc`. Neither the official `containerd` release
tarball nor `nerdctl`/`buildkit` bundle `runc`, so skipping that step leaves every
other tool reporting a successful install while containers still fail to start.

## 1. Install containerd

Set the version once so every command below can reference it.

```bash
CONTAINERD_VER="2.3.0"
```

Download the release tarball.

```bash
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
```

Extract it into `/usr/local` — this lays down `/usr/local/bin/{containerd,ctr,...}`.
It's a plain system-wide binary install; nothing here is rootful-specific, rootless
containerd will exec these same binaries inside its own namespace.

```bash
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
```

Remove the tarball, it's no longer needed.

```bash
rm containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
```

Make sure `/usr/local/bin` is on your `PATH` (add this line to `~/.bashrc` to persist it across shells).

```bash
export PATH=$PATH:/usr/local/bin
```

Confirm the binary works.

```bash
ctr --version
```

## 2. Install runc

This is the piece most tutorials forget. Without it, `containerd`/`nerdctl` run fine
and can even pull images, but fail the moment they try to actually start a container:

```
FATA[0009] failed to create shim task: OCI runtime create failed: ...
exec: "runc" executable file not found in $PATH
```

Set the version.

```bash
RUNC_VER="1.5.0"
```

Download the `runc` binary directly (it ships as a single static binary, no tarball).

```bash
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64
```

Install it into `/usr/local/bin` with the executable bit set.

```bash
sudo install -m 755 runc.amd64 /usr/local/bin/runc
```

Remove the downloaded file.

```bash
rm runc.amd64
```

Confirm it works.

```bash
runc --version
```

## 3. Install nerdctl (full tarball)

Set the version.

```bash
NERDCTL_VER="2.3.4"
```

Download the release tarball.

```bash
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
```

Extract **everything** from the tarball, not just the `nerdctl` binary — the plain
release also ships `containerd-rootless.sh` and `containerd-rootless-setuptool.sh`,
which the rootless setup in step 6 needs.

```bash
sudo tar Cxzf /usr/local/bin nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
```

Remove the tarball.

```bash
rm nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
```

Confirm it works.

```bash
nerdctl --version
ls /usr/local/bin/containerd-rootless*
```

## 4. Install CNI plugins (container networking)

Set the version.

```bash
CNI_VER="1.9.1"
```

Download the release tarball.

```bash
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_VER}/cni-plugins-linux-amd64-v${CNI_VER}.tgz
```

Create the directory containerd's CNI config points to.

```bash
sudo mkdir -p /opt/cni/bin
```

Extract all the plugin binaries there.

```bash
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v${CNI_VER}.tgz
```

Remove the tarball.

```bash
rm cni-plugins-linux-amd64-v${CNI_VER}.tgz
```

> Note the *binary* directory is `/opt/cni/bin`. containerd separately writes CNI
> *config* (network definitions) to `/etc/cni/net.d` the first time you run a
> container — you don't create that yourself. See the troubleshooting note below for
> why that matters if you're reinstalling over a previous rootful setup.

## 5. Install rootlesskit and slirp4netns

These aren't containerd/nerdctl components — they're what let containerd run inside
an unprivileged user namespace at all. `rootlesskit` creates and manages that
namespace; `slirp4netns` gives containers a userspace network stack without needing
root or `CAP_NET_ADMIN`.

```bash
ROOTLESSKIT_VER="2.3.5"
wget https://github.com/rootless-containers/rootlesskit/releases/download/v${ROOTLESSKIT_VER}/rootlesskit-x86_64.tar.gz
sudo tar Cxzf /usr/local/bin rootlesskit-x86_64.tar.gz
rm rootlesskit-x86_64.tar.gz
rootlesskit --version
```

`slirp4netns` is packaged for Ubuntu — no need to build it from source.

```bash
sudo apt-get install -y slirp4netns
```

> If you skip this, `containerd-rootless.sh` falls back to a network mode called
> `gvisor-tap-vsock`, which the plain `rootlesskit` binary from GitHub doesn't
> actually implement — you'll get `error: unknown network mode: gvisor-tap-vsock` and
> the daemon will refuse to start. Installing `slirp4netns` first avoids that
> fallback entirely; `containerd-rootless.sh` prefers it automatically when present.

## 6. Set up subuid/subgid

Rootless containerd maps extra UIDs/GIDs inside its user namespace (so container
processes don't all appear as your own UID on the host). Check you have a range
allocated:

```bash
grep "^$USER:" /etc/subuid
grep "^$USER:" /etc/subgid
```

You should see something like `lirone:100000:65536`. If there's no output:

```bash
sudo usermod --add-subuids 100000-165535 "$USER"
sudo usermod --add-subgids 100000-165535 "$USER"
```

## 7. Install rootless containerd

Run this as **yourself**, without `sudo`.

```bash
containerd-rootless-setuptool.sh install
```

This creates and starts `~/.config/systemd/user/containerd.service`, running
containerd inside a `rootlesskit` namespace under your own UID.

Allow it to keep running (and start on boot) even when you're not logged in:

```bash
sudo loginctl enable-linger "$USER"
```

Confirm it's active:

```bash
systemctl --user status containerd.service
```

## 8. Install buildkit (optional, needed for `nerdctl build`)

Set the version.

```bash
BUILDKIT_VER="0.31.1"
```

Download the release tarball.

```bash
wget https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VER}/buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
```

Extract it — this creates a local `bin/` folder with `buildctl`, `buildkitd`, etc.

```bash
tar -xvf buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
```

Move all the extracted binaries into your `PATH`.

```bash
sudo mv bin/* /usr/local/bin/
```

Remove the tarball.

```bash
rm buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
```

## 9. Test it

No `sudo` anywhere from here on.

```bash
nerdctl run -d --name redis redis:alpine
nerdctl ps
```

If you re-run a container name that failed to start on a previous attempt (e.g.
before `runc` was installed), containerd may still have the name registered even
though no container is running:

```
FATA[0000] name-store error
name "redis" is already used by ID "..."
```

Remove the leftover name/ID before retrying.

```bash
nerdctl rm -f redis
```

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `cannot access containerd socket ... no such file or directory` | Rootless containerd isn't running, or `XDG_RUNTIME_DIR` isn't set (only happens in non-interactive shells — a normal login session sets it automatically) | `systemctl --user status containerd.service`; if inactive, `systemctl --user start containerd.service` |
| `exec: "runc" executable file not found in $PATH` | `runc` not installed | Install `runc` (step 2) |
| `name "X" is already used by ID "..."` | Leftover container object from a prior failed run | `nerdctl rm -f X` |
| `error: unknown network mode: gvisor-tap-vsock` | `slirp4netns` isn't installed, so `containerd-rootless.sh` fell back to a mode `rootlesskit` doesn't implement | `sudo apt-get install -y slirp4netns`, then `systemctl --user restart containerd.service` |
| containerd fails to start with `failed to watch cni conf dir /etc/cni/net.d: permission denied` | `/etc/cni/net.d` is a leftover from a *previous rootful install*, owned `root:root` with `700` permissions — the unprivileged rootless daemon can't read it | `sudo rm -rf /etc/cni/net.d` (safe — containerd/nerdctl regenerate it on first run), then `systemctl --user restart containerd.service` |
| containerd fails to start with `failed to create socket "/var/run/nri/nri.sock": ... permission denied` | Same story: `/run/nri` left over from a previous rootful install, root-owned | `sudo rm -rf /run/nri`, then restart — or disable the (unused) NRI plugin permanently by setting `disable = true` under `[plugins.'io.containerd.nri.v1.nri']` in `~/.config/containerd/config.toml` |
| `nerdctl stop`/`rm`/`kill` hangs then fails with `unable to signal init: permission denied` | nerdctl's auto-applied `nerdctl-default` AppArmor profile blocks the stop/kill signal when it arrives via `rootlesskit` in rootless mode — confirmed via `journalctl -k \| grep apparmor`, look for `apparmor="DENIED" operation="signal"`. This affects every rootless container by default; it's a gap in nerdctl's rootless+AppArmor profile generation, not something you did wrong. | Run affected containers with `--security-opt apparmor=unconfined`, e.g. `nerdctl run -d --name redis --security-opt apparmor=unconfined redis:alpine`. A container already stuck in this state can only be killed with a direct host-level `kill -9 <pid>` (find the PID via `ps aux \| grep redis-server`) — the AppArmor-mediated stop/kill RPC path is blocked entirely, no client-side flag fixes an already-running container. |

## Full cleanup (start over from scratch)

Remove any running/stopped containers first.

```bash
nerdctl rm -f $(nerdctl ps -aq) 2>/dev/null
```

Uninstall and stop the rootless service.

```bash
containerd-rootless-setuptool.sh uninstall
systemctl --user daemon-reload
```

Remove containerd's data, config, and runtime directories.

```bash
rm -rf ~/.local/share/containerd ~/.local/share/nerdctl ~/.local/share/buildkit
rm -rf ~/.config/containerd ~/.config/nerdctl
rm -f ~/.config/systemd/user/containerd.service ~/.config/systemd/user/buildkit.service
rm -rf /run/user/"$(id -u)"/containerd-rootless /run/user/"$(id -u)"/buildkit
```

Remove the CNI plugins and config directories (**both** — see the troubleshooting
note above on why `/etc/cni/net.d` matters, not just `/opt/cni`).

```bash
sudo rm -rf /opt/cni /etc/cni
```

Remove the leftover NRI socket directory.

```bash
sudo rm -rf /run/nri
```

Remove every binary that may exist in `/usr/local/bin`.

```bash
sudo rm -f /usr/local/bin/containerd \
           /usr/local/bin/containerd-shim-runc-v2 \
           /usr/local/bin/containerd-stress \
           /usr/local/bin/containerd-fuse-overlayfs-grpc \
           /usr/local/bin/containerd-stargz-grpc \
           /usr/local/bin/containerd-rootless.sh \
           /usr/local/bin/containerd-rootless-setuptool.sh \
           /usr/local/bin/ctr \
           /usr/local/bin/ctr-enc \
           /usr/local/bin/ctr-remote \
           /usr/local/bin/runc \
           /usr/local/bin/nerdctl \
           /usr/local/bin/nerdctl.gomodjail \
           /usr/local/bin/buildctl \
           /usr/local/bin/buildkitd \
           /usr/local/bin/buildkit-* \
           /usr/local/bin/rootlesskit \
           /usr/local/bin/rootlessctl \
           /usr/local/bin/rootlesskit-docker-proxy
```

Verify everything is gone — these should print nothing / "No such file or directory".

```bash
which containerd ctr nerdctl runc buildctl buildkitd rootlesskit
ls /etc/containerd /etc/cni /opt/cni /var/lib/containerd /run/nri 2>&1
systemctl --user status containerd 2>&1 | head -3
ps aux | grep -E 'containerd|rootlesskit|buildkitd' | grep -v grep
```

The last three should show `could not be found`/`inactive` and no matching
processes.

## Appendix: rootful setup (not recommended, kept for reference)

If you specifically need containerd to run as a root-owned systemd service (e.g. to
match a production node's setup for practice), install it the same way as steps 1–2
above, then:

```bash
curl -fsSL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /tmp/containerd.service
sudo cp /tmp/containerd.service /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

**Do not run this alongside the rootless setup above on the same machine.** If you
must, always use `sudo nerdctl` for every single command with no exceptions — one
plain `nerdctl` invocation is enough to bootstrap a second, independent rootless
stack and put you back in the two-daemons situation this tutorial exists to avoid.

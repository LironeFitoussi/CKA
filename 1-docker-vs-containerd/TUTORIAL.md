# Installing containerd + nerdctl from binaries (no Docker)

This is the full, working install path for running containers with `containerd` and
`nerdctl` directly, without Docker. It covers every piece that's actually required —
including the two that are easy to miss: the `containerd` systemd service and `runc`.

## What you need, and why

| Component    | Role                                                              |
|--------------|--------------------------------------------------------------------|
| `containerd` | The daemon that manages images, containers, and storage           |
| `runc`       | The low-level OCI runtime that actually creates container processes |
| `nerdctl`    | Docker-compatible CLI that talks to `containerd`                  |
| CNI plugins  | Container networking (so containers get an IP, can reach network) |
| buildkit     | Optional — builds images from Dockerfiles (`nerdctl build`)       |

`containerd` on its own only manages the daemon and images — it delegates actually
starting a container process to `runc`. Neither the official `containerd` release
tarball nor `nerdctl`/`buildkit` bundle `runc`, and none of them install a systemd
unit for you. Skip either step and containers will fail to start even though every
other tool reports a successful install.

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

Create the config directory containerd expects.

```bash
sudo mkdir -p /etc/containerd
```

Generate the default config file into place.

```bash
containerd config default | sudo tee /etc/containerd/config.toml
```

## 2. Run containerd as a systemd service

The binary release doesn't register a service — you have to install the unit file
yourself, otherwise there's no daemon listening on `/run/containerd/containerd.sock`
and every `nerdctl`/`ctr` command will fail with:

```
FATA[0000] cannot access containerd socket "/run/containerd/containerd.sock": no such file or directory
```

Download the official systemd unit file.

```bash
curl -fsSL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /tmp/containerd.service
```

Install it where systemd looks for unit files.

```bash
sudo cp /tmp/containerd.service /etc/systemd/system/containerd.service
```

Reload systemd so it picks up the new unit file.

```bash
sudo systemctl daemon-reload
```

Enable it (start on boot) and start it now, in one step.

```bash
sudo systemctl enable --now containerd
```

Confirm it's active — you should see `active (running)`.

```bash
sudo systemctl status containerd
```

## 3. Install runc

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

## 4. Install nerdctl

Set the version.

```bash
NERDCTL_VER="2.3.4"
```

Download the release tarball.

```bash
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
```

Extract just the `nerdctl` binary from the tarball.

```bash
tar -xvf nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz nerdctl
```

Move it into your `PATH`.

```bash
sudo mv nerdctl /usr/local/bin/
```

Remove the tarball.

```bash
rm nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
```

Confirm it works.

```bash
nerdctl --version
```

## 5. Install CNI plugins (container networking)

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

## 6. Install buildkit (optional, needed for `nerdctl build`)

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

## 7. Test it

Run a container in the background.

```bash
sudo nerdctl run -d --name redis redis:alpine
```

List running containers to confirm it's up.

```bash
sudo nerdctl ps
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
sudo nerdctl rm -f redis
```

Then retry the run.

```bash
sudo nerdctl run -d --name redis redis:alpine
```

## Troubleshooting summary

| Error | Cause | Fix |
|---|---|---|
| `cannot access containerd socket ... no such file or directory` | containerd daemon isn't running | Install + start the systemd service (step 2) |
| `exec: "runc" executable file not found in $PATH` | `runc` not installed | Install `runc` (step 3) |
| `name "X" is already used by ID "..."` | Leftover container object from a prior failed run | `sudo nerdctl rm -f X` |

## Full cleanup (start over from scratch)

Remove any running/stopped containers first.

```bash
sudo nerdctl rm -f $(sudo nerdctl ps -aq)
```

Stop and disable the systemd service.

```bash
sudo systemctl disable --now containerd
```

Remove the systemd unit file.

```bash
sudo rm -f /etc/systemd/system/containerd.service
```

Reload systemd so it forgets the removed unit.

```bash
sudo systemctl daemon-reload
```

Remove containerd's data, runtime, and config directories.

```bash
sudo rm -rf /var/lib/containerd /run/containerd /etc/containerd
```

Remove the CNI plugins directory.

```bash
sudo rm -rf /opt/cni
```

Remove every binary installed in this tutorial.

```bash
sudo rm -f /usr/local/bin/containerd /usr/local/bin/containerd-shim-runc-v2 /usr/local/bin/containerd-stress /usr/local/bin/ctr /usr/local/bin/runc /usr/local/bin/nerdctl /usr/local/bin/buildctl /usr/local/bin/buildkitd /usr/local/bin/buildkit-*
```

Verify everything is gone — these should print nothing / "No such file or directory".

```bash
which containerd ctr nerdctl runc buildctl buildkitd
```

```bash
ls /etc/containerd /opt/cni /var/lib/containerd
```

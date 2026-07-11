# Installing containerd + nerdctl from binaries (no Docker)

This is the full, working install path for running containers with `containerd` and
`nerdctl` directly, without Docker. It covers every piece that's actually required —
including the two that are easy to miss: the `containerd` systemd service and `runc`.

Scripts in this folder (`install.sh`, `ctr.sh`, `nerdctl.sh`) download the binaries
below; this tutorial adds the missing setup steps and explains why each one exists.

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

```bash
CONTAINERD_VER="2.3.0"
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
rm containerd-${CONTAINERD_VER}-linux-amd64.tar.gz

export PATH=$PATH:/usr/local/bin   # add to ~/.bashrc to persist
ctr --version
```

Generate the default config:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

## 2. Run containerd as a systemd service

The binary release doesn't register a service — you have to install the unit file
yourself, otherwise there's no daemon listening on `/run/containerd/containerd.sock`
and every `nerdctl`/`ctr` command will fail with:

```
FATA[0000] cannot access containerd socket "/run/containerd/containerd.sock": no such file or directory
```

```bash
curl -fsSL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
  -o /tmp/containerd.service
sudo cp /tmp/containerd.service /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd   # should show "active (running)"
```

## 3. Install runc

This is the piece most tutorials forget. Without it, `containerd`/`nerdctl` run fine
and can even pull images, but fail the moment they try to actually start a container:

```
FATA[0009] failed to create shim task: OCI runtime create failed: ...
exec: "runc" executable file not found in $PATH
```

```bash
RUNC_VER="1.5.0"
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/bin/runc
rm runc.amd64
runc --version
```

## 4. Install nerdctl

```bash
NERDCTL_VER="2.3.4"
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
tar -xvf nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz nerdctl
sudo mv nerdctl /usr/local/bin/
rm nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
nerdctl --version
```

## 5. Install CNI plugins (container networking)

```bash
CNI_VER="1.9.1"
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_VER}/cni-plugins-linux-amd64-v${CNI_VER}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v${CNI_VER}.tgz
rm cni-plugins-linux-amd64-v${CNI_VER}.tgz
```

## 6. Install buildkit (optional, needed for `nerdctl build`)

```bash
BUILDKIT_VER="0.31.1"
wget https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VER}/buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
tar -xvf buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
sudo mv bin/* /usr/local/bin/
rm buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
```

## 7. Test it

```bash
sudo nerdctl run -d --name redis redis:alpine
sudo nerdctl ps
```

If you re-run a container name that failed to start on a previous attempt (e.g.
before `runc` was installed), containerd may still have the name registered even
though no container is running:

```
FATA[0000] name-store error
name "redis" is already used by ID "..."
```

Clean it up first, then retry:

```bash
sudo nerdctl rm -f redis
sudo nerdctl run -d --name redis redis:alpine
```

## Troubleshooting summary

| Error | Cause | Fix |
|---|---|---|
| `cannot access containerd socket ... no such file or directory` | containerd daemon isn't running | Install + start the systemd service (step 2) |
| `exec: "runc" executable file not found in $PATH` | `runc` not installed | Install `runc` (step 3) |
| `name "X" is already used by ID "..."` | Leftover container object from a prior failed run | `sudo nerdctl rm -f X` |

# Installing containerd + nerdctl from binaries, rootful (systemd-managed)

This is the rootful counterpart to [TUTORIAL.md](TUTORIAL.md). It installs `containerd`
as a root-owned systemd service — the same way a real Kubernetes node runs it — instead
of the unprivileged, per-user setup the main tutorial uses.

Everything runs with `sudo`. There is no `rootlesskit`, `slirp4netns`,
`containerd-rootless-setuptool.sh`, or subuid/subgid mapping in this path — those only
exist to let containerd run *without* root, which isn't the goal here.

## Why rootful this time

The main tutorial deliberately avoids rootful containerd because mixing it with a
rootless install on the same machine causes two independent daemons to silently
coexist (see TUTORIAL.md's "Why rootless, not rootful" section). That risk goes away
if rootful is the *only* stack on the machine — which is what this tutorial sets up.
This is also closer to how `kubeadm`-provisioned nodes are actually configured, which
matters if you're practicing for that.

**Do not run this alongside a rootless install on the same machine.** If you have a
rootless setup already, tear it down completely first (see TUTORIAL.md's "Full
cleanup" section) before following the steps below.

## What you need, and why

| Component     | Role                                                              |
|----------------|--------------------------------------------------------------------|
| `containerd`   | The daemon that manages images, containers, and storage            |
| `runc`         | The low-level OCI runtime that actually creates container processes |
| `nerdctl`      | Docker-compatible CLI that talks to `containerd`                   |
| CNI plugins    | Container networking (so containers get an IP, can reach network)  |
| `crictl`       | CRI-level CLI — talks to containerd's CRI plugin directly, the same interface kubelet uses |
| `buildkit`     | Optional — builds images from Dockerfiles (`nerdctl build`)        |

`containerd` on its own only manages the daemon and images — it delegates actually
starting a container process to `runc`. Skipping that step leaves every other tool
reporting a successful install while containers still fail to start.

## 1. Install containerd

```bash
CONTAINERD_VER="2.3.0"
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
rm containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
```

Make sure `/usr/local/bin` is on your `PATH` (add to `~/.bashrc` to persist).

```bash
export PATH=$PATH:/usr/local/bin
ctr --version
```

## 2. Install runc

```bash
RUNC_VER="1.5.0"
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VER}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/bin/runc
rm runc.amd64
runc --version
```

## 3. Install nerdctl (full tarball)

```bash
NERDCTL_VER="2.3.4"
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
sudo tar Cxzf /usr/local/bin nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
rm nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz
nerdctl --version
```

The tarball also includes `containerd-rootless.sh` /
`containerd-rootless-setuptool.sh` — harmless to have installed, just unused in this
setup.

## 4. Install CNI plugins (container networking)

```bash
CNI_VER="1.9.1"
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_VER}/cni-plugins-linux-amd64-v${CNI_VER}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v${CNI_VER}.tgz
rm cni-plugins-linux-amd64-v${CNI_VER}.tgz
```

> containerd separately writes CNI *config* (network definitions) to `/etc/cni/net.d`
> the first time you run a container — you don't create that yourself.

## 5. Install crictl

`crictl` talks to containerd's CRI plugin directly — the same interface `kubelet`
uses on a real Kubernetes node. Rootful containerd exposes this cleanly at the
standard socket, so unlike the rootless setup, no namespace gymnastics are needed to
reach it.

```bash
CRICTL_VER="1.36.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VER}/crictl-v${CRICTL_VER}-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-v${CRICTL_VER}-linux-amd64.tar.gz
rm crictl-v${CRICTL_VER}-linux-amd64.tar.gz
crictl --version
```

Point it at the rootful containerd socket by default, so you don't need
`--runtime-endpoint`/`--image-endpoint` flags on every call:

```bash
sudo tee /etc/crictl.yaml >/dev/null <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

## 6. Set up the containerd systemd service

```bash
curl -fsSL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /tmp/containerd.service
sudo cp /tmp/containerd.service /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

## 7. Install buildkit (optional, needed for `nerdctl build`)

```bash
BUILDKIT_VER="0.31.1"
wget https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VER}/buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
tar -xvf buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
sudo mv bin/* /usr/local/bin/
rm buildkit-v${BUILDKIT_VER}.linux-amd64.tar.gz
```

## 8. Test it

Every command needs `sudo` from here on — there's no rootless daemon to fall back to.

```bash
sudo nerdctl run -d --name redis redis:alpine
sudo nerdctl ps
```

Check the same containerd through the CRI lens with `crictl`. Note that `nerdctl`
containers live in containerd's `default` namespace while `crictl`/CRI operates in
the `k8s.io` namespace — so `sudo crictl ps` won't show containers started with
`nerdctl`, and vice versa. That's expected: `crictl` is for inspecting what a kubelet
(or you, imitating one) manages via CRI, not a general-purpose replacement for
`nerdctl ps`.

```bash
sudo crictl pull busybox
sudo crictl images
sudo crictl ps -a
```

If you re-run a container name that failed to start on a previous attempt, containerd
may still have the name registered even though no container is running:

```
FATA[0000] name-store error
name "redis" is already used by ID "..."
```

Remove the leftover name/ID before retrying.

```bash
sudo nerdctl rm -f redis
```

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `exec: "runc" executable file not found in $PATH` | `runc` not installed | Install `runc` (step 2) |
| `name "X" is already used by ID "..."` | Leftover container object from a prior failed run | `sudo nerdctl rm -f X` |
| `failed to verify networking settings: failed to create default network: subnet 10.4.0.0/24 overlaps with other one on this address space` | A `nerdctl0` (or similar) bridge interface from a *previous rootless install* is still on the host holding that subnet | `ip link show nerdctl0` to confirm, then `sudo ip link delete nerdctl0` |
| `crictl` commands hang or say `connect: no such file or directory` | containerd service isn't running, or `/etc/crictl.yaml` points at the wrong socket | `sudo systemctl status containerd`; confirm `/etc/crictl.yaml` has `unix:///run/containerd/containerd.sock` |
| `sudo crictl ps` shows nothing even though `nerdctl ps` shows containers | Not a bug — `nerdctl` uses containerd's `default` namespace, `crictl`/CRI uses `k8s.io`. They're intentionally separate. | Use `nerdctl` to inspect `nerdctl`-started containers, `crictl` to inspect CRI/kubelet-managed ones |

## Full cleanup (start over from scratch)

```bash
sudo nerdctl rm -f $(sudo nerdctl ps -aq) 2>/dev/null

sudo systemctl disable --now containerd
sudo rm -f /etc/systemd/system/containerd.service
sudo systemctl daemon-reload

sudo rm -rf /var/lib/containerd /etc/containerd
sudo rm -f /etc/crictl.yaml
sudo rm -rf /opt/cni /etc/cni
sudo rm -rf /run/nri

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
           /usr/local/bin/crictl

which containerd ctr nerdctl runc buildctl buildkitd crictl
ls /etc/containerd /etc/cni /opt/cni /var/lib/containerd /run/nri 2>&1
sudo systemctl status containerd 2>&1 | head -3
ps aux | grep -E 'containerd|buildkitd' | grep -v grep
```

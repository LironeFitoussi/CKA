# Installation (Linux preferred)
# 1. Download the latest release from
wget https://github.com/containerd/containerd/releases/download/v2.3.0/containerd-2.3.0-linux-amd64.tar.gz

# 2. Extract the tarball into /usr/local (creates /usr/local/bin/{containerd,ctr,...})
sudo tar Cxzvf /usr/local containerd-2.3.0-linux-amd64.tar.gz

# 3. Remove the downloaded tarball, it's no longer needed
rm containerd-2.3.0-linux-amd64.tar.gz

# 4. Make sure /usr/local/bin is on PATH, then test the installation
export PATH=$PATH:/usr/local/bin
ctr --version

# 5. Generate the default config where the containerd daemon expects it
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# 6. (Optional) run containerd as a systemd service
# curl -o containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
# sudo mv containerd.service /usr/lib/systemd/system/containerd.service
# sudo systemctl daemon-reload
# sudo systemctl enable --now containerd
#! Install nerdctl on Linux
# List of packages for nerdctl installation:
#? - nerdctl: The command-line interface for containerd, allowing users to manage containers and images.
#* link: https://github.com/containerd/nerdctl/releases#release-v2.3.4
#TODO a1 Download the latest release from
wget https://github.com/containerd/nerdctl/releases/download/v2.3.4/nerdctl-2.3.4-linux-amd64.tar.gz
#TODO a2 Extract the tarball
tar -xvf nerdctl-2.3.4-linux-amd64.tar.gz nerdctl

# tar refersher:
# x - extract files from an archive
# v - verbosely list files processed
# f - use archive file
# 1st argument is the archive file name, and the 2nd argument is the file to extract from the archive.
# in short, the command extracts the contents of the nerdctl-2.3.4-linux-amd64.tar.gz archive file and lists the files being extracted. 

# 3. Move the binary to a directory in your PATH
sudo mv nerdctl /usr/local/bin/

# 4. remove the downloaded tarball
rm nerdctl-2.3.4-linux-amd64.tar.gz

#? - CNI plugins: A set of networking plugins for container networking, enabling containers to communicate with each other and the host network.
#* link: https://github.com/containernetworking/plugins/releases
#TODO b1 Download the latest release from
wget https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-amd64-v1.9.1.tgz

#TODO b2 Create a directory for CNI plugins
sudo mkdir -p /opt/cni/bin

#TODO b3 Extract the tarball to the CNI plugins directory
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.9.1.tgz

#TODO b4 remove the downloaded tarball
rm cni-plugins-linux-amd64-v1.9.1.tgz

#* (OPTIONAL but recommended)
#? -buildkit: A toolkit for building container images, providing advanced features and optimizations for image creation.
#* link: https://github.com/moby/buildkit/releases

#TODO: c1 Download the latest release from
wget https://github.com/moby/buildkit/releases/download/v0.31.1/buildkit-v0.31.1.linux-amd64.tar.gz
# darwin refresher
#? - darwin: The macOS operating system, which is used for development and testing containerized applications.
# TODO: c2 Extract the tarball
tar -xvf buildkit-v0.31.1.linux-amd64.tar.gz 

# TODO: c3 Move the binaries to a directory in your PATH
sudo mv bin/* /usr/local/bin/

# TODO: c4 remove the downloaded tarball
rm buildkit-v0.31.1.linux-amd64.tar.gz

# final step: Test the installation
nerdctl --version

# even better:
sudo nerdctl run -d --name redis redis:alpine
# Own /dev/kvm
sudo chmod 0666 /dev/kvm

# Update to the latest
nix-channel --add https://nixos.org/channels/nixos-unstable nixos \
    && nixos-rebuild switch --upgrade

# Make ramdisk
mkdir ~/ramdisk
mount -t tmpfs none ~/ramdisk
mkdir -p ~/ramdisk/workspace/nixpkgs

# Allow unfree
mkdir -p ~/.config/nixpkgs
cat > ~/.config/nixpkgs/config.nix << EOF
{
  allowUnfree = true;
}
EOF

# Point nix to the local store on the ramdisk and enable more features
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
system-features = nixos-test benchmark big-parallel kvm
experimental-features = nix-command flakes
store = $HOME/ramdisk
EOF

# Install some tools we'll need
nix profile install nixpkgs/nixpkgs-unstable#{git,awscli2,zstd}

# Copy and unpack nixpkgs
curl -L https://github.com/ConnorBaker/nixpkgs/archive/refs/heads/nixpkgs-unstable.tar.gz \
        | tar -xz --directory ~/ramdisk/workspace/nixpkgs --strip-components 1

# Build the test for hadoop
cd ~/ramdisk/workspace
nix build -f ./nixpkgs/nixos/tests/hadoop/hadoop.nix --print-build-logs --debug 2>build_log.txt

# TODO: Tar and then zstd the ramdisk
# TODO: Make a copy of the log (keep it surface level to avoid large blobs)

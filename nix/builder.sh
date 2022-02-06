#! /usr/bin/env bash

source $stdenv/setup

buildPhase() {
  ssh-keygen -t ed25519 -f id_ed25519 -N ""
  chmod 0400 id_ed25519 id_ed25519.pub
  cp nix/run.sh nix/nix-hadoop-aarch64-test
  chmod +x nix/nix-hadoop-aarch64-test
}

installPhase() {
  mkdir -p $out/{bin,ssh}
  cp id_ed25519 id_ed25519.pub $out/ssh
  cp nix/nix-hadoop-aarch64-test $out/bin/nix-hadoop-aarch64-test
}

genericBuild

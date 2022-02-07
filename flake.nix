{
  description = "A flake for provisioning AWS EC2 instances with NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      with nixpkgs.legacyPackages.${system};
      rec {
        devShell = mkShell rec {
          buildInputs = [
            awscli2
            terraform
            openssh
            coreutils
            nmap
          ];
        };
      });
}

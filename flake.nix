{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      # Import local override if it exists
      imports = [
        (
          if builtins.pathExists ./local.nix
          then ./local.nix
          else {}
        )
      ];

      # Sensible defaults
      systems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: let
        node = pkgs.nodejs;
        nil = pkgs.nil;
        task = pkgs.go-task;
        coreutils = pkgs.coreutils;
        trunk = pkgs.trunk-io;
        copier = pkgs.copier;
        cockroachdb = pkgs.cockroachdb-bin;
        envsubst = pkgs.envsubst;
        tini = pkgs.tini;
        su-exec = pkgs.su-exec;
        usql = pkgs.usql;
      in {
        # Override pkgs argument
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            # Allow packages with non-free licenses
            allowUnfree = true;
            # Allow packages with broken dependencies
            allowBroken = true;
            # Allow packages with unsupported system
            allowUnsupportedSystem = true;
          };
        };

        # Set which formatter should be used
        formatter = pkgs.alejandra;

        # Define multiple development shells for different purposes
        devShells = {
          default = pkgs.mkShell {
            name = "dev";

            packages = [
              node
              nil
              task
              coreutils
              trunk
              copier
              cockroachdb
              envsubst
              usql
            ];
          };

          runtime = pkgs.mkShell {
            name = "runtime";

            packages = [
              cockroachdb
              envsubst
              tini
              su-exec
            ];
          };

          template = pkgs.mkShell {
            name = "template";

            packages = [
              task
              coreutils
              copier
            ];
          };

          lint = pkgs.mkShell {
            name = "lint";

            packages = [
              node
              task
              coreutils
              trunk
            ];
          };

          docs = pkgs.mkShell {
            name = "docs";

            packages = [
              node
              task
              coreutils
            ];
          };
        };
      };
    };
}

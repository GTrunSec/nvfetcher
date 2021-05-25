{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    devshell-flake.url = "github:numtide/devshell";
  };
  outputs = { self, nixpkgs, flake-utils, flake-compat, devshell-flake, ... }:
    with flake-utils.lib;
    eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
              devshell-flake.overlay
            ];
          };
        in
        with pkgs; rec {
          defaultPackage = nvfetcher-bin;
          devShell = with pkgs;
            devshell.mkShell {
              packages = [
                cabal2nix
                devEnv
              ];
              commands = with pkgs; [
                {
                  name = "cabal2nvfetcher";
                  command = "cd nix && cabal2nix ../. > default.nix && git apply ignore.patch";
                  help = "call cabal2nix to nvfetcher";
                }
              ];
            };
          packages.nvfetcher-lib = with haskell.lib;
            overrideCabal
              (haskellPackages.nvfetcher)
              (drv: {
                haddockFlags = [
                  "--html-location='https://hackage.haskell.org/package/$pkg-$version/docs'"
                ];
              });
          hydraJobs = {
            inherit packages;
          };
        }) // {
      overlay = final: prev:
        {
          haskellPackages = prev.haskellPackages.override
            (old: {
              overrides = hself: hsuper: {
                nvfetcher = prev.haskellPackages.callPackage ./nix { };
              };
            });

          nvfetcher-bin = with prev;
            with final.haskellPackages;
            lib.overrideDerivation
              (haskell.lib.justStaticExecutables nvfetcher)
              (drv: {
                nativeBuildInputs = drv.nativeBuildInputs ++ [ makeWrapper ];
                postInstall = ''
                    EXE=${lib.makeBinPath [ nvchecker nix-prefetch-git ]}
                  wrapProgram $out/bin/nvfetcher \
                  --prefix PATH : "$out/bin:$EXE"
                '';
              });

          devEnv = with prev; (haskell.lib.addBuildTools final.haskellPackages.nvfetcher
            [
              haskell-language-server
              cabal-install
              nvchecker
              nix-prefetch-git
            ]
          );
        };
    };
}

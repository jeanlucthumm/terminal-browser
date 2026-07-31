{
  description = "A real browser that runs inside your terminal";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      release = builtins.fromJSON (builtins.readFile ./nix/release.json);

      # Every release tarball is pinned in nix/release.json, but only Apple
      # Silicon is packaged for now: the Linux tarballs need ELF patching to
      # run on NixOS, and nixpkgs-unstable dropped Intel macs in 26.11.
      targets = {
        aarch64-darwin = "darwin-arm64";
      };

      package =
        system: target:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "terminal-browser";
          version = release.version;

          src = pkgs.fetchurl {
            url = "https://github.com/zenbu-labs/terminal-browser/releases/download/${release.version}/terminal-browser-${target}.tar.gz";
            sha256 = release.platforms.${target};
          };

          installPhase = ''
            mkdir -p $out/opt $out/bin
            cp -R . $out/opt/terminal-browser
            ln -s $out/opt/terminal-browser/bin/terminal-browser $out/bin/terminal-browser
          '';

          # Fixup would rewrite the Mach-O binaries and invalidate their code
          # signatures, so the bundle must be installed untouched.
          dontFixup = true;

          meta = {
            description = "A real browser that runs inside your terminal";
            homepage = "https://github.com/zenbu-labs/terminal-browser";
            license = pkgs.lib.licenses.mit;
            platforms = builtins.attrNames targets;
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
            mainProgram = "terminal-browser";
          };
        };
    in
    {
      packages = builtins.mapAttrs (
        system: target:
        let
          terminal-browser = package system target;
        in
        {
          inherit terminal-browser;
          default = terminal-browser;
        }
      ) targets;

      apps = builtins.mapAttrs (system: target: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/terminal-browser";
        };
      }) targets;
    };
}

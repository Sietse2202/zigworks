{
  description = "Zigworks flake";

  inputs = {
    zls.url = "github:zigtools/zls?ref=0.15.1";
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = {
    zig2nix,
    zls,
    ...
  }: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
    zlsPkg = zls.packages.${system}.default;
    env = zig2nix.outputs.zig-env.${system} {
      zig = zig2nix.outputs.packages.${system}.zig-0_15_2;
    };
  in
    with builtins;
    with env.lib;
    with env.pkgs.lib; {
      packages.target = genAttrs allTargetTriples (target:
        env.packageForTarget target {
          src = cleanSource ./.;
        });

      apps.test = env.app [] "zig build test -- \"$@\"";
      apps.docs = env.app [] "zig build docs -- \"$@\"";
      apps.deps = env.showExternalDeps;
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      devShells.default = env.mkShell {
        nativeBuildInputs = [zlsPkg];
      };
    }));
}

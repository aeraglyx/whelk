{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
    packages = with pkgs; [
        julia
    ];
	env = {
		JULIA_NUM_THREADS = "auto";
	};
}

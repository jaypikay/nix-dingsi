{
  lib,
  fetchFromGitHub,
}: let
  version = "0.26.0";
in {
  inherit version;

  src = fetchFromGitHub {
    owner = "Donkie";
    repo = "Spoolman";
    rev = "v${version}";
    hash = lib.fakeHash;
  };

  meta = {
    description = "Keep track of your inventory of 3D-printer filament spools";
    homepage = "https://github.com/Donkie/Spoolman";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      MayNiklas
      pinpox
    ];
    mainProgram = "spoolman";
  };
}

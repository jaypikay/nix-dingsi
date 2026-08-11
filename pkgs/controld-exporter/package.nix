{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchpatch,
  nixosTests,
}:
buildGoModule (finalAttrs: {
  pname = "controld-exporter";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "umatare5";
    repo = "controld-exporter";
    rev = "d551f8a16148c5e3d85522c33ad96bad377e9eb6";
    hash = "sha256-ovcqCy+OKBRnqWunxI/qghsQGmXWdHvr84R/Qhlj42E=";
  };

  vendorHash = "sha256-8X+nQ46ewMdViJAr+v7+ctx7au+Nozs2j12T7VPlNIo=";

  meta = {
    inherit (finalAttrs.src.meta) homepage;
    description = "Prometheus metrics exporter for ControlD";
    mainProgram = "controld-exporter";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      jaypikay
    ];
  };
})

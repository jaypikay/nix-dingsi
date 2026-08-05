{
  python312,
  lib,
  callPackage,
  writeShellScript,
  makeWrapper,
}:

let
  common = callPackage ./common.nix { };
  frontend = callPackage ./frontend.nix { };
  frontendV2 = callPackage ./frontend-v2.nix { };
  # fastapi/hishel pull in a chain of test-only tools that are never
  # actually needed to build or run spoolman (fastapi's nativeCheckInputs
  # -> inline-snapshot -> isort -> pylama -> vulture -> pint ->
  # uncertainties/scipy get merged into nativeBuildInputs unconditionally
  # by nixpkgs). Several of these have their own environment-sensitive
  # test suites (a hypothesis-generated numerical precision failure in
  # scipy, a black-formatting-version mismatch in inline-snapshot) that
  # fail here. Disable their installCheck phases via package overrides so
  # every package referencing python.pkgs.<name> picks up the fixed
  # variant.
  python = python312.override {
    packageOverrides = _self: super: {
      scipy = super.scipy.overrideAttrs (_old: {
        doCheck = false;
        doInstallCheck = false;
      });
      inline-snapshot = super.inline-snapshot.overrideAttrs (_old: {
        doCheck = false;
        doInstallCheck = false;
      });
    };
  };
  hishel_0_1 = python.pkgs.hishel.overrideAttrs (old: rec {
    version = "0.1.5";
    src = old.src.override {
      tag = version;
      hash = "sha256-OyQR/ruowNk5z4ITRHcIJn1kc0xLZiofmxajf6hNR9k=";
    };
  });
  aiomysql = python.pkgs.aiomysql.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      python.pkgs.pythonRelaxDepsHook
    ];
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "setuptools-scm" ];
    # pythonRelaxDepsHook only relaxes [project.dependencies], not
    # [build-system.requires], so the setuptools_scm upper bound there
    # must be patched manually to allow the newer version in nixpkgs.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace pyproject.toml \
        --replace-fail 'setuptools_scm[toml] >= 7, < 10' 'setuptools_scm[toml] >= 7'
    '';
  });
in

python.pkgs.buildPythonPackage rec {

  pname = "spoolman";
  inherit (common) version src;

  pyproject = true;

  nativeBuildInputs = [
    makeWrapper
    python.pkgs.setuptools
    python.pkgs.pythonRelaxDepsHook
  ];

  pythonRelaxDeps = [
    "setuptools"
    "websockets"
    "setuptools-scm"
  ];

  postPatch = ''
    substituteInPlace pyproject.toml --replace-fail psycopg2-binary psycopg2

    # upstream removed [build-system] in 0.23.x, causing setuptools
    # to fail on the flat layout with multiple top-level directories
    cat >> pyproject.toml <<EOF

    [build-system]
    requires = ["setuptools"]
    build-backend = "setuptools.build_meta"

    [tool.setuptools.packages.find]
    include = ["spoolman*"]
    EOF
  '';

  propagatedBuildInputs = with python.pkgs; [
    uvloop
    alembic
    aiomysql
    anysqlite
    asyncpg
    fastapi
    hishel_0_1
    httptools
    httpx
    aiosqlite
    platformdirs
    prometheus-client
    psycopg2
    pydantic
    scheduler
    setuptools
    sqlalchemy
    sqlalchemy-cockroachdb
    uvicorn
    websockets
  ];

  pythonImportsCheck = [ "spoolman" ];

  postInstall =
    let
      start_script = writeShellScript "start-spoolman" ''
        ${lib.getExe python.pkgs.uvicorn} "$@" spoolman.main:app;
      '';
    in
    ''
      mkdir -p $out/runpath/client/dist $out/runpath/client_v2/build $out/bin
      cp -r $src/* $out/runpath
      cp -r ${frontend}/* $out/runpath/client/dist
      cp -r ${frontendV2}/* $out/runpath/client_v2/build

      makeWrapper ${start_script} $out/bin/spoolman \
      --chdir $out/runpath \
      --prefix PYTHONPATH : "$out/${python.sitePackages}" \
      --prefix PYTHONPATH : "${python.pkgs.makePythonPath propagatedBuildInputs}" \
      --prefix PATH : "${python.pkgs.alembic}/bin"
    '';

  meta = common.meta // {
    description = "Spoolman server";
    mainProgram = "spoolman";
  };
}

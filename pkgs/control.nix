{ pkgs
, stdenv
, contrailVersion
, contrailBuildInputs
, contrailWorkspace
, isContrail41
}:

stdenv.mkDerivation rec {
  name = "contrail-control-${version}";
  version = contrailVersion;
  src = contrailWorkspace;
  USER = "contrail";
  # Only required on R4.1
  dontUseCmakeConfigure = true;

  buildInputs = contrailBuildInputs;

  buildPhase = ''
    scons -j1 --optimization=production contrail-control
  '';
  installPhase = ''
    mkdir -p $out/{bin,etc/contrail}
    cp build/production/control-node/contrail-control $out/bin/
    cp ${contrailWorkspace}/controller/src/control-node/contrail-control.conf $out/etc/contrail/
  '';
}


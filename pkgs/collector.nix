{ pkgs
, stdenv
, libgrok
, contrailVersion
, contrailWorkspace
, contrailBuildInputs
, isContrail32
}:

stdenv.mkDerivation rec {
  name = "contrail-collector-${version}";
  version = contrailVersion;
  src = contrailWorkspace;
  USER="contrail";

  # Only required on master
  dontUseCmakeConfigure = true;
  buildInputs = with pkgs;
    contrailBuildInputs ++
    [ coreutils cyrus_sasl.dev gperftools lz4.dev libgrok pcre.dev tokyocabinet libevent.dev ];

  # To fix a scons cycle on buildinfo
  patches = pkgs.lib.optional isContrail32 [ ./patches/analytics.patch ];
  patchFlags = "-p0";

  buildPhase = ''
    # To export pyconfig.h. This should be patched into the python derivation instead.
    export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -isystem ${pkgs.python}/include/python2.7/"

    scons -j1 --optimization=production contrail-collector
  '';
  installPhase = ''
    mkdir -p $out/{bin,etc/contrail}
    cp build/production/analytics/vizd $out/bin/contrail-collector
    cp ${contrailWorkspace}/controller/src/analytics/contrail-collector.conf $out/etc/contrail/
  '';
}

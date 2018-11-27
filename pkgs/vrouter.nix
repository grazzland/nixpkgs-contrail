{ pkgs
, stdenv
, contrailVersion
, contrailWorkspace
, contrailBuildInputs
, isContrail41
}:

with pkgs.lib;

kernelHeaders: stdenv.mkDerivation rec {
  name = "contrail-vrouter-${kernelHeaders.name}";
  version = contrailVersion;
  src = contrailWorkspace;
  hardeningDisable = [ "pic" ];
  USER = "contrail";
  KERNEL_VERSION = getVersion kernelHeaders;
  # Only required on R4.1
  dontUseCmakeConfigure = true;
  buildInputs = contrailBuildInputs ++ [ pkgs.libelf ];
  buildPhase = ''
    # We patch the kernel Makefile ONLY to reduce the closure
    # size of the vrouter kernel module. Without this patch, the
    # kernel source are referenced by the output path. See the issue
    # https://github.com/NixOS/nixpkgs/issues/34006.
    # Note this is only used with Nix kernel headers.
    cp -r ${kernelHeaders} kernel-headers
    chmod -R a+w kernel-headers
    sed -i "s|MAKEARGS := -C /nix/store/.*-linux-${KERNEL_VERSION}-dev/lib/modules/${KERNEL_VERSION}/source|MAKEARGS := -C $PWD/kernel-headers/lib/modules/${KERNEL_VERSION}/source|" kernel-headers/lib/modules/${KERNEL_VERSION}/build/Makefile || true

    kernelSrc=$(echo $PWD/kernel-headers/lib/modules/*/build/)
    scons --optimization=production --kernel-dir=$kernelSrc vrouter/vrouter.ko
  '';
  installPhase = ''
    mkdir -p $out/lib/modules/$KERNEL_VERSION/extra/net/vrouter/
    cp vrouter/vrouter.ko $out/lib/modules/$KERNEL_VERSION/extra/net/vrouter/
  '';
  shellHook = ''
    kernelSrc=$(echo ${kernelHeaders}/lib/modules/*/build/)
  '';

  meta = {
    description = "Contrail vrouter kernel module for kernel ${kernelHeaders.name}";
  };
}


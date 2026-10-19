# OpenBoot

Sun's OpenBoot 4.x firmware sources (imported from
[openbios/openboot](https://github.com/openbios/openboot)) with a port to
x86 PCs.  The SPARC sources are under `obp/`, as released.

The x86 port builds an OpenBoot image that runs as a coreboot payload or
from a Multiboot loader; see [obp/arch/x86/README.md](obp/arch/x86/README.md).

    cd obp/arch/x86/pc && make && make run

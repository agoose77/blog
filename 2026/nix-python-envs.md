---
title: "Creating Python Environments with Nix"
date: 2026-02-25
---

## What is Nix/NixOS?

<wiki:NixOS> is a Linux distribution that is built on top of the Nix package manager. Amongst other things, this makes it possible to compose configurations across several machines, and makes continuous, reproducible system upgrades trivial. I host [my NixOS configuration](https://github.com/agoose77/nixos-config) publicly on GitHub. See [the configuration](https://github.com/agoose77/nixos-config/blob/9b9a0f3349ac57603c7ca803bed9f20749a80b10/modules/hosts/nixos/configuration.nix) for my main `nixos` host.

What makes NixOS shine is the Nix package manager. Nix expressions, written in the Nix Expression Language, are defined as pure functions that accept dependencies as arguments and produce a result that describes a reproducible build environment. Builds are performed in a sandbox, and the results stored using an addressing system that depends upon the hash of the full derivation dependency tree. This creates immutable package stores that enables atomic upgrades and rollbacks, as well as multiple-version installs.

## Distributing Python

Python has not earned a brilliant reputation with respect to packaging. Most of this is unfair; Python comes from a time before modern packaging practices and has grown organically to provide support for things like package indices and binary distributions. I don't think that any of the core developers would disagree with the assertion that if we could wave a magic wand, we'd have done things differently.

> Just beacuase they're smart doesn't mean they talk to each other.
>
> — CobaltCam on Python Developers, Reddit.

There are several package managers and indices that handle Python packages:

- The PyPI package index contains sdist and wheel distributions designed originally to be installed by `pip`.
- The conda package channels (such as conda-forge, and anaconda) that contain conda builds designed for installation by `conda` (and these days `micromamba` and `pixi`).
- The Debian package index containing `.deb` archives.

The list goes on.

The biggest change to Python package installation in recent times has been the introduction of the Python wheel. Finally, this made it possible to have Python distributions that didn't ship with an entire compilation toolchain, as wheels shift the burden of compilation onto the package author.

Wheels themselves are ultimately fancy ZIP archives. To support a range of different distributions of Python, wheels use a set of wheel-tags that encode platform and toolchain information (such as WASM, 32 bit, etc.). For Linux targets, Python uses a standard called [`manylinux`](https://peps.python.org/pep-0513/). `manylinux` is really just a quirky hack built on two observations:

1. Most Linux wheels fail to run on certain distributions due to missing shared libraries
2. Linux wheels built on newer systems (with new glibc versions) typically fail to run properly on older systems (with older glibc versions).

From analysing packages distributed in the Anaconda and Canopy distributions, a set of baseline shared libraries that most packages require was identified. The manylinux standard(s) simply encode the set of these libraries that compatible systems are expected to ship with, and the minimum version of glibc that they must have (given that the wheels are compiled against _this_ version).

## Python on NixOS

As mentioned above, `manylinux` makes it possible to run Python wheels on many kinds of Linux distributions. It effectively defines a runtime environment specification. NixOS distributions typically do not implement such a specification. Specifically, NixOS does not implement the <wiki:Filesystem_Hierarchy_Standard> or use dynamic linking. This means that a naive binary will not be able to locate _any_ shared libraries. Nix package builds typically set the `rpath` of built libraries so that they can locate their dependencies explicitly.

:::{pull-quote}
NixOS does not implement the <wiki:Filesystem_Hierarchy_Standard> or use dynamic linking.
:::

This means that a naive Python wheel, such as NumPy, will typically not load on a NixOS system without additional work. Let's first look at _how_ shared libraries are located on Linux systems (see @fig:linker-path).

:::{figure} https://circuitlabs.net/wp-content/uploads/2025/09/dynamic-linkers-search-path-65eb42.svg
:label: fig:linker-path

A process diagram of the dynamic linker's search path on Linux, from <https://circuitlabs.net>.
:::

Nix packages, such as the Python package taken from `nixpkgs`, have a hard-coded `RPATH` pointing to the pre-computed library directories for this package:

```{code} text
:emphasize-lines: 16
:label: readelf-python
:linenos:
# Get Python and readelf
❯ nix shell nixpkgs#python314 nixpkgs#bintools
# Find linker
> readelf $(which python) -p .interp
[     0]  /nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib/ld-linux-x86-64.so.2
# Look up search path
❯ readelf -d $(which python)

Dynamic section at offset 0x2d68 contains 33 entries:
  Tag        Type                         Name/Value
 0x0000000000000001 (NEEDED)             Shared library: [libpython3.14.so.1.0]
 0x0000000000000001 (NEEDED)             Shared library: [libdl.so.2]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libgcc_s.so.1]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x000000000000001d (RUNPATH)            Library runpath: [/nix/store/sddj4ifk8jdpqi1vzzz6cl7bb0cshskx-python3-3.14.0/lib:/nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib:/nix/store/xm08aqdd7pxcdhm0ak6aqb1v7hw5q6ri-gcc-14.3.0-lib/lib]
 0x000000000000000c (INIT)               0x1000
 0x000000000000000d (FINI)               0x114c
 0x0000000000000019 (INIT_ARRAY)         0x3d58
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x3d60
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x0000000000000004 (HASH)               0x408
 0x000000006ffffef5 (GNU_HASH)           0x458
 0x0000000000000005 (STRTAB)             0x5f0
 0x0000000000000006 (SYMTAB)             0x4a0
 0x000000000000000a (STRSZ)              445 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000015 (DEBUG)              0x0
 0x0000000000000003 (PLTGOT)             0x3fb8
 0x0000000000000002 (PLTRELSZ)           24 (bytes)
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000017 (JMPREL)             0x8c0
 0x0000000000000007 (RELA)               0x800
 0x0000000000000008 (RELASZ)             192 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000000000001e (FLAGS)              BIND_NOW
 0x000000006ffffffb (FLAGS_1)            Flags: NOW PIE
 0x000000006ffffffe (VERNEED)            0x7d0
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x7ae
 0x000000006ffffff9 (RELACOUNT)          3
 0x0000000000000000 (NULL)               0x0
```

The Python binary from nixpkgs is linked properly. But, if we use `pip` to install a package, we will quickly encounter a linking problem:

```{code} text
:emphasize-lines: 10
:linenos:
❯ python -m venv .venv > /dev/null
❯ source .venv/bin/activate > /dev/null
❯ pip install numpy > /dev/null
❯ python -c "import numpy"
Traceback (most recent call last):
  File "/tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/__init__.py", line 24, in <module>
    from . import multiarray
  File "/tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/multiarray.py", line 11, in <module>
    from . import _multiarray_umath, overrides
ImportError: libstdc++.so.6: cannot open shared object file: No such file or directory

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "<string>", line 1, in <module>
    import numpy
  File "/tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/__init__.py", line 112, in <module>
    from numpy.__config__ import show_config
  File "/tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/__config__.py", line 4, in <module>
    from numpy._core._multiarray_umath import (
    ...<3 lines>...
    )
  File "/tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/__init__.py", line 85, in <module>
    raise ImportError(msg) from exc
ImportError:

IMPORTANT: PLEASE READ THIS FOR ADVICE ON HOW TO SOLVE THIS ISSUE!

Importing the numpy C-extensions failed. This error can happen for
many reasons, often due to issues with your setup or how NumPy was
installed.

We have compiled some common reasons and troubleshooting tips at:

    https://numpy.org/devdocs/user/troubleshooting-importerror.html

Please note and check the following:

  * The Python version is: Python 3.14 from "/tmp/tmp.8UZkLANZSC/.venv/bin/python"
  * The NumPy version is: "2.4.2"

and make sure that they are the versions you expect.

Please carefully study the information and documentation linked above.
This is unlikely to be a NumPy issue but will be caused by a bad install
or environment on your machine.

Original error was: libstdc++.so.6: cannot open shared object file: No such file or directory

```

The problem is that the linker used by the Python binary is unable to locate the shared libraries required by the NumPy wheel and the `manylinux` specification:

```{code} text
:emphasize-lines: 4, 12
:linenos:
❯ ldd .venv/lib/python3.14/site-packages/numpy/_core/_multiarray_umath.cpython-314-x86_64-linux-gnu.so
    linux-vdso.so.1 (0x00007f7bede7a000)
    libscipy_openblas64_-096271d3.so => /tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/../../numpy.libs/libscipy_openblas64_-096271d3.so (0x00007f7bebc00000)
    libstdc++.so.6 => not found
    libm.so.6 => /nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib/libm.so.6 (0x00007f7bebb18000)
    libgcc_s.so.1 => /nix/store/2a3izq4hffdd9r9gb2w6q2ibdc86kss6-xgcc-14.3.0-libgcc/lib/libgcc_s.so.1 (0x00007f7bede46000)
    libc.so.6 => /nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib/libc.so.6 (0x00007f7beb800000)
    /nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib64/ld-linux-x86-64.so.2 (0x00007f7bede7c000)
    libpthread.so.0 => /nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66/lib/libpthread.so.0 (0x00007f7bede3f000)
    libgfortran-040039e1-0352e75f.so.5.0.0 => /tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/../../numpy.libs/libgfortran-040039e1-0352e75f.so.5.0.0 (0x00007f7beb200000)
    libquadmath-96973f99-934c22de.so.0.0.0 => /tmp/tmp.8UZkLANZSC/.venv/lib/python3.14/site-packages/numpy/_core/../../numpy.libs/libquadmath-96973f99-934c22de.so.0.0.0 (0x00007f7beae00000)
    libz.so.1 => not found
```

(sec:how-resolved)=

## How shared libraries are resolved

The `ld` dynamic linker follows [a strict process](https://man7.org/linux/man-pages/man8/ld.so.8.html#DESCRIPTION) for resolving dynamic libraries required by a program. Many programs set `DT_RPATH` or `DT_RUNPATH` dynamic attributes. These specify paths to directories containing shared libraries, and may include special tokens like `$ORIGIN` that define these paths relative to the library itself. The semantics of `DT_RUNPATH` and `DT_RPATH` are described in the `ld` manual page. These paths are used to resolve binaries in the `NEEDED` section of the library, e.g. those in @readelf-python. Importantly, there three important lookup paths for shared libraries:

1. The binary's `DT_RPATH` attribute (if the `DT_RUNPATH` attribute does not exist).
1. The path indicated by the `LD_LIBRARY_PATH` environment variable.
1. The binary's `DT_RUNPATH` attribute.

It follows that the system can modify which shared libraries are resolved by setting `LD_LIBRARY_PATH`, but only for binaries that either don't define `DT_RPATH` or for which the `DT_RPATH` location does not yield a matching library.

This is all very useful information, but it doesn't explain why we can't easily "fix" NixOS Python binaries to support wheels. Why can't we just set `DT_RPATH` / `DT_RUNPATH` on the Python binary to include paths to the required manylinux shared libraries? Well, there's a nuance. Whilst these paths are searched when linking `NEEDED` dependencies of the Python binary, `DT_RUNPATH` is not respected when resolving child dependencies (dependencies of NEEDED binaries). But, this is still not the reason. Rather, Python loads compiled modules like `numpy` using `dlopen`, which has [its own rules](https://www.man7.org/linux/man-pages/man3/dlopen.3.html#DESCRIPTION) for shared library resolution. As such, setting `LD_LIBRARY_PATH` is the only mechanism for fixing dynamically loaded Python libraries in a non-invasive (with respect to these libraries) manner.

:::{warning}
:label: prob:ld-lib-scope
However, changing `LD_LIBRARY_PATH` is a sledgehammer. It will easily break binaries that are expecting, for example, a particular version of libc or other binaries. There's no way to scope it to a single binary unless you shim the binary in question.
:::

## Changing the linker

An assumption in @sec:how-resolved is that we're using the standard dynamic linker `ld`. But, this is only an assumption. [`nix-ld`](https://github.com/nix-community/nix-ld) is a shim that enables system users to configure alternative dynamic library paths. It is designed to drop-in in place of the standard linker. This is where we can get clever. `nix-ld` lets us define a custom `NIX_LD_LIBRARY_PATH` that's set _only_ for the dynamic linker, resolving the problem outlined in @prob:ld-lib-scope. We can patch the `python` binary to use this linker, and shim the patched binary so that it sets `NIX_LD_LIBRARY_PATH`. This is what I've done in [my Python flake](https://github.com/agoose77/dev-flakes/blob/45e941722640b75cb55af326151c8a9af52f598b/python/venv-shell-hook.sh#L13-L33), which is [exposed via my `dev-flakes` as a package](https://github.com/agoose77/dev-flakes/blob/828aa4faa8ab65570313991f9db95a3d7f09833e/python/flake.nix#L18) that can be added to a `devShell` (as [in my dev flake](https://github.com/agoose77/dev-flakes/blob/828aa4faa8ab65570313991f9db95a3d7f09833e/python/flake.nix#L38)).

## Future work
In future, I think we can probably dispense with `nix-ld`. It's a bit of a sledgehammer for what we actually want to do. I suspect we can build a Nix derivation of `glibc` that either replaces the lookup of `LD_LIBRARY_PATH` with our own variable, or just hard-codes the lookup paths directly.

This blog post wasn't up to my normal standard, but I am aware that sometimes a bad blog post is better than no blog post!

---
title: "Creating Python Environments with Nix"
date: 2026-02-25
---

## What is Nix/NixOS?

<wiki:NixOS> is a Linux distribution that is built on top of the Nix package manager. Amongst other things, this makes it trivial to compose configurations across several machines, and makes continuous, reproducible system upgrades trivial. I host [my NixOS configuration](https://github.com/agoose77/nixos-config) publicly on GitHub.

What makes NixOS shine is the Nix package manager. Nix expressions, writtin the Nix Expression Language, are defined as pure functions that accept dependencies as arguments and produce a result that describes a reproducible build environment. Builds are performed in a sandbox, and the results stored using an addressing system that depends upon the hash of the full dependency tree of the derivation. This creates immutable package stores that enables atomic upgrades and rollbacks, as well as multiple-version installs.

## Distributing Python

Python has not earned a brilliant reputation with respect to packaging. Most of this is unfair; Python comes from a time before modern packaging practices and has grown organically to provide support for things like package indices and binary distributions. I don't think that any of the core developers would disagree with the assertion that if we could wave a magic wand, we'd have done things differently.

There are several package managers and indices that handle Python packages:

- The PyPI package index contains sdist and wheel distributions designed originally to be installed by `pip`.
- The conda package channels (such as conda-forge, and anaconda) that contain conda builds designed for installation by `conda` (and these days `micromamba` and `pixi`).
- The Debian package index containing `.deb` archives.

The list goes on.

The biggest change to Python package installation in recent times has been the introduction of the Python wheel. Finally this made it possible to have Python distributions that didn't ship with an entire compilation toolchain, as wheels shift the burden of compilation onto the package author.

Wheels themselves are ultimately fancy ZIP archives. To support a range of different distributions of Python, wheels use a set of wheel-tags that encode platform and toolchain information (such as WASM, 32 bit, etc.). For Linux targets, Python uses a standard called [`manylinux`](https://peps.python.org/pep-0513/). `manylinux` is really just a quirky hack built on two observations:

1. Most Linux wheels fail to run on certain distributions due to missing shared libraries
2. Linux wheells built on newer systems (with new glibc versions) typically fail to run properly on older systems (with older glibc versions).

From analysing packages distributed in the Anaconda and Canopy distributions, a set of baseline shared libraries that most packages require was identified. The manylinux standard(s) simply encode the set of these libraries that compatible systems are expected to ship with, and the minimum version of glibc that they must have (given that the wheels are compiled against _this_ version).

## Python on NixOS

As mentioned above, `manylinux` makes it possible to run Python wheels on many kinds of Linux distributions. It effectively defines a runtime environment specification. NixOS distributions typically do not implement such a specification. Specifically, NixOS does not implement the <wiki:Filesystem_Hierarchy_Standard> or use dynamic linking. This means that a naive binary will not be able to locate *any* shared libraries. Nix package builds typically set the `rpath` of built libraries so that they can locate their dependencies explicitly.

:::{pull-quote}
NixOS does not implement the <wiki:Filesystem_Hierarchy_Standard> or use dynamic linking.
:::

This means that a naive Python wheel, such as NumPy, will typically not load on a NixOS system without additional work. 
 
:::{note} To Do
- `LD_LIBRARY_PATH`
- `patchelf`
- packages shipping binaries
- Flakes showing this
:::



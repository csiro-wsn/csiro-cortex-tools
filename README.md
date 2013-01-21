csiro-cortex-tools
==============================

Development tools for wireless sensor nodes based on ARM Cortex-M3.

## Content

This directory contains a build script (build.sh) to compile the following tools:

1. GNU C Compiler (GCC) (Linaro-GCC-4.7.2013.01)

2. GNU Debugger (GDB) (Linaro-GDB-7.5-2012.12-1)

3. Newlib (2.0.0)

4. Binutils (binutils-2.23.1)

## Build Instructions:

1. Open a shell and change to the "src" directory of this repository.
2. Build the toolchain by running "PREFIX=<install-location> ./build.sh", where you have to substitute <install-location> with the desired final installation location for the toolchain (e.g. "/opt/csiro-cortex-tools/" or "$HOME/csiro-cortex-tools").  Binary files will be written to the "bin" folder within that location.
3. Add the location of the binary files (e.g. "/opt/csiro-cortex-tools/bin" or "$HOME/csiro-cortex-tools/bin") to the PATH environment variable of your shell. This can be done by adding the following line to your $HOME/.bashrc file (if you are using Bash):
```
export PATH=$PATH:$HOME/csiro-cortex-tools
```
4. Check if the gcc compiler for ARM is correctly installed by typing:
```
arm-none-eabi-gcc --version
```


# Contact: 

* [Philipp Sommer](mailto:Philipp.Sommer@csiro.au)

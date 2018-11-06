# act: automagic compiler tormentor

[![Build Status](https://travis-ci.com/MattWindsor91/act.svg?branch=master)](https://travis-ci.com/MattWindsor91/act)

`act` is a work-in-progress automatic compiler tester for finding
concurrency memory model discrepancies between C code and its
compiled assembly.  It uses
[memalloy](https://github.com/JohnWickerson/memalloy) as a test-case
generator, and will eventually generate litmus tests that can be
used with herd7.


## Licence and Acknowledgements

- The overall `act` project, and all original code, is licenced under
  the MIT licence: see `LICENSE`.

- The architecture lexers and parsers are based on those from
  [herd7](https://github.com/herd/herdtools7).  We include these in
  `act` under the provisos of herd's
  [CECILL-B](http://www.cecill.info/licences/Licence_CeCILL-B_V1-en.html)
  licence: see `LICENSE.herd`. _(Note: this does *not* constitute an
  official endorsement by the Herd team of this project.)_


## What it can do (so far)

- Run various versions of x86-32 gcc/clang against a set of memalloy
  witnesses (including experimental compile-by-SSH support);
- Sanitise the assembly output by removing or simplifying pieces of
  syntax that herd7 doesn't understand (though this process is
  inherently partial and prone to issues);
- Generate litmus tests from the sanitised assembly;
- Run herd on those litmus tests, saving the results for later
  inspection.
- Other modes allow per-file sanitisation, litmus generation,
  Herd running, etc.

Future versions of `act` will automate the comparison of herd output
against the memalloy input, and support more
compilers/architectures/dialects/instructions/syntax.


## Building and running

`act` uses the `dune` build system.  The practical upshot of this is
that, so long as you run `act` through `dune exec`, `dune` will
automatically build `act` for you when needed.


### Supported operating systems

`act` uses Jane Street's `core` library, which only works properly on
POSIX-style operating systems.  If you're using Windows, consider
using WSL, or Cygwin, etc.

We've tested `act` on:

- macOS (x86-64)
- Debian buster (x86-64): note: this is tested fairly infrequently, so
  there may be regressions compared to macOS


### Requirements

First, you'll need:

- OCaml (4.07+)
- opam (tested with version 2)
- dune (1.4+)

You'll then need to install several `opam` packages.  To find out which,
run `dune external-lib-deps --missing bin/main.exe`.

**NOTE**: For `menhirLib`, install the `menhir` OPAM package (not the
nonexistent `menhirLib` one!).


### Preparation

First, copy `bin/compiler.spec.example` somewhere (by default, `act`
looks for it in `./compiler.spec`), and adjust to your needs.


### Running

The easiest way to run `act` is through `dune exec bin/main.exe --
ARGS`; this will build `act` if needed.  Use `dune exec bin/main.exe
-- help` for general usage.  (The `--` is needed to stop `dune` from
trying to parse the arguments itself.)

To start with, try:

```
$ dune exec act -- specs
```

This will read in your `compiler.spec` file, and, if all is well,
output the available compilers.


### Installing

To install `act` into your OPAM `bin` directory, try:

```
$ dune build @install
$ dune install
```

### Testing

`dune runtest` will run `act`'s test suite, and output any
discrepancies in `act`'s output as diffs.

`act` has the following types of test:

- _expects tests_, which are inlined into the code, and test the
  immediate output of various `act` functions;
- _regression tests_, which run the explainer and litmusifier on a
  directory of sample assembly and diff the result against a last
  known good output (see `bin/tests` and `bin/dune` for the tests)


## How to use `act`

`act` has several different subcommands:

- `specs`: displaying information about the compiler spec file;
- `compare`: comparing the litmusified assembly output for each
  compiler over the same test case;
- `explain`: asking `act` to explain every line in an assembly file
  from its perspective;
- `litmusify`: converting a single assembly file to a litmus test, and
  optionally sending it to Herd;
- `test`: running `act` on every example generated by a run of
  `memalloy`.

Short documentation on each follows, with more available on the
[wiki](https://github.com/MattWindsor91/act/wiki).

**NOTE:** The example commands assume that you've installed `act` into
your `PATH`.  If you want to try a command against your working source
copy of `act` without installing, replace `act` with `dune exec act
--` in the commands below.

### `specs`: display compiler specs

```
$ act specs
```

This asks `act` to list all the compilers it knows about from reading
in a spec file.  Pass `-verbose` to print out more information
per-compiler.


### `explain`: analyse assembly without conversion

```
$ act explain COMPILER-NAME path/to/asm.s
```

This asks `act` to dump out the given assembly file along with
line-by-line annotations explaining how `act` categorised each line of
assembly.  This is mostly useful for debugging what `act` is doing.

The output from `explain` on raw assembly can fill up with directives
and unused labels and be hard to understand.  To help with this,
you can pass the `-sanitise` flag, which asks `act` to do minimal
cleanup on the assembly first.


### `compare`: compare litmus output across compilers

```
$ act compare path/to/C/file.c
```

This asks `act` to run the compile-sanitise process for the given
C file, for each compiler in the spec file, and output the Litmus
program tables for each compiler as a Markdown document.  This is
useful for seeing, at a glance, how different compilers and
optimisation levels influence the result.


### `litmusify`: convert a single assembly file to a litmus test

```
$ act litmusify COMPILER-NAME path/to/asm.s
```

This asks `act` to try to convert the given assembly file into a
Litmus test, using the spec for compiler `COMPILER-NAME` to tell it
things about the flavour of assembly incoming.

By default, the litmus test is printed on stdout.  You can use `-o
FILE` to override, and/or `-herd` to apply `herd` directly to the
generated litmus test before outputting.

**NOTE**:
Since `act` won't have any information besides that inside the
assembly file, the litmus output won't have any postconditions or
initial assignments, and `act` will make incomplete guesses about
where program boundaries and interesting memory locations are.


### `test`: processing a memalloy run

```
$ act test path/to/memalloy/results
```

This asks `act` to run the compilers listed in `./compiler.spec` on
the witnesses in `path/to/memalloy/results/C`, then convert them into
litmus tests in the same way that `litmusify` would.

By default, `act` will dump its results in directories in the current
working directory.  The directory structure corresponds to the
identifiers in `./compiler.spec`: for example, `(local gcc x86 O3)`
will emit assembly in `./local/gcc/x86/O3/asm`, and
litmus tests in `./local/gcc/x86/O3/litmus`.


### Other commands

- `regress`: runs `act`'s regression tests.  This is intended for
  use by `dune runtest`, which also runs the inline unit tests.

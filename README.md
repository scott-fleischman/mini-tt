# Mini-TT

This is taken and adapted from following paper. [PDF]( http://www.cse.chalmers.se/~bengt/papers/GKminiTT.pdf). [Original Code](http://www.cse.chalmers.se/research/group/logic/Mini-TT/).
> Coquand, Thierry, Yoshiki Kinoshita, Bengt Nordström, and Makoto Takeyama. "A simple type-theoretic language: Mini-TT." From Semantics to Computer Science; Essays in Honour of Gilles Kahn (2009): 139-164.

## Build

[![Build Status](https://travis-ci.org/scott-fleischman/mini-tt.svg?branch=master)](https://travis-ci.org/scott-fleischman/mini-tt)

Build the code using the Haskell tool [Stack](https://docs.haskellstack.org/en/stable/README/).

```sh
stack build
```

## Examples

### Type check

```sh
stack exec agdacore examples/paper.mtt
```

### Parse
This is helpful to debug parsing errors.

```sh
stack exec parse examples/paper.mtt
```

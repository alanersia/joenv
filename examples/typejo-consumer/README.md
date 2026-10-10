# Typejo consumer

This example exercises the actual public Typejo API with a valid and an invalid username. Its lockfile pins the Typejo repository commit. The dependency source is generated locally by `joenv install`, so `mojo_packages/` is not checked in.

From the Joenv repository root, run:

```sh
cd examples/typejo-consumer
../../joenv install
../../joenv run src/main.mojo
```

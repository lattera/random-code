# memdlopen

This project demonstrates how to combine `memfd_create(2)` and `fdlopen(3)` to
load a shared object anonymously.

## Requirements

* FreeBSD; or
* HardenedBSD, but with the `hardening.harden_shm` sysctl tunable set to 1 or 0.

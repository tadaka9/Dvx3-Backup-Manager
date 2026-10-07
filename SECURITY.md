# Security notes

This checkout is an unreleased development refactor; no supported-release matrix
or completed independent security audit is asserted.

The engine uses libsodium Argon2id and XSalsa20-Poly1305, authenticates new archive
headers and verifies encrypted payload before extraction. Valid legacy archives
retain weaker metadata guarantees. Plaintext staging, extraction boundaries and
password-handling limitations are described in [ARCHITECTURE.md](ARCHITECTURE.md).

For vulnerability reports, use GitHub private vulnerability reporting if enabled
for this repository, or contact the maintainer without disclosing passwords,
private archives or exploit details in a public issue.

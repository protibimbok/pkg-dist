# GPG signing key setup

Create a dedicated signing identity for all protibimbok packages.

## 1. Generate primary + signing subkey

```bash
gpg --full-generate-key
```

Recommended settings:

- Key type: `(9) ECC (sign and encrypt)`
- Curve: `Curve 25519`
- Expiry: `0` (does not expire) for primary; `1y` for subkey (renew annually)
- Real name: `Protibimbok Package Signing Key`
- Email: `packages@protibimbok.com` (or your preferred address)

## 2. Add a dedicated signing subkey (if not created above)

```bash
gpg --edit-key packages@protibimbok.com
gpg> addkey
# Choose: (10) ECC (sign only) → Curve 25519 → 1y expiry
gpg> save
```

## 3. Back up the primary key (offline)

```bash
gpg --armor --export-secret-keys packages@protibimbok.com > master-backup.gpg
```

Store `master-backup.gpg` offline (encrypted USB, password manager, etc.). **Never commit this file.**

## 4. Export the CI signing key

List keys and find the one with signing capability (`[S]` or `[SC]`):

```bash
gpg --list-keys --keyid-format long packages@protibimbok.com
```

**If you have a dedicated signing subkey** (marked `[S]`):

```bash
gpg --armor --export-secret-subkeys <SIGNING_SUBKEY_ID> > ci-subkey.asc
```

Set `SignWith:` in `apt/conf/distributions` to that subkey ID.

**If signing is on the primary key** (marked `[SC]`, no `[S]` subkey):

`--export-secret-subkeys` only exports subkeys and replaces the primary secret
with a stub, so CI cannot sign. Export the primary signing secret instead:

```bash
gpg --armor --export-secret-keys <PRIMARY_KEY_ID> > ci-signing-key.asc
```

Set `SignWith:` to the primary key ID.

Add the armored export as the `GPG_PRIVATE_KEY` secret in the **pkg-dist** repo.
Add the key passphrase as `GPG_PASSPHRASE` (required for encrypted keys).

## 5. Publish the public key

```bash
gpg --armor --export packages@protibimbok.com > public.gpg
```

Commit `public.gpg` to the root of pkg-dist.

## 6. Configure reprepro

Edit `apt/conf/distributions` and set `SignWith:` to your signing key ID
(the `[S]` subkey, or the primary key if it has `[SC]`):

```
SignWith: ABCD1234ABCD1234
```

## Rotating the CI subkey

1. Generate a new subkey on the offline primary key.
2. Export new `ci-subkey.asc` → update GitHub secret.
3. Re-export `public.gpg` (now includes the new subkey) → commit to pkg-dist.
4. Revoke the old subkey when ready.

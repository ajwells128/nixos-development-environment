# Quickstart
## Fork the repo
Recommendation: make it public. If it's not public, you'll simply need to scp it to your new machine from another machine.

## Make it your own
Search for TODO's and make all necessary changes.

## SOPS Setup

Reference this [source material](https://github.com/andreaugustoaragao/nix/blob/main/SOPS-SETUP-GUIDE.md) with the following guidelines:

- You'll want to start with the `From-Scratch Bootstrap of Every Host` since you presumably haven't got any existing systems yet
- With respect to "minimums", follow the actual minimums in the current [secrets.yaml](./secrets/secrets.yaml)

Sample `secrets.yaml` (decrypted):
```
user_password: $y$...
root_password: $y$...
ssh_key_github: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
ssh_pubkey_github: |
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIR+S0aMGSSVEoq3uuIHVmaKqbnXXtqcxbYpRDUsZkTG awells@K3K9TFMGGQwq
git_work_email: ...
```

### Password Generation
NixOS supports only a few hash algorithms for passwords. `yescrypt` appears to be recommended, but alpine doesn't support it. My route:
1) `docker run -it --rm ubuntu:24.04 bash`
2) `apt-get update` (very slow due to zscaler I think)
3) `apt-get install whois`
4) `mkpasswd -m yescrypt` -> resulting password should start with $y$. $6$ I think refers to SHA512 which may be supported. Everything weaker than that will be rejected by NixOS.

## Create the VM
Follow [this guide](https://github.com/andreaugustoaragao/nix/blob/main/VM-SETUP.md) (first take note of the guidance below). Err on the side of giving it more CPU and RAM, though that can be changed later.

### Phase 3: Run the Installer
If you created a public repo, you should be able to follow the guide with only minimal changes to the script (the repo url, for example).

If you elected for a private repo, you'll need to `scp` your repo over. If you do that, I recommend that you execute commands from the install script by hand (via `ssh`, for ease of copy-paste) or by making necessary adjustments to the script so that it runs in LOCAL_FLAKE mode.

See [troubleshooting](#network-issues) for the actual final nixos-install line if you encounter a problem.

## Troubleshooting
### Network Issues
I can't remember the exact symptom, but zscaler was preventing the download of some files via curl or something. I used the following syntax to ensure the bundle of certs was used when installing:

```
sudo NIX_SSL_CERT_FILE=/mnt/home/andrew/code/nix/bundle.crt nixos-install --root /mnt --flake "/mnt/home/andrew/code/nix#vmware-work"
```

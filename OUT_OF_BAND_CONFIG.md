# Out-of-band configuration

Nix can't do everything. These are the things that must be done by hand.

## 1Password desktop app

1Password protects certain security-focused settings from external tampering,
so these need to be done manually. Both live in the desktop app under
`Settings -> Developer`.

### `Integrate with 1Password CLI`

Lets `op` authenticate against the unlocked desktop app (biometric / system
auth) instead of a terminal session token. If `op whoami` succeeds without
running `op signin` first, then this is properly configured.

### Use the SSH agent

Creates `~/.1password/agent.sock`, which `programs.ssh.settings."*"
.IdentityAgent` points to. Until it's turned on, the socket doesn't exist and
`ssh` falls back to whatever on-disk keys are in `~/.ssh` without any warning.
Check that the socket is there and serving keys:

```sh
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
```

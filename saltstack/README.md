# SaltStack: Windows Server 2016 AD Domain Controller

## Layout

```
salt-ad-dc/
├── pillar/
│   ├── top.sls        # targets the pillar data at your DC minion
│   └── ad_dc.sls       # domain settings + secrets
├── salt/
│   ├── top.sls          # targets the state at your DC minion
│   └── ad_dc/
│       └── init.sls    # the actual state: feature install + promotion + reboot
└── README.md
```

Copy `pillar/*` into your `pillar_roots` path and `salt/*` into your
`file_roots` path (typically `/srv/pillar` and `/srv/salt`).

## Prerequisites

1. **Windows minion already installed and connected.** This state assumes
   `salt-minion` is already running on the target Server 2016 box and its
   key is accepted on the master. Salt doesn't bootstrap the OS itself —
   use your existing provisioning (WDS, sysprep image, Packer, whatever)
   to get to "Windows is up, minion is talking to master" first.
2. Edit `pillar/top.sls` and `salt/top.sls` to match your actual minion ID
   (they currently glob-match `dc01*`).
3. Edit `pillar/ad_dc.sls` with your real domain name, NetBIOS name, and
   paths.

## Running it

```bash
# Sanity check pillar renders correctly
salt 'dc01*' pillar.items

# Dry run
salt 'dc01*' state.apply ad_dc test=True

# Apply for real
salt 'dc01*' state.apply ad_dc
```

The state will:
1. Install `AD-Domain-Services`, `RSAT-ADDS`, `RSAT-AD-PowerShell`, and
   optionally `DNS`.
2. Run `Install-ADDSForest` (new forest) or `Install-ADDSDomainController`
   (joining an existing domain), guarded so it only runs once — a second
   `state.apply` after promotion is a no-op because the state checks for
   the `NTDS` service.
3. Reboot.
4. On the **next** highstate run (after the minion reconnects), verify the
   promotion via `Get-ADDomainController`.

Because the box reboots mid-workflow, plan on running highstate twice:
once to promote, and once after reboot to confirm. If you use
`scheduler` or an orchestrate runner, you can automate the "wait for
minion, then re-apply" sequence — see the Orchestration note below.

## Important: the safe mode password

`ad_dc.sls` has the DSRM (Directory Services Restore Mode) password in
plaintext for clarity. **Don't ship that to production.** Two better options:

- **GPG-encrypted pillar**: `gpg --encrypt` the value, wrap it with
  `!!str |` in a `#!yaml|gpg` renderer pillar file. Salt decrypts it
  server-side when compiling pillar for the minion.
- **External secrets backend**: pull it via `sdb` (e.g. an `sdb://` URL
  backed by HashiCorp Vault, or a cloud KMS) instead of storing it in the
  pillar tree at all.

Either way, never let this value land in your state/pillar git repo in
plaintext.

## Orchestration across the reboot

If you want a single command that handles promote → wait for reboot →
verify, use a Salt **orchestrate** runner instead of calling `state.apply`
directly:

```yaml
# salt/orchestrate/ad_dc.sls
promote:
  salt.state:
    - tgt: 'dc01*'
    - sls: ad_dc

wait_for_minion:
  salt.wait_for_event:
    - name: 'salt/minion/dc01*/start'
    - id_list:
      - dc01
    - timeout: 600
    - require:
      - salt: promote

verify:
  salt.state:
    - tgt: 'dc01*'
    - sls: ad_dc
    - require:
      - salt: wait_for_minion
```

Run with: `salt-run state.orchestrate orchestrate.ad_dc`

## Additional domain controllers

Set `first_dc: False` in pillar, and fill in `existing_domain_admin` /
`existing_domain_admin_password` (again, pull the password from a secrets
backend, not plaintext pillar). The state then calls
`Install-ADDSDomainController` against the existing domain instead of
building a new forest.

## Things worth double-checking before you run this against anything real

- **Functional levels**: `WinThreshold` is the DSC/PowerShell name for the
  2016 forest/domain functional level. Confirm this still matches what you
  want (you can also run at a lower functional level if you have older DCs
  in the environment).
- **DNS delegation**: if this is a new forest and it isn't the DNS root
  for your network, you'll still need to sort out conditional forwarders
  or delegation from your existing DNS infrastructure.
- **First DC in a new forest is essentially irreversible without a
  rebuild.** Test the whole flow in a lab/VM snapshot first.
- **`-SkipPreChecks`** is used here to keep the state non-interactive.
  Run `Test-ADDSForestInstallation` / `Test-ADDSDomainControllerInstallation`
  manually beforehand in a lab so you're not skipping checks blind in
  production.

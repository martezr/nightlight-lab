ad_dc:
  # --- Core domain identity ---
  domain_name: corp.example.com
  netbios_name: CORP
  domain_mode: WinThreshold        # WinThreshold = 2016 functional level
  forest_mode: WinThreshold

  # --- Paths (defaults shown, override if you want the DB/logs on another volume) ---
  database_path: 'C:\Windows\NTDS'
  log_path: 'C:\Windows\NTDS'
  sysvol_path: 'C:\Windows\SYSVOL'

  install_dns: True

  # --- New forest vs. additional DC in an existing domain ---
  # 'first_dc' installs a brand-new forest/domain.
  # For additional DCs, set to False and fill in existing_domain_admin below.
  first_dc: True

  # Only needed when first_dc is False (joining an existing domain):
  # existing_domain_admin: 'CORP\svc-salt-adjoin'

  # --- Secrets ---
  # DO NOT leave this as plaintext in a real deployment. See the README for
  # how to source this from an encrypted pillar (GPG) or a secrets backend
  # (Vault/sdb) instead. Shown in plaintext here only so the structure is clear.
  safe_mode_password: 'Ch4ngeMe!SuperSecretDSRM'
  # existing_domain_admin_password: 'Ch4ngeMe!AlsoSecret'

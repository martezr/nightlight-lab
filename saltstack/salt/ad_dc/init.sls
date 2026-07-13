{#
  ad_dc/init.sls

  Deploys and promotes a Windows Server 2016 box to an Active Directory
  Domain Controller.

  Design notes:
  - Windows feature install and DC promotion are two separate, idempotent
    steps. Promotion is guarded with an `unless` check against
    Win32_ComputerSystem.DomainRole (>=4 means the box is already a DC) so
    re-running highstate after the box is already promoted is a no-op.
    NOTE: don't use `Get-Service NTDS` for this check -- installing the
    AD-Domain-Services *feature* pre-stages that service entry before any
    promotion happens, which causes a false positive and silently skips
    the actual Install-ADDSForest call.
  - Promotion forces -NoRebootOnCompletion so Salt stays in control of the
    reboot (a bare Install-ADDSForest reboot would kill the minion mid-run
    in a way Salt can't observe cleanly).
  - After the state completes, the box will still be mid-reboot. You must
    re-run highstate (or let your scheduler do it) once the minion
    reconnects to confirm convergence and run any post-promotion checks.
#}

{% set ad = salt['pillar.get']('ad_dc', {}) %}

{% if not ad %}
missing-ad-dc-pillar:
  test.fail_without_changes:
    - name: missing-ad-dc-pillar
    - comment: >
        No 'ad_dc' pillar data found for this minion. Check that pillar/top.sls
        targets this minion ID correctly (run `salt '<minion>' pillar.items` to
        verify) and that pillar/ad_dc.sls is present in your pillar_roots.
{% else %}

# ---------------------------------------------------------------------------
# 1. Install the required Windows roles/features
# ---------------------------------------------------------------------------
ad-domain-services-feature:
  win_servermanager.installed:
    - name: AD-Domain-Services
    - restart: False

rsat-adds-feature:
  win_servermanager.installed:
    - name: RSAT-ADDS
    - restart: False

rsat-ad-powershell-feature:
  win_servermanager.installed:
    - name: RSAT-AD-PowerShell
    - restart: False

{% if ad.get('install_dns', True) %}
dns-feature:
  win_servermanager.installed:
    - name: DNS
    - restart: False
{% endif %}

# ---------------------------------------------------------------------------
# 2. Promote the server
# ---------------------------------------------------------------------------
# NOTE: promotion is done via a real .ps1 file on disk, executed with -File,
# rather than passed inline as a multi-line -Command string. Multi-line
# PowerShell handed to cmd.run via `shell: powershell` can get flattened/
# mis-quoted on the way to powershell.exe, silently truncating the script
# after the first statement -- it will report retcode 0 with no output in
# a couple seconds, having done nothing. Writing a file and running it with
# -File sidesteps that entirely.

{% if ad.get('first_dc', True) %}

# --- New forest / new domain ---
deploy-promote-forest-script:
  file.managed:
    - name: 'C:\Windows\Temp\Promote-ADDSForest.ps1'
    - makedirs: True
    - contents: |
        $ErrorActionPreference = 'Stop'
        try {
            $SecurePassword = ConvertTo-SecureString '{{ ad.safe_mode_password }}' -AsPlainText -Force

            Install-ADDSForest `
              -DomainName '{{ ad.domain_name }}' `
              -DomainNetbiosName '{{ ad.netbios_name }}' `
              -ForestMode '{{ ad.forest_mode }}' `
              -DomainMode '{{ ad.domain_mode }}' `
              -DatabasePath '{{ ad.database_path }}' `
              -LogPath '{{ ad.log_path }}' `
              -SysvolPath '{{ ad.sysvol_path }}' `
              -SafeModeAdministratorPassword $SecurePassword `
              -InstallDns:${{ 'true' if ad.get('install_dns', True) else 'false' }} `
              -NoRebootOnCompletion:$true `
              -SkipPreChecks:$true `
              -Force:$true

            Write-Output 'PROMOTION_OK'
            exit 0
        }
        catch {
            Write-Error $_.Exception.ToString()
            exit 1
        }
    - require:
      - win_servermanager: ad-domain-services-feature
      - win_servermanager: rsat-adds-feature
      - win_servermanager: rsat-ad-powershell-feature

promote-new-forest:
  cmd.run:
    - name: 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Windows\Temp\Promote-ADDSForest.ps1"'
    - shell: cmd
    - timeout: 1800
    - unless: powershell -Command "if ((Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4) { exit 0 } else { exit 1 }"
    - require:
      - file: deploy-promote-forest-script

{% else %}

# --- Additional DC joining an existing domain/forest ---
deploy-promote-dc-script:
  file.managed:
    - name: 'C:\Windows\Temp\Promote-ADDSDomainController.ps1'
    - makedirs: True
    - contents: |
        $ErrorActionPreference = 'Stop'
        try {
            $SafePassword = ConvertTo-SecureString '{{ ad.safe_mode_password }}' -AsPlainText -Force
            $AdminPassword = ConvertTo-SecureString '{{ ad.existing_domain_admin_password }}' -AsPlainText -Force
            $Cred = New-Object System.Management.Automation.PSCredential('{{ ad.existing_domain_admin }}', $AdminPassword)

            Install-ADDSDomainController `
              -DomainName '{{ ad.domain_name }}' `
              -Credential $Cred `
              -DatabasePath '{{ ad.database_path }}' `
              -LogPath '{{ ad.log_path }}' `
              -SysvolPath '{{ ad.sysvol_path }}' `
              -SafeModeAdministratorPassword $SafePassword `
              -InstallDns:${{ 'true' if ad.get('install_dns', True) else 'false' }} `
              -NoRebootOnCompletion:$true `
              -SkipPreChecks:$true `
              -Force:$true

            Write-Output 'PROMOTION_OK'
            exit 0
        }
        catch {
            Write-Error $_.Exception.ToString()
            exit 1
        }
    - require:
      - win_servermanager: ad-domain-services-feature
      - win_servermanager: rsat-adds-feature
      - win_servermanager: rsat-ad-powershell-feature

promote-additional-dc:
  cmd.run:
    - name: 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Windows\Temp\Promote-ADDSDomainController.ps1"'
    - shell: cmd
    - timeout: 1800
    - unless: powershell -Command "if ((Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4) { exit 0 } else { exit 1 }"
    - require:
      - file: deploy-promote-dc-script

{% endif %}

# ---------------------------------------------------------------------------
# 3. Reboot to complete promotion
# ---------------------------------------------------------------------------
reboot-after-promotion:
  cmd.run:
    - name: 'shutdown /r /t 10 /c "Rebooting to complete AD DS promotion (Salt)"'
    - shell: cmd
    - onchanges:
      {% if ad.get('first_dc', True) %}
      - cmd: promote-new-forest
      {% else %}
      - cmd: promote-additional-dc
      {% endif %}

# ---------------------------------------------------------------------------
# 4. Post-reboot verification (only meaningful once minion reconnects and
#    highstate is re-run)
# ---------------------------------------------------------------------------
verify-domain-controller:
  cmd.run:
    - name: powershell -Command "Get-ADDomainController -Identity $env:COMPUTERNAME | Format-List"
    - shell: cmd
    - onlyif: powershell -Command "if ((Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4) { exit 0 } else { exit 1 }"
    - require:
      - win_servermanager: ad-domain-services-feature

{% endif %}
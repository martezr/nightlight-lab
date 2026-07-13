## Windows Salt Bootstrap

```powershell
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12';
Invoke-WebRequest -Uri https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.ps1 -OutFile "$env:TEMP\bootstrap-salt.ps1";
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; & "$env:TEMP\bootstrap-salt.ps1" -Master 192.168.128.103
```

```
st2 pack install https://github.com/martezr/nightlight-lab.git
```
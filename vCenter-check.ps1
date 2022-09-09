[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Register-PSRepository -Default -Verbose
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Get-PSRepository

install-module vmware.powercli -scope AllUsers -force -SkipPublisherCheck -AllowClobber
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
Connect-VIServer -Server vcenter.local # put vCenter name here
$vm = get-VM "TestVMName" #VM name
$credentialWin = Get-Credential -Message "Credentials to access Windows servers"
Invoke-VMScript -VM $vm -ScriptText "powershell.exe 'Get-WmiObject Win32_Process'" -GuestCredential $credentialWin 
Invoke-VMScript -VM $vm -ScriptText "powershell.exe 'netstat -ano -p tcp'" -GuestCredential $credentialWin

$credentialLin = Get-Credential -Message "Credentials to access Linux servers"
Invoke-VMScript -VM $vm -ScriptText "ps -o pid,cmd | grep -v ]$" -GuestCredential $credentialLin
Invoke-VMScript -VM $vm -ScriptText "netstat -atnp | awk '{print $4,$5,$7}'" -GuestCredential $credentialLin

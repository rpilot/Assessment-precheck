<#
This script is to be run from Azure Migrate appliance installed on-premise
- It is recommended to add vCenter and ESXi IPs to the hosts file
#>

$vcenterName = "vcenter.local" # Can be IP or FQDN for vCenter server
$ESXiName = "host01.local" # Can be IP or FQDN for ESXi
$VMname = "TestVMName" # VM name for testing access

# ----------------------------    VMs Discovery   ---------------------------------
# 1. ESXi / vCenter connectivity check
Test-NetConnection $vcenterName -Port 443
Test-NetConnection $ESXiName -Port 443
# You need a server running vCenter Server version 6.7, 6.5, 6.0, or 5.5.
# Servers must be hosted on an ESXi host running version 5.5 or later.

# ----------------------------    Discovery of installed applications and for agentless dependency analysis   ---------------------------------
# 2. Guest operations privileges enabled
# Install / confirm if PSGallery repository is available. Useful for fresh servers where you're getting error: No match was found for the specified search criteria and module name 'VMware.PowerCLI'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
Install-Module PowerShellGet -RequiredVersion 2.2.4 -SkipPublisherCheck
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Register-PSRepository -Default -Verbose
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Get-PSRepository

# Connecting to vCenter and checking if the vCenter Server user account provided for server discovery does have guest operations privileges enabled
Install-Module vmware.powercli -scope AllUsers -force -SkipPublisherCheck -AllowClobber
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
Connect-VIServer -Server $vcenterName
$vm = get-VM $VMname
# Windows
  $credentialWin = Get-Credential -Message "Credentials to access Windows servers"
  Invoke-VMScript -VM $vm -ScriptText "powershell.exe 'Get-WmiObject Win32_Process'" -GuestCredential $credentialWin 
  Invoke-VMScript -VM $vm -ScriptText "powershell.exe 'netstat -ano -p tcp'" -GuestCredential $credentialWin
  # Windows servers must have PowerShell version 2.0 or later installed.

# Linux
  $credentialLin = Get-Credential -Message "Credentials to access Linux servers"
  Invoke-VMScript -VM $vm -ScriptText "ps -o pid,cmd | grep -v ]$" -GuestCredential $credentialLin
  Invoke-VMScript -VM $vm -ScriptText "netstat -atnp | awk '{print $4,$5,$7}'" -GuestCredential $credentialLin
# For agentless dependecy analysis you need a root user account, or an account that has these permissions on /bin/netstat and /bin/ls files: CAP_DAC_READ_SEARCH and CAP_SYS_PTRACE
# Set these capabilities by using the following commands:
  sudo setcap CAP_DAC_READ_SEARCH,CAP_SYS_PTRACE=ep /bin/ls
  sudo setcap CAP_DAC_READ_SEARCH,CAP_SYS_PTRACE=ep /bin/netstat
# Check capabilities by these commands:
  getcap /bin/netstat -v
  getcap /bin/ls -v
<# Check Linux OS version is supported: 
  Red Hat Enterprise Linux 7, 6, 5
  Ubuntu Linux 20.04, 18.04, 16.04, 14.04 (14.04 is problematic in fact)
  Debian 8, 7
  Oracle Linux 7, 6
  CentOS 7, 6, 5
  SUSE Linux Enterprise Server 11 and later #>
  lsb_release -a # For Ubuntu
  hostnamectl # For Red Hat
  
  <# Fallback options for checking dependencies and software inventory:
  # Linux
  	apt list --installed > "$(uname -n)-apt.txt"
	netstat -atp > "$(uname -n)-netstat.txt"
  # Windows
  	Get-WmiObject -Class Win32_Product | select Name, Vendor, Version | Out-File "$env:computername-soft.txt"
  	netstat -abf | Out-File "$env:computername-netstat.txt"
  #>
  
# 3. VMware Tools (version 10.2.1 or later) must be installed and running on servers.
  Get-VM $VMname | Select-Object -Property Name,@{Name='ToolsVersion';Expression={$_.Guest.ToolsVersion}}

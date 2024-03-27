##******************************************************************
##
## Revision date: 2024.03.27
##
## Copyright (c) 2023-2024 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************

param(
	[Parameter()]
	[switch]$NoScan,
	[Parameter()]
	[int]$Delay = 60,
	[Parameter()]
	[Alias("Targets")]
	$Target
)

# Presume target(s) will be scanned after sending the wakeup packet
[Boolean]$ScanSelectHosts = !$NoScan.IsPresent

if ($Null -eq $Target) {
	# Interactive mode: let the user decide ;)

	# Get the filename containing the list of hosts to target, if any.
	Add-Type -AssemblyName System.Windows.Forms
	$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
		# InitialDirectory = [Environment]::GetFolderPath('Desktop') 
		InitialDirectory = $script:MyInvocation.MyCommand.Path
		Filter = ''
		Title = 'Please locate your list of MAC addresses'
	}
	$FileBrowser.ShowDialog() | Out-Null

	# Get the list of MAC addresses, which may be a null string if it contains only comments or if the user aborts:
	if (![string]::IsNullOrEmpty($FileBrowser.FileName)) {
		$TargetHosts = (Get-Content $FileBrowser.FileName) -match "^[^#]" | ConvertFrom-String -PropertyNames HostName,MACAddress

		# Make sure we have an array!
		if ($Null -ne $TargetHosts) {
			if ($TargetHosts.GetType().Name -eq "PSCustomObject") { $TargetHosts = @($TargetHosts) }

			# Sanity check: we should only have Host name and MAC addresses
			if (($TargetHosts | Get-Member -MemberType NoteProperty | Measure-Object).Count -ne 2) {
				# We inherited some other property: don't trust this configuration file.
				Write-Warning $($FileBrowser.FileName + " is not properly formatted.")
				Pause
				exit 911
			}
		}
	}
	else { $TargetHosts = $Null }

	# Let the user select its choice of hosts : Out-GridView accepts a null string and may return a nul string
	$TargetHosts = $TargetHosts | Out-GridView -PassThru -Title "Please select ALL hosts that should be targeted:"

	if ($Null -eq $TargetHosts) {
		# User bail out ?.
		Write-Warning "No target selected!"
		Pause
		exit 911
	}
}
else {
	# Command line mode : get the MAC addresses (there is at least one argument ;)
	$TargetHosts = foreach ($MAC in $Target) `
 		{ [pscustomobject]@{ HostName = "Unnamed"; MACAddress = $MAC } }
	# We won't have a hostname to poke on exit
	if ($NoScan.IsPresent) { Write-Warning "-NoScan ignored in command line mode." }
	$ScanSelectHosts = $False
}

# Add a property to hold the 6 bytes MAC address
$TargetHosts | Add-Member -Name "PhysicalAddress" -MemberType NoteProperty -Value @()

# Convert the MAC address to its binary format
foreach ($Machine in $TargetHosts) {
	$Junk = $ErrorActionPreference # Tuck this away ;-)
	$ErrorActionPreference = "Stop"

	try {
		$Machine.PhysicalAddress = $([System.Net.NetworkInformation.PhysicalAddress]::Parse(`
 					($Machine.MACAddress.ToUpper() -replace '[^0-9A-F]',''))).GetAddressBytes()
		if ($Machine.PhysicalAddress.Length -ne 6) { throw }
	}
	catch { Write-Host "Invalid parameter: $($Machine.MACAddress)"
		$Machine.PhysicalAddress = @()
	}

	$ErrorActionPreference = $Junk
}

<#
	Now, wake up these guys ;-).
	
	This is a rewrite of https://stackoverflow.com/questions/72853502/how-to-send-a-wake-on-lan-magic-packet-using-powershell
	to allow multiple hosts and multiple protocols.
	
#>


# Constants
$DiscardProtocolPort = 9 # TCP/UDP sink
$SystemReservedPort = 0 # Any port available at runtime
$NetworkBroadcastV4 = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Broadcast,$DiscardProtocolPort)
$NetworkMulticastV6 = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse("FF02::1"),$DiscardProtocolPort)

# A packet is considered "magic" when it contains FF FF FF FF FF FF followed by sixteen instances of the card's six-byte MAC address. 
# See AMD's white paper, "Magic Packet Technology", https://www.amd.com/content/dam/amd/en/documents/archived-tech-docs/white-papers/20213.pdf 
$MagicPacket = [byte[]](,0xFF * (17 * 6))

# This may be a multi-homed system ...
[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() `
 	| Where-Object { $_.NetworkInterfaceType -ne [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback `
 		-and $_.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up } `
 	| ForEach-Object { `
 		Write-Host "Targeting $($_.Name) ($($_.Description)) ... " -NoNewline
	# ... and each interface may be bound to several protocols...
	foreach ($IP in ($_.GetIPProperties().UnicastAddresses).Address) { `
 			$Here = [System.Net.Sockets.UdpClient]::new(`
 				# Force a reparse of IPv6 addresses to also include scope
			[System.Net.IPEndPoint]::new($([ipaddress]$IP.IPAddressToString),`
 					$SystemReservedPort))
		$Here.EnableBroadcast = $True
		# ... and there may be more than one target
		foreach ($Machine in $TargetHosts) {
			if ($Machine.PhysicalAddress -ne @()) {
				# Fill the Magic Packet
				6..101 | ForEach-Object { $MagicPacket[$_] = $Machine.PhysicalAddress[($_ % 6)] }

				switch ($IP.AddressFamily) {
					$([System.Net.Sockets.AddressFamily]::InterNetwork) `
 						{ $Here.Send($MagicPacket,$MagicPacket.Length,$NetworkBroadcastV4) | Out-Null }

					$([System.Net.Sockets.AddressFamily]::InterNetworkV6) `
 						{ $Here.Send($MagicPacket,$MagicPacket.Length,$NetworkMulticastV6) | Out-Null }

				}
			}
		}
		$Here.Dispose()
	}
	Write-Host "Done."
}

# Give it a rest ;)
if ($Delay -gt 0) {
	Write-Warning "Waiting $Delay seconds for the target(s) to connect to their network(s)..."
	Start-Sleep -Seconds $Delay
}

# Poke each target ...
if ($ScanSelectHosts) {
	foreach ($Machine in $TargetHosts) {
		if ($Machine.PhysicalAddress -ne @()) { Test-NetConnection -ComputerName $Machine.HostName }
	}
}

# In GUI mode, wait for the user's confirmation before Exit
if ($Null -eq $Target) { Pause }

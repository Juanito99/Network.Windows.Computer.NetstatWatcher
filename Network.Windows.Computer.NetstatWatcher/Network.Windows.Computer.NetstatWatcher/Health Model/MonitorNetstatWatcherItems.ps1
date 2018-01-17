param($sourceId,$managedEntityId,$MonitorItem,$Threshold,$IntervalSeconds,$MatchCount,$SampleCount,$WithinSeconds,$TimeoutSeconds)

$Threshold       = [int]::Parse($Threshold)
$IntervalSeconds = [int]::Parse($IntervalSeconds)
$MatchCount      = [int]::Parse($MatchCount)
$SampleCount     = [int]::Parse($SampleCount)
$WithinSeconds   = [int]::Parse($WithinSeconds)
$TimeoutSeconds  = [int]::Parse($TimeoutSeconds)


$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$script:ErrorView      = 'NormalView'
$ErrorActionPreference = 'Continue'

$testedAt              = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"

$localComputerName     = $env:COMPUTERNAME
$localComputerDomain   = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$localIPAddresses      = ([System.Net.Dns]::GetHostAddresses($localComputerName)) | Where-Object { $_.AddressFamily -eq 'interNetwork' } | Select-Object -ExpandProperty IPAddressToString	| Select-Object -First 1

$regPath               = 'HKLM:\SOFTWARE\ABCIT\NetstatWatcher'
$filePath              = Get-ItemProperty -Path $regPath | Select-Object -ExpandProperty FilePath

$netStatIpFile         = $filePath + '\' + 'netstatIp' + $MonitorItem + '.txt'		

$regIpPat              = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
$regNamePat            = '[a-zA-Z]{1,}[-_\.]?[0-9]?'
		 
 
if (Test-Path -Path $netStatIpFile) {
	Remove-Item -Path $netStatIpFile -Force
}       		
		

Function Format-NetstatData {

	param(
		[Parameter(Mandatory=$true)][object]$netstatInPut,
		[Parameter(Mandatory=$true)][string]$qryType,				
		[Parameter(Mandatory=$true)][ref]$nestatIPData
	)

	$allProcesses    = Get-Process | Select-Object -Property Name, id
	$netStatConnects = New-Object -TypeName System.Collections.Generic.List[object]
	$netStatArr      =  $netstatInPut -split "`r`n"						

	$netStatArr | ForEach-Object {

		$netStatItm = $_

		if ($netStatItm -match "\d") {       

			$netStatItmParts = [Regex]::Split($netStatItm,"\s{2,}")							

			if ($qryType -eq 'tcpConnection') {
			
				$proto           = $netStatItmParts[1]					
				$localIP         = ($netStatItmParts[2] -split ':')[0]
				$localPort       = ($netStatItmParts[2] -split ':')[1]					
				$remoteIP        = ($netStatItmParts[3] -split ':')[0]
				$remotePort      = ($netStatItmParts[3] -split ':')[1]
				$connectState    = $netStatItmParts[4]
				$procId          = $netStatItmParts[5]				

				$procInfo = $allProcesses | Where-Object { $_.id -eq $procId }
				$procName = $procInfo.Name												

				if ($localIPAddresses -contains $localIP) {
					$localName = $localComputerName
				}					
			                                                         
				if (($localIp -match $regIpPat -and $remoteIp -match $regIpPat) -and ($remoteIP -notmatch '0.0.0.0|127.0.0.1') ) {
					$myNetHsh = @{'proto' = $proto}
					$myNetHsh.Add('localIP', $localIP)
					$myNetHsh.Add('localName', $localName)						
					$myNetHsh.Add('remoteIP', $remoteIP)
					$myNetHsh.Add('remotePort', $remotePort)
					$myNetHsh.Add('connectState', $connectState)
					$myNetHsh.Add('procId', $procId)
					$myNetHsh.Add('procName', $procName)					

					$myNetObj = New-Object -TypeName PSObject -Property $myNetHsh
					$null     = $netStatConnects.Add($myNetObj)    
				}

			} else {

				$proto               = $netStatItmParts[1]		

				if ($proto -ieq 'TCP') {
					$localIP         = ($netStatItmParts[2] -split ':')[0]
					$localPort       = ($netStatItmParts[2] -split ':')[1]					
					$remoteIP        = ($netStatItmParts[3] -split ':')[0]
					$remotePort      = ($netStatItmParts[3] -split ':')[1]
					$connectState    = $netStatItmParts[4]
					$procId          = $netStatItmParts[5]					
				} else {
					$localIP         = ($netStatItmParts[2] -split ':')[0]
					$localPort       = ($netStatItmParts[2] -split ':')[1]					
					$remoteIP        = ($netStatItmParts[3] -split ':')[0]
					$remotePort      = ($netStatItmParts[3] -split ':')[1]
					$connectState    = '-'
					$procId          = $netStatItmParts[4]					
				}				
							
				$procInfo = $allProcesses | Where-Object { $_.id -eq $procId }
				$procName = $procInfo.Name								
				
				if ($localIPAddresses -contains $localIP) {
					$localName = $localComputerName
				}					

				if (($localIp -match $regIpPat) -and ($remoteIP -match '\*|0.0.0.0|127.0.0.1') ) {
					$myNetHsh = @{'proto' = $proto}
					$myNetHsh.Add('localIP', $localIP)
					$myNetHsh.Add('localName', $localName)													
					$myNetHsh.Add('localPort', $localPort)						
					$myNetHsh.Add('connectState', $connectState)
					$myNetHsh.Add('procId', $procId)
					$myNetHsh.Add('procName', $procName)											

					$myNetObj = New-Object -TypeName PSObject -Property $myNetHsh
					$null     = $netStatConnects.Add($myNetObj)    
				} 

			} # END if ($qryType -eq 'tcpConnect')										

		} #END if ($netStatItm -match "\d") 

	} #END $netStatIpArr | ForEach-Object {} 

	If ($netStatConnects.count -gt 0) {
		$rtn = $true
		$nestatIPData.Value = $netStatConnects
	} else {
		$rtn = $false	
	}

	$rtn

} #END Funciton Format-NetstatIPData		


Invoke-Expression "C:\Windows\System32\netstat.exe -ano" | Out-File -FilePath $netStatIpFile
$netStatIp = Get-Content -Path $netStatIpFile | Out-String		

$netStatIPConnects = New-Object -TypeName System.Collections.Generic.List[object]
Format-NetstatData -netstatInPut $netStatIp -qryType $MonitorItem -nestatIPData ([ref]$netStatIPConnects)			



if($MonitorItem -eq 'tcpConnection') {

	$monitoredTcpConnectsFilePath = $filePath + '\' + 'monitoredTcpConnects.csv'
	
	if (Test-Path -Path $monitoredTcpConnectsFilePath) {						
		
		$monitoredTcpConnects = Import-Csv -Path $monitoredTcpConnectsFilePath					

		foreach ($tcpConnect in $monitoredTcpConnects) {

			$remoteIP        = ''
			$remoteName      = ''
			$remotePort      = ''
			$comment         = ''
			$procName        = ''
			$connectDetails  = ''
			$connectionState = ''

			$remoteIP        = $tcpConnect.remoteIP
			$remoteName      = $tcpConnect.remoteName
			$remotePort      = $tcpConnect.remotePort
			$comment         = $tcpConnect.comment
			$procName        = $tcpConnect.procName			
						
			if ($remoteName -and ([String]::IsNullOrEmpty($remoteIP))) {
				$remoteIP = [system.net.dns]::Resolve($remoteName).AddressList | Where-Object { $_.AddressFamily -eq 'interNetwork' } | Select-Object -ExpandProperty IPAddressToString
			} 		
				
			if ($remotePort -and $remoteIP) {	
				
				$SampleResults = @()			
			  
				if (-not $WithinSeconds) {					
					$WithinSeconds = $IntervalSeconds					
				}

				if ($WithinSeconds -ge $IntervalSeconds) {					
					$WithinSeconds = $IntervalSeconds					
				}
			
				if (-not $MatchCount) {					
					$MatchCount = 3					
				}

				if (-not $SampleCount) {					
					$SampleCount = $MatchCount					
				}

				if ($MatchCount -gt $SampleCount) {					
					$MatchCount = $SampleCount					
				}
				
				if ($WithinSeconds -gt $TimeoutSeconds) {					
					$WithinSeconds = $TimeoutSeconds					
				}					
							
				$timeToWait = $WithinSeconds / $SampleCount
				$timeToWait = [Math]::Round($timeToWait)							

				for ($loopRunner = 1; $loopRunner -le $SampleCount; $loopRunner ++) {
					
					$doForeachFlag = $true			
						
					$connectDetails = $netStatIPConnects | Where-Object { $_.remotePort -eq $remotePort -and $_.remoteIP -eq $remoteIP }							
				
					if ([string]::IsNullOrEmpty($connectDetails) -or [string]::IsNullOrWhiteSpace($connectDetails)) {					

						$localIP         = $localIPAddresses					
						$displayName     = 'tcpConnect On ' + $localComputerName + ' To ' + $remoteIP + ':' + $remotePort + ' for ' + $procName
						$Key             = "tcpConnectOn$($localComputerName)For$($procName)To$($remoteIP):$($remotePort)"

						$testedAt        = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"
						$connectionState = 'No active connection found.'									
				
						$state           = 'Red'
						$localName       = 'NA'
						$localPort       = 'NA'										
						$supplement      = "localIP: $($localIP)`t localPort: $($localPort)`n procName: $($procName)`n ConnecionState: $($connectionState)`n"
						$supplement     += "remoteIP: $($remoteIP)`t remotePort: $($remotePort)`n"																		
					
						$myBagHsh = @{'Key' = $key}
						$myBagHsh.Add('State', $state)
						$myBagHsh.Add('Supplement', $supplement)
						$myBagHsh.Add('TestedAt', $testedAt)
						$myBagObj = New-Object -TypeName PSObject -Property $myBagHsh
						$SampleResults += $myBagObj

						$doForeachFlag = $false										
						
						
					} #END if ([string]::IsNullOrEmpty($connectDetails) -or [string]::IsNullOrWhiteSpace($connectDetails))											

					foreach ($connDetail in $connectDetails) {								

						$connectionState = ''
						$supplement      = ''

						$localIP         = $connDetail.localIP
						$localName       = $connDetail.localName												

						if ([String]::IsNullOrEmpty($remoteName)) {
							$tmpName = [system.net.dns]::Resolve($remoteIP).HostName
							if ($tmpName -ne $remoteIP) {
								$tmpName    = $tmpName -replace $localComputerDomain,''
								$tmpName    = $tmpName -replace '\.',''
								$remoteName = $tmpName          
							} else {
								$remoteName = 'No reverse record in DNS.'
							}
						}

						if ($remoteName -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
							$tmpName = [system.net.dns]::Resolve($remoteName).HostName					
							if ($tmpName -ne $remoteIP) {
								$tmpName    = $tmpName -replace $localComputerDomain,''
								$tmpName    = $tmpName -replace '\.',''
								$remoteName = $tmpName
							} else {
								$remoteName = 'No reverse record in DNS.'
							}
						}

						$displayName     = 'tcpConnect On ' + $localComputerName + ' To ' + $remoteIP + ':' + $remotePort + ' for ' + $procName
						$Key             = "tcpConnectOn$($localComputerName)For$($procName)To$($remoteIP):$($remotePort)"

						$testedAt        = "Tested on: $(Get-Date -Format u) / $(([TimeZoneInfo]::Local).DisplayName)"
						$connectionState = $connDetail.connectState

						$supplement      = "localIP: $($localIP)`t  `n procName: $($procName)`t `n ConnecionState: $($connectionState)`n"
						$supplement     += "remoteIP: $($remoteIP)`t remotePort: $($remotePort)`n"						

						if ($connectionState -eq 'ESTABLISHED') {
							$state       = 'Green'						
						} elseif ($connectionState -eq 'TIME_WAIT') {						
							$state       = 'Yellow'
							$supplement += 'TIME_WAIT = Local endpoint (this computer) has closed the connection.'
						} else {
							$state       = 'Red'
							$supplement += 'CLOSE_WAIT = Remote endpoint (this computer) has closed the connection.'
						}																						
					
						if ($doForeachFlag) {
							$myBagHsh = @{'Key' = $key}
							$myBagHsh.Add('State', $state)
							$myBagHsh.Add('Supplement', $supplement)
							$myBagHsh.Add('TestedAt', $testedAt)
							$myBagObj = New-Object -TypeName PSObject -Property $myBagHsh
							$SampleResults += $myBagObj														
						}				
						
					} #END foreach ($connDetail in $connectDetails)					
										
					Start-Sleep -Seconds $timeToWait					

				} #END for ($loopRunner = 1; $loopRunner -le $SampleCount; $loopRunner++ )						
				
				$sampleResultsGreen  = ($SampleResults | Where-Object {$_.State -eq 'Green'}).count				
				$sampleResultsRed    = ($SampleResults | Where-Object {$_.State -eq 'Red'}).count
				$sampleResultsYellow = ($SampleResults | Where-Object {$_.State -eq 'Yellow'}).count
												
				if ($sampleResultsGreen -ge $MatchCount) {
					$state = 'Green'
				} else {
					$state = ($SampleResults[($SampleResults.count) -1]).State
				}
				
				$Key        = ($SampleResults[($SampleResults.count) -1]).Key
				$supplement = ($SampleResults[($SampleResults.count) -1]).Supplement
				$testedAt   = ($SampleResults[($SampleResults.count) -1]).testedAt				
				
				$bag = $api.CreatePropertybag()								
				$bag.AddValue("Key",$key)		
				$bag.AddValue("State",$state)				
				$bag.AddValue("Supplement",$supplement)		
				$bag.AddValue("TestedAt",$testedAt)			
				$bag									
									
			} else {

				$foo = 'No details this time, not sending to inventory.'

			} # END	if ($connectDetails)		
								
		} #END foreach($tcpConnect in $monitoredTcpConnects)


	} else {

		$api.LogScriptEvent('Monitor NetStatWatcher Three State.ps1',3002,1,"NetStatWatcherMon MonitorItem $($MonitorItem) - File not found in $($monitoredTcpConnectsFilePath)")

	}

} elseif ($MonitorItem -eq 'listeningPort') {
	

	$monitoredListeningPortsFilePath = $filePath + '\' + 'monitoredListeningPorts.csv'
	
	if (Test-Path -Path $monitoredListeningPortsFilePath) {	

		$monitoredListeningPorts = Import-Csv -Path $monitoredListeningPortsFilePath			

		foreach($listenPort in $monitoredListeningPorts) {
			
			$localIP       = ''
			$localPort     = ''
			$ipProtocol    = ''
			$procName      = '' 
			$comment       = ''
			$listenDetails = ''
			$state         = ''
			
			$localIP       = $listenPort.localIP
			$localPort     = $listenPort.localPort
			$ipProtocol    = ($listenPort.ipProtocol).ToUpper()
			$procName      = $listenPort.procName
			$comment       = $listenPort.comment

			if ($localPort -and $ipProtocol -and $procName) {

				if ([string]::IsNullOrEmpty($localIP)) {
					$localIP = '-'					
				}

				if ([string]::IsNullOrEmpty($comment)) {
					$comment = '-'
				}
				
				$supplement    =  "localIP: $($localIP)`t localPort: $($localPort)`n procName: $($procName) `t proto: $($ipProtocol)"						
				
				$listenDetails = $netStatIPConnects | Where-Object { ($_.procName -imatch $procName) -and ($_.proto -imatch $ipProtocol) -and ($_.localPort -imatch $localPort) }
				
				if ([string]::IsNullOrEmpty($listenDetails) -or [string]::IsNullOrWhiteSpace($listenDetails)) {								
					
					$Key             = "listeningPortOn.$($localComputerName)For.$($procName):$($localPort).$($ipProtocol)"
					$connectionState = 'No active connection found.'											
					$state           = 'Bad'																						
										
					$bag = $api.CreatePropertybag()								
					$bag.AddValue("Key",$key)		
					$bag.AddValue("State",$state)				
					$bag.AddValue("Supplement",$supplement)		
					$bag.AddValue("TestedAt",$testedAt)			
					$bag	

					continue
					
				} #END if ([string]::IsNullOrEmpty($connectDetails) -or [string]::IsNullOrWhiteSpace($connectDetails))							
												
				foreach ($listener in $listenDetails) {

					$localIP         = ''
					$localPort       = ''
					$ipProtocol      = ''
					$procName        = '' 
					$comment         = ''
					$connectionState = ''
					$state           = ''										

					$localIP         = $listener.localIP
					$localPort       = $listener.localPort
					$ipProtocol      = ($listener.proto).ToUpper()
					$procName        = $listener.procName
					$comment         = $listener.comment
					$connectionState = $listener.connectState					
					$supplement      = "localIP: $($localIP)`t localPort: $($localPort)`n procName: $($procName) `n connectionstate: $($connectionState))"	

					if ([string]::IsNullOrEmpty($localIP)) {
						$localIP = '-'
					}

					if ([string]::IsNullOrEmpty($comment)) {
						$comment = '-'
					}					

					if ($ipProtocol -ieq 'TCP') {
						if ($connectionState -eq 'LISTENING') {
							$state       = 'Good'						
						} elseif ($connectionState -eq 'TIME_WAIT') {						
							$state       = 'Good'
							$supplement += "`nTIME_WAIT = Local endpoint (this computer) has closed the connection."
						} else {
							$state       = 'Bad'
							$supplement += "`nCLOSE_WAIT = Remote endpoint (this computer) has closed the connection."
						}																		
					} else {
						$state       = 'Good'
						$supplement += "`nUDP - No additional information exposted. "					
					} # END if ($ipProtocol -eq 'TCP')		
										
					
					$Key = "listeningPortOn.$($localComputerName)For.$($procName):$($localPort).$($ipProtocol)"																		

					$bag = $api.CreatePropertybag()								
					$bag.AddValue("Key",$key)		
					$bag.AddValue("State",$state)				
					$bag.AddValue("Supplement",$supplement)		
					$bag.AddValue("TestedAt",$testedAt)			
					$bag															

				} #END foreach ($listener in $listenDetails)
				
			} #END if ($localPort -and $ipProtocol -and $procName)

		} #END foreach($listenPort in $monitoredListeningPorts)
		
	} #END if (Test-Path -Path $monitoredListeningPortsFilePath)		

} else {

	$foo = 'Invalid discovery paramater'
	
}
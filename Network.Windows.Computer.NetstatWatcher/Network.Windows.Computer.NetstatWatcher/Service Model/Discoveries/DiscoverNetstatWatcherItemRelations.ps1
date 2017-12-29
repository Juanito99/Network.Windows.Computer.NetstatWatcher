param($sourceId,$managedEntityId,$discoveryItem,$filePath,$ComputerName)


$api                   = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData         = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$script:ErrorView      = 'NormalView'
$ErrorActionPreference = 'Continue'

$localComputerName     = $env:COMPUTERNAME
$localComputerDomain   = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$localIPAddresses      = ([System.Net.Dns]::GetHostAddresses($localComputerName)) | Where-Object { $_.AddressFamily -eq 'interNetwork' } | Select-Object -ExpandProperty IPAddressToString	| Select-Object -First 1


if($discoveryItem -eq 'tcpConnection') {

	$monitoredTcpConnectsFilePath = $filePath + '\' + 'monitoredTcpConnects.csv'

	if (Test-Path -Path $monitoredTcpConnectsFilePath) {						     		 		
		
		$monitoredTcpConnectsFilePath = $filePath + '\' + 'monitoredTcpConnects.csv'
		$monitoredTcpConnects         = Import-Csv -Path $monitoredTcpConnectsFilePath

		$srcInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.Computer']$")		
		$srcInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)	
		$srcInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.Computer']/FilePath$", $filePath)		
		$discoveryData.AddInstance($srcInstance)
		
		$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
		$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)			
		$discoveryData.AddInstance($healthInstance)


		foreach($tcpConnect in $monitoredTcpConnects) {

			$remoteIP       = ''
			$remoteName     = ''
			$remotePort     = ''
			$comment        = ''
			$procName       = ''
			$connectDetails = ''

			$remoteIP       = $tcpConnect.remoteIP
			$remoteName     = $tcpConnect.remoteName
			$remotePort     = $tcpConnect.remotePort
			$comment        = $tcpConnect.comment
			$procName       = $tcpConnect.procName
			

			if ($remoteName -and (-not $remoteIP)) {
				$remoteIP = [system.net.dns]::Resolve($remoteName).AddressList | Where-Object { $_.AddressFamily -eq 'interNetwork' } | Select-Object -ExpandProperty IPAddressToString
			}
			
			if ($remotePort -and $remoteIP -and $procName) {
					
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

				if ([String]::IsNullOrEmpty($comment)) {
					$comment = '-'
				}

				$displayName = 'tcpConnect On ' + $localComputerName + ' To ' + $remoteIP + ':' + $remotePort + ' for ' + $procName
				$Key         = "tcpConnectOn$($localComputerName)For$($procName)To$($remoteIP):$($remotePort)"

				$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']$")	
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/ComputerName$",$localComputerName)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/Key$",$Key)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/localIP$",$localIPAddresses)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/localName$",$localComputerName)					
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remoteIP$",$remoteIP)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remoteName$",$remoteName)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remotePort$",$remotePort)				
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/comment$",$comment)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/procName$",$procName)																					
				$discoveryData.AddInstance($targetInstance)
								
				$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
				$relHealthInstance.Source = $healthInstance
				$relHealthInstance.Target = $targetInstance									
				$discoveryData.AddInstance($relHealthInstance)
					
				$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ComputerHostsTcpConnection']$")
				$relInstance.Source = $srcInstance
				$relInstance.Target = $targetInstance									
				$discoveryData.AddInstance($relInstance)					
										
			} else {

				$foo = 'No details this time, not sending to inventory.'

			} # END	if ($remotePort -and $remoteIP -and $procName)
		
		} #END foreach($tcpConnect in $monitoredTcpConnects)		

	} else {

		$foo = 'Invalid data'

	}

} elseif ($discoveryItem -eq 'listeningPort') {

	$monitoredListeningPortsFilePath = $filePath + '\' + 'monitoredListeningPorts.csv'
	
   if (Test-Path -Path $monitoredListeningPortsFilePath) {	

		$monitoredListeningPorts = Import-Csv -Path $monitoredListeningPortsFilePath

		$srcInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.Computer']$")		
		$srcInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)	
		$srcInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.Computer']/FilePath$", $filePath)		
		$discoveryData.AddInstance($srcInstance)
		
		$healthInstance = $discoveryData.CreateClassInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthService']$")		
		$healthInstance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $ComputerName)			
		$discoveryData.AddInstance($healthInstance)		

		foreach($listenPort in $monitoredListeningPorts) {
			
			$localIP    = ''
			$localPort  = ''
			$ipProtocol = ''
			$procName   = '' 
			$comment    = ''
			
			$localIP    = $listenPort.localIP
			$localPort  = $listenPort.localPort
			$ipProtocol = ($listenPort.ipProtocol).ToUpper()
			$procName   = $listenPort.procName
			$comment    = $listenPort.comment

			if ($localPort -and $ipProtocol -and $procName) {

				if ([string]::IsNullOrEmpty($localIP)) {
					$localIP = '-'
				}

				if ([string]::IsNullOrEmpty($comment)) {
					$comment = '-'
				}				

				$displayName = 'listeningPort On  ' + $localComputerName + ':' + $localPort + ' For ' + $procName + ' ' + $ipProtocol
				$Key         = "listeningPortOn.$($localComputerName)For.$($procName):$($localPort).$($ipProtocol)"
				
				$targetInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']$")	
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/ComputerName$",$localComputerName)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/Key$",$Key)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/localIP$",$localIP)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/localPort$",$localPort)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/ipProtocol$",$ipProtocol)																		
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/comment$",$comment)
				$targetInstance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/procName$",$procName)										
				$targetInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
				$discoveryData.AddInstance($targetInstance)
								
				$relHealthInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='SC!Microsoft.SystemCenter.HealthServiceShouldManageEntity']$")
				$relHealthInstance.Source = $healthInstance
				$relHealthInstance.Target = $targetInstance									
				$discoveryData.AddInstance($relHealthInstance)
					
				$relInstance        = $discoveryData.CreateRelationShipInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ComputerHostsListeningPort']$")
				$relInstance.Source = $srcInstance
				$relInstance.Target = $targetInstance									
				$discoveryData.AddInstance($relInstance)

			}

		} #END foreach($listenPort in $monitoredListeningPorts)
		
	} #END if (Test-Path -Path $monitoredListeningPortsFilePath)		

} else {

	$foo = 'Invalid discovery paramater'

}


$discoveryData
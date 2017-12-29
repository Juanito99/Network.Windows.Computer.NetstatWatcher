param($sourceId,$managedEntityId,$discoveryItem,$filePath)


$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$script:ErrorView      = 'NormalView'
$ErrorActionPreference = 'Continue'

$localComputerName     = $env:COMPUTERNAME
$localComputerDomain   = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$localIPAddresses      = ([System.Net.Dns]::GetHostAddresses($localComputerName)) | Where-Object { $_.AddressFamily -eq 'interNetwork' } | Select-Object -ExpandProperty IPAddressToString | Select-Object -First 1


if ($discoveryItem -eq 'tcpConnection') {	

	$monitoredTcpConnectsFilePath = $filePath + '\' + 'monitoredTcpConnects.csv'

	if (Test-Path -Path $monitoredTcpConnectsFilePath) {				
						
		$monitoredTcpConnects = Import-Csv -Path $monitoredTcpConnectsFilePath			

		foreach ($tcpConnect in $monitoredTcpConnects) {

			$remoteIP       = ''
			$remoteName     = ''
			$remotePort     = ''
			$procName       = ''
			$comment        = ''
			$connectDetails = ''
			
			$remoteIP       = $tcpConnect.remoteIP
			$remoteName     = $tcpConnect.remoteName
			$remotePort     = $tcpConnect.remotePort
			$procName       = $tcpConnect.procName
			$comment        = $tcpConnect.comment			
						
			if ($remoteName -and ([String]::IsNullOrEmpty($remoteIP))) {
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
				
				$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']$")	
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/ComputerName$",$localComputerName)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/Key$",$Key)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/localIP$",$localIPAddresses)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/localName$",$localComputerName)					
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remoteIP$",$remoteIP)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remoteName$",$remoteName)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/remotePort$",$remotePort)				
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/comment$",$comment)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.TcpConnection']/procName$",$procName)										
				$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
				$discoveryData.AddInstance($instance)					

			} else {

				$foo = 'No details this time, not sending to inventory.'

			} # END	if ($remotePort -and $remoteIP -and $procName)
		
		} #END foreach($tcpConnect in $monitoredTcpConnects)

	} else {

		$foo = 'Invalid data'

	} #END if (Test-Path -Path $monitoredTcpConnectsFilePath)


}  elseif ($discoveryItem -eq 'listeningPort') {

	$monitoredListeningPortsFilePath = $filePath + '\' + 'monitoredListeningPorts.csv'
	
	if (Test-Path -Path $monitoredListeningPortsFilePath) {	

	   $monitoredListeningPorts = Import-Csv -Path $monitoredListeningPortsFilePath
		
		foreach ($listenPort in $monitoredListeningPorts) {
			
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

				$instance = $discoveryData.CreateClassInstance("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']$")	
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/ComputerName$",$localComputerName)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/Key$",$Key)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/localIP$",$localIP)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/localPort$",$localPort)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/ipProtocol$",$ipProtocol)																		
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/comment$",$comment)
				$instance.AddProperty("$MPElement[Name='Network.Windows.Computer.NetstatWatcher.ListeningPort']/procName$",$procName)										
				$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
				$discoveryData.AddInstance($instance)

			}

		} #END foreach($listenPort in $monitoredListeningPorts)
		
	} #END if (Test-Path -Path $monitoredListeningPortsFilePath)		

} else {

	$foo = 'Invalid discovery paramater'

}

$discoveryData
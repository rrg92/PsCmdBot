function GetCurrentDateTime{
	<#
		.SYNOPSIS 
			Get current date and time!
	#>
	param()
	
	return (Get-Date);
}

function WinLogs {
	<#
		.SYNOPSIS 
			Get top windows event logs!
	#>
	param(
		#max events!
		$top = 40
	)
	
	Get-WinEvent -LogName Application,System -MaxEvents $top | fl | out-string;
}
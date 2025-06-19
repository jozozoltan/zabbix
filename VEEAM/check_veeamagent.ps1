$events = Get-WinEvent -LogName "Veeam Agent" -MaxEvents 100
foreach ($event in $events) {
	if ($event.Message -like "Veeam Agent '*'*finished*") {
		$status = 1
		$info = ""
		$last = $event.TimeCreated
		$last = $last.ToString("yyyy/MM/dd HH:mm:ss")
		$now = (Get-Date).AddDays(-1).ToString("yyyy/MM/dd HH:mm:ss")
		$name = $event.Message.Split("'")[1]
		if ($now -gt $last) { $status = 3; $info = 'Last run older than 1 day'  }
		elseif ($event.LevelDisplayName -eq "Error") { $status = 3; $info = "Finished with error status" }
		elseif ($event.LevelDisplayName -eq "Warning") { $status = 2; $info = "Finished with warning status" }
		Write-Host "[{""{#BCKSTATUS}"":""$status"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""1 day"",""{#BCKINFO}"":""$info""}]"
		continue 2
	}
}

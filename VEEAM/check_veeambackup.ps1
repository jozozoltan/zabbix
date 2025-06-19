Import-Module "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell.dll" -DisableNameChecking

$alljobs = Get-VBRJob -WarningAction SilentlyContinue
$jsonArray = @()

$bckjob = Get-VBRConfigurationBackupJob -WarningAction SilentlyContinue

if ($bckjob -eq $null) {
    } else {
		$name = $bckjob.Name
		$bckjobevent = Get-WinEvent -FilterHashtable @{Logname='Veeam Backup';ID=40700} -MaxEvents 10 -ErrorAction SilentlyContinue | Select-Object 'Message','TimeCreated' | select -First 1
		if (!$bckjobevent) {
			if ($bckjob.LastResult -eq "Success") {
				$bcknow = (Get-Date).AddDays(-1).AddMinutes(-30)
				$backjobtime = (Get-Date $bckjobevent.TimeCreated)
				if((Get-Date $bcknow) -gt (Get-Date $backjobtime)) {
					$jsonArray += "{""{#BCKSTATUS}"":""8"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":""1 day"",""{#BCKINFO}"":""""}"
				} else {
					$jsonArray += "{""{#BCKSTATUS}"":""1"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
				}
			} elseif ($bckjob.LastResult -eq "Failed") {
				$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
			} else {
				$jsonArray += "{""{#BCKSTATUS}"":""2"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
			}
		} else {
			$backjobmessage = $bckjobevent[0].Message
			$backjobtime = $bckjobevent[0].TimeCreated
			$bckperiod = 8 - ($bckjob.ScheduleOptions.DailyOptions.DayOfWeek -split '\s+').Count
			$bcknow = (Get-Date).AddDays(-$bckperiod)
			if((Get-Date $bcknow) -gt (Get-Date $backjobtime)) {
				$jsonArray += "{""{#BCKSTATUS}"":""8"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":""$bckperiod"",""{#BCKINFO}"":""""}"
			} elseif ($backjobmessage -like '*Failed*') {
				$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":""$bckperiod"",""{#BCKINFO}"":""$backjobmessage""}"
			} elseif ($backjobmessage -notlike '*Success*') {
				$jsonArray += "{""{#BCKSTATUS}"":""2"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":""$bckperiod"",""{#BCKINFO}"":""$backjobmessage""}"
			} else {
				$jsonArray += "{""{#BCKSTATUS}"":""1"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$backjobtime"",""{#BCKPER}"":""$bckperiod"",""{#BCKINFO}"":""$backjobmessage""}"
			}
		}
	}

foreach ($job in $alljobs) {

    $name = $job.Name

    if ($job -eq $null) { #unknown
        $jsonArray += "{""{#BCKSTATUS}"":""6"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
        continue
    }

    if ($job.IsScheduleEnabled -ne $true) { #disabled
        $jsonArray += "{""{#BCKSTATUS}"":""4"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
        continue
    }

    if ($job.CanRunByScheduler() -ne $true) { #not scheduled
        $jsonArray += "{""{#BCKSTATUS}"":""5"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
        continue
    }

    $status = $job.GetLastResult()

    if ($status -eq "None") { #running
		if ($job.JobType -eq "SimpleBackupCopyPolicy" -or $job.JobType -eq "BackupSync") {
			$jsonArray += "{""{#BCKSTATUS}"":""9"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
		}
        $jsonArray += "{""{#BCKSTATUS}"":""7"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""""}"
        continue
    }

   if ($job.JobType -eq "SimpleBackupCopyPolicy" -or $job.JobType -eq "BackupSync") { #BACKUP COPY LOOP

        $wjr = $job.GetWorkerJobs()

        foreach($wj in $wjr) {
			
			$status = $wj.GetLastResult()
            $parentname = $wj.Name -replace '.*\\',''
			
		    if ($status -eq "Failed") {
				$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""Backup failed""}"
				continue
			}
			
			if ($job.IsBackup -eq $true) {
				$Restorepoints = Get-VBRBackup -Name $job.Name | Get-VBRRestorePoint -Name *

				foreach($RP in $Restorepoints) {
					$CheckState = $RP.IsCorrupted
					$RecheckState = $RP.IsRecheckCorrupted
					$ConsistentState = $RP.IsConsistent

					if ($CheckState -ne $false -or $RecheckState -ne $false -or $ConsistentState -ne $true) {
						$VM = $RP.Name
						$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$VM"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""Corrupted""}"
						continue
					}
				}
			}
			
            $parentjob = Get-VBRJob -Name $parentname -WarningAction SilentlyContinue
            $js = Get-VBRJobScheduleOptions -Job $wj -WarningAction SilentlyContinue
            $lastjs = $js -replace '.*Latest run time: \[', ''
            $last = $lastjs.split(']')[0]
			
            if($parentjob.ScheduleOptions.OptionsDaily.Enabled -eq "True") {
                $period = 8 - ($parentjob.ScheduleOptions.OptionsDaily.DaysSrv -split '\s+').Count
                $periodtext = "$period days"
                $now = (Get-Date).AddDays(-$period).AddMinutes(-30)
            } elseif($parentjob.ScheduleOptions.OptionsMonthly.Enabled -eq "True") {
				$periodtext = "Every " + $parentjob.ScheduleOptions.OptionsMonthly.DayNumberInMonth + " " + $parentjob.ScheduleOptions.OptionsMonthly.DayOfWeek + ", " + ($parentjob.ScheduleOptions.OptionsMonthly.Months -split ' ').Count + " months."
				
				$dayNumberInMonth = switch ($parentjob.ScheduleOptions.OptionsMonthly.DayNumberInMonth) {
					"First"  { 1 }
					"Second" { 2 }
					"Third"  { 3 }
					"Fourth" { 4 }
					"Last"   { 5 }
					"OnDay"   { 6 }
					Default  { }
				}
				$dayOfWeek = switch ($parentjob.ScheduleOptions.OptionsMonthly.DayOfWeek) {
					"Monday"  { 1 }
					"Tuesday" { 2 }
					"Wednesday"  { 3 }
					"Thursday" { 4 }
					"Friday"   { 5 }
					"Saturday"   { 6 }
					"Sunday"   { 7 }
					Default  { }
				}


				if ($dayNumberInMonth -eq "OnDay") {
					$lastMonthStart = (Get-Date).AddMonths(-1).Date
					$targethour = $parentjob.ScheduleOptions.OptionsMonthly.TimeLocal #.ToString("yyyy. MM. dd. H:mm:ss")
					$hour, $minute, $second = (($targethour.Split(' ') | Select-Object -Last 1) -replace ":", ", ") -split ', '
					$now = [datetime]::new($lastMonthStart.Year, $lastMonthStart.Month, $job.ScheduleOptions.OptionsMonthly.DayOfMonth, $hour, $minute, $second)
					$now = $now.AddMinutes(-30)
				} else {
					$lastMonthStart = (Get-Date).AddMonths(-1).AddDays(-((Get-Date).Day - 1))
					$targetday = $lastMonthStart.AddDays((7 + $dayOfWeek - $lastMonthStart.DayOfWeek) % 7 + ($dayNumberInMonth - 1) * 7)
					$targethour = $parentjob.ScheduleOptions.OptionsMonthly.TimeLocal #.ToString("yyyy. MM. dd. H:mm:ss")
					$hour, $minute, $second = (($targethour.Split(' ') | Select-Object -Last 1) -replace ":", ", ") -split ', '
					$now = [datetime]::new($targetday.Year, $targetday.Month, $targetday.Day, $hour, $minute, $second)
					$now = $now.AddMinutes(-30)
				}
            } elseif($parentjob.ScheduleOptions.OptionsPeriodically.Enabled -eq "True") {
                $period = $parentjob.ScheduleOptions.OptionsPeriodically.FullPeriod
                $periodunit = $parentjob.ScheduleOptions.OptionsPeriodically.Unit
                $periodtext = "$period $periodunit"

                switch ($periodunit) {
                    "Hours" { $now = (Get-Date).AddHours(-$period).AddMinutes(-30) }
                    "Minutes" { $now = (Get-Date).AddMinutes(-$period).AddMinutes(-30) }
                    "Seconds" { $now = (Get-Date).AddSeconds(-$period).AddMinutes(-30) }
                }
            }
			#$last = $last.ToString("yyyy/MM/dd hh:mm:ss tt")
			#$now = $now.ToString("yyyy/MM/dd hh:mm:ss tt")
			if((Get-Date $now) -gt (Get-Date $last)) {
				if($wj.IsRunning -eq $true) {
					$jsonArray += "{""{#BCKSTATUS}"":""7"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""last run time older than period""}"
				}
				$jsonArray += "{""{#BCKSTATUS}"":""8"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""last run time older than period, target time: $now""}"
				continue
			}
			

			if ($status -ne "Success") {

				$vmObjects = Get-VBRJobObject -Job $job -WarningAction SilentlyContinue
				$vmCount = $vmObjects.Count
				$Restorepoints = Get-VBRBackup -Name $job.Name | Get-VBRRestorePoint | Sort-Object -Property CreationTime -Descending | Select-Object -First $vmCount

				foreach($RP in $Restorepoints) {
					$infowarn = Get-WinEvent -FilterHashtable @{Logname='Veeam Backup';ID=150} -MaxEvents 10 | Select-Object Message | Select-String -Pattern $RP.Name | select -First 1

					if ($infowarn -like '*Success*') { continue }

					$infowarn = $infowarn -replace '.*Task details: ', ''  -replace '.* state.', ''  -replace '}', ''  -replace '\n', ''   -replace '<br>', ''

					if ($infowarntext -notlike "*$infowarn*") { $infowarntext += "$infowarn" }
				}

				$jsonArray += "{""{#BCKSTATUS}"":""2"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""$infowarntext""}"
				$infowarntext = ''
				continue
			}
			
			$jsonArray += "{""{#BCKSTATUS}"":""1"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""""}"
			continue

		}
    } else
	{ #RENDES LOOP
		$info = ''
        $info = Get-WinEvent -FilterHashtable @{Logname='Veeam Backup';ID=190} -MaxEvents 10 | Select-Object Message | Select-String -Pattern $name | select -First 1
        $info = $info -replace '@{Message=', ''  -replace '}', ''  -replace '\n', ''  -replace '<br>', ''
        $last = $job.GetScheduleOptions() -replace '.*Latest run time: \[', ''
        $last = $last.split(']')[0]
		
	    if ($status -eq "Failed") {
			$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""$info""}"
			continue
		}
		
		if ($job.IsBackup -eq $true) {
			$Restorepoints = Get-VBRBackup -Name $job.Name | Get-VBRRestorePoint -Name *

			foreach($RP in $Restorepoints) {
				$CheckState = $RP.IsCorrupted
				$RecheckState = $RP.IsRecheckCorrupted
				$ConsistentState = $RP.IsConsistent

				if ($CheckState -ne $false -or $RecheckState -ne $false -or $ConsistentState -ne $true) {
					$VM = $RP.Name
					$jsonArray += "{""{#BCKSTATUS}"":""3"",""{#BCKNAME}"":""$VM"",""{#BCKRUN}"":"""",""{#BCKPER}"":"""",""{#BCKINFO}"":""Corrupted""}"
					continue
				}
			}
		}
	
		if($job.ScheduleOptions.OptionsDaily.Enabled -eq "True") {
			$period = 8 - ($job.ScheduleOptions.OptionsDaily.DaysSrv -split '\s+').Count
			$periodtext = "$period days"
			$now = (Get-Date).AddDays(-$period).AddMinutes(-30)
		} elseif($job.ScheduleOptions.OptionsMonthly.Enabled -eq "True") {	
			
			$dayNumberInMonth = switch ($job.ScheduleOptions.OptionsMonthly.DayNumberInMonth) {
				"First"  { 1 }
				"Second" { 2 }
				"Third"  { 3 }
				"Fourth" { 4 }
				"Last"   { 5 }
				"OnDay"   { 6 }
				Default  { }
			}
			$dayOfWeek = switch ($job.ScheduleOptions.OptionsMonthly.DayOfWeek) {
				"Monday"  { 1 }
				"Tuesday" { 2 }
				"Wednesday"  { 3 }
				"Thursday" { 4 }
				"Friday"   { 5 }
				"Saturday"   { 6 }
				"Sunday"   { 7 }
				Default  { }
			}

				if ($dayNumberInMonth -eq 6) {
					$periodtext = "Every " + $job.ScheduleOptions.OptionsMonthly.DayNumberInMonth + " " + $job.ScheduleOptions.OptionsMonthly.DayOfMonth + ", " + ($job.ScheduleOptions.OptionsMonthly.Months -split ' ').Count + " months."
					$lastMonthStart = (Get-Date).AddMonths(-1).Date
					$targethour = $job.ScheduleOptions.OptionsMonthly.TimeLocal #.ToString("yyyy. MM. dd. HH:mm:ss")
					$hour, $minute, $second = (($targethour.Split(' ') | Select-Object -Last 1) -replace ":", ", ") -split ', '
					$day = [int]$job.ScheduleOptions.OptionsMonthly.DayOfMonth.Value
					$now = [datetime]::new($lastMonthStart.Year, $lastMonthStart.Month, $day, $hour, $minute, $second)
					$now = $now.AddMinutes(-30)
				} else {
					$periodtext = "Every " + $job.ScheduleOptions.OptionsMonthly.DayNumberInMonth + " " + $job.ScheduleOptions.OptionsMonthly.DayOfWeek + ", " + ($job.ScheduleOptions.OptionsMonthly.Months -split ' ').Count + " months."
					$lastMonthStart = (Get-Date).AddMonths(-1).AddDays(-((Get-Date).Day - 1))
					$targetday = $lastMonthStart.AddDays((7 + $dayOfWeek - $lastMonthStart.DayOfWeek) % 7 + ($dayNumberInMonth - 1) * 7)
					$targethour = $job.ScheduleOptions.OptionsMonthly.TimeLocal #.ToString("yyyy. MM. dd. HH:mm:ss")
					$hour, $minute, $second = (($targethour.Split(' ') | Select-Object -Last 1) -replace ":", ", ") -split ', '
					$now = [datetime]::new($targetday.Year, $targetday.Month, $targetday.Day, $hour, $minute, $second)
					$now = $now.AddMinutes(-30)
				}
		} elseif($job.ScheduleOptions.OptionsPeriodically.Enabled -eq "True") {
			$period = $job.ScheduleOptions.OptionsPeriodically.FullPeriod
			$periodunit = $job.ScheduleOptions.OptionsPeriodically.Unit
			$periodtext = "$period $periodunit"
			switch ($periodunit) {
				"Minutes" { $now = (Get-Date).AddMinutes(-$period).AddMinutes(-30) }
				"Seconds" { $now = (Get-Date).AddSeconds(-$period).AddMinutes(-30) }
			}
		}
		#$last = $last.ToString("yyyy/MM/dd HH:mm:ss")
		#$now = $now.ToString("yyyy/MM/dd HH:mm:ss")
		if((Get-Date $now) -gt (Get-Date $last)) {
			if($job.IsRunning -eq $true) {
				$jsonArray += "{""{#BCKSTATUS}"":""7"",""{#BCKNAME}"":""$name - $parentname"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""last run time older than period""}"
			}
			$jsonArray += "{""{#BCKSTATUS}"":""8"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""last run time older than period, $info, target time: $now""}"
			continue
		}

		if ($status -ne "Success") {

			$vmObjects = Get-VBRJobObject -Job $job -WarningAction SilentlyContinue
			$vmCount = $vmObjects.Count
			$Restorepoints = Get-VBRBackup -Name $job.Name | Get-VBRRestorePoint | Sort-Object -Property CreationTime -Descending | Select-Object -First $vmCount

			foreach($RP in $Restorepoints) {
				$infowarn = Get-WinEvent -FilterHashtable @{Logname='Veeam Backup';ID=150} -MaxEvents 20 | Select-Object Message | Select-String -Pattern $RP.Name | select -First 1

				if ($infowarn -like '*Success*') { continue }

				$infowarn = $infowarn -replace '.*Task details: ', ''  -replace '.* state.', ''  -replace '}', ''  -replace '\n', ''   -replace '<br>', ''

				if ($infowarntext -notlike "*$infowarn*") { $infowarntext += "$infowarn" }
			}

			$jsonArray += "{""{#BCKSTATUS}"":""2"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""$info $infowarntext""}"
			$infowarntext = ''
			continue
		}
		
		$jsonArray += "{""{#BCKSTATUS}"":""1"",""{#BCKNAME}"":""$name"",""{#BCKRUN}"":""$last"",""{#BCKPER}"":""$periodtext"",""{#BCKINFO}"":""$info""}"
		continue
		
    }
}

$jsonOutput = "[" + ($jsonArray -join ",") + "]"
$escapedJsonOutput = $jsonOutput -replace '[^\x20-\x7E]+', ''  -replace '\\', ''
$escapedJsonOutput | Out-File -FilePath "C:\ZAgent\veeamresult.txt" -Encoding UTF8

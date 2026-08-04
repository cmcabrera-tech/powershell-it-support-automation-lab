Import-Module ActiveDirectory -ErrorAction Stop

$LogPath = "C:\IT-Automation-Lab\Logs\Offboarding-Log.csv"
$DisabledUsersOU = "OU=Disabled Accounts,OU=Cabrera Technologies,DC=cabreralab,DC=test"
$Username = Read-Host "Enter the username to offboard"

try {
    $User = Get-ADUser -Identity $Username `
        -Properties Enabled,Department,Title,MemberOf `
        -ErrorAction Stop

    $Groups = Get-ADPrincipalGroupMembership -Identity $User |
        Where-Object Name -ne "Domain Users"

    Write-Host "`nOFFBOARDING SUMMARY" -ForegroundColor Cyan
    Write-Host "Name: $($User.Name)"
    Write-Host "Username: $($User.SamAccountName)"
    Write-Host "Department: $($User.Department)"
    Write-Host "Title: $($User.Title)"
    Write-Host "Enabled: $($User.Enabled)"
    Write-Host "Groups to remove: $($Groups.Name -join ', ')"

    $Confirmation = Read-Host "`nType YES to confirm offboarding"

    if ($Confirmation -ne "YES") {
        Write-Host "OFFBOARDING CANCELLED" -ForegroundColor Yellow
        exit
    }

    Disable-ADAccount -Identity $User -ErrorAction Stop

    foreach ($Group in $Groups) {
        Remove-ADGroupMember `
            -Identity $Group `
            -Members $User `
            -Confirm:$false `
            -ErrorAction Stop
    }

    $Description = "Offboarded on $(Get-Date -Format 'yyyy-MM-dd') by $env:USERNAME"

    Set-ADUser `
        -Identity $User `
        -Description $Description `
        -ErrorAction Stop

    Move-ADObject `
        -Identity $User.DistinguishedName `
        -TargetPath $DisabledUsersOU `
        -ErrorAction Stop

    $RemovedGroups = $Groups.Name -join "; "

    $Result = [PSCustomObject]@{
        Timestamp     = Get-Date
        Technician    = $env:USERNAME
        Username      = $User.SamAccountName
        DisplayName   = $User.Name
        Department    = $User.Department
        RemovedGroups = $RemovedGroups
        DestinationOU = $DisabledUsersOU
        Status        = "Success"
    }

    $Result | Export-Csv $LogPath -Append -NoTypeInformation

    Write-Host "`nOFFBOARDING COMPLETED" -ForegroundColor Green
    Write-Host "Account disabled: $($User.SamAccountName)"
    Write-Host "Groups removed: $RemovedGroups"
    Write-Host "Moved to: $DisabledUsersOU"
    Write-Host "Log file: $LogPath"
}
catch {
    Write-Host "`nOFFBOARDING FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    [PSCustomObject]@{
        Timestamp     = Get-Date
        Technician    = $env:USERNAME
        Username      = $Username
        DisplayName   = ""
        Department    = ""
        RemovedGroups = ""
        DestinationOU = ""
        Status        = "Failed: $($_.Exception.Message)"
    } | Export-Csv $LogPath -Append -NoTypeInformation
}
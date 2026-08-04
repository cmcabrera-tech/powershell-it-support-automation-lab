Import-Module ActiveDirectory -ErrorAction Stop

$LogPath = "C:\IT-Automation-Lab\Logs\Password-Reset-Log.csv"
$Username = Read-Host "Enter the username"

try {
    $User = Get-ADUser -Identity $Username -Properties LockedOut,Enabled -ErrorAction Stop

    Write-Host "`nUser found: $($User.Name)" -ForegroundColor Cyan
    Write-Host "Enabled: $($User.Enabled)"
    Write-Host "Locked out: $($User.LockedOut)"

    $TemporaryPassword = Read-Host "Enter the temporary password" -AsSecureString

    Set-ADAccountPassword `
        -Identity $User `
        -Reset `
        -NewPassword $TemporaryPassword `
        -ErrorAction Stop

    if ($User.LockedOut) {
        Unlock-ADAccount -Identity $User -ErrorAction Stop
        $UnlockStatus = "Account unlocked"
    }
    else {
        $UnlockStatus = "Account was not locked"
    }

    Set-ADUser -Identity $User -ChangePasswordAtLogon $true -ErrorAction Stop

    $Result = [PSCustomObject]@{
        Timestamp    = Get-Date
        Technician   = $env:USERNAME
        Username     = $User.SamAccountName
        DisplayName  = $User.Name
        Action       = "Password Reset"
        UnlockStatus = $UnlockStatus
        Status       = "Success"
    }

    Write-Host "`nPASSWORD RESET COMPLETED" -ForegroundColor Green
    Write-Host "Username: $($User.SamAccountName)"
    Write-Host "Change password at next logon: Enabled"
    Write-Host $UnlockStatus

    $Result | Export-Csv $LogPath -Append -NoTypeInformation
}
catch {
    $Result = [PSCustomObject]@{
        Timestamp    = Get-Date
        Technician   = $env:USERNAME
        Username     = $Username
        DisplayName  = ""
        Action       = "Password Reset"
        UnlockStatus = ""
        Status       = "Failed: $($_.Exception.Message)"
    }

    Write-Host "`nPASSWORD RESET FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $Result | Export-Csv $LogPath -Append -NoTypeInformation
}
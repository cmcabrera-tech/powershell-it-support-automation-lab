Import-Module ActiveDirectory -ErrorAction Stop

$CsvPath = "C:\IT-Automation-Lab\Input\NewUsers.csv"
$LogPath = "C:\IT-Automation-Lab\Logs\Bulk-User-Creation-Log.csv"
$Domain = (Get-ADDomain).DNSRoot
$Results = @()

if (-not (Test-Path $CsvPath)) {
    Write-Host "CSV FILE NOT FOUND: $CsvPath" -ForegroundColor Red
    exit
}

$TemporaryPassword = Read-Host "Enter the temporary password" -AsSecureString
$Users = Import-Csv $CsvPath

foreach ($User in $Users) {

    $Username = $User.Username.Trim()
    $DisplayName = "$($User.FirstName) $($User.LastName)"

    try {
            $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'"

            if ($ExistingUser) {
                Write-Host "SKIPPED: $Username already exists" -ForegroundColor Yellow

                $Results += [PSCustomObject]@{
                Timestamp  = Get-Date
                Username   = $Username
                Name       = $DisplayName
                Department = $User.Department
                Group      = $User.Group
                Status     = "Skipped"
                Message    = "User already exists"
    }

    continue
        }

        if (-not (Get-ADOrganizationalUnit -Identity $User.OU -ErrorAction SilentlyContinue)) {
            throw "Destination OU does not exist: $($User.OU)"
        }

        if (-not (Get-ADGroup -Identity $User.Group -ErrorAction SilentlyContinue)) {
            throw "Security group does not exist: $($User.Group)"
        }

        $NewUserParameters = @{
            Name                  = $DisplayName
            GivenName             = $User.FirstName
            Surname               = $User.LastName
            DisplayName           = $DisplayName
            SamAccountName        = $Username
            UserPrincipalName     = "$Username@$Domain"
            Department            = $User.Department
            Title                 = $User.Title
            Path                  = $User.OU
            AccountPassword       = $TemporaryPassword
            Enabled               = $true
            ChangePasswordAtLogon = $true
        }

        New-ADUser @NewUserParameters -ErrorAction Stop
        Add-ADGroupMember -Identity $User.Group -Members $Username -ErrorAction Stop

        Write-Host "CREATED: $DisplayName ($Username)" -ForegroundColor Green

        $Results += [PSCustomObject]@{
            Timestamp  = Get-Date
            Username   = $Username
            Name       = $DisplayName
            Department = $User.Department
            Group      = $User.Group
            Status     = "Created"
            Message    = "User created and added to security group"
        }
    }
   catch {
    $ErrorMessage = $_.Exception.Message

    $PartialUser = Get-ADUser -Filter "SamAccountName -eq '$Username'"

    if ($PartialUser) {
        Remove-ADUser -Identity $PartialUser -Confirm:$false
        $ErrorMessage = "$ErrorMessage | Partial account removed by rollback"
    }

    Write-Host "FAILED: $Username - $ErrorMessage" -ForegroundColor Red

    $Results += [PSCustomObject]@{
        Timestamp  = Get-Date
        Username   = $Username
        Name       = $DisplayName
        Department = $User.Department
        Group      = $User.Group
        Status     = "Failed"
        Message    = $ErrorMessage
    }
}
}

$Results | Export-Csv $LogPath -NoTypeInformation

Write-Host "`nBULK USER CREATION COMPLETED" -ForegroundColor Cyan
Write-Host "Log file: $LogPath" -ForegroundColor Cyan

$Results | Format-Table Username, Department, Group, Status -AutoSize
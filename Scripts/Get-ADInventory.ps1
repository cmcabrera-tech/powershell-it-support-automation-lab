Import-Module ActiveDirectory -ErrorAction Stop

$ReportPath = "C:\IT-Automation-Lab\Reports"

if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

try {
    $Users = Get-ADUser -Filter * -Properties Department, Title, Enabled |
        Select-Object Name, SamAccountName, Department, Title, Enabled

    $Groups = Get-ADGroup -Filter * -Properties GroupCategory, GroupScope |
        Select-Object Name, GroupCategory, GroupScope

    $OrganizationalUnits = Get-ADOrganizationalUnit -Filter * |
        Select-Object Name, DistinguishedName

    $Users | Export-Csv `
        (Join-Path $ReportPath "AD-Users-Baseline.csv") `
        -NoTypeInformation

    $Groups | Export-Csv `
        (Join-Path $ReportPath "AD-Groups-Baseline.csv") `
        -NoTypeInformation

    $OrganizationalUnits | Export-Csv `
        (Join-Path $ReportPath "AD-OUs-Baseline.csv") `
        -NoTypeInformation

    $Summary = [PSCustomObject]@{
        Domain                 = (Get-ADDomain).DNSRoot
        Users                  = $Users.Count
        Groups                 = $Groups.Count
        OrganizationalUnits    = $OrganizationalUnits.Count
        ReportLocation         = $ReportPath
    }

    Write-Host "`nACTIVE DIRECTORY INVENTORY COMPLETED" `
        -ForegroundColor Green

    $Summary | Format-List
}
catch {
    Write-Host "`nACTIVE DIRECTORY INVENTORY FAILED" `
        -ForegroundColor Red

    Write-Host $_.Exception.Message -ForegroundColor Red
}


﻿function Find-ESC3Condition2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$ADCSObjects,
        [Parameter(Mandatory = $true)]
        [array]$SafeUsers
    )
    $ADCSObjects | Where-Object {
        ($_.objectClass -eq 'pKICertificateTemplate') -and
        ($_.pkiExtendedKeyUsage -match $ClientAuthEKU) -and
        ($_.'msPKI-Certificate-Name-Flag' -eq 1) -and
        !($_.'msPKI-Enrollment-Flag' -band 2) -and
        ($_.'msPKI-RA-Application-Policies' -eq '1.3.6.1.4.1.311.20.2.1') -and
        ( ($_.'msPKI-RA-Signature' -eq 1) )
    } | ForEach-Object {
        foreach ($entry in $_.nTSecurityDescriptor.Access) {
            $Principal = New-Object System.Security.Principal.NTAccount($entry.IdentityReference)
            if ($Principal -match '^(S-1|O:)') {
                $SID = $Principal
            } else {
                $SID = ($Principal.Translate([System.Security.Principal.SecurityIdentifier])).Value
            }
            if ( ($SID -notmatch $SafeUsers) -and ($entry.ActiveDirectoryRights -match 'ExtendedRight') ) {
                $Issue = New-Object -TypeName pscustomobject
                $Issue | Add-Member -MemberType NoteProperty -Name Forest -Value $_.CanonicalName.split('/')[0] -Force
                $Issue | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name -Force
                $Issue | Add-Member -MemberType NoteProperty -Name DistinguishedName -Value $_.DistinguishedName -Force
                $Issue | Add-Member -MemberType NoteProperty -Name IdentityReference -Value $entry.IdentityReference -Force
                $Issue | Add-Member -MemberType NoteProperty -Name ActiveDirectoryRights -Value $entry.ActiveDirectoryRights -Force
                $Issue | Add-Member -MemberType NoteProperty -Name Issue `
                    -Value "$($entry.IdentityReference) can enroll in this Client Authentication template using a SAN without Manager Approval"  -Force
                $Issue | Add-Member -MemberType NoteProperty -Name Fix `
                    -Value "Get-ADObject `'$($_.DistinguishedName)`' | Set-ADObject -Replace @{'msPKI-Certificate-Name-Flag' = 0}" -Force
                $Issue | Add-Member -MemberType NoteProperty -Name Revert `
                    -Value "Get-ADObject `'$($_.DistinguishedName)`' | Set-ADObject -Replace @{'msPKI-Certificate-Name-Flag' = 1}"  -Force
                $Issue | Add-Member -MemberType NoteProperty -Name Technique -Value 'ESC3'
                $Severity = Set-Severity -Issue $Issue
                $Issue | Add-Member -MemberType NoteProperty -Name Severity -Value $Severity
                $Issue
            }
        }
    }
}

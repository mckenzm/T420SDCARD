# ============================================================================
# install-elevated.ps1
#
# Runs ELEVATED. Installs pkg\ricoh-e822-sdhost.inf by:
#   1. creating a temporary self-signed code-signing certificate,
#   2. generating + signing a catalog for the INF,
#   3. trusting that cert (Root + TrustedPublisher) just long enough to install,
#   4. running pnputil /add-driver /install,
#   5. verifying the reader bound to sdbus,
#   6. REMOVING the temporary certificate from all stores (nothing left trusted).
#
# All progress is written to install-log.txt in the parent folder.
# ============================================================================

$base = 'C:\Users\t420e\ricoh-sd-reader-driver'
$pkg  = Join-Path $base 'pkg'
$inf  = Join-Path $pkg  'ricoh-e822-sdhost.inf'
$cat  = Join-Path $pkg  'ricoh-e822-sdhost.cat'
$cer  = Join-Path $pkg  '_temp_signer.cer'
$log  = Join-Path $base 'install-log.txt'

function Log($m) {
    $line = ('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $m)
    Add-Content -Path $log -Value $line -Encoding UTF8
}

Set-Content -Path $log -Value ("Ricoh E822 elevated install  -  " + (Get-Date)) -Encoding UTF8

$cert = $null
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('S-1-5-32-544')
    Log "Elevated: $isAdmin"
    if (-not $isAdmin) { Log 'ERROR: not elevated; aborting.'; return }

    # 1. temporary self-signed code-signing certificate
    Log 'Creating temporary self-signed code-signing certificate...'
    $cert = New-SelfSignedCertificate -Type CodeSigningCert `
                -Subject 'CN=Ricoh E822 Temp Driver Signer' `
                -CertStoreLocation 'Cert:\LocalMachine\My' `
                -KeyUsage DigitalSignature -HashAlgorithm SHA256 `
                -NotAfter (Get-Date).AddDays(1)
    Log ("  Thumbprint: " + $cert.Thumbprint)

    # 2. catalog covering the INF
    #    pre-clean any stale artifacts so only the .inf is hashed
    Get-ChildItem -Path $pkg -Filter '*.cat'  -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $pkg -Filter '_*'     -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Log 'Generating catalog (New-FileCatalog, SHA256)...'
    New-FileCatalog -Path $pkg -CatalogFilePath $cat -CatalogVersion 2 | Out-Null
    Log ("  Catalog present: " + (Test-Path $cat))

    # 3. sign the catalog
    Log 'Signing catalog...'
    $sig = Set-AuthenticodeSignature -FilePath $cat -Certificate $cert -HashAlgorithm SHA256
    Log ("  Signature status: " + $sig.Status)

    # 4. trust the signer (machine Root + TrustedPublisher)
    Log 'Adding signer to LocalMachine Root + TrustedPublisher (temporary)...'
    Export-Certificate -Cert $cert -FilePath $cer | Out-Null
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\Root'            | Out-Null
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPublisher' | Out-Null

    # 5. install
    Log 'Running: pnputil /add-driver /install ...'
    $out    = Join-Path $pkg '_pnputil.out'
    $errf   = Join-Path $pkg '_pnputil.err'
    $proc = Start-Process -FilePath 'pnputil.exe' `
                -ArgumentList '/add-driver', "`"$inf`"", '/install' `
                -Wait -NoNewWindow -PassThru `
                -RedirectStandardOutput $out -RedirectStandardError $errf
    Log ("pnputil exit code: " + $proc.ExitCode)
    if (Test-Path $out)  { Log ("pnputil stdout:`n" + ((Get-Content $out  -Raw))) }
    if (Test-Path $errf) { $e = (Get-Content $errf -Raw); if ($e -and $e.Trim()) { Log ("pnputil stderr:`n" + $e) } }
    Remove-Item $out,$errf -Force -ErrorAction SilentlyContinue

    # 6. verify binding
    Start-Sleep -Seconds 2
    $dev = Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE '%VEN_1180&DEV_E822%'"
    Log ("Device now : Name='" + $dev.Name + "'  ErrorCode=" + $dev.ConfigManagerErrorCode + "  Service='" + $dev.Service + "'")
    if ($dev.ConfigManagerErrorCode -eq 0 -and $dev.Service) {
        Log ("RESULT: SUCCESS - reader bound to service '" + $dev.Service + "'.")
    } else {
        Log ("RESULT: NOT BOUND - still error code " + $dev.ConfigManagerErrorCode + ".")
    }
}
catch {
    Log ("ERROR: " + $_.Exception.Message)
}
finally {
    Log 'Cleaning up temporary certificate from all stores...'
    if ($cert) {
        foreach ($s in 'My','Root','TrustedPublisher') {
            $p = "Cert:\LocalMachine\$s\$($cert.Thumbprint)"
            if (Test-Path $p) {
                try { Remove-Item $p -Force; Log "  removed from LocalMachine\$s" }
                catch { Log "  could NOT remove from LocalMachine\$s : $($_.Exception.Message)" }
            }
        }
    }
    if (Test-Path $cer) { Remove-Item $cer -Force -ErrorAction SilentlyContinue }
    Log 'Done.'
}

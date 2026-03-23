$cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq 'CN=StyLua-Roblox' -and $_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3' } |
    Select-Object -First 1

if (-not $cert) {
    throw "Code signing certificate not found. Create one with:`nNew-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=StyLua-Roblox' -CertStoreLocation Cert:\CurrentUser\My"
}

Set-AuthenticodeSignature -FilePath .\StyLua-Roblox.exe -Certificate $cert

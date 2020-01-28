# Automatic update for dnscrypt-proxy and dnscrypt-lists
$service = Get-Service -Name 'dnscrypt-proxy'
$release = Invoke-RestMethod 'https://api.github.com/repos/jedisct1/dnscrypt-proxy/releases/latest' -ErrorVariable err
if ( !$err `
    -and !$release.prerelease `
    -and ( !(Test-Path 'dnscrypt-proxy.tag') `
        -or ([System.Version]$release.tag_name -gt [System.Version](Get-Content 'dnscrypt-proxy.tag'))) ) {

    if ( $asset = $release.assets | ? { $_.name -ilike 'dnscrypt-proxy-win64-*.zip' } ) {
        $wc = [System.Net.WebClient]::new()
        $wc.DownloadFile($asset.browser_download_url, $asset.name)
        $wc.DownloadFile($asset.browser_download_url + '.minisig', $asset.name + '.minisig')
        $wc.Dispose()
        & '.\minisign.exe' -Vm "$($asset.name)" -P 'RWTk1xXqcTODeYttYMCMLo0YJHaFEHn7a3akqHlb/7QvIQXHVPxKbjB5' -q
        if ( $? ) {
            Expand-Archive -Path $asset.name -DestinationPath . -Force
            Remove-Item -Path $asset.name, $($asset.name + '.minisig')
            $service | Stop-Service
            Get-ChildItem -Path 'win64\' | Move-Item -Destination . -Force
            $service | Start-Service
            Remove-Item -Path 'win64\'
            $release.tag_name > 'dnscrypt-proxy.tag'
        }
    }
}
$release = Invoke-RestMethod 'https://api.github.com/repos/zeffy/dnscrypt-lists/releases/latest' -ErrorVariable err
if ( !$err `
    -and (!(Test-Path 'dnscrypt-lists.tag') `
        -or ([int]$release.tag_name -gt [int](Get-Content 'dnscrypt-lists.tag'))) ) {

    $release.assets | ? { @('whitelist.zip', 'advanced-blacklist.zip') -icontains $_.name } | % {
        $wc = [System.Net.WebClient]::new()
        $wc.DownloadFile($_.browser_download_url, $_.name)
        $wc.Dispose()
        $service | Stop-Service
        Expand-Archive -Path $_.name -DestinationPath . -Force
        $service | Start-Service
        Remove-Item -Path $_.name
        $release.tag_name > "dnscrypt-lists.tag"
    }
}

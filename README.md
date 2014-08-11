CitrixTools
===========

Powershell module for working with Citrix products
(part of the saTools library)

Most useful of exported functions right now is Get-saCtxHotfixDownload, which retrieves from support.citrix.com all 'Public' and 'Recommended' hotfixes for selected products.

Usage
Several modes are supported, but mostly useful is probably to create a config file and use it to retrieve hotfixes.

Get-saCtxHotfixDownload -WriteConfigFile
writes a config file into the current directory. It uses the current directory as the base and generates a .csv file, _HotfixSampleConfig.csv_ in the current directory. Edit this file and remove any products you don't want to patch. Change the name if you want, e.g. _MyHotfixList.csv_.

Get-saCtxHotfixDownload -CsvConfigFile MyHotfixList.csv
downloads all 'Public' and 'Recommended' hotfixes for listed products. It also writes the path to the config file into the registry at HKCU:\Software\NCGi\saTools\CitrixTools, so in the future you can simply run

Get-saCtxHotfixDownload 
and download patches for the same products.

Subsequent downloads will retrieve only hotfixes that Cirix has added since the last download. By default, download activity is logged to _CtxHotfixDownloadLog.csv_ in the same directory with the config file. Logfile path can be changed or logging turned off with appropriate switches _-LogfilePath_ and  _-NoLog_.

.zip files will be automatically extracted into a folder of the same name as as the .zip archive in the same directory. Can be turned off with switch _-NoUnzip_.

By default, all downloaded files are touched with the release date of the hotfix as specified in the matching CTX article.  Can be disabled with _-NoTouch_.

For convenience in a larer environment, the config file can be placed into a fileshare and a Group Policy Preference created to set the UNC path in
HKLM:\Software\NCGi\saTools\CitrixTools -Name CsvConfigFile REG_SZ
When run without parameters the script will check HKCU first. If it finds nothiing there it will check HKLM, and if nothing there it will retrieve patches for XenApp 6.5.


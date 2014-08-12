CitrixTools
===========

Powershell module for working with Citrix products  
(part of the saTools library)  
Author: [Bob Daniel](http://www.linkedin.com/in/bobdaniel)  

Most useful of exported functions right now is `Get-saCtxHotfixDownload`, which retrieves from support.citrix.com all 'Public' and 'Recommended' hotfixes for selected products.

###Usage
Several modes are supported, but most convenient is probably to create a config file and use it to retrieve hotfixes. _-Verbose_ and _-Whatif_ are supported.   

`Get-saCtxHotfixDownload -WriteConfigFile`   
writes a .csv config file, _HotfixSampleConfig.csv_ in the current directory. Edit this file and remove any products you don't want. Change the name if you'd like , e.g. _MyHotfixList.csv_.

Then you can retrieve hotfixes by specifying the config file:  
`Get-saCtxHotfixDownload -CsvConfigFile MyHotfixList.csv`  
downloads all 'Public' and 'Recommended' hotfixes for products found in the config. It also writes the config file path into the registry at HKCU:\Software\NCGi\saTools\CitrixTools, so in the future you can simply run  
`Get-saCtxHotfixDownload`  
and download patches for the same products.

Subsequent downloads will retrieve only hotfixes that Citrix has added since the last download. By default, download activity is logged to _CtxHotfixDownloadLog.csv_ in the same directory with the config file. Logfile path can be changed or logging turned off with appropriate switches _-LogfilePath_ and  _-NoLog_.

.zip files will be automatically extracted into a folder of the same name as as the .zip archive in the same directory. Can be turned off with _-NoUnzip_.

By default, all downloaded files are touched with the release date of the hotfix as specified in the matching CTX article.  Can be disabled with _-NoTouch_.

For convenience in a larger environment, the config file can be placed into a fileshare and a Group Policy Preference created to set the UNC path in  
HKLM:\Software\NCGi\saTools\CitrixTools -Name CsvConfigFile REG_SZ  
When run without parameters the script will check HKCU first. If it finds nothiing there it will check HKLM, and if nothing there it will retrieve patches for XenApp 6.5.


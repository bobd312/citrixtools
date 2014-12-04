function Get-saXALoggedOnUserInfo
{
	$clt = dir HKLM:\Software\Citrix\ICA\Session -Recurse|? {
		$_.psiscontainer -and $_.name -match "Connection"
		} |% { 
			(gp $_.pspath)
		}
	$clt | ft -a username,clientaddress,ClientName,ClientVersion
}

function Set-saPrinterAttributesForCUPSperCTX136265
{

<#
.LINK
http://support.citrix.com/article/CTX136265
.LINK
http://www.undocprint.org/winspool/registry
.NOTES
CTX article states "subtract 4096 from Attributes value", but registry article indicated Attributes is a bitmap
Subtracting 4096 from a value where the bit for 4096 isn't set will alter other flags
#>

	[CmdletBinding()]
	param(
		[int]$BadBit=4096
	)

	$changes = 0
	dir HKLM:\System\CurrentControlSet\Control\Print\Printers |? {$_.psiscontainer} |% {
		write-verbose "checking $(split-path -leaf $_.pspath)"
		$olda = (gp $_.pspath).Attributes
		if ($olda -band $badbit) { 
			$newa = $olda -bxor $badbit
			write-verbose "`tChanged $($olda) to $($newa) "
			set-itemproperty $_.pspath -Name "Attributes-Old" -Value $olda
			set-itemproperty $_.pspath -Name "Attributes" -Value $newa
			$changes++
		}
	}
	if ($changes -gt 0) { 
		#Restart-PrintServices
	}
}

function Expand-ZIPFile
{
<#
.LINK
http://gallery.technet.microsoft.com/scriptcenter/PowerShell-Function-to-727d6200
#>

	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias("ZIPFile","FileName")]
		[string[]]$FullName
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$DirectoryName
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$BaseName
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$Destination
		,[Parameter(ValueFromPipeline=$true)]
		[object[]]$FileInfo
	)

	BEGIN {
<#
			write-verbose "Begin PipelineLength: $(($PSCmdlet.MyInvocation).PipelineLength)"
			write-verbose "Begin PipelinePosition: $(($PSCmdlet.MyInvocation).PipelinePosition)"
#>
		$fg = $host.UI.RawUI.ForegroundColor
		$bg = $host.UI.RawUI.BackgroundColor
		$shell = new-object -com shell.application
	}

	PROCESS {
			$FullName = (Resolve-Path $FullName).ProviderPath
			if (($PSCmdlet.MyInvocation.PipelineLength -gt 1) -or (! $Destination)) {
				$Destination = "${DirectoryName}\${BaseName}"
			}
		If (! $PSBoundParameters.WhatIf) {
			if (! (test-path $Destination) ) { md $Destination -Force  | Out-Null}
				# if $Destination exists and is empty
			if ( (test-path $Destination) -and ( @(dir $Destination).Count -eq 0)) { 
				If ($PSVersionTable.PSVersion.Major -ge 3 -and 
		       ((Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version -like "4.5*" -or 
		       (Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" -ErrorAction SilentlyContinue).Version -like "4.5*"))
				{
					$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
					$host.PrivateData.VerboseForegroundColor = [ConsoleColor]::Green
					Write-Verbose -Message "extracting $FullName to location $Destination using .NET 4.5" 
					$host.UI.RawUI.ForegroundColor = $fg
			        try { 
			            [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
			            [System.IO.Compression.ZipFile]::ExtractToDirectory("$Fullname", "$Destination") 
			        } 
			        catch { 
			            Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message" 
			        } 
				}
			    else { 
					$host.UI.RawUI.ForegroundColor = [ConsoleColor]::Blue
					$host.PrivateData.VerboseForegroundColor = [ConsoleColor]::Cyan
			        Write-Verbose -Message "extracting $FullName to location $Destination using COM" 
					$host.UI.RawUI.ForegroundColor = $fg
			        try { 
			 
						$zip = $shell.NameSpace((Resolve-Path $FullName).Providerpath)
						$shell.Namespace((resolve-path $Destination).ProviderPath).copyhere($zip.items())
					}
			        catch { 
			            Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message" 
			        } 
			    } 
			}
			else {
				write-warning "`tskipping ${Fullname}: ${Destination} not empty, "
			}
		}
	}

	END {
	}
}

function hfxGetReplacedHotfixes
{
	[CmdletBinding()]
	param(
		[string[]]$links
		 )
	begin {
		$ie = new-object -com InternetExplorer.Application
		$superseded = @()
	}
	
	process {
	
# start replaces
				# at the moment this section breaks the download
				# get the list of hotfixes this patch replaces
				# invoke IE so we can navigate the DOM
				# rather than try to parse HTML with PoSh regex
			$links |% {
				$link = $_
				$ie.Navigate($link)
				$doc = $ie.Document
				$elements = @($doc.getElementsByTagName("rmc_replaces_list"))
				if ($elements.count  -gt 0) {
					$replaces = $elements[0].innerText
					$superseded += $replaces -split ', '
				}
			}

# end replaces #
	}
	end {
			$superseded |% { 
				write-verbose "SUPERSEDED: $_"
				write-output $_ 
			}
	
	}

}

function hfxDownload
{
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[ref]$kblinks
		,[ref]$webclient
		,[ref]$logs
	) # end param() block

	begin {
		write-verbose "Starting hfxDownload"
		$superseded = @()
			# PrivateData is how we manipulate screen colors in Write-Verbose
		$hostPrivateData = (get-host).PrivateData
        $msg = @{$false = "Needed"; $true = "Found"}
		$vcolor = @{$false = "Magenta"; $true = "Found"}
        $dlPrompt = @{
                    $false = @{"msg"="Needed";"fg"="Gray";"bg"="DarkRed"}
                    ;$true = @{"msg"="Found";"fg"="Green";"bg"="DarkGreen"}
                    }
			
	} # end begin block

	process 
	{
		$kblinks.Value |% {
			$kblink = $_
			$relDt = Get-Date $($_.date)
			$ctxarticle = ($_.link -split "\/")[-1]
			$wpage = ($webclient.Value).DownloadString($kblink.link)
				# somewhere in here
				# we should look for SUPERSEDED  or 'Replaces'
			if ($wpage -cmatch "SUPER[SC]ED") { 
					if ($pg -match 'Hotfix package name.+\>(X\S+?)\<') { 
						$superseded += $matches[1] 
					} 
			}
			$filepattern="href=`"(\S+\.\w{3})`".+title=`"Download`"?"
			if ($wpage -match $filepattern) {
				write-verbose "$($_.date)`t$($_.link)"
				$dllink = $matches[1]
					# Citrix download links are inconsistent
 					# most begin with '/' and are relative to support URL
 					# some are full URL pointing elsewhere
				if ($dllink -match "^\/") {
					$dllink = "http://support.citrix.com${dllink}"
				}
				$file = ($dllink -split "\/")[-1]
					# 
					# hack for XenServer driver patches
					# Citrix doesn't alway include a version number so different versions
					# have the same name, e.g., emulex.zip
					# if the filename has no digits, prepend the CTX article
				if (! ($file -match "\d+")) {
					$file = $("${ctxarticle}-${file}")
				}
				$target = "${FilePath}\${file}"
				$basename = if ($file -match "(\S+)\.\w+$" ) { write-output $matches[1] }
				$f = $null
					#
					# check for a file or a directory of the same name without extension
				$found = if (test-path $target) {
						$f = (dir $target)
						write-output $true
					} elseif (test-path "${FilePath}\${basename}") {
							$f = (dir $FilePath -Filter "${basename}*")
							write-output $true
					} else {
						write-output $false 
					}
				$vfgin = $hostPrivateData.VerboseForegroundColor
				$vbgin = $hostPrivateData.VerboseBackgroundColor
				$hostPrivateData.VerboseForegroundColor = $dlPrompt.$found.fg
                $hostPrivateData.VerboseBackgroundColor = $dlPrompt.$found.bg
				write-verbose "$($dlPrompt.$found.msg): ${file}"
				$hostPrivateData.VerboseForegroundColor = $vfgin
				$hostPrivateData.VerboseBackgroundColor = $vbgin
				if (! $found) {
					write-verbose "Downloading ${target} from ${dllink}"
					if (! $PSBoundParameters.WhatIf ) {
						($webclient.Value).DownloadFile($dllink,$target)
						$f = (dir $target)
							#
							# change the file datetime to match the release date
						if ($f -and (! $PSBoundParameters.WhatIf) -and (! $NoTouch)) {
							$f.lastwritetime = $relDt
						}
							# add the CTX article to the pipeline
						$f | Add-Member -MemberType NoteProperty -Name VendorReference -Value $ctxArticle
							# unzip any .zip files unless specifically prohibited
						if (! $NoUnzip -and $f.Extension -match "\.zip") {
							try {
								$f | Expand-ZIPFile
							}
							catch {}
						}
						$logs.Value += New-Object PSObject -Prop @{
							"DateDownloaded"=(get-date).tostring("yyyyMMddHHmm")
							;"FileName"=$target
							;"KB"=$kbLink
							}
	
						$dlfiles += $target
						write-output $f
					}
				}
#$superseded += hfxGetReplacedHotfixes -Links $kblink.link @PSBoundParameters
			}
		} # end '$kblinks.Value |% ...'
	} # end process block

	end {
		if ($superseded.Count -gt 0 ) {
			$superseded |% {
				$target = "${FilePath}\${_}"
				if (test-path $target) {
					ren $target "SUPERSEDED_${target}"
				}
			}
		}
		write-verbose "Ending hfxDownload"
	}
} # end function hfxDownload

function Get-saCtxHotFixDownload
{
<#
.SYNOPSIS
Check Citrix lists of publicly available patches and retrieve any we need
.DESCRIPTION
Use Citrix support web page to
- get the list of CTX articles describing the patches
- parse each article looking for download URLs for .msp, .zip or .iso files
- check filename against target directory (default target directory is current directory)
- download file if needed
.PARAMETER FilePath
Location to check and download files. Default is current directory ($pwd). Valid aliases are Destination, Target and SavePath
.PARAMETER rssURL
Product URL to check. Each product (XenDesktop, XenApp, etc.) and version (6.5, 6.0, etc.) have a unique feed. Default URL is for XenApp 6.5
Hint: Each product URL is available from the Citrix support page, support.citrix.com/search
- select the product
.PARAMETER CsvConfigFile
read URL and Destination folder from CSV-format configuration file
The file must be in strict .csv format and be importable by Powershell Import-Csv function and must include the headers
rssUrl,FilePath
Writes value to registry HKCU:Software\NCGi\saTools\CitrixTools REG_SZ CsvConfigFile
.PARAMETER FromRegistry
Retrieve the config file path from the registry. Default path is Software\NCGi\saTools\CitrixTools. Tries HKCU: first, then HKLM:, then throws exception. This allows an admin to use a Group Policy Preference to set a default value in HKLM for all systems, but for each individual to have a separate default.
.PARAMETER LogFilePath
path and filename of .csv file containing log of download activity. Defaults to 'CtxHotfixDownloadLog.csv' in the CsvConfigFile folder, or in the current directory if no config file specified.
on the first line. Acceptable Aliases for FilePath are Destination,Target and SavePath
.PARAMETER WriteConfigSample
if specified, writes a sample config file using default settings to the file 'HotfixConfigSample.csv' in the current directory. Respects -Verbose and -Whatif, but ignores other parameters and just writes sample and quits.
.PARAMETER NoTouch
By default every file date/time is set to the release date shown in the RSS feed. This is true of files and folders found, as well as any downloaded. Specify -NoTouch to leave the datetime as is.
.PARAMETER NoLog
Do not log downloads. Logging is on by default.
.PARAMETER NoUnzip
Do not automatically extract .zip files. Zip files are extracted by default.
.PARAMETER Reentrant
Ignore this parameter. This is for internal program use, not expected to be a user-supplied parameter. It's a hack way for the function to re-launch itself using the piped config file, rather than parse the config file as a function of.. the function.
.EXAMPLE
Get-saCtxHotfixes -rssURL 'http://support.citrix.com/product/xens/v6.2.0/hotfix/general/?rss=on'
checks all public hotfixes for XenServer 6.2 against contents of the current directory and downloads any that are missing
.EXAMPLE
Get-saCtxHotFixDownload -Verbose -Whatif
Checks all public hotfixes for XenApp 6.5 against the contents of the current directory and displays what it would do, but doesn't download anything
.EXAMPLE
Get-saCtxHotFixDownload -Verbose -FilePath T:\Citrix\XenApp\XenApp65\HotFixes
Checks all public hotfixes for XenApp 6.5 against the contents of T:\Citrix\XenApp\XenApp65\HotFixes and downloads any it doesn't find in the path
.EXAMPLE
Get-saCtxHotFixDownload -Verbose -CsvConfigFile .\HotFixDownloads.csv
retrieves URLs and Destination file paths from file HotFixDownloads.csv in the current directory and processes verbosely
.EXAMPLE
Import-Csv.\HotFixDownloads.csv | Get-saCtxHotFixDownload -Verbose  
Config file from pipeline. Same behavior as specifiying with switch.
.EXAMPLE
Get-saCtxHotFixDownload -Verbose -WriteConfigFile
Writes file 'HotfixSampleConfig.csv' in current directory and quits.
.INPUTS
Accepts rssURL,Filepath pairs from pipeline (or config file exported from Import-Csv)
.OUTPUTS
File objects of files downloaded
.LINK
http://www.bugfree.dk/blog/2012/04/21/downloading-rss-enclosures-with-powershell/
.LINK
http://www.xenappblog.com/2013/prepare-a-provisioning-services-vdisk-for-standard-mode/
.LINK
http://www.codeproject.com/Articles/61900/PowerShell-and-XML
.LINK
http://www.yusufozturk.info/windows-powershell/how-to-parse-a-web-page-and-find-a-specific-info-with-powershell.html
.LINK
http://answers.oreilly.com/topic/2006-how-to-download-a-file-from-the-internet-with-windows-powershell/
.LINK
http://support.citrix.com/product/xa/v6.0_2008r2/hotfix/general/?rss=on
.LINK
http://support.citrix.com/product/xd/v5.6/hotfix/general/?rss=on
.LINK
http://support.citrix.com/product/xens/v6.2.0/hotfix/general/?rss=on
.LINK
http://support.citrix.com/product/xens/v6.1.0/hotfix/general/?rss=on
.NOTES
When using Powershell to parse XML from an RSS feed, PoSH creates a name collision because it adds an 'Item' property to support hashtables, but RSS feeds contain an XML Item node. Solution is to bypass the collision by explicitly calling the collection item.
Error message:
format-default : The member "Item" is already present.
#>

	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias("Destination","Target","SavePath")]
		[string[]]$FilePath = $($pwd.ProviderPath -replace "\\$","")
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$rssURL = 'http://support.citrix.com/search?searchQuery=*&lang=en&sort=date_desc&ct=Hotfixes&prod=XenApp&pver=XenApp+6.5+for+Windows+Server+2008+R2'
		,[string]$CsvConfigFile
		,[string]$LogFilePath = "CtxHotfixDownloadLog.csv"
		,[string]$regBase = 'Software\NCGi\saTools\CitrixTools'
		,[switch]$FromRegistry = $false
		,[switch]$WriteConfigSample = $false
		,[switch]$NoTouch = $false
		,[switch]$NoLog = $false
		,[switch]$NoUnZip = $false
		,[bool]$Reentrant = $false
	) # end 'param()' block

	BEGIN { 
		if ($WriteConfigSample) {
			$txt = @()
			$txt += "rssURL,Destination"
			$produrl = @();
			$produrl += @{prod='XenDesktop';pver='XenDesktop+7.6'}
			$produrl += @{prod='XenDesktop';pver='XenDesktop+7.5'}
			$produrl += @{prod='XenDesktop';pver='XenDesktop+7.1'}
			$produrl += @{prod='XenDesktop';pver='XenDesktop+7'}
			$produrl += @{prod='XenDesktop';pver='XenDesktop+5.6'}
			$produrl += @{prod='XenApp';pver='XenApp+7.5'}
			$produrl += @{prod='XenApp';pver='XenApp+6.5+for+Windows+Server+2008+R2'}
			$produrl += @{prod='XenApp';pver='XenApp+6.0+for+Windows+Server+2008+R2'}
			$produrl += @{prod='XenApp';pver='XenApp+5.0+for+Windows+Server+2008'}
			$produrl += @{prod='Provisioning+Services';pver='Provisioning Services 7.6'}
			$produrl += @{prod='Provisioning+Services';pver='Provisioning Services 7.1'}
			$produrl += @{prod='Provisioning+Services';pver='Provisioning Services 7.0'}
			$produrl += @{prod='Provisioning+Services';pver='Provisioning Services 6.1'}
			$produrl += @{prod='Provisioning+Services';pver='Provisioning Services 6.0'}
			$produrl += @{prod='EdgeSight';pver='EdgeSight+for+XenApp+5.4'}
			$produrl += @{prod='XenServer';pver='XenServer+6.2.0'}
			$produrl += @{prod='XenServer';pver='XenServer+6.1.0'}
			$produrl += @{prod='XenServer';pver='XenServer+5.6+SP+2'}

			$prefix = 'http://support.citrix.com/search?searchQuery=%3F&lang=en&sort=date_desc&ct=Hotfixes&';
			$produrl |% { 
					$prod = $_.prod;
					$pver = $_.pver;
					$prodpath = "Hotfixes\$($pver -replace '\+',' ')";
					$txt += "${prefix}prod=${prod}&pver=${pver},$((Resolve-Path $FilePath).ProviderPath)\$prodpath" 
			}
			$samplefile = "$((Resolve-Path $pwd).ProviderPath)\HotfixConfigSample.csv"
			write-verbose "Writing config sample to $samplefile"
			$txt | Out-File -Encoding ASCII -File $sampleFile
		} #end 'if ($WriteConfigSample' 
        else {
			if ($FromRegistry -or ((! $PSBoundParameters.Reentrant) -and (! $CsvConfigFile))) {
				if ($CsvConfigFile = if ($prp = (gp HKCU:$regBase).CsvConfigFile) 
                    {
							# need to add test for property
							# as it is, if the reg key exists but is empty
							# function throws exception, but should check HKLM first
						write-output $prp
				} # 
                elseif ($prp = (gp HKLM:$regBase).CsvConfigFile) {
						write-output $prp
					} 
				) {
                    $PSBoundParameters.CsvConfigFile = $CsvConfigFile 
                   }
				write-verbose "Config file from ${regBase}: ${CsvConfigFile}"
				if (! $CsvConfigFile) { throw "No config path found in registry" }
				$PSBoundParameters.Remove('FromRegistry') | Out-Null
			} #end 'if ($FromRegistry ...'
				#
				# if we received a config file as a parameter
				# recursively pipe it in
				# after removing the config file parameter
				# otherwise we blow up with an infinite call stack
			if ($CsvConfigFile) {
				if (! (Test-Path HKCU:$regBase)) { mkdir HKCU:$regBase -Force | Out-Null}
					# write the config file name to the registry
				sp HKCU:$regBase -Name "CsvConfigFile" -Value $CsvConfigfile
					#
					# if our logfilepath was passed as just a filename
					# and we have a config file
					# write the log into the same path as the config file
				if ((split-path $LogFilePath) -match "^$") {
					$PSBoundParameters.LogFilePath = "$(split-path $CsvConfigFile)\$LogFilePath"
				} # end 'if ((split-path $logFilePath...'
				write-verbose "Logfile: $($PSBoundParameters.LogFilePath)"
				$PSBoundParameters.Remove('CsvConfigFile') | Out-Null
				$PSBoundParameters.Reentrant = $true 
					#
					# splat the bound parameters to preserve -Whatif and -Verbose 
				Import-Csv $CsvConfigFile | & $($MyInvocation.MyCommand.Name) @PSBoundParameters
			} # end 'if ($CsvConfigFile'
			#$msg = @{$false = "Needed"; $true = "Found"}
				# array of files downloaded
			$dlfiles = @()
			$logs = @()
			$webclient = new-object System.Net.Webclient
			$hostPrivateData = (get-host).PrivateData
		}
	} # end 'BEGIN' block
	PROCESS {
			#
			# if we received a config file we'll be called recursively
			# so don't process with default parameters
		if ((! $WriteConfigSample) -and (! $CsvConfigFile)) {
			$rssURL |% {
				write-verbose $_
                    # skip config lines beginning with comment character
				if (! ($_ -match "^#")) 
				{
				$thisverurl = $_
				write-verbose $thisverurl
				try {
					if (! (test-path $FilePath)) { 
						try { 
							mkdir $FilePath -Force
						} # end 'try'
						catch {
							$err = new-object System.Management.Automation.ItemNotFoundException
							throw $err
						} # end 'catch'
					} # end 'if (! Test-path ... '
					$kblinks = new-object -type PSObject
					$kblist = @{};
					$kbitems = @()
						# by default we don't want patches marked 'Limited' 
						# so we need to suffix the product Url with 'Recommended' and 'Public'
						# this may be better done in the config file
						# so we get the correct URL without massaging it
						# but would require two lines for each product
						# however, making the config URL the absolute authority *would*
						# permit users to specify *all* patches, including Limited, if desired
                        # d'oh - now we need a new switch, e.g.
                        # -ConfigURLisAbsolute
                        # or
                        # -LiteralURL
					foreach ($ctcf in ("Recommended","Public")) {
						$url = "${thisverurl}&ctcf=${ctcf}"
						write-verbose $url
					$item=@{link="";date=""}
						# new Citrix support page returns 10 links at a time
						# so we keep fetching until the return count is less than 10
						# at which point we have all of them
						# update: this breaks if the total patch count is an integral multiple of 10
					$pglen = 10;
					$startct=0;
					do {
						$alist = ($webclient.downloadstring($url) -split '\n' )
						$kblist = ($alist |% { 
										if ($_ -match "(\d+)\ssearch results") 
										{
											# try to get the total patch count from the page
											# then use it to break out of while loop 
											$patchct = $matches[1]
										}
										elseif ($_ -match "(http:\/\/support.citrix.com\/article\/CTX\d+)") 
										{
											$item.link = $matches[1];
										}
										elseif ($_ -match "slistDate.*\>(.*)\<" )
										{ 
						 					$item.date = $matches[1]
											if ($item.link -ne "" -and $item.date -ne "")
											{
													# leave this alone!!
													# 'write-output $item' returns item to $kblist
												write-output $item
												$item=@{link="";date=""}
											}
										} # end 'elseif'
									}) #end '$kblist = ($alist ...'
							$kbitems += $kblist;
                                # increment page counter and update query URL
							$startct += $pglen
							if ($url -match "st=\d+$") {
								$url = $url -replace "st=\d+","st=${startct}";
							}
							else
							{
								$url += "&st=${startct}"
							}
							write-verbose "KB items: $($kbitems.count) Patches: ${patchct} PageCt: ${startct}"
						} while (($kbitems.count -lt $patchct) -or ($startct -lt $pglen));
					} # end 'foreach ctcf'
					if ($kbitems.count) {
						$kblinks = ( $kbitems |% {write-output $(new-object -type PSObject -Prop $_) } )

						hfxDownload ([ref]$kblinks) ([ref]$webclient) ([ref]$logs)

					} # end 'if($kbitems.count)'
				} # end 'try'
				catch [System.Exception] {
					write-warning "Error `n$($_)`nretrieving `n$($url) `nto `n${FilePath}"
				} # end 'catch '
			} # end 'if ( (! ($_ -match "^#"))
			} # end 'rssURL |% '
		} #end 'if ..' check for csvconfigfile
	} # end 'process' block
	END {
		if ((! $NoLog) -and $logs.Count) {
			if (! (test-path $LogFilePath)) {
				$logs | Export-CSV -NoType -Path $logfilepath
			} else {
				@($logs | ConvertTo-Csv -NoTypeInformation)[1..$logs.Count] | Out-File -Encoding ASCII -Append -File $LogFilePath
			}
		}
	} #end 'end' block
} # end function Get-saCtxHotFixDownload

function Get-saCtxProductPrefix
{
	$prd = gwmi win32_product
	$prd |? { $_.vendor -match "Citrix" -and $_.name -cmatch "^Citrix (X)\w+([AD])\w+\s+(\d+)\.(\d+)"} |% { 
		$prefix = $null
		} {
			(1..$($matches.Count)) |% { $prefix +=  $($matches[$_]) } 
	}
		#
		# Citrix file prefix format is two-character product code and 3-digit version
		# e.g. XA650, XD560, etc.
	if ( ([char[]]$prefix).count -lt 5) { $prefix += "0" }
	write-output $prefix
}

function Find-saCtxNeededPatches
{
<#
.SYNOPSIS
determine which patch files need to be installed
.DESCRIPTION
Process a list of files and compare the filenames to two lists; installed hotfixes and deprecated hotfixes. If the files contain hotfix Rollups, emit only the latest Rollup and post-rollup hotfixes.
.PARAMETER XAVersion
The product prefix used by the file, e.g. 'XA650' for XenApp 6.5. If not supplied, the system tries to determine a prefix based on the installed product list (uses the output of function Get-saCtxProductPrefix)
.PARAMETER DeprecatedList
Filename of text file containing list of deprecated hotfixes, one hotifx per line. Default is 'Deprecated.txt' in current directory.
.PARAMETER patchExtension
The file extension used by Citrix hotfixes. Defaults to '.msp'
.PARAMETER Fullname
The list of full paths to patch files. No default; accepts a list of files from pipeline.
.PARAMETER FileList
object array of unnamed pipeline objects. Or an array of file objects, e.g. output of dir
.EXAMPLE
dir . | Find-saCtxNeededPatches
process a list of files from the current directory and determine which (if any) need to be applied
.EXAMPLE
Get-saCtxHotFixDownload -Verbose -CsvConfigFile .\HotfixConfigXA60.csv | Find-saCtxNeededPatches -Verbose
Download the lastest hotfixes from Citrix and determine which need to be installed. Show the list of files being processed.
#>
	[CmdletBinding()]
	param(
			#
			# apparently we need an object array parameter 
			# to enable pipeline binding from a function emitting file objects
		[Parameter(ValueFromPipeline=$true)]
		[object[]]$FileList
		,[Alias("FilePrefix")]
		[string]$XAVersion = $(Get-saCtxProductPrefix)
		,[string]$DeprecatedList = "Deprecated.txt"
		,[string]$patchExtension = ".msp"
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$Fullname
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$BaseName 
		,[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$Extension 

	)
	BEGIN {
		$hfxRegLocation = "HKLM:\Software\Wow6432Node\Citrix\ProductCodes\Hotfixes"
		if ( test-path $hfxRegLocation ) {
			$installedHfx = @(dir $hfxRegLocation |% { write-output $(split-path -leaf $_.Name) } )
		}
		if (test-path $DeprecatedList) {
			$deprecatedHfx = @(get-content $DeprecatedList)
		}
		[object[]]$needed = @()
	}

	PROCESS {
		$FullName |% {
			try {
					#
					# we might have gotten FullName from a pipeline 
					# that wasn't a file object
					# so make we sure we get basename and extension
				$f = dir $FullName
				if ($Extension -match "" -or $BaseName -match "") {
					$Extension = $f.Extension
					$BaseName = $f.BaseName
				}
				if ($Extension -match $patchExtension -and $BaseName -match $XAVersion) {
					write-verbose "Checking ${Basename}"
					$found = (($installedHFX -contains $BaseName) -or ($deprecatedHfx -contains $BaseName) )
					if (! $found) {
						$needed += $f
					}
				}
			}
			catch [System.Exception] {
				write-warning "D'oh - $($error[0])"
			}
		}
	}
	END {
		$Rollup = ""
		[regex]$rxRollup = "(R\d{2})$"
		$needed |? {$_.Basename -match $rxRollup } | select -first 1 |% { $_.BaseName -match $rxRollup }
		if ( $matches.count -gt 0 ) { $Rollup = $matches[1]}
		if ( $Rollup -ne "" ) {
				#
				# if we have a rollup, send it first, 
				# then post-rollup hotfixes in FIFO date order
			write-output $needed |? { $_.BaseName -match $rxRollup }
			$XARollup = "${XAVersion}${Rollup}"
			write-output $needed |? { $_.BaseName -match $XARollup } | sort lastwritetime
		} else {
				#
				# emit list of file objects according to file date, FIFO
			write-output $needed | sort lastwritetime
		}

	}
}

#$myCtxVersion = $(Get-saCtxProductPrefix)
#(Get-Module CitrixTools).exportedcommands.keys

function Set-saCRLDisabled
{
<#
.SYNOPSIS
	disable CRL(Certificate Revocation List) checking for IIS web sites to speed up Web Interface and StoreFront loading. Does not change load performance for .Net 4.0 and higher.
.DESCRIPTION
	when run on IIS web server, add element 'generatePublisherEvidence' to aspnet.config and set value "enabled" to "false" default is to modify every .Net version aspnet.config file. Recycle IIS Application Pool for changes to take effect.
.PARAMETER FileList
array of file objects that should be aspnet.config files. Accepts pipeline output of 'dir'.
.LINK
http://blogs.msdn.com/b/pfedev/archive/2008/11/26/best-practice-generatepublisherevidence-in-aspnet-config.aspx
.LINK
http://www.citrix.com/tv/#videos/8457
.LINK
http://msdn.microsoft.com/en-us/library/bb629393.aspx
#>

	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[object[]]$FileList = @(dir "${env:SystemRoot}\Microsoft.NET" -filter aspnet.config -Recurse)
	)
	BEGIN {
		$e = 'generatePublisherEvidence'
	}

	PROCESS {
		$FileList |% {
			if ($_.Name -match "Aspnet.config") {
				$file = $_.fullname
				[xml]$x = [xml](gc $file)
					#
					# check whether element already exists
				if (! $x.configuration.runtime.SelectSingleNode($e) ) {
					$n = $x.CreateElement($e)
					$n.SetAttribute("enabled","false")
					$x.configuration.runtime.AppendChild($n)
					$x.Save($file)
				}
			}
		}
	}

	END {

	}

}

function Set-saCtxWIShowDesktopViewer
{
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string[]]$FullName
		,[switch]$Off = $false
		,[Parameter(ValueFromPipeline=$true)]
		[object[]]$FileList
	)

	begin {
	}

	process {
		$FullName |% {
			$text = "ShowDesktopViewer="
			$text += if ($off) { "Off" } else { "On" }
			write-verbose "Off: ${Off} `t Text: ${text}"
			if (! ( (cat $_) -match "^$text") ) {
				write-output $text | Out-File -Enc ASCII -Append -File $_
			}
		}
	}

	end {

	}

}

function Set-saCtxICAVirtualChannelPriority
{
<#
.SYNOPSIS

.DESCRIPTION

.LINK
http://support.citrix.com/article/CTX128190
.LINK
http://support.citrix.com/article/CTX116890
.LINK
http://support.citrix.com/article/CTX131001
#>

	[CmdletBinding(SupportsShouldProcess=$true)]
	param (

	)

	begin {
		$chpri = @{}
		$chval = @()
		$channeldata = @(@'
CTXTW  ,0
CTXTWI ,0
CTXCAM ,0
CTXCLIP,1
CTXLIC ,1
CTXVFM ,1
CTXPN  ,1
CTXSBR ,1
CTXMM  ,1
CTXFLSH,1
CTXGUSB,1
CTXSCRD,1
CTXCTL ,1
CTXEUEM,1
CTXCCM ,2
CTXCDM ,3
CTXCM  ,3
CTXLPT1,3
CTXLPT2,3
CTXCOM1,3
CTXCOM2,3
CTXCPM ,3
OEMOEM2,3
OEMOEM ,3
'@) -split "\n"

		$channeldata |% {if ( $_ -match "^(\w+)\s*,(\d+)" ) { $chpri += @{$matches[1]= $matches[2]} } }
		$regkey = 'HKLM:\SOFTWARE\Wow6432Node\Citrix\GroupPolicy\Defaults\WDSettings'
		$regName = 'VirtualChannelPriority'

	}
		
	process {
		$chpri.GetEnumerator() | sort Key | sort Value |% {
				#
				# Virtual Channel name should be exactly 7 chars, use trailing spaces to pad
			$chval += "$($_.key.padright(7)),$($_.Value)" 
		}

	}

	end {
		if ( ! (test-path $regkey)) { mkdir $regkey -Force }
		sp $regkey -Name $regname -Value $chval -type multistring
	}

}

Export-ModuleMember -Function Expand-ZIPFile
Export-ModuleMember -Function Find-saCtxNeededPatches
Export-ModuleMember -Function Get-saCtxHotFixDownload
Export-ModuleMember -Function Get-saCtxProductPrefix
Export-ModuleMember -Function Get-saXALoggedOnUserInfo
Export-ModuleMember -Function Set-saCRLDisabled
Export-ModuleMember -Function Set-saCtxICAVirtualChannelPriority
Export-ModuleMember -Function Set-saCtxWIShowDesktopViewer
Export-ModuleMember -Function Set-saPrinterAttributesForCUPSperCTX136265

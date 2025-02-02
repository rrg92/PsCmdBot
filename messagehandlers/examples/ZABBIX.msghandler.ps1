@{
	COMMANDS = @{
		zbxgethosts = @{
			Syntax		= '/zbxgethosts [NAME:]HOSTNAME,... [SEARCH:] [GROUPS:GROUP] [ZABBIX:NAME]'
			ALIAS		= 'zbxgh'
			DESCRIPTION = 'Search for specific hosts!'
			REQUIRED_PERMISSIONS = 'GET_HOSTS'
			BODY = {
				$ArgHostName 	= $Arguments["NAME"];
				$ArgSearch		= $Arguments.Contains("SEARCH");
				$ArgGroups		= $Arguments["GROUPS"];
				$ArgZabbix		= $Arguments["ZABBIX"];

				if($DefaultArguments[0] -and !$ArgHostName){
					$ArgHostName = $DefaultArguments[0]
				}
				
				if(!$ArgHostName){
					$ArgHostName =  & $Actions.EXTRACT -Message $m.reply_to_message.text -Extractor "VISIBLE_NAME";
				}


				if(!$ArgHostName -and !$ArgGroups){
					$res.reply.message = "You dont specify filtering arguments!";
					return;
				}

			
				$ZabbixCallParams = @{
					output = @('name')
					search = $ArgSearch
				}
				
				if($ArgGroups){
					$ZabbixCallParams.add('groups',$ArgGroups);
				}

				if($ArgHostName){
					$ZabbixCallParams.add('name',$ArgHostName);
				}

				& $this.PRIVATE.ACTIONS.AUTH -ServerName $ArgZabbix -CurrentUser $CurrentUser;

				$Hosts = Get-ZabbixHost @ZabbixCallParams
				
				if($Hosts){
					$res.reply.message = @($Hosts | %{
						"[$($_.hostid)] $($_.name)"
					}) -join "`r`n"
				} else {
					$res.reply.message = "No hosts found with specified filter!";
				}

			}
		}

		zbxgetevents = @{
			Syntax		= '/zbxgetevents [NAME:]HOSTNAME,... [GROUPS:GROUP] [ZABBIX:NAME]'
			ALIAS		= 'zbxge'
			DESCRIPTION = 'Get top 10 events from a specific host or group of host!'
			REQUIRED_PERMISSIONS = 'GET_EVENTS'
			BODY = {
				$ArgHostName 	= $Arguments["NAME"];
				$ArgSearch		= $Arguments.Contains("SEARCH");
				$ArgGroups		= $Arguments["GROUPS"];
				$ArgZabbix		= $Arguments["ZABBIX"];

				if($DefaultArguments[0] -and !$ArgHostName){
					$ArgHostName = $DefaultArguments[0]
				}

				if(!$ArgHostName -and !$ArgGroups){
					$res.reply.message = "You dont specify filtering arguments!";
					return;
				}

			
				$ZabbixCallParams = @{
					limit 				= 10
					selectRelatedObject = 'priority','description'
					selectHosts 		= @('name')
					ManualParams 		= @{
							sortorder = "DESC"
							sortfield = "clock","eventid"
						}
				}
				
				if($ArgGroups){
					$ZabbixCallParams.add('Groups',$ArgGroups);
				}

				if($ArgHostName){
					$ZabbixCallParams.add('Hosts',$ArgHostName);
				}

				& $this.PRIVATE.ACTIONS.AUTH -ServerName $ArgZabbix -CurrentUser $CurrentUser;

				$Events = Get-ZabbixEvent @ZabbixCallParams 
				
				if($Events){
					$res.reply.message = @($Events | %{
						"[$($_.eventid)]$($_.datetime): $($_.TriggerName)"
						"SEVERITY:$($_.TriggerSeverity)"
						"HOST:$($_.HostName)"
						"---"
						""
					}) -join "`r`n"
				} else {
					$res.reply.message = "No events found for specified filters!"
				}
			}
		}

		zbxgetacks = @{
			Syntax		= '/zbxgetacks EventID [ZABBIX:NAME]'
			DESCRIPTION = 'Get acks for a specific eventid'
			REQUIRED_PERMISSIONS = 'GET_ACKS'
			BODY = {
				$ArgEventID 	= $DefaultArguments[0]
				$ArgZabbix		= $Arguments["ZABBIX"];


				if(!$ArgEventID){
					$ArgEventID = & $Actions.EXTRACT -Message $m.reply_to_message.text -Extractor "EVENTID";
				}
				
				if(!$ArgEventID){
					$res.reply.message = "You dont specify the EventID";
					return;
				}

			
				$ZabbixCallParams = @{
					Id 					= $ArgEventID
					selectRelatedObject = 'priority','description'
					selectHosts 		= @('name')
					selectAcknowledges = 'alias','clock','message'
				}
				
				& $this.PRIVATE.ACTIONS.AUTH -ServerName $ArgZabbix -CurrentUser $CurrentUser;
				$Event = Get-ZabbixEvent @ZabbixCallParams 
				
				if($Event.acknowledges){
						
						$acks = @($Event.acknowledges | %{
							$AckTime = (PSCmdBot_UnixTime2LocalTime $_.clock).toString("dd/MM/yyyy HH:mm:ss");
							
							"TIME: $AckTime"
							"USER: $($_.alias)"
							"ACK: $($_.message)"
							"------"
							""
						})
				
					$res.reply.message = @($Event | %{
						"[$($_.eventid)]$($_.datetime): $($_.TriggerName)"
						"SEVERIDADE:$($_.TriggerSeverity)"
						"HOST:$($_.HostName)"
						"ACKS: "
						""
						$acks
					}) -join "`r`n"
				} else {
					$res.reply.message = "This event dont have acks!" + (Get-EmojiString 0x1f62d -count 3)
				}
			}
		}

		zbxack = @{
			Syntax		= '/zbxack EventID MSG:ACK MSG [ZABBIX:NAME]'
			DESCRIPTION = 'Ack a event'
			REQUIRED_PERMISSIONS = 'ACK'
			BODY = {
				$ArgEventID 	= $DefaultArguments[0]
				$ArgMsg 		= @($Arguments["MSG"])[0];
				$ArgZabbix		= $Arguments["ZABBIX"];

				#Attempts extract!
				if($m.reply_to_message.text){
					$ArgEventID = & $Actions.EXTRACT -Message $m.reply_to_message.text -Extractor "ACK_EVENTID";
					
					if(!$ArgMsg){
						$ArgMsg = $DefaultArguments[0];
					}
				}
				
				if(!$ArgEventID){
					$res.reply.message = "You dont specify the EventID";
					return;
				}

				if(!$ArgMsg){
					$res.reply.message = "You dont specify the ack message!";
					return;
				}
			
				& $this.PRIVATE.ACTIONS.AUTH -ServerName $ArgZabbix -CurrentUser $CurrentUser;
				Ack-ZabbixEvent -EventId $ArgEventID -Message $ArgMsg;
				$res.reply.message = "Acknowledged successfully!";
			}
		}

		zbxaddserver = @{
			Syntax		= '/zbxaddserver NAME URL'
			DESCRIPTION = 'Register a server to be used!'
			REQUIRED_PERMISSIONS = 'EDIT_SERVERS'
			BODY = {
				$ArgServerName 	= $null;
				$ArgURL			= $null;

				#Get the sername!
				if($DefaultArguments.count -ge 1){
					$ArgServerName = $DefaultArguments[0];
				}
				
				#Get the sername!
				if($DefaultArguments.count -ge 2){
					$ArgURL = $DefaultArguments[1];
				}

				if(!$ArgServerName){
					$res.reply.message = "Invalid servername!"
					return;
				}

				if(!$ArgURL){
					$res.reply.message = "Invalid URL!"
					return;
				}
			
				& $Actions.REGISTER_SERVER -ServerName $ArgServerName -URL $ArgURL
				$res.reply.message = "Server added to list!";
			}
		}
		
		zbxaddcred = @{
			Syntax		= '/zbxaddcred NAME USER PASS'
			DESCRIPTION = 'Register a credential for a server!'
			BODY = {
				$ArgServerName 	= $DefaultArguments[0];;
				$ArgUser		= $DefaultArguments[1];
				$ArgPass		= $DefaultArguments[2];

				if($m.chat.type -ne "private"){
					$res.reply.message = "You must send this command for me in a private chat because you must provide sensitive information!"
					return;	
				}

				if(!$ArgServerName){
					$res.reply.message = "Invalid servername!"
					return;
				}

				if(!$ArgUser){
					$res.reply.message = "Invalid USER!"
					return;
				}

				if(!$ArgPass){
					$res.reply.message = "Invalid PASS!"
					return;
				}

				$RegisteredServers = $this.PRIVATE.STORE.SERVERS;
				if(!$RegisteredServers.Contains($ArgServerName)){
					$res.reply.message = "Server $ArgServerName not exists!"
					return;
				}

				
				& $Actions.MODIFY_CREDENTIALS -ServerName $ArgServerName -User $ArgUser -Password $ArgPass -CurrentUser $CurrentUser
				$res.reply.message = "Credentials updated!";
			}
		}

		zbxgetcred = @{
			Syntax		= '/zbxgetcred NAME'
			DESCRIPTION = 'Gets the credentials for the current user!'
			BODY = {
				$ArgServerName 	= $DefaultArguments[0];;


				if(!$ArgServerName){
					$res.reply.message = "Invalid servername!"
					return;
				}

				$Server = $this.PRIVATE.STORE.SERVERS[$ArgServerName];
				if(!$Server){
					$res.reply.message = "Server $ArgServerName not exists!"
					return;
				}

				#Get the user auth key!
				$Auth  = $Server.AUTH[$CurrentUser];

				if($Auth){
					$UserName = $Auth.GetNetworkCredential().UserName
					$Password = $Auth.GetNetworkCredential().Password
					
					$ReplyText = @(
						"Using the username: $UserName"
					)

					if($m.chat.type -eq "private"){
						$ReplyText += "PASSWORD: $Password"
					} else {
						$ReplyText = "For get password, send the command to me in a private chat!"
					}

					$res.reply.message = $ReplyText -Join "`r`n";
				} else {
					$res.reply.message = "No credentials for you!"
				}
			}
		}

		zbxdelcred = @{
			Syntax		= '/zbxdelcred NAME'
			DESCRIPTION = 'Remove your credentials for a server!'
			BODY = {
				$ArgServerName 	= $DefaultArguments[0];;

				if(!$ArgServerName){
					$res.reply.message = "Invalid servername!"
					return;
				}

				$RegisteredServers = $this.PRIVATE.STORE.SERVERS;
				if(!$RegisteredServers.Contains($ArgServerName)){
					$res.reply.message = "Server $ArgServerName not exists!"
					return;
				}

				
				$removed = & $Actions.DELETE_CREDENTIALS -ServerName $ArgServerName -CurrentUser $CurrentUser
				if($removed){
					$res.reply.message = "Credentials removed!";
				} else {
					$res.reply.message = "You dont have credentials for $ArgServerName. Nothing to do";
				}
			}
		}

		zbxgetservers = @{
			Syntax		= '/zbxgetservers'
			DESCRIPTION = 'Gets the list of registered servers'
			BODY = {
				$Server = $this.PRIVATE.STORE.SERVERS;
				if($Server.count){
					$ReplyText = @(
						"Servers List:"
					)

					$Server.GetEnumerator() | %{
						$ReplyText += "NAME: $($_.Key) URL:$($_.Value.URL)"
					}

					$res.reply.message = $ReplyText -Join "`r`n";
				} else {
					$res.reply.message = "No servers registered!"
				}
			}
		}
		
		zbxdelserver = @{
			Syntax		= '/zbxdelserver NAME'
			DESCRIPTION = 'Remove a server'
			REQUIRED_PERMISSIONS = 'EDIT_SERVERS'
			BODY = {
				$ArgServerName 	= $null;

				#Get the sername!
				if($DefaultArguments.count -ge 1){
					$ArgServerName = $DefaultArguments[0];
				}
				
				#Get the sername!
				if($DefaultArguments.count -ge 2){
					$ArgURL = $DefaultArguments[1];
				}

				if(!$ArgServerName){
					$res.reply.message = "Invalid servername!"
					return;
				}

				$removed = & $Actions.DELETE_SERVER -ServerName $ArgServerName
				
				if($removed){
					$res.reply.message = "Server removed!"
				} else {
					$res.reply.message = "Server not exists. Nothing was done."
				}
			}
		
		}

		zbxtestextractor = @{
				Syntax		= '/zbxreplytest EXTRACTOR SERVER'
				DESCRIPTION = 'Test a extractor'
				BODY = {
					$ArgExtractor 	= $Arguments["EXTRACTOR"];
					$ArgServer 		= $Arguments["SERVER"];

					if($DefaultArguments[0] -and !$ArgExtractor){
						$ArgExtractor = $DefaultArguments[0]
					}
					
					if($DefaultArguments[1] -and !$ArgServer){
						$ArgServer = $DefaultArguments[1]
					}
					
					#Check if extracto exists!
					if(!$this.CONFIG.REGEX_EXTRACTOR.Contains($ArgExtractor)){
						$res.reply.message = "Extractor not exists: $ArgExtractor"
						return;
					}
					
					#Check if extracto exists!
					if(!$m.reply_to_message.text){
						$res.reply.message = "You must reply a message in order to test extractor!"
						return;
					}
					
					try {
						$ServerExtractor = & $Actions.PICK_SERVER -NameOnly -ServerName $ArgServer
					} catch {
						$ServerExtractor = "Failed: $_";
					}
					
					$ExtractorResult = & $Actions.EXTRACT -Test -Message $m.reply_to_message.text -Extractor $ArgExtractor;
					
					$res.reply.message = @(
						"SERVER: $ServerExtractor"
						"EXTRACTOR $ArgExtractor :"
						$ExtractorResult
					) -Join "`r`n"
				}
			}
	
		zbxsetdefault = @{
			Syntax		= '/zbxsetdefault NAME'
			DESCRIPTION = 'Set default server'
			REQUIRED_PERMISSIONS = 'EDIT_SERVERS'
			BODY = {
				$ArgServerName 	= $null;
				
				#Get the sername!
				if($DefaultArguments.count -ge 1){
					$ArgServerName = $DefaultArguments[0];
				}
				
				& $Actions.SET_DEFAULT_SERVER -ServerName $ArgServerName;
				if($ArgServerName){
					$res.reply.message = "Server $ArgServerName is now the default!";
				} else {
					$res.reply.message = "Default server removed!";
				}
			}
		}
		
		zbxgetdefault = @{
			Syntax		= '/zbxgetdefault'
			DESCRIPTION = 'Gets the default server!'
			BODY = {
				try {
					$ServerName = & $Actions.PICK_SERVER -NameOnly
					$Reply 		= "Default server: $ServerName"
				} catch {
					$Reply		= "Error: $_";
				}
				
				
				$res.reply.message = $Reply
			}
		}
		
	}

	CONFIG = @{
		PERMISSIONS = @{
			'*'	= @()
		}
		
		POWER_ZABBIX_PATH 		= '\modules\power-zabbix'
		POWER_ZABBIX_LITERAL	= $null
		
		#If true, persists server informations (including creds)
		PERSISTS 		= $false
		PERSIST_PATH	= '\ZABBIXMSGHANDLER.store'
		
		#Expressions to determine the servername based on message!
		#We pass the messahe object as first parameter!
		SERVER_EXTRACTOR = @{
			SERVERNAME = {}	
		}
		

		REGEX_EXTRACTOR	= @{
			#Used when need extract eventid for ack
			ACK_EVENTID = $null
			
			#Used when need a HOST VISIBLE NAME
			VISIBLE_NAME = $null
			
			#Extract a event id!
			EVENTID		= $null
		}
	}

	ON_START = {
		param($params)

		$me					= $params.Handler;
		$WorkingDirectory 	= PsCmdBot_GetWorkingDirectory;
		#Load servernames from CONFIG!
		$MyConfig 		= $me.getMyConfig();
		
		if($MyConfig.POWER_ZABBIX_LITERAL){
			$PowerZabbix 		= $MyConfig.POWER_ZABBIX_LITERAL;
		} elseif($MyConfig.POWER_ZABBIX_PATH){
			$PowerZabbix 		= $MyConfig.POWER_ZABBIX_PATH;
		} else {
			$PowerZabbix 		= "$WorkingDirectory\modules\power-zabbix"; 
		}

		
		if(![IO.Directory]::Exists($PowerZabbix) -and !$MyConfig.POWER_ZABBIX_LITERAL){
			throw "POWERZABBIX_MODULE_NOTFOUND: $PowerZabbix";
		}

		import-module $PowerZabbix -force; 

		#Restore state!
		& $me.PRIVATE.ACTIONS.STORE_RESTORE;

		if($MyConfig.SERVERS -is [hashtable]){
			$MyConfig.SERVERS.GetEnumerator() | ? {-not ( @($me.PRIVATE.STORE.SERVERS.Keys) -Contains $_.Key)} | %{
				$ServerName = $_.Key;
				$URL  = $_.Value.URL;
				PsCmdBot_Log "ZABBIX HANDLER: Registering server $ServerName" "DETAILED"
				& $me.PRIVATE.ACTIONS.REGISTER_SERVER -ServerName $ServerName -URL $URL;
			}
		}

		
	}

	PRIVATE = @{
		ACTIONS = @{
			REGISTER_SERVER = {
				param($ServerName, $URL)

				if($this){
					$me = $this
				}
				
				
				$RegisteredServers = $me.PRIVATE.STORE.SERVERS;
				
				if($RegisteredServers.Contains($ServerName)){
					$ServerSlot = $RegisteredServers[$ServerName];
				} else {
					$ServerSlot = @{
									URL = $null
									AUTH = @{}
							}
					$RegisteredServers[$ServerName] = $ServerSlot;
				}
				
				$ServerSlot.URL = $URL
				
				if(!$Actions){
					$Actions = $me.PRIVATE.ACTIONS
				}
				
				& $Actions.PERSIST_STORE;
				return;
			}
			
			SET_DEFAULT_SERVER = {
				param($ServerName)

				if($this){
					$me = $this
				}
				
				if($ServerName.Length -gt 0){
					$RegisteredServers = $me.PRIVATE.STORE.SERVERS;
			
					if($RegisteredServers.Contains($ServerName)){
						$me.PRIVATE.STORE.DEFAULT_SERVER = $ServerName;
					} else {
						$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_SETDEFAULT' -Msg "Server not exists: $ServerName";
						throw $ex;
					}
				} else {
					$me.PRIVATE.STORE.DEFAULT_SERVER = $null;
				}

				& $Actions.PERSIST_STORE;
				
				return;
			}

			PICK_SERVER = {
				param($ServerName, [switch]$NameOnly = $false)

				if($this){
					$me = $this
				}
	
				if(!$ServerName){
					
					# Tries pick the server from extractor!
					#Server extractor are defined by administrator!
					#If multuple extractors are returned for this messahe, we will trhow a error!
					if($m){
						$ServerExtractor = @($myConfig.SERVER_EXTRACTOR.GetEnumerator() | ? {
										& $_.Value $m;
								})	
								
						if($ServerExtractor.count -gt 1){
							$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_SERVEREXTRACTOR' -Msg "Multiple servers matched!";
							throw $ex;
						} elseif($ServerExtractor.count -eq 1) {
							$ServerName = $ServerExtractor.Key;
						}
					} 
				
					#If at this point we continue without server, attempt get from default!
					if(!$ServerName){
						# Here we check if was defined a default server!
						# If yes, we use them!
						if($me.PRIVATE.STORE.DEFAULT_SERVER){
							$ServerName = $me.PRIVATE.STORE.DEFAULT_SERVER 
						} else {
							# If no, then we just pickup server from list if exists just one!
							if($me.PRIVATE.STORE.SERVERS.count -eq 1){
								$ServerName = @($me.PRIVATE.STORE.SERVERS.Keys)[0]
							}
						}
					}
				}

				if(!$ServerName){
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_INVALIDSERVER' -Msg "No server informed!";
					throw $ex;
				}
				
				$RegisteredServers = $me.PRIVATE.STORE.SERVERS;
				if(!$RegisteredServers.Contains($ServerName)){
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_INVALIDSERVER' -Msg "Server invalid: $ServerName";
					throw $ex;
				}
				
				if($NameOnly){
					return $ServerName;
				} else {
					return $RegisteredServers[$ServerName];
				}
				
			}

			DELETE_SERVER = {
				param($ServerName)

				$RegisteredServers = $this.PRIVATE.STORE.SERVERS;
				
				if($RegisteredServers.Contains($ServerName)){
					$RegisteredServers.Remove($ServerName);
					$result = $true;
				} else {
					$result = $false;
				}
				
				& $Actions.PERSIST_STORE;
				return $result;
			}
	
			MODIFY_CREDENTIALS = {
				param($ServerName, $User, $Password, $CurrentUser)

				$Server 	= $this.PRIVATE.STORE.SERVERS[$ServerName];
				$PassSecure	= ConvertTo-SecureString $Password -AsPlainText -Force;
				$Creds		= New-Object Management.Automation.PSCredential($User, $PassSecure)
				$Server.AUTH[$CurrentUser] = $Creds;
				
				& $Actions.PERSIST_STORE;

				return;
			}

			DELETE_CREDENTIALS = {
				param($ServerName, $CurrentUser)

				$Server 	= $this.PRIVATE.STORE.SERVERS[$ServerName];
				$AuthKey	= $Server.AUTH[$CurrentUser];

				if($Server.AUTH.Contains($CurrentUser)){
					$Server.AUTH.Remove($CurrentUser);
					$result = $true;
				} else {
					$result = $false;
				}
				
				& $Actions.PERSIST_STORE;
				return $result;
			}

			PERSIST_STORE = {
				
				if(!$myConfig.PERSISTS){
					return;
				}
				
				if($this){
					$me = $this
				}
			
				#Get the servers!
				$Servers 	= $me.PRIVATE.STORE;
				
				#Exporting!
				$Servers  | Export-CliXMl $myConfig.PERSIST_PATH
			}
			
			STORE_RESTORE = {
				
				$FilePath = "";
				if($myConfig.PERSIST_PATH){
					$FilePath = $myConfig.PERSIST_PATH;
				}
				
				if(!$myConfig.PERSISTS -or ![IO.File]::Exists($FilePath)){
					return;
				}
				
				#Reimporting!
				if($this){
					$me = $this;
				}
				
				$PersistedStore = Import-CliXML $FilePath 
				
				if($PersistedStore -is [hashtable]){
					$me.PRIVATE.STORE = $PersistedStore 
				}
				
			}
			
			EXTRACT = {
				param($Message, $Extractor, [switch]$Test)
				
				if(!$Message){
					return;
				}
				
				$ExtractorRegExp = $myConfig.REGEX_EXTRACTOR[$Extractor];
				
				if(!$ExtractorRegExp){
					throw "ZABBIXHANDLER_INVALID_EXTRACTOR: $Extractor";
				}
				
				if( $Message -split "`n" | ? {$_ -match $ExtractorRegExp}){
					if($Test){
						$ReplyArr = @(
							"RegEx: $ExtractorRegExp"
							"Matches:"
						)
						
						$matches.GetEnumerator() | %{
							$ReplyArr += "[$($_.Name)]: $($_.Value)";
						}
					} else {
						return $matches[1];
					}
				} else {
					if(!$Test){
						return;
					}
					
					$ReplyArr = @("No matches!")
				}
				
				return ($ReplyArr -Join "`r`n");
			}
			
			AUTH = {
				param($ServerName, $CurrentUser)
				
				if($this){
					$me = $this;
				}
				
				try {
					$Server = & $Actions.PICK_SERVER -ServerName $ServerName
				} catch {
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_AUTH_PICKSERVERFAILED' -Inner $_;
					throw $ex;
				}
				
				$AuthKey	= $Server.AUTH[$CurrentUser];

				if($AuthKey){
					$User	 	= $AuthKey.GetNetworkCredential().UserName;
					$Pass	 	= $AuthKey.GetNetworkCredential().Password;
					Auth-Zabbix -URL $Server.URL -User $User -Password $Pass
				} else {
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_AUTH' -Msg "You dont have credentials mapped in server $ServerName";
					throw $ex;
				}

				return;
			}
		}

		STORE = @{
			DEFAULT_SERVER = $NULL;
			SERVERS = @{
				<#
				NAME = @{
					URL = "";
					AUTH = @{
						TELEGRAM_USERNAME = @{ZABBIX_USERNAME=$NULL;PASSWORD=$null}
					}
				}
				#>
			}
		}

	}
	
	

	HANDLER = {
		param($res, $Update)
		
		$m = $Update.message;
		$res.mustReply = $true;
		$BotCommand 	= PsCmdBot_DCP_ParseCommand $m;
		$CommandName	= $BotCommand.CommandName;
		$Arguments		= $BotCommand.Arguments;
		$DefaultArguments = $Arguments[""];
		$Configuration	= PsCmdBot_CM_GetConfiguration;
		$myConfig		= $this.getMyConfig();
		$CurrentUser	= $m.from.username;
		$Actions		= $this.PRIVATE.ACTIONS;

		$RealCommand = $this.getRealCommandName($BotCommand.CommandName);
		$Command = $this.COMMANDS[$RealCommand];

		if(-not $Command.BODY -is [scriptblock]){
			$res.reply.message = "Command not implemented!";
			return $res;
		}

		#Get permissions for the current user!
		$UserPermissions = @($myConfig.PERMISSIONS['*']) + @($myConfig.PERMISSIONS[$CurrentUser]);
		$RequiredNotGranted = $Command.REQUIRED_PERMISSIONS | ? {-not($UserPermissions -Contains $_)};
		$IsSuper			= $Configuration.GLOBAL.ADMIN.SUPER_ADMINS -Contains $CurrentUser
	
		if($Command.REQUIRED_PERMISSIONS -and $RequiredNotGranted -and !$IsSuper){
			$res.reply.message = "You must have this permissions to run this command: $RequiredNotGranted";
			return;
		}


		if(!$DefaultArguments){
			$DefaultArguments = @();
		}

		try {
			$out = . $Command.BODY;
		} catch {
			$Formmated  = PsCmdBot_FormatExceptions $_ -prefix "ZABBIX_HANDLER_EXCEPTION" -BaseDir (PsCmdBot_GetWorkingDirectory)
			PsCmdBot_Log "$Formmated";
			$res.reply.message = @(
				"Command failed: "
				$_
			) -Join "`r`n"
		}

		return $res;
	}
}
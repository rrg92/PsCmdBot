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
			Syntax		= '/zbxack EventID [MSG:ACK MSG] [ZABBIX:NAME]'
			DESCRIPTION = 'Ack a event'
			REQUIRED_PERMISSIONS = 'ACK'
			BODY = {
				$ArgEventID 	= $DefaultArguments[0]
				$ArgMsg 		= @($Arguments["MSG"])[0];
				$ArgZabbix		= $Arguments["ZABBIX"];

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

				$RegisteredServers = $this.PRIVATE.SERVERS;
				if($RegisteredServers.Contains($ArgServerName)){
					$res.reply.message = "Server $ArgServerName already registered!"
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

				$RegisteredServers = $this.PRIVATE.SERVERS;
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

				$Server = $this.PRIVATE.SERVERS[$ArgServerName];
				if(!$Server){
					$res.reply.message = "Server $ArgServerName not exists!"
					return;
				}

				#Get the user auth key!
				$Auth  = $Server.AUTH[$CurrentUser];

				if($Auth){
					$ReplyText = @(
						"Using the username: $($Auth.ZABBIX_USERNAME)"
					)

					if($m.chat.type -eq "private"){
						$ReplyText += "PASSWORD: $($Auth.PASSWORD)"
					} else {
						$ReplyText = "For get password, send the command to me in a private chat!"
					}

					$res.reply.message = $ReplyText -Join "`r`n";
				} else {
					$res.reply.message = "No credentials for you!"
				}
			}
		}

		zbxgetservers = @{
			Syntax		= '/zbxgetservers'
			DESCRIPTION = 'Gets the list of registered servers'
			BODY = {
				$Server = $this.PRIVATE.SERVERS;
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
		
	}

	CONFIG = @{
		PERMISSIONS = @{
			'*'	= @()
		}

	}

	ON_START = {
		param($params)

		$me					= $params.Handler;
		$WorkingDirectory 	= PsCmdBot_GetWorkingDirectory;
		$PowerZabbix 		= "$WorkingDirectory\modules\power-zabbix";

		if(![IO.Directory]::Exists($PowerZabbix) ){
			throw "POWERZABBIX_MODULE_NOTFOUND: $PowerZabbix";
		}

		import-module $PowerZabbix -force; 

		#Load servernames from CONFIG!
		$MyConfig = $me.getMyConfig();
		if($MyConfig.SERVERS -is [hashtable]){
			$MyConfig.SERVERS.GetEnumerator() | %{
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

				$RegisteredServers = $this.PRIVATE.SERVERS;
				$RegisteredServers.add( $ServerName, @{
											URL = $URL
											AUTH = @{}
									})
				return;
			}

			MODIFY_CREDENTIALS = {
				param($ServerName, $User, $Password, $CurrentUser)

				$Server 	= $this.PRIVATE.SERVERS[$ServerName];
				$AuthKey	= $Server.AUTH[$CurrentUser];

				if($AuthKey){
					$AuthKey['ZABBIX_USERNAME'] = $User;
					$AuthKey['PASSWORD'] = $Password; 
				} else {
					$AuthKey = @{
						ZABBIX_USERNAME = $User
						PASSWORD = $Password
					}
					$Server.AUTH.add($CurrentUser,$AuthKey);
				}

				return;
			}

			AUTH = {
				param($ServerName, $CurrentUser)
				
				if(!$ServerName){
					$ServerName = @($this.PRIVATE.SERVERS.Keys)[0];
				}

				if(!$ServerName){
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_AUTH' -Msg "Invalid server name!";
					throw $ex;
				}

				$Server 	= $this.PRIVATE.SERVERS[$ServerName];
				$AuthKey	= $Server.AUTH[$CurrentUser];

				if($AuthKey){
					Auth-Zabbix -URL $Server.URL -User $AuthKey['ZABBIX_USERNAME'] -Password $AuthKey['PASSWORD'];
				} else {
					$ex = PSCmdBot_GetNewException -ID 'ZABBIX_HANDLER_AUTH' -Msg "You dont have credentials mapped in server $ServerName";
					throw $ex;
				}

				return;
			}
		}

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
	
	

	HANDLER = {
		param($Update)
		
		$m = $Update.message;
		$res = NewHandlerResult $this;
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
	
		if($Command.REQUIRED_PERMISSIONS -and $RequiredNotGranted){
			$res.reply.message = "You must have this permissions to run this command: $RequiredNotGranted";
			return $res;
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
@{

	COMMANDS = @{
		listcmds = @{
			ALIAS		= 'help'
			SYNTAX		= '/listcmds Flags'
			DESCRIPTION = 'List all possible commands and descriptions. Specify -BF in flags to BOTFATHER help'
			BODY		= {
					$Flags		  = @{};
					
					$Params | ? {$_} | %{
						if( $_[0] -eq '-' ){
							$FlagsParam	  = $_ -replace '^-','' -split ',';
						}
						else {
							$CommandName = $_;
						}
						
					}
					
					if($FlagsParam){
						$FlagsParam -split ',' | %{
							$Flags.add($_,$true);
						}
					}
					
					
					$CommandHelpParams = @{};
					
					if($CommandName){
						$CommandHelpParams.add("Command", $CommandName);
					}
					
					if($Flags.BF){
						$CommandsHelp = PsCmdBot_MsgHandlers_GetCommandsHelp -BotFatherList;
						$ReplyText = @(
							$CommandsHelp
						) -join "`r`n"
					} else {
						$CommandsHelp = PsCmdBot_MsgHandlers_GetCommandsHelp @CommandHelpParams;
					
						$ReplyText = @(
							"PSCmdBot! by Rodrigo Ribeiro Gomes!"
							""
							$CommandsHelp
						) -join "`r`n"
					}
				}
		}
		
		setopt = @{
			SYNTAX		= '/setopt OptionName OptionValue'
			DESCRIPTION = 'Sets a option in bot'
			BODY		= {
				if( $this.COMMANDS.setopt.AUTHORIZED_USERS -Contains $Update.message.from.username ){
					$OptName = $CmdParts[1];
					$OptValue = $CmdParts[2];
									
					$CurrOpt = Get-PsCmdBotOption -Name $OptName;
					
					if($CurrOpt){
						Set-PsCmdBotOption -Name $OptName -Value $OptValue;
						$ReplyText = "Changed option $OptName from $($CurrOpt.Value) to $OptValue"
					} else {
						$ReplyText = "I dont found the option you specified: $OptName";
						
					}
				} else {
					$ReplyText = 'You dont have authorization for this'
				}
			}
		}
		
		getopt = @{
			SYNTAX		= '/getopt [OptionName]'
			DESCRIPTION = 'Get all options values or specific one'
			BODY		= {
				$OptName = $CmdParts[1];
				
				$OptValues = Get-PsCmdBotOption  -Name $OptName | %{
					"$($_.key) $($_.value)"
				}
				
				$ReplyText = @(
					"Segue a lista de options:"
					$OptValues
				) -join "`r`n"
			}
		}
		
		botping = @{
			SYNTAX = '/ping'
			DESCRIPTION = 'pings the bot to check if it responding.'
			BODY = {
				$Emoji = @(
					Get-EmojiString 0x1f64b #Man raising hand
					Get-EmojiString 0x261d #index point up
					Get-EmojiString 0x1f44b #horns
				) | Get-Random
				
				
				
				$ReplyText = @(
					"Sim, estou aqui! $Emoji"
					"Oi, tô aqui $Emoji"
					"$Emoji acordado desde $(PSCmdBot_GetStartTime)"						
				) | Get-Random
			}
		}
		
		chatinfo = @{
			SYNTAX = '/chatinfo'
			DESCRIPTION = 'Dump informations about current chat!'
			BODY = {
				$ChatInfo = $m.chat;
				
				$ReplyText = @(
					"You request a chatinfo!"
					"ChatId: $($ChatInfo.id)"
					"Type: $($ChatInfo.type)"
					"Username: $($ChatInfo.username)"
				) -Join "`r`n";
			}
		}
		
		envinfo = @{
			SYNTAX = '/envinfo'
			DESCRIPTION = 'Information about current bot execution environemnt and host'
			BODY = {
				$SO = $null;
				$ComputerName = $null;
				$Emoji = "";
				
				if($Env:ComputerName){
					$SO = 'Windows';
					$ComputerName  = $Env:ComputerName;
					$Emoji = Get-EmojiString 0x1F601
				}
				elseif($Env:HOSTNAME){
					$SO = 'Linux';
					$ComputerName  = $Env:HOSTNAME;
					$Emoji = Get-EmojiString 0x1F630
				}
			
				$ReplyText = @(
					"SO: $SO $Emoji"
					"CurrentComputer: $ComputerName"
				) -Join "`r`n";
			}
		}
		
		failsim = @{
				SYNTAX = '/failsim'
				DESCRIPTION = 'Simulate failure'
				BODY		= {
					throw '/FAILSIM: FAILURE SIMULATION'
				}
			}


		dcptest = @{
			SYNTAX 			= '/dcptest PARAMS'
			DESCRIPTION		= 'Test bot command parsing with DEFAULT COMMAND PARSER (DCP) of pscmdbot'
			BODY			= {
					$ParseResult = PsCmdBot_DCP_ParseCommand $m;
					
					if($ParseResult.error) {
						$ReplyText = @(
							"PARSING ERROR: "
							$ParseResult.error
						) -Join "`r`n";
					} else {
						$ReplyText = @(
							"Sucessfully parsed."
							"CommandName: $($ParseResult.CommandName)"
						);

						if($ParseResult.Arguments.count -gt 0){
							$ReplyText += "Parameters values:";
							$ReplyText += "";

							$ParseResult.Arguments.GetEnumerator() | %{
								
								if($_.Key.Length -eq 0){
									$ReplyText += "-- DEFAULT --"
								} else {
									$ReplyText += $_.Key;
								}
								
								

								$_.Value | %{
									if($_ -ne $null){
										$ValueType = $_.GetType().FullName;
									} else {
										$ValueType = '$NULL'
									}

									$ReplyText += "`t[$ValueType]"+$_;
								}
							}
						}

						$ReplyText = $ReplyText -Join "`r`n";
					}
			}
		}


		getcfg = @{
			SYNTAX	= '/getcfg [CFG1 CF2 ... CFX] [C[ONFIG]:CONFIGNAME]'
			DESCRIPTION = 'Prints current effective configuraton values'
			BODY = {
				$Arguments 	= $ParseResult.Arguments;
				$ConfigName = "E";

				$KeyToList = @();
				if($Arguments.Contains("")){
					$KeyToList = $Arguments[""];
				}

				if( $Arguments.Contains("C") ){
					$ConfigName = $Arguments["C"];
				}

				if( $Arguments.Contains("CONFIG") ){
					$ConfigName = $Arguments["CONFIG"];
				}

				$ConfigToDump = $null;
				$ConfigStor = (PsCmdBot_Stor_GetStorage).CONFIGURATION;
				switch($ConfigName){
					"U" {
						$Msg = "Dumping USER CONFIGURATION"
						$ConfigToDump = $ConfigStor.USER.CONFIG;
					}

					"R" {
						$Msg = "Dumping RUNTIME CONFIGURATION"
						$ConfigToDump = $ConfigStor.RUNTIME;
					}

					"D" {
						$Msg = "Dumping DEFAULT CONFIGURATION"
						$ConfigToDump = $ConfigStor.DEFAULT;
					}

					"H" {
						$Msg = "Dumping HANDLERS DEFAULT CONFIGURATION"
						$ConfigToDump 		= PsCmdBot_CM_GetHandlersDefaultConfig;
					}

					default {
						$Msg = "Dumping EFFECTIVE COFNIGURATION"
						$ConfigToDump  = $CurrentConfig
					}
				}

				$Result = PsCmdBot_Hash2String -Hash $ConfigToDump -KeyList $KeyToList -SensitiveList $CurrentConfig.GLOBAL.ADMIN.SENSITIVE_CONFIG_KEYS;

				if(!$Result){
					$Result = "No configurations founds!"
				}

				$ReplyText = @(
						$Msg
						$Result 
				) -Join "`r`n";
			}
		}

		setcfg = @{
			SYNTAX = '/setcfg CFGPATH VALUE [U:] [A:] [UN:]'
			DESCRIPTION = 'Change a configuration in runtime!'
			BODY = {
				$Arguments = $ParseResult.Arguments;
				$DefaultArgs = $Arguments[""];
				$Unset		= $Arguments.Contains("U");
				$ArrayMode	= $Arguments.Contains("A"); #Make the operation to be made in array element only!
				$Force	= $Arguments.Contains("F"); #force append. Duplicates will be allowed

				if(!$DefaultArgs){
					$res.reply.message = "Insuficient arguments provided!"
					return $res;
				}

				if($DefaultArgs.count -ge 1){
					$CfgPath = $DefaultArgs[0];
				}

				if($DefaultArgs.count -ge 2){
					$CfgNewValue = $DefaultArgs[1];
				}

				if(!$CfgPath){
					$res.reply.message = "Configuration path required!";
					return $res;		
				}

				if(!$Unset -and $CfgNewValue -eq $null){
					$res.reply.message = "New value not provided!";
					return $res;
				}
				
				
				if( $ArrayMode ){
					#Array mode handle values like array!
					$CurrentValue = @(PsCmdBot_CM_GetConfiguration $CfgPath);

					if(!$CurrentValue){
						$CurrentValue = @();
					}

					#Put the config into a array!
					if($Unset){ #If unset, remove vaule from array and update value!
						$CfgNewValue = $CurrentValue | ? {$_ -ne $CfgNewValue;  };
						$Unset = $false;
					} else {
						#Just add the value to array!
						if(!$Force){
							if( $CurrentValue | ? { $_ -eq $CfgNewValue }){
								$res.reply.message = "Value already exist in configuration!"
								return $res;
							}
						}

						
						$CfgNewValue = $CurrentValue + $CfgNewValue;
					}
					

				}


				$SetConfigParams = @{
					Unset = $Unset
					Value = $CfgNewValue
					ConfigPath = $CfgPath
				}




				try {
					PsCmdBot_CM_ModifyConfigRuntime @SetConfigParams;
					if($ArrayMode){
						$ReplyText  = "Configuration updated in array mode!";
					} else {
						$ReplyText  = "Configuration updated!";
					}
					
				} catch {
					$Formmated = PsCmdBot_FormatExceptions $_ -BaseDir $PsCmdBot_ModuleRoot;
					PSCmdBot_Log "ERROR CHANGING THE CONFIGURATION: $Formmated"
					
					$ReplyText = @(
							"Error when changing the configuration in runtime!"
							$_
					) -Join "`r`n"
				}
			}
		}

	}
	
	HANDLER = {
		param($res, $update)
		
		$res.mustReply = $true;
		

		$m			= $update.message;
		$CmdParts	= ($m.text -split ' ');
		$BotCommand = PsCmdBot_DCP_GetCommandName $m;
		$ParseResult = PsCmdBot_DCP_ParseCommand $m;
		$CurrentConfig = PsCmdBot_CM_GetConfiguration

		if($ParseResult.error) {
			$res.reply.message = @(
				"COMMAND PARSING ERROR: "
				$ParseResult.error
			) -Join "`r`n";
			return $res;
		}
		
		$RealCommand = $this.getRealCommandName($BotCommand);
		$Command = $this.COMMANDS[$RealCommand];

		if(-not $Command.BODY -is [scriptblock]){
			$res.reply.message = "Command not implemented!";
			return $res;
		}
		
		if($CmdParts.Length -gt 1){
			$Params		= 1..($CmdParts.Length-1) | %{$CmdParts[$_]};
		} else {
			$Params = @();
		}

		. $Command.BODY

		$res.reply.message = $ReplyText;
	}


}
@{
	COMMANDS = @{
		listcmds = @{
			ALIAS		= 'help'
			SYNTAX		= '/listcmds Flags'
			DESCRIPTION = 'List all possible commands and descriptions. Specify -BF in flags to BOTFATHER help'
		}
		
		setopt = @{
			SYNTAX		= '/setopt OptionName OptionValue'
			DESCRIPTION = 'Sets a option in bot'
			AUTHORIZED_USERS = @('rrg92')
		}
		
		getopt = @{
			SYNTAX		= '/getopt [OptionName]'
			DESCRIPTION = 'Get all options values or specific one'
		}
		
		botping = @{
			SYNTAX = '/ping'
			DESCRIPTION = 'pings the bot to check if it responding.'
		}
		
		chatinfo = @{
			SYNTAX = '/chatinfo'
			DESCRIPTION = 'Dump informations about current chat!'
		}
		
		envinfo = @{
			SYNTAX = '/envinfo'
			DESCRIPTION = 'Information about current bot execution environemnt and host'
		}
		
		failsim = @{
				SYNTAX = '/failsim'
				DESCRIPTION = 'Simulate failure'
			}

		dcptest = @{
			SYNTAX 			= '/dcptest PARAMS'
			DESCRIPTION		= 'Test bot command parsing with DEFAULT COMMAND PARSER (DCP) of pscmdbot'

		}
	}
	
	HANDLER = {
		param($Update)
		
		$m			= $Update.message;
		$CmdParts	= ($m.text -split ' ');
		$BotCommand = PsCmdBot_DCP_GetCommandName $m;
		
		if($CmdParts.Length -gt 1){
			$Params		= 1..($CmdParts.Length-1) | %{$CmdParts[$_]};
		} else {
			$Params = @();
		}
		
		
		switch -regex ($BotCommand){
			'listcmds|help' {
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
			
			'setopt' {
				if( $this.COMMANDS.setopt.AUTHORIZED_USERS -Contains $Update.message.from.username ){
					$OptName = $CmdParts[1];
					$OptValue = $CmdParts[2];
									
					$CurrOpt = Get-PsCmdBotOption -Name $OptName;
					
					if($CurrOpt){
						Set-PsCmdBotOption -Name $OptName -Value $OptValue;
						$ReplyText = "Mudei a option $OptName de $($CurrOpt.Value) para $OptValue"
					} else {
						$ReplyText = "Não encontrei a option que você informou: $OptName";
						
					}
				} else {
					$ReplyText = 'Você não tem autorização para isso!'
				}
			}
			
			'getopt' {
					$OptName = $CmdParts[1];
					
					$OptValues = Get-PsCmdBotOption  -Name $OptName | %{
						"$($_.key) $($_.value)"
					}
					
					$ReplyText = @(
						"Segue a lista de options:"
						$OptValues
					) -join "`r`n"
			}
			
			'botping' {
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
			
			'chatinfo' {
				$ChatInfo = $m.chat;
				
				$ReplyText = @(
					"You request a chatinfo!"
					"ChatId: $($ChatInfo.id)"
					"Type: $($ChatInfo.type)"
					"Username: $($ChatInfo.username)"
				) -Join "`r`n";
				
			}
		
			'failsim' {
				throw '/FAILSIM: FAILURE SIMULATION'
			}
			
			'envinfo' {
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
			
			
			'dcptest' {
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
								$ReplyText += "`t"+$_;
							}
						}
					}

					$ReplyText = $ReplyText -Join "`r`n";
				}


			}
		}
		
		$res = NewHandlerResult $this;
		$res.mustReply = $true;
		$res.reply.message = $ReplyText;
		
		
		return $res;
	}


}
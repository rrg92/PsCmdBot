@{
	COMMANDS = @{
		ps = @{
			Syntax		= '/ps PowershellCommand'
			DESCRIPTION = 'Allows users execute powershell commands'
		}
	}

	HANDLER				= {
							param($Update)
	
							$m = $Update.message;
	
							#Removes "/ps "
							$PsToExecute = $m.text -replace "/ps(@[^ ]+)?",'';
							
							$res = NewHandlerResult $this;
							
							#Executes powershell and get output:
							try {
								$CmdResult = powershell -Noninteractive -Command $PSToExecute;
								$Smile = Get-EmojiString 0x1F44C
								$ReplyText=@(
									"$Smile Executei o comando: $PsToExecute."
									"Resultado: "
									($CmdResult -join "`r`n")
								) -join "`r`n"
							} catch {
								$CryingEmoji = Get-EmojiString 0x1F62D -count (get-random -min 1 -max 4)
								$ReplyText=@(
										"O bot executou o comando: $PsToExecute"
										"Deu erro : $CryingEmoji"
										"$_"
									) -join "`r`n"
							}
						
							$res.reply.message = $ReplyText;
							$res.mustReply = $true;
							
							
							return $res;
			}
}
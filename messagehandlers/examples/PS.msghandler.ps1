@{
	COMMANDS = @{
		ps = @{
			Syntax		= '/ps PowershellCommand'
			DESCRIPTION = 'Allows users execute powershell commands'
		}
	}

	CONFIG = @{
		ALLOW_EXECUTION = $true;
	}

	HANDLER				= {
						param($res, $Update)

						$m = $Update.message;
						$myConfig = $this.getMyConfig();
						
						#Removes "/ps "
						$PsToExecute = $m.text -replace "/ps(@[^ ]+)?",'';
						

						#Executes powershell and get output:
						if($myConfig.ALLOW_EXECUTION){
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
						} else {
							$ReplyText = "The execution was disabled due to handler configuration!";
						}

						$res.reply.message = $ReplyText;
						$res.mustReply = $true;
			}
}
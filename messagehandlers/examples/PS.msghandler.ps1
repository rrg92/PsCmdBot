@{
	COMMANDS = @{
		ps = @{
			Syntax		= '/ps PowershellCommand'
			DESCRIPTION = 'Allows users execute powershell commands'
		}
	}
	
	AUTHORIZED_USERS 	= 'rrg92'
	
	HANDLER				= {
							param($Update)
	
							$m = $Update.message;
	
							#Removes "/ps "
							$PsToExecute = $m.text.replace("/ps ","");
							
							$res = NewHandlerResult $this;
							
							#Executes powershell and get output:
							if($this.AUTHORIZED_USERS -Contains $m.from.username){
								try {
									$CmdResult= Invoke-Expression  $PSToExecute;
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
								$Smile = Get-EmojiString 0x1F601 -count 2
								$ReplyText = "Somente o Rodrigo pode mandar comandos /ps $Smile"
							}
							
							$res.reply.message = $ReplyText;
							$res.mustReply = $true;
							
							
							return $res;
			}
}
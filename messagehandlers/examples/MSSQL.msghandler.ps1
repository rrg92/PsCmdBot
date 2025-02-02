@{
	COMMANDS			= @{
		mssql = @{
			Syntax		= '/mssql Server Database'
			DESCRIPTION = 'Allows user execute SQL in a server database'
		}
	}
	
	
	PENDING_SCRIPTS		= @{
							<#
								Server
								Database
							#>
	
						}
	
	HANDLER				= {
							param($res, $Update)
	
							$m = $Update.message;
	
							#Syntax /mssql Server Database
							#Removes "/ps "
							$Options = $m.text -split ' ';
							
							#Get options
							$Server 	= $Options[1]
							$Database 	= $Options[2]
							
							
							$res.mustReply = $true;
							
							write-verbose "Current source is: $($this.SOURCE)"
							switch($this.SOURCE){
								"REPLY_LISTENER" {
								
									#Get the data!
									$PendingEntry = $this.getListenerData($m.reply_to_message);
								
									if( !$PendingEntry ){
										throw "PSCMDBOT_MSGHANDLER_MSSQL_REPLYLISTENER_INVALIDPENDINGENTRY"
									}
									
									#Check if who reply is same who sending the command!
									if(   $m.from.username -ne $PendingEntry.Username  ){
										$res.reply.message = "Ei! Não é você que tem que dizer os scripts! Tenha mais respeito!"
										return $res;
									} 
			
									
									if($m.text) {
										#If message is just text...
										$CommandToExec = $m.text;
									} elseif ($m.document){
										#If message have a attached file...
										try {
											$TelegramFile 	= Get-TelegramFile -file_id $m.document.file_id;
											$CommandToExec	= Get-TelegramFileContent -File $TelegramFile
										} catch {
											$res.reply.message = @(
													"Não consegui abrir o arquivo que você enviou. Falha: "
													"$_"
												) -join "`r`n"
										}
									}

									if($CommandToExec){
											try {
												$cmdRes = Invoke-Expression "sqlcmd -W -U Bot -P bot -S $($PendingEntry.Server) -d $($PendingEntry.Database) -Q ""$CommandToExec"" "
												$Claps = Get-EmojiString 0x1F44F (Get-Random -Min 2 -Max 6)
												$reply = @(
													"Executei o comando que você pediu $Claps! Instância $($PendingEntry.Server), banco $($PendingEntry.Database)."
													"Resultado: "
													($cmdRes -join "`r`n")
												) -join "`r`n"
											} catch {
												$ScreamingEmoji = Get-EmojiString 0x1F628 (Get-Random -Min 1 -Max 3)
												$reply = @(
													"Executei o comando que você pediu e deu erro! $ScreamingEmoji (Server: $($PendingEntry.Server) | Database: $($PendingEntry.Database)): "
													"$_"
												) -join "`r`n"
											}
											
											$res.reply.message = $reply;
									} else {
										$Emoji = Get-EmojiString 0x1F60F
										$res.reply.message = "Não consegui identificar o comando. Vou descartar, porque não tenho tempo para esperar sua imbecilidade. $Emoji"
									}
								
									$this.unlisten( $m.reply_to_message );
								}
								
								default {
									#Executes and get output:
									if($this.AUTHORIZED_USERS -Contains $m.from.username -or $this.AUTHORIZED_USERS -Contains '*'){
										
										$PendingEntry = @{
											Database 	= $Database
											Server		= $Server
											Username	= $m.from.username
										}
										
										
										#Prepare the script that will add to list of pending scripts!
										$me = $this;
										$res.reply.scripts += {
											param($params)
											
											$me.listen( $params.SentMessage , $PendingEntry );
										}.GetNewClosure()
										
										#Prepare message!
										$DocumentEncoding = (Get-PsCmdBotOption 'DEFAULT_DOCUMENT_ENCODING').Value;
										$OkEmoji = Get-EmojiString 0x1F44D
										$res.reply.message = "Entendido $OkEmoji! Responda essa mensagem com o codigo SQL ou com o arquivo com o código (codificado em $DocumentEncoding). No Aguardo!"
									} else {
										$res.reply.message = "Ei! Você não está autorizado a usar este comando!" + (Get-EmojiString 0x1F52B 2)
									}
															

									
								}
							
							
								
							}
							

							return $res;
			}
}
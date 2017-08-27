@{
	COMMANDS = @{
		zbx = @{
			Syntax		= '/zbx'
			DESCRIPTION = 'Allows user execute zabbix predefined commands!'
		}
		

		
	}
	
	
	CONFIG = @{
			ZABBIX_CREDS = @{
				#TJ = @{URL='http://10.100.1.10';USER='t1002186';Password='STF1q2w3e4r'}
				STFCIA = @{URL='http://zabbix.stfcia.com.br/zabbix';USER='rrgomes1';Password='STFCIA@123'}
			} 
		}
		
	SUBCOMMANDS = @{
		
		# getHosts <TYPE>:STR1,STR2,STR3
		getHosts = {
			
			$Filter = $CmdParts[3];
			
			$FilterParts 	= @($Filter -Split ':')
			
			if($FilterParts.Length -eq 1){
					$FilterValues	= @($FilterParts[0] -Split ',')
					$FilterType = 'host'
			} else {
					$FilterType		= $FilterParts[0]
					$FilterValues	= @($FilterParts[1] -Split ',')
			}

			
			if(!$FilterValues){
				$res.reply.message = "Ei, você não especificou os valores dos filtros!"
			}
			
			$ZabbixCallParams = @{
				output = @('name')
			}
			
			
			
			switch($FilterType){
				"GROUP" {
					$ZabbixCallParams.add('Groups',$FilterValues)
				}
				
				"SEARCH" {
					$ZabbixCallParams.add('search',$true)
					$ZabbixCallParams.add('Name',$FilterValues)
				}
				
				default {
					$ZabbixCallParams.add('Name', $FilterValues)
				}
			}
			
			$Hosts = Get-ZabbixHost @ZabbixCallParams
			
			if($Hosts){
				$res.reply.message = @($Hosts | %{
					"[$($_.hostid)] $($_.name)"
				}) -join "`r`n"
			} else {
				$res.reply.message = "Nenhum Host encontrado para o filtro $Filter"
			}

			
			
		}
		
		# getEvents <TYPE>:STR1,STR2,STR3
		getEvents = {
			
			$Filter = $CmdParts[3];
			
			$FilterParts 	= @($Filter -Split ':')
			
			if($FilterParts.Length -eq 1){
					$FilterValues	= @($FilterParts[0] -Split ',')
					$FilterType = 'host'
			} else {
					$FilterType		= $FilterParts[0]
					$FilterValues	= @($FilterParts[1] -Split ',')
			}

			
			if(!$FilterValues){
				$res.reply.message = "Ei, você não especificou os valores dos filtros!"
			}
			
			$ZabbixCallParams = @{
				limit = 10
				selectRelatedObject = 'priority','description'
				selectHosts = @('name')
			}
			
			
			
			switch($FilterType){
				"GROUP" {
					$ZabbixCallParams.add('Groups',$FilterValues)
				}
				
				default {
					$ZabbixCallParams.add('Hosts', $FilterValues)
				}
			}
			
			$Hosts = Get-ZabbixEvent @ZabbixCallParams 
			
			if($Hosts){
				$res.reply.message = @($Hosts | %{
					"[$($_.eventid)]$($_.datetime): $($_.TriggerName)"
					"SEVERIDADE:$($_.TriggerSeverity)"
					"HOST:$($_.HostName)"
					"---"
					""
				}) -join "`r`n"
			} else {
				$res.reply.message = "Nenhum evento encontrado para o filtro $Filter"
			}

			
			
		}
		
		# getAcks EVENTID
		getAcks = {
			
			$EventID = $CmdParts[3];
			

			if(!$EventID){
				$res.reply.message = "Ei, você não especificou o ID do evento!"
			} else {
				$ZabbixCallParams = @{
					Id = $EventID
					selectRelatedObject = 'priority','description'
					selectHosts = @('name')
					selectAcknowledges = 'alias','clock','message'
				}
				
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
					$res.reply.message = "Nenhum ack neste evento!" + (Get-EmojiString 0x1f62d -count 3)
				}
			}
			
			
		}
		
		# ack EVENTID
		ack = {
			
			
			switch($this.SOURCE){
				"REPLY_LISTENER" {
					$AckData = $ReplyData.AckData;
					$Event = $AckData.Event;
					$AckMessage = $m.text;
					

					$ack = $Event | Ack-ZabbixEvent -Message $AckMessage;
					$res.reply.message = "Ack realizado com sucesso!"
				}
				
				default {
					$EventID = $CmdParts[3];
					
					
					if($EventID){
						$ZabbixCallParams = @{
							Id = $EventID
						}
						
						$Event = Get-ZabbixEvent @ZabbixCallParams 
						
						if($Event){
							$res.data = @{
								SubCommand	= $SubCommand
								Server		= $Server
								AckData = @{
									Event 		= $Event
								}
							}
							
							$res.reply.message = "Responda essa mensagem como a mensagem de ack"
							$res.reply.script = {
								param($me, $replyMessage)
								
								$me.handler.listen( $replyMessage , $me.data );
							}
							
						} else {
							$res.reply.message = "Não encontrei o evento $EventID no zabbix!"
						}
						

						
					} else {
						$res.reply.message = "Ei, você não especificou o ID do evento!"
					}
	
				}
			}
			
		

			
		}
		
		

		
		
	}

	HANDLER = {
		param($Update)
		
		$m = $Update.message;
		
		$res = NewHandlerResult $this;
		$res.mustReply = $true;
		
		switch($this.SOURCE){
			"REPLY_LISTENER" {
			
				$ReplyData = $this.getListenerData($m.reply_to_message);
				
				#Check SubCommand
				$SubCommand = $ReplyData.SubCommand;
				$Server		= $ReplyData.Server;
			
			}
			
			default {
				#Identify current command!
				#/zbx SERVER SUBCMD VALUES
				$CmdParts = ($m.text -split ' ');
				$BotCommand = $CmdParts[0];
				$Server		= $CmdParts[1];
				$SubCmd		= $CmdParts[2];
				
				$SubCommand = $this.SUBCOMMANDS[$SubCmd];
			}
		}
			
		if(!$SubCommand){
			$AvailableSubCommands = $this.SUBCOMMANDS.Keys;
			
			$res.reply.message = @(
					"Sub-comando $SubCommand não identificado!"
					"Sub-comandos possiveis: "
					$AvailableSubCommands
				) -join "`r`n"
				
				
			return $res;
		}
		
		if(-not(Get-Module power-zabbix)){
			import-module powershell\power-zabbix;
		}
		
		$Creds = $this.CONFIG.ZABBIX_CREDS[$Server];
		if(!$Creds){
			$AvaliableServers = $this.CONFIG.ZABBIX_CREDS.Keys;
			
			$res.reply.message = @(
					"Servidor não disponível: $Server"
					"Servidores disponíveis: "
					$AvaliableServers
				) -join "`r`n"
				
				
			return $res;
		}
			
		try {
			Auth-Zabbix -URL $Creds.URL -User $Creds.USER -Password $Creds.Password;
			
			. $SubCommand;
			
		} catch {
			$res.reply.message = @(
					"Falha: "
					"$_"
				) -join "`r`n"
		}

		return $res;
	}
}
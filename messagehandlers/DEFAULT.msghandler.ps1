@{
	PRIORITY = -1;
	FILTER_UPDATE = {$true}
	IS_AUTHORIZED = {$true}
	
	REPLY_MESSAGES = @{
		REPEATED_FIRST = "Não reconheço este comando!"
		REPEATED_1 = "Ei, eu já lhe disse que eu não entendo este comando!"
		REPEATED_2 = {"Você é burro ou o quê? Não entendo esse comando!" + (Get-EmojiString 0x1F629 -count (Get-Random -Min 0 -Max 3)) } 
		REPEATED_3 = "Nossa mano! Você não saber ler? EU NÃO ENTENDO ESSE COMANDO!"
		REPEATED_4 = { 
				param($M) 
				
				$UserName = $M.from.first_name,$M.from.last_name | Get-Random
				
				"Ignorando você. Atenção membros do grupo, o $UserName é um retardado e não sabe ler!"
				
			}
			
		REPEATED_MANY = "#Burro","#Retardado","#Analfabeto",'#VaiAprenderALer',(Get-EmojiString 0x1F621),(Get-EmojiString 0x1F612) 
		
		REPEATED_ALL_MANY = @(
			"Cara, na boa, você vai ficar tentando os comandos ai ou vai procurar saber o que eu posso ou não fazer?"
			"Ah nem..."
			"#ImbecilModeOn"
			 "#Burro"+(Get-EmojiString 0x1F434),"#Retardado","#Analfabeto"
			 '#VaiAprenderALer', { Get-EmojiString 0x1F621 -count (Get-Random -Min 1 -Max 3) }
			{param($M) "E o prêmio lerdo do ano vai para $($M.from.first_name)"}
		)
		
	}
	
	TRACK_COUNT = @{}
	
	HANDLER = {
		param($REs, $Update)
		
		# Other handles processed. That dont need run!
		if($res.handlers.count -gt 1){
			return;
		}
		
		$Config = PsCmdBot_CM_GetConfiguration;
		
		if($Config.GLOBAL.COMMANDS_SETTINGS.IGNORE_UNRECOGNIZED){
			if(PsCmdBot_CanLog "DEBUG"){
				PsCmdBot_Log "	Ignoring unrecognized due to configuration!" "DEBUG"
			}
			$res = NewHandlerResult $this;
			$res.mustReply = $false;
			return $res;
		}
		
		$m = $Update.message;
		$ChatTrack =$this.TRACK_COUNT[$Update.message.chat.id];
		
		#Identify current command!
		$BotCommand = ($m.text -split ' ')[0];
		
		#Gets a chat track!
		if( !$ChatTrack  ){
			$ChatTrack = @{};
			$this.TRACK_COUNT[$Update.message.chat.id] = $ChatTrack;
		}
		
		#Get user that send the message!
		$UserID = $m.from.id;
		$UserTrack = $ChatTrack[$UserID];
		
		#Now, check if current user exists in chat track.
		if (  !$UserTrack ) {
			$UserTrack = @{  CommandTrack=@{}; count=0;   }
			$ChatTrack[$UserID] = $UserTrack;
		}
		
		#Increments user total count (any command)!
		$UserTotalCount = $UserTrack.count;
		$UserTrack.count = $UserTrack.count + 1;
		
		#Now, gets the count for current command!
		$CurrentCommandTrack = $UserTrack.CommandTrack[$BotCommand];
		
		if(!$CurrentCommandTrack){
			$CurrentCommandTrack = @{ count=0 };
			$UserTrack.CommandTrack[$BotCommand] = $CurrentCommandTrack;
		}
		
		#Increments usage counter!
		$UserCount = $CurrentCommandTrack.count;
		$CurrentCommandTrack.count = $CurrentCommandTrack.count + 1;
		
		#Choose right message!
		$ReplyMsg=$null;
		if($UserCount -eq 0){
			$ReplyMsg = $this.REPLY_MESSAGES.REPEATED_FIRST | Get-Random; 
		} elseif ($UserCount -ge 5) {
			$ReplyMsg = $this.REPLY_MESSAGES.REPEATED_MANY | Get-Random; 
		} else {
			$MsgName = "REPEATED_"+$UserCount
			$ReplyMsg = $this.REPLY_MESSAGES[$MsgName] | Get-Random; 
		}
		
		#We get a message based on total if many reached and random gets 1
		#or
		#We get a message for based on total, in case user type many different commands...
		if( ($UserTotalCount -ge 5  -and  (Get-Random -Min 0 -Max 1)) -or ($UserCount -eq 0 -and $UserTotalCount -ge 3) ){
			$ReplyMsg = $this.REPLY_MESSAGES.REPEATED_ALL_MANY | Get-Random; 
		}
		
		[string]$ReplyText = "";
		if($ReplyMsg -is [scriptblock]){
			$ReplyText = & $ReplyMsg $m;
		} else {
			$ReplyText = $ReplyMsg.toString();
		}
		
		$res.mustReply = $true;
		$res.reply.message = $ReplyText;
	}
}
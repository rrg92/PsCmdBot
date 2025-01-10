# Hellow World handler!

@{
	ON_START = {
		
		$ToolsDir = $PsScriptRoot
		
		Get-AiTools -global | Remove-AiTool 
		Add-AiTool -Global "$ToolsDir/tools.ps1"
		
		
		
	}
	
	IS_AUTHORIZED = {
		return $true;
	}
	
	FILTER_UPDATE = {
		param($update)
		
		return $true;
	}
	
	HANDLER = {
		param($res, $update)
		
		$from = $update.message.from;
		$UserJsonInfo = $from | ConvertTo-Json -Compress;
		
		$SystemPrompt = "
			Users are chatting with you from telegram. Answer users in their language
			User Info (JSON):
				$UserJsonInfo
				
			Use provided tools to help answer user questions.
		"
		
		
		$ChatId = $update.message.chat.id;
		$ChatName = "Telegram:$ChatId"
		
		$Chat = New-PowershaiChat $ChatName -IfNotExists
		Set-PowershaiActiveChat $ChatName;
		
		Set-PowershaiChatParameter MaxContextSize 128000
		
		write-host "Invoking completion...";
		$Control = @{
			lines = @();
			LastAction = $null;
		}
		
		Send-TelegramChatAction -ChatId $ChatId -Action typing;
		$Control.LastAction = (Get-Date);
		
		ai -Lines -prompt @(
			"s: $SystemPrompt"
			$update.message.text
		) | %{
			$Control.lines += $_;
			$Elapsed = (Get-Date) - $Control.LastAction;
			
			if(!$Elapsed.totalSeconds -ge 5){
				$Control.LastAction = (Get-Date);
				Send-TelegramChatAction -ChatId $ChatId -Action typing;
			}
			
			
		}
		
		
		
		#$resp = Get-AiChat -ContentOnly $prompt
		
		$res.mustReply = $true;
		$res.reply.message = @($Control.lines) -Join "`n";
	}
	
}
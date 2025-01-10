@{
	GLOBAL = @{
		SECURITY = @{
			#Authroize chats
			#format: '@user','-group'
			#@username,-12345 
			#to get id, start bot, and send command /chatinfo to get ids! (add it to group before, if is group chat)
			USERHANDLERS_CHATS = @()
		}
	}
	
	
	# per habdle config 
	HANDLERS = @{
		
		hellow = @{
			COMMANDS = @{
				'helloworld' = @{
					AUTHORIZED_USERS = '*'
				}
			}
		}
		
		# One subkey for each handler name in msghandlers/<HandlerName>.msghandler.ps1
		# Replance <HandlerName>'
		'<HandlerName>' = @{
			# Commands keys define commands options!
			COMMANDS = @{
				# Replace <CommandName> by command name.
				'<CommandName>' = @{
					AUTHORIZED_USERS = @() #@user, -12343 (Group);
				}
			}
		}
		

		
	}
}
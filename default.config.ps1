<# 

Default configuration file.
Use this file for check for all possible configurations
Note for handlers writes: Places configurations of your handlers in a separte key in format, "HANDLERNAME"  

#>

@{
	
	#This contains global options for the bot!
	GLOBAL = @{
		
		#Options that can be changed at runtime!
		RUNTIME_OPTIONS = @{
			AUTHORIZED_USERS = @()
			OPTIONS = @{
				DEFAULT_DOCUMENT_ENCODING = "UTF8"
			}
		}
		
		#Controls unandhled expections!
		FAILURES = @{
			#Indicates how many unandled exceptions bot can accept before exit!
			MAX_FAILURES = 2
			
			#Chat id to which send message if bot will exit!
			NOTIFICATION_CHATID = $null
		}
		
		#The default logging level of messages!
		LOGGING = @{
			#The log level!
			LEVEL 	= "DETAILED";
			
			#The log file. You can specify relative path to the working directory.
			#You also can specify a absolute path
			FILE	= 'log.log';
		}

		
		#Control how many updates fetch from telegram!
		UPDATE_FETCH_SIZE = 1;
		
		#Indicates if bot must log telegram messages objects received.
		MESSAGES = @{
			#indicates that message must be logged.
			#By default, message are not logged or are logged when log level is VERBOSE.
			LOG = $false
			
			#In addition to log messages to default log file, logs to a custom file!
			#This will be used only when LOG option is set to true.
			#If logging of message if made due to VERBOSE logging only, this file is not used.
			LOG_FILE = $null;
			
		}
		
		
		#Options to commands system behavior
		COMMANDS_SETTINGS = @{
			#Ignore unrecognized commands (not repy will be send)
			#This is useful if many bots are in a group and you want
			#By default, bot will send a reply!
			IGNORE_UNRECOGNIZED = $false
		}


		
	}

	#Settings for specific commands
	#Put the command name and the settings!
	#Any comand can have a "AUTHORIZED_USERS" keys. 
	COMMANDS = @{


	
		'botping' = @{
			AUTHORIZED_USERS = '*';
		}
	
		listcmds = @{
			AUTHORIZED_USERS = '*';
		}
		
		#Settings for ps command (commad separated)
		'chatinfo' = @{
			AUTHORIZED_USERS = '*';
		}
	
		#Settings for ps command (commad separated)
		'ps' = @{
			AUTHORIZED_USERS = @()
		}
		

		
	}
	

	#For HANDLERS 
	HANDLERS = @{
		HANDLE_NAME = @{
			#Sets a priority of the handler!
			PRIORITY = 0
		}
	}
	

	#Configuration about users!
	USERS = @{
		
		
		<# LAYOUT
				#Commands that user can run.
				AUTHORIZED_COMMANDS = @();
				
				#Commands that user cannot run.
				DENIED_COMMANDS = @();
			}
		#>
	}
	
	
}
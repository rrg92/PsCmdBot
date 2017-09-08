<# 
	Default configuration file.
	Use this file for check for all possible configurations
	Note for handlers writes: Places configurations of your handlers in a separte key in format, "HANDLERNAME"  
#>

@{
	
	#This contains global options for the bot!
	GLOBAL = @{

		#The bot token to be used! If not bot token is passed in -Token of Start-CmdBot cmdlet, it will try use this.
		BOT_TOKEN = $null;
		
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
			#Can be any valid chat_id acceptable by telegram api (numbers or chanell @channelname)
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
		
		
		#This key define behavior of the engine of PSCMdBot relative to the commands.
		#Specific commands functionalities are place in the handlers specific configuration.
		COMMANDS_SETTINGS = @{
			#Ignore unrecognized commands (not repy will be send)
			#This is useful if many bots are in a group and you want
			#By default, bot will send a reply!
			IGNORE_UNRECOGNIZED = $false
		}

		#Security options!
		SECURITY = @{
			#Controls chat_id where the bot can process thirdy party handlers!
			USERHANDLERS_CHATS = $null

			#This must be used for debugging purposes only. Dont enable in production.
			#if enabled, the chat securitu check will be disabled!
			DISABLE_CHATID_CHECK = $false

			#Controls which chats bot can process internals handlers!
			SYSTEMHANDLERS_CHATS = '*'
		}


		
	}


	#This is reserverd configuration for each handler.
	#Handler writes will define own configuration options and read this key from user config file.
	#Check handler documentation for appropriate help about options.
	#Bellow, some options used by engine
	HANDLERS = @{
		#AUXCMDS is internal handler that provides basic commands for the bot.
		#Is is auxiliary only, and shipped with PsCmdBot.
		#Also, it is a example of options!
		AUXCMDS = @{
			#Priority of the handlers.
			#The higher value, most priority the handler will have
			#If two handlers can handle same command name, this priority will determine most priori.
			#If two or more have equal priority, the choosed handler is random.
			PRIORITY = 0


			#This key controls the commands of the handler! 
			#Each subkey is a command name!
			#The AUTHORIZED_KEYS is part of DEFAULT AUTHORIZATION CHECK ALGORORITHM. Check doc/DEFAULTAUTHORIZATIONCHECK.md for more details.
			#A special key, '*', can be defined, meaning default option for every command in this handler!
			COMMANDS = @{
				'*' = @{
					AUTHORIZED_USERS = $null
				}

				botping = @{
					AUTHORIZED_USERS = '*';
				}
			
				listcmds = @{
					AUTHORIZED_USERS = '*';
				}
				
				chatinfo = @{
					AUTHORIZED_USERS = '*';
				}

				dcptest = @{
					AUTHORIZED_USERS = '*';
				}
			}


		}

	}
	
	
}
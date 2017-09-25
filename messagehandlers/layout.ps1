#Message Handler layout
#Contains all possible properties  and methods that a handler can definer!
#Uses this as a template to writing new handlers

#Engine will load this file and create a object based on this.
#The object will be used to interate with rou handler. We call this object as 'handler object'
#The object is created and is added to a list of available handlers in memory. This is made whenever engine statrs, only this time.
#Thats its, any changes in handler layout, requires a engine restart.

#This is a simple hashtable.
#Keys that are scriptblock are turn into the a method of the handler object that represents your handler.
#All other keys are turn into a propertu of the handler.
#Yes, inside your methods,  you can use $this special variable to access properties.

#The Engine expects some default and can apply default values to it if  you not define.
#Also, the engine will create some more properties when loading your handler.
#Check layout bellow to leanr all keyus expected and how your can define it, if necessary.

#You can use your own properties. We recommends you put your handler personal data in property called PRIVATE
#Engine reservers this word only for your use.


@{

	#The default priority of this handler.
	#If two or more handlers can handler same command, then the egnien will choose the handler with the bigger priority value.
	#This value can be overwritten at configuration level by user.
	PRIORITY = 0

	#This define all supported commands by your handler.
	#Each key is a command name.
	#It not mandatory, but in most case, you will define, at least, one command.
	COMMANDS = @{
	
		#The command name must following telegram commands syntax.
		#Dont specify the start slash (/) in name because ii is implicity.
		CommandName1 = @{
			#In this, define the syntax of your command. This is showed to the user when promped to help.
			SYNTAX = '/CommandName Example1 Example2'
			
			#Write a description that users will see when asking for help.
			DESCRIPTION = 'Command description'
		
			#Array of alias names
			#A alias is a antoher name that can be used to invoke command.
			#note that you cannot define same alias in different commands.
			ALIAS = @()
		}
		
		
		CommandName2 = @{}
		CommandName3 = @{}
		#...

	}
	
	#Define your owns properties here.
	#Its is just a best pratice because engine nevers will use this value to anything.
	#It is reserverd for you :)
	PRIVATE = @{}

	#This is the method that handler will call to handler runs.
	#After choosing this handler, the engine will call this method. That is, your handler take control over the bot.
	#It will receive the Message object that triggered at first parameter.
	#This is mandatory. This is heart, body and brain of your handler.
	HANDLER = {
		param(
			#The telegram Message object of the message received.
			$Message
		)
	}
	
	#This will be called by engine when it needs check if current message contains a supported command.
	#It must return true if yes, or false if not.
	#This is not mandatory. You must hide it it you wants default, or set it to $null.
	#The default behavior is get list of commands from
	CHECK_COMMAND = {
		param($message)
	}
	
	#This is used to check authorization of user sending message
	#When engine wants check if user has authorization to execute the command.
	#This is not mandatory. You must hide it it you wants default, or set it to $null.
	#Check the doc/DEFAULTAUTHORIZATIONCHECK.md file to more info about default auhtorization algorithm.
	IS_AUTHORIZED = {
		param($message)
	}
	
	<# Event methods

		The events methods start with "ON_" in name.
		This are script that are executed when some event occurs.
		This scriptblocks not are converted into a method of handler. This are executed as is.

		The engine will passes a  hashtable as first parameter of this script:

			@{
				Handler = HandlerObject
				Params = @{}

			}

		The "Handler" is the object that represents the handler!
		The PArams will contains some parameters depending of event. Check ON_ descriptiion to more information.

	#>

	#Configuration update subscriber.
	#This will be called wheenver some configurastions changes.
	#A configuration object, just with change keys, will be passed.
	#Params: 
	#	ChangedConfig - A hashtable containing the configuratons items that was changed!
	ON_CONFIG_CHANGE = {
	
	}

	#Actions to be executed when engine is about to enter on main loop (inside Start-Cmdbot cmdlet)
	#Params: none.
	ON_START = {

	}
	
	
	#The handler default config
	#This is default configuration for the handler!
	#You can setup options here that will be set when handles load.
	#This options will be set on CURRENT_CONFIG.HANDLERS[HANDLER_NAME]
	CONFIG = @{

	}


	
	
	#RUNTIME PROPERTIES AND MEHTODS #################################################
	#The following properties are runtime properties.
	#It always will be generated by the engine based on internals values or values of another parameters.
	#You never must include this, and its defined here just for documentation!
	#But, you can use it in your scripts because it is well doducmented.
	
	
	#The handler name
	#Then name of handler is name of file where handler was defined without ".msghandler.ps1" extension.
	NAME = $null
	

	
	#Indicates the source of call to handler.
	#Dou you uess that handler is invoked only when a command define in COMMANDS is sent by telegram user?
	#Dont! Engine is most powerfully.
	#Some events can happen, in way the engine will invoke handler to treat it.
	#For example, REPLY_LISTENER source indicates that a message was a reply to a prvious listened message.
	#This property will indicates the source of message, and allows your code treat each situation according.
	#Possible values are:
	#	COMMAND: Indicates the message is a normal command sent.
	#	REPLY_LISTENER: Indicates that message is a reply to a message in reply listener.
	#	
	#
	SOURCE = 'COMMAND','REPLY_LISTENER'
	
	#Array with names of supported commands.
	#This will be generated from commands names in COMMANDS property plus the defined alias.
	SupportedCommandNames = @()
	
	#A mapping of aliases
	#Each key is a alias name and the key is the command name of the alias.
	#Engine uses this to fast convert a alias name to corresponding command.
	Aliases = @{}
	
	#Receives a string and transalte it to a command name.
	#This is useful when engine dont know if a command is alias or real command.
	#It calls this method to get the command associated with given alias.
	#If the given string is not alias, then, it returns the passed string. It no check for command existence (this is work of CHECK_COMMAND).
	getRealCommandName = {
		param($CommandName)
	}
	
	#Adds a reply listener to a telegram message.
	#Must pass the telegram message object
	#Can pass a custom data to listener, in order to recovery access a previous data when created the listener.
	listen = {param($Message,$data)}
	
	#Get a a data associated with a messag listener.
	#Seem Message Listeners on doc/MESSAGEHANDLERS.md
	#Must inform a telegram message object
	getListenerData = {param($Message)}
	
	#Removes a reply listener of a message.
	#Must pass the telegra message object
	unlisten = {param($Message)}
	
	
	#Returns the current effective configuration of the handler!
	getMyConfig = {}

	
}





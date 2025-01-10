<#
	This is sample message habdler, to youunderstand how PsCmdBot works.
	You dont define change anything!
	Just start bot and it works!
	
	When the handler is loaded, the PsCmdBot will transform tha tinto a object.
	ScriptBlock keys turn into methods. Other are properties.
	So, inside method, you can use $this to refer own instance.
	
	The unique mandatory method is HANDLER.
	It is sample reply to user message with current date and a string!
	Recommend you start your bot without chaning anything, try start conversation and check if works.
	After that, read comments bellow, change values and see how that change your bot!
	
	AFter you changed a lot, then, you master the basic.    
	To advanced scenarios, checks messagehandlers/examples in module source.
	Also, messagehandlers/layout.ps1 is a good source of information.
	
	You can remove all comments if you guess that this template is dirty!
#>

@{
	
	#This is method called by PSCmdBot when a messages arrives to your handler!
	#The $Res containing the reply (or response) message.
	#The $update containg the source telegram update that triggered.
	#IF other habndlers processed before that, you will see in $res.handlers , that is array with all other prev habndlers (0 oldest, -1/last is this).
	#note that if other handlers process after that, it can override your reply.
	#You dont have control over that. The Admin os PsCmdBot can chain many handlers as him want.
	#The maximum you can do, is doc well to explain how you handles must works!
	HANDLER = {
		param($res, $update)
		
		$res.mustReply = $true;
		$res.reply.message = "Hellow: $(Get-Date)";
		
		
		#Optionally, you can schedule scripts to ran after PsCmdBot sent the reply to user!
		#Your script will receive $params variable.
		#	SentMessage is message sent to user 
		#	CurrentUpdate is the current update being processed
		# 	ReplyMessage is the same as $res 
		# You can use closures to acesss variables, liek current handler!
			
			#$me = $this 
			#$res.reply.scripts += {
			#	param($params)
			#	
			#	$Handler = $Params.handler;
			#	$SentMessage = $params.SentMessage
			#	$me.listen( $SentMessage , @{ test="somedata" } );
			#}.GetNewClosure()
		
			# The # THe .listen method allows makes PsCmdBot listen replies to user message sent.
			# It is useful to force PsCmdBot invoke the handler when a message you sent is being quoted (repluy explicit) by user. 
			# Whe PsCmdBot sent relpied message back to you due litening, $this.SOURCE will be REPLY_LISTENER 
			# You can use $this.getListenerData($update.reply_to_message) to get data pssed in second param of listen method.
		
	}
	
	#PsCmdBot will invoke FILTER_UPDATE method to detemrine if hable can process that command!
	#PsCmdBot provide a defualt check, that parse message as DCP and check if command is in list of COMMANDS properties of handler.
	#But, you want write you own custom logic to check, just uncomment this method and write. Return true if thi handle must handle message!
	#The message parameter is a update message that comes from telegram!
	#The command is the comamnd anem parsed by dcp, if message is in dcp format!
	#	DCP* = Default Command Parse, is a simple syntax provided by PsCmdBot, that parse "command messages"
	#		A command message is a user message text message sent in format /CommandName CommandArgs CommandParam=Args 
	
		#FILTER_UPDATE = {
		#	param($update, $command)
		#	
		#	
		#}
	
	#PsCmdBot has two mechanism to control who can chat.
	#First is a global security: GLOBAL.SECURITY.USERHANDLERS_CHATS -> This settings controls which chats can invoke user habdlers (non system handlers).
	#	It is a basic checks based on username, forcing admins explicit authorize chats, independent of habndles.
	#	This is unique mechanism system wide (valid for all pscmdbot chats).
	#
	#Next mechanism is delegated to each handler.
	#	After validate if chat is authorized, each PsCmdBot allows each handler take a chance to validate acces using your own rules.
	#	This is implemented by that method: IS_AUTHORIZED
	#	If it not provided, the PSCmdBot default behavior is check by using command name!
	#	If user send a message in DCP alid format, the default IS_AUTHORIZED method, is validate if user has explicit authorization looking into
	#		UserConfiguration.Handlers[HandleName].Commands[CommandName]
	#	This means if you write custom FILTER_UPDATE (that accept non commands messages), then, you also writte a custom IS_AUTHORIZED method, because no commands is available to check. If do, all messages with no DCP associated, will be deinied!
	# 	

	
		#IS_AUTHORIZED = {
		#	param($update)
		#}
	
	# Custom configuraitons defined to that handler!
	# user can override in user confniguration file!
	# values here are defaults!
	# you can access effective values in scritps using $this.GetMyConfig()
		#CONFIG = @{}
	
	#Called when loading handler!
	#Opportunity to load modules, initializations, etc.
	
		#ON_START = {}
	
	#This is a generic slot to define anyone you want!
	#Nothing in that is changed by user or by PsCmdbot engine!
	#It is entire just for you!
	#Access with $this.PRIVATE
	
		#PRIVATE = @{}
	

	
}
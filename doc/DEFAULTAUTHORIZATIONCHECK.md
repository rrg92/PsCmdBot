#About Default algorithm to check authorization

Whenver a command is received, the engine wll check if user that sends it have permissions to execute it.
The IS_AUTHORIZED method of a message handler is called to check this.

The engine supply a default algorithm. It is used when the definiton of message handler not include this method.
If a message handler contains a custom algorithm, you must  check the documentation of the handler!

This doc talks about the default one!

#Basic information
	
The default algorithm will check if user sending message is on some keys in the configuration.
The possible configurations that controls permissions is:

	
	- The HANDLERS/<CommandName>/AUTHORIZED_USER Key
		This is a array contains each username that can run a command.
		
	- The HANDLERS/<CommandName>/DENIED_USERS Key
		This is a array tht contains user that cannot run the commnad.
		
## Configuration priority

Because same user can be granted or denied to a same command in different levels, there are a need to establish a priority to resolve any conflics.
The list bellow details configurations priorities. The high priority override lower. 
The priorities as assigned in order that appears (first is highgest priori):

	HANDLERS/<CommandName>/DENIED_USERS
	HANDLERS/<CommandName>/AUTHORIZED_USERS

		


The algorithm will load all keys and values that apply to current user and command.
If a user has no explcity AUTHORIZED on comman, then it is denied. Same if it contains a explicity deny.
Uses must have explcity AUTHORIZED and none DENY to be granted to run command!




Note that, the term "authorization" means, that handler can be invoked.
If your handler implements additional authorization mechanism, it must be approved on it also.
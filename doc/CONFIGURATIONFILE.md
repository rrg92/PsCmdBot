# About configuration file

The configuration file specify a lot options that module cmdlets and handlers can support.
It a simple file that return a hashtable with the options and your values.

All possible configuratons, your default values and your descriptions, are documented on default configuration file.

Users can specify configurations files on working directory.
Check WORKINGDIRECTORY.md for more information about working directory.

## The default configuration file

The [default configuration file](/default.config.ps1) define all possible options, the documentation of them.
The author os message handlers, must place default configuration on it and document appropriately using comments.

The default configuration file options is used when no user configuration is specified.

## The working directory configuration file

The working directory can contains a configuration file.
This file must be named config.ps1
You can specify just options that you want change.


## The configuration file structure

The configuration file is just a key-pair hashtable like this:

@{
	CONFIG1 = VALUE
	
	CONFIG2 = @{
		CONFIG2_1 = value
		CONFIG2_2 = @{
		
			}
	}
}

You can specify nested hashtables for options that accept a hashtable as value.
Inside of it, you can specify just sub-options that you can change.

The VALUE is any valid powershell type, like strings, number, scriptblocks, another hahstales, etc.


## Note to handler writers

If you plans write a  message handler, read notes in this section.
This module will load default configuration file options, and working directory configuration file, if any.
The effective configuration is stored in memory. The effective configuraation file is a merge of two files.

For configurations defined in working directory, this will be used.

In handlers, you must use PsCmdBot_CM_GetConfiguration to return the effective configuration file.
Dont access configurations files directly to avoid errors. Always use PSCmdBot_GetConfiguration to return hashtable with the effective configurations.

Note that, because this architecture, you always must define the configurations supported by your msghandler.

### Configurations patterns

The configuration manager is component of pscmdbot responsible for pasrsing configurations.
The configuration manager define some predefined keys and if you plan write a message handler, is is very important.
Predefined keys is:

* GLOBAL
	Contains configuration data to general setup of pscmdbot.
	Msg handlers dont have define nothing here. Just PsCMdBot authors can determine is subkeys.
	
* COMMANDS
	Contains the configurations per possible command.
	Each subkey is a command name.
	You can acess directly this key via PsCmdBot_CM_GetConfiguration
	
* AUTHORIZED_USERS
	Every command in COMMANDS keys can have this key.
	By default, is the default authorization check is used, the engine uses this key to check if user that sends message have authorization to execute a command.
	Users can specify a  array of users.
	A value of '*' means any user (Must present alone in array).

	You can maintain this pattern for you own authorization mechanism.
	FOr more information about default authorization check, see MESSAGEHANDLERS.md















#About Working Directory

The working directory is a directory that cmdlets in this module will search for user customizations.
This customizations include configurations files, additional message handlers,  etc.

Some cmdlets can accept a parameter to specify a working directory.
You also can set the default working directory using Set-PsCmdBotWorkingDirectory.

Using a separate working directory than module directory, allows any customizations be independent of module root.
For example, when upgrading the module version, just module directory needs to be updated.

Backup your working directory content in order to avoid problems.


## The Working Directory structure

The working directory can contains follwoing elements.
If this elements not exists, then module will use default ones.

	- DIRECTORY: msghandlers
		Contains the additional messages handlers files.
		Check MSGHANDLERS.md in doc to more help.
		
	- FILE: config.ps1
		The configuration file.
		This file can contain many options.
		The default configuration file, is located under module root, config.default.ps1
		All configurations defined in config.ps1 on working directory, overwrites the default config.ps1
		Check CONFIGURATIONFILE.md to more information about configuration file.
		
	- DIRECTORY: modules
		Can contains modules used by msg handlers.
		Writes of message handlers  can use PSCmdBot_ImportModule to import a module here.
		
	- DIRECTORY: storage
		This is directory used by storage services of the module.
		Msg Handlers can use a service provided by module called storage servides.
		This service allows modules persits data. Check STORAGESERVICES.md for more information.
		
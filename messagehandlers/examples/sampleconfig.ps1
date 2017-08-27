@{
		#Settings for mssql commands
		mssql = @{
			#Specify users that can execute this (comma separated)
			AUTHORIZED_USERS = @()
		}
		
		#Configurations for zbx commands
		zbx = @{
			
			#Specify users that can execute this command
			AUTHORIZED_USERS = '*'
			
			#List of zabbix servers and credentials!
			#Specify default
			ZABBIX_SERVERS = @{
				#A entry for each servername.
				#The name specified here must be used in command 
				#For example: /zbx MyExampleServer
				MyExampleServer = @{
					#The URL to zabbix server
					URL 	= 'http://Server'
					USER	= 'LoginName'
					PASS	= 'Password'
				}
			}
			
			#The name o the default zabbix server to connect!
			DEFAULT_SERVER = 'MyExampleServer'
			
			
			#Specify configurations for each subcommand!
			SUBCOMMANDS = @{
				#Specify each subcommand name. The valid keys are:
				#Example:
				SubCommandExample = @{
					#Each username that can run this.
					AUTHORIZED_USERS = @()
				}
				
			}
			
			
		}
		
}
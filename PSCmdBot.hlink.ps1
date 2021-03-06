#Módulo para o powershell!
$ErrorActionPreference= "Stop";

#Global useful vars...
$ModuleRoot 			= (Split-Path -Parent $MyInvocation.MyCommand.Definition );
$MessageHandlersScripts	= "$ModuleRoot\messagehandlers\*.msghandler.ps1"

######################### Auxiliary	
	Function CheckAssembly {
		param($Name)
		
		if($Global:PowerZabbix_Loaded){
			return $true;
		}
		
		if( [appdomain]::currentdomain.getassemblies() | ? {$_ -match $Name}){
			$Global:PowerZabbix_Loaded = $true
			return $true;
		} else {
			return $false
		}
	}

	Function LoadJsonEngine {

		$Engine = "System.Web.Extensions"

		if(!(CheckAssembly $Engine)){
			try {
				Add-Type -Assembly  $Engine
				$Global:PowerZabbix_Loaded = $true;
			} catch {
				throw "ERROR_LOADIING_WEB_EXTENSIONS: $_";
			}
		}

	}

	#Troca caracteres não-unicode por um \u + codigo!
	#Solucao adapatada da resposta do Douglas em: http://stackoverflow.com/a/25349901/4100116
	Function EscapeNonUnicodeJson {
		param([string]$Json)
		
		$Replacer = {
			param($m)
			
			return [string]::format('\u{0:x4}', [int]$m.Value[0] )
		}
		
		$RegEx = [regex]'[^\x00-\x7F]';
		write-verbose "$($MyInvocation.InvocationName):  Original Json: $Json";
		$ReplacedJSon = $RegEx.replace( $Json, $Replacer)
		write-verbose "$($MyInvocation.InvocationName):  NonUnicode Json: $ReplacedJson";
		return $ReplacedJSon;
	}

	#Converts objets to JSON and vice versa,
	Function ConvertToJson($o) {
		LoadJsonEngine

		$jo=new-object system.web.script.serialization.javascriptSerializer
		$jo.maxJsonLength=[int32]::maxvalue;
		return EscapeNonUnicodeJson ($jo.Serialize($o))
	}

	Function ConvertFromJson([string]$json) {
		LoadJsonEngine
		$jo=new-object system.web.script.serialization.javascriptSerializer
		$jo.maxJsonLength=[int32]::maxvalue;
		return $jo.DeserializeObject($json)
	}

	#Get a emoji string
	Function Get-EmojiString {
		param(
			$emoji
			,$count = 1
		)
		
		if($emoji -is [int]){
			return [string]( [char]::ConvertFromUtf32($emoji) ) * $count;
		}
		
	}
	

	#Merges two hashtables
	#It assumes that HashTable1 have all possible keys and propeties!
	#If exists same key on HashTable2, the value in 2 is used.
	Function PSCmdBot_MergeHashTables {
		param($HashTable1, $HashTable2)
		
		$Merged = $HashTable2.psobject.copy();
		
		#For each key in 1...
		$HashTable1.GetEnumerator() | %{
			$CurrentKey1 	= $_.Key;
			$CurrentValue1 	= $_.Value;
			$EffectiveValue = $null
			
			#If the key dont exists on 2, then gets the of one.
			if(!$Merged.Contains($CurrentKey1)){
				$Merged[$CurrentKey1] = $CurrentValue1;
				return; #Go to next...
			}
			
			#At this point, means the value exists on 2...
			$CurrentValue2 = $Merged[$CurrentKey1];
			
			#If 1 and 2 values are a hash, we recursivelly calls this functions to evaluate your keys...
			if(  $CurrentValue1 -is [hashtable] -and $CurrentValue2 -is [hashtable]  ){
				$Merged[$CurrentKey1] = PSCmdBot_MergeHashTables -HashTable1  $CurrentValue1 -HashTable2 $CurrentValue2;
			}
		}
		
		
		return $Merged;
	}


	#Returns the difference between two hashtables.
	#It check just for keys in Table1 thare are updated in Table2.
	Function PsCmdBot_HashDiff {
		param($Table1, $Table2)
		
		$Diff = @{};
		
		if(!$Table1){
			$Table1 = @{}
		}
		
		if(!$Table2){
			$Table2 = @{}
		}
		
		@($Table1.Keys) | %{
			$CurrKey = $_;
			$CurrValue1 = $Table1[$CurrKey];
			
			#Verifica se a key existe na table2
			if($Table2.Contains($CurrKey)){
				$CurrValue2 = $Table2[$CurrKey];
			} else {
				return;
			}
			
			
			#If ambos são hashtable, retorna so a diferenca..(assume que deveriam ter as mesmas)
			if($CurrValue1 -is [hashtable] -and $CurrValue2 -is [hashtable]){
				$HashDiff = PsCmdBot_HashDiff $CurrValue1 $CurrValue2;
				if($HashDiff.count){
					$Diff.add($CurrKey, $HashDiff);
				}
			} else{
				#TODO: THE NULL ARRAY PROBLEM
				if($CurrValue1-ne $CurrValue2){
					$Diff.add($CurrKey, $CurrValue2);
				}
			}
			
		}
		
		return $Diff;
	}	
	
	
	#Convert a PsCustomOject to hashtable!!!
	Function PSCmdBot_Object2HashString {
		param($Objects, [switch]$Expand = $false, [switch]$PureHashTables = $false, $MaxDepths = 100, $CurrDepth = 0, $Processed = @(), $ExcludeProp = @())

		$ALLObjects = @()
		
		
		if($CurrDepth -gt $MaxDepths){
			return "MAX_DEPTHS_REACHED";
		}
		
		foreach($object in $Objects){
			$PropsString = @()
			
			if($Processed | ? { $_.Equals($object) }){
				return "***";
			}
			
			$Processed += $Object;
			
			$IsPrimitive = $false;
			
			if($object){
				$type = $object.getType();
				
				if($type.FullName -like "*[[][]]"){
					$ALLObjects += "$($type.FullName):$($object.length)";
					continue;
				}
				
				if($Type.IsPrimitive -or [decimal],[string],[datetime] -contains $type  ){
					$IsPrimitive = $true;
				}
				
				if($IsPrimitive){
					$ALLObjects += $object.toString();
					continue;
				}

				
			
			}
			

			#if users wants expand and treat hashtable as a object, then convert it to a property of a object...
			if($object -is [hashtable] -and $Expand -and !$PureHashTables){
				$object = (New-Object PSObject -Prop $Object);
				$Processed += $Object;
			}
			
			foreach($Prop in $Object.psobject.properties) { 
				
				if($ExcludeProp -Contains $Prop.Name){
					continue;
				}
				
				$PropValue = $Prop.Value;
				
				if( ($PropValue -is [psobject] -or ($PropValue -is [hashtable] -and !$PureHashTables)) -and $Expand){
					
					
					if($Processed | ? { $_.Equals($PropValue) }){
						return "***";
					}
					
					$Params = @{Object=$PropValue;Expand=$Expand;PureHashTables=$PureHashTables;CurrDepth=$CurrDepth+1;MaxDepths=$MaxDepths; Processed = $Processed}
					$PropValue  = PSCmdBot_Object2HashString @Params;
				} else {
					if($PropValue){
						$type = $PropValue.getType();
						
						if($type.FullName -like "*[[][]]"){
							$PropValue = "$($type.FullName):$($PropValue.length)";
						} else {
							$PropValue = $PropValue.toString()
						}
						
					}
				}
				
				$PropsString	 += "$($Prop.Name)=$($PropValue)";
			}
			
			$ALLObjects += "@{"+($PropsString -join ";")+"}"
		}
		


		return ($ALLObjects -join "`r`n");
	}

	
#Make calls to a zabbix server url api.
	Function CallTelegramURL([object]$data = $null,$url = $null,$method = "POST", $contentType = "application/json"){
		$ErrorActionPreference="Stop";
		
		write-verbose "$($MyInvocation.InvocationName):  URL param is: $Url";
		
		
		try {
			if(!$data){
				$data = "";
			}
		
			if($data -is [hashtable]){
				write-verbose "Converting input object to json string..."
				$data = ConvertToJson $data;
			}
			
			write-verbose "$($MyInvocation.InvocationName):  json that will be send is: $data"
			
			write-verbose "Usando URL: $URL"
		
			write-verbose "$($MyInvocation.InvocationName):  Creating WebRequest method... Url: $url. Method: $Method ContentType: $ContentType";
			$Web = [System.Net.WebRequest]::Create($url);
			$Web.Method = $method;
			$Web.ContentType = $contentType
			
			#Determina a quantidade de bytes...
			[Byte[]]$bytes = [byte[]][char[]]$data;
			
			#Escrevendo os dados
			$Web.ContentLength = $bytes.Length;
			write-verbose "$($MyInvocation.InvocationName):  Bytes lengths: $($Web.ContentLength)"
			
			
			write-verbose "$($MyInvocation.InvocationName):  Getting request stream...."
			$RequestStream = $Web.GetRequestStream();
			
			
			try {
				write-verbose "$($MyInvocation.InvocationName):  Writing bytes to the request stream...";
				$RequestStream.Write($bytes, 0, $bytes.length);
			} finally {
				write-verbose "$($MyInvocation.InvocationName):  Disposing the request stream!"
				$RequestStream.Dispose() #This must be called after writing!
			}
			
			
			
			write-verbose "$($MyInvocation.InvocationName):  Making http request... Waiting for the response..."
			$HttpResp = $Web.GetResponse();
			
			
			
			$responseString  = $null;
			
			if($HttpResp){
				write-verbose "$($MyInvocation.InvocationName):  charset: $($HttpResp.CharacterSet) encoding: $($HttpResp.ContentEncoding). ContentType: $($HttpResp.ContentType)"
				write-verbose "$($MyInvocation.InvocationName):  Getting response stream..."
				$ResponseStream  = $HttpResp.GetResponseStream();
				
				write-verbose "$($MyInvocation.InvocationName):  Response stream size: $($ResponseStream.Length) bytes"
				
				$IO = New-Object System.IO.StreamReader($ResponseStream);
				
				write-verbose "$($MyInvocation.InvocationName):  Reading response stream...."
				$responseString = $IO.ReadToEnd();
				
				write-verbose "$($MyInvocation.InvocationName):  response json is: $responseString"
			}
			
			
			write-verbose "$($MyInvocation.InvocationName):  Response String size: $($responseString.length) characters! "
			return $responseString;
		} catch {
			throw "ERROR_CALLING_TELEGRAM_URL: $_";
		} finally {
			if($IO){
				$IO.close()
			}
			
			if($ResponseStream){
				$ResponseStream.Close()
			}
			
			<#
			if($HttpResp){
				write-host "Finazling http request stream..."
				$HttpResp.finalize()
			}
			#>

		
			if($RequestStream){
				write-verbose "Finazling request stream..."
				$RequestStream.Close()
			}
		}
	}

	
	#Handle the zabbix server answers.
	#If the repsonse represents a error, a exception will be thrown. Otherwise, a object containing the response will be returned.
	Function TranslateResponseJson {
		param($Response)
		
		#Converts the response to a object.
		$ResponseO = ConvertFromJson $Response;
		
		#Check outputs
		if($ResponseO.ok -eq $false){
			$ResponseError = $ResponseO;
			$MessageException = "[$($ResponseError.error_code)]: $($ResponseError.description)";
			$Exception = New-Object System.Exception($MessageException)
			$Exception.Source = "TelegramAPI"
			throw $Exception;
			return;
		}
		
		
		#If not error, then return response result.
		return $ResponseO.result;
	}


	#Convert a datetime object to a unix time representation.
	Function Datetime2Unix {
		param([datetime]$Datetime)
		
		return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
	}

	#Converts a unixtime representation to a datetime in local time.
	Function PSCmdBot_UnixTime2LocalTime {
		param([uint32]$unixts)
		
		return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
	}
	
	#This will contains the storage!
		if(!$Global:PSCmdBot_Storage){
			$Global:PSCmdBot_Storage=@{
				DEFAULT_TOKEN = $null;
			};
		}
			
	#This will configure OPTIONS of the PsCmdBot...
		if(!$Global:PSCmdBot_Storage.OPTIONS){
			$Global:PSCmdBot_Storage.OPTIONS = @{};
		}
		
		$AllPossibleOptions = @{
			DEFAULT_DOCUMENT_ENCODING = 'UTF8'
		}
		
		$AllPossibleOptions.GetEnumerator() | %{
			$OptName 	= $_.Key;
			$OptDefaultValue	= $_.Value;
			
			if($Global:PSCmdBot_Storage.OPTIONS[$OptName] -eq $null){
				$Global:PSCmdBot_Storage.OPTIONS[$OptName] = $OptDefaultValue;
			}
			
		}
		
		#Remove invalid options!
		@($Global:PSCmdBot_Storage.OPTIONS.Keys) | ? { -not ($AllPossibleOptions.Keys -Contains $_) } | %{ $Global:PSCmdBot_Storage.OPTIONS.remove($_) };
		
		
	#This will initialize configuration
		$Global:PSCmdBot_Storage.CONFIGURATION = @{
			EFFECTIVE 	= $null		#current effective configuration
			LAST		= @{}		#Last configuration before most recent.
			DEFAULT		= @{}		#defautl configuration
			USER		= @{
					LAST_FILE_MODIFIED = [datetime]'1900-01-01'
				}
			CHANGE_SUBSCRIBERS = @()
		}
		
	#Working directory slot
		if(!$Global:PSCmdBot_Storage.Contains("WORKING_DIRECTORY")){
			$Global:PSCmdBot_Storage.add("WORKING_DIRECTORY",$null);
		}
		
		
	#Set value of a option
	Function Set-PsCmdBotOption {
		param($Name,$Value)
		
		if(!$Name){
			throw "PSCMDBOT_SETOPTION_EMPTYNAME";
		}
		
		$Global:PSCmdBot_Storage.OPTIONS[$Name] = $Value;
	}
	
	#Set value of a option
	Function Get-PsCmdBotOption {
		param($Name = $null)
		
		$Global:PSCmdBot_Storage.OPTIONS.GetEnumerator() | ? { $_.Key -eq $Name -or !$Name };
	}

	Function Set-DefaultToken {
		param($token)
		
		if(!$token){
			throw "PSCMDBOT_SETDEFAULTTOKEN_INVALID"
		}
		
		$Global:PSCmdBot_Storage.DEFAULT_TOKEN = $token;
	}
	
	Function Get-BotToken {
		param($token, [switch]$NoDefault = $false)
		
		if($token){
			return $token;
		} else {
			if($Global:PSCmdBot_Storage.DEFAULT_TOKEN -and !$NoDefault){
				return $Global:PSCmdBot_Storage.DEFAULT_TOKEN;
			} else {
				throw "PSCMDBOT_TELEGRAMAPI_NOTOKEN"
			}
		}
	}
	
	### HTTP REQUESTS SUPPORT

		#Copies bytes from a stream to another!
		Function PsCmdBot_CopyToStream {
			param($From,$To)
			
			[Byte[]]$Buffer = New-Object Byte[](4096);
			$BytesRead = 0;
			while( ($BytesRead = $From.read($Buffer, 0,$Buffer.length)) -gt 0  ){
				$To.Write($buffer, 0, $BytesRead);
			}
		}

	
		#Converts a hashtable to a URLENCODED format to be send over HTTP requests.
		Function PSCmdBot_BuildURLEncoded {
			param($DATA)
			
			$FinalString = @();
			$DATA.GetEnumerator() | %{
				$FinalString += "$($_.Key)=$($_.Value)";
			}

			Return ($FinalString -Join "&");
		}
	
	
		#Makes a POST HTTP call and return cmdlet with the results.
		#This will return a object containing following:
		#	raw 		- The raw bytes of response content.
		#	html		- The html respponse, if contentType is text/html
		#	httpResponse - The original http response object!
		#	session	- The session data, to be used as the parameter "session" to simulate sessions!
		Function PSCmdBot_InvokeHttp {
			[CmdLetBinding()]
			param($URL, [hashtable]$data = @{}, $Session = $null, $method = 'POST', [switch]$AllowRedirect = $false)
			
			
			$Result = New-Object PsObject @{
				raw = $null
				html = $null
				httpResponse = $null
				session = @{cookies=$null}
			}
			
			$CookieContainer = New-Object Net.CookieContainer;
			
			if($Session){
				write-verbose "$($MyInvocation.InvocationName): Session was informed. Importing cookies!"
				$Session.Cookies | ?{$_} | %{
						write-verbose "$($MyInvocation.InvocationName): Cookie $($_.Name) imported!"
						$CookieContainer.add($_);
				}
			}
			
			try {
				$HttpRequest 					= [Net.WebRequest]::Create($URL);
				$HttpRequest.CookieContainer 	= $CookieContainer;
				$HttpRequest.Method 			= $method;
				$HttpRequest.AllowAutoRedirect 	= $AllowRedirect
				
				if($HttpRequest.method -eq 'POST'){
					write-verbose "$($MyInvocation.InvocationName): Setiing up the POST headers!"
					$PostData 	= PSCmdBot_BuildURLEncoded $data
					write-verbose "$($MyInvocation.InvocationName): Post data encoded is: $PostData"
					$PostBytes 	= [System.Text.Encoding]::UTF8.GetBytes($PostData)
					$HttpRequest.ContentType = 'application/x-www-form-urlencoded';
					$HttpRequest.ContentLength 	= $PostBytes.length;
					write-verbose "$($MyInvocation.InvocationName): Post data length is: $($PostBytes.Length)"
					
					write-verbose "$($MyInvocation.InvocationName): getting request stream to write post data..."
					$RequestStream					= $HttpRequest.GetRequestStream();
					try {
						write-verbose "$($MyInvocation.InvocationName): writing the post data to request stream..."
						$RequestStream.Write($PostBytes, 0, $PostBytes.Length);
					} finally {
						write-verbose "$($MyInvocation.InvocationName): disposing the request stream..."
						$RequestStream.Dispose();
					}
				}
				
				write-verbose "$($MyInvocation.InvocationName): Calling the page..."
				$HttpResponse = $HttpRequest.getResponse();
				
				if($HttpResponse){
					write-verbose "$($MyInvocation.InvocationName): Http response received. $($HttpResponse.ContentLength) bytes of $($HttpResponse.ContentType)"
					$Result.httpResponse = $HttpResponse;
					
					if($HttpResponse.Cookies){
						write-verbose "$($MyInvocation.InvocationName): Generating response session!";
						$HttpResponse.Cookies | %{
							write-verbose "$($MyInvocation.InvocationName): Updating path of cookie $($_.Name)";
							$_.Path = '/';
						}
						
						$Result.session = @{cookies=$HttpResponse.Cookies};
					}
					
					
					write-verbose "$($MyInvocation.InvocationName): Getting response stream and read it..."
					$ResponseStream = $HttpResponse.GetResponseStream();
					
					write-verbose "$($MyInvocation.InvocationName): Creating memory stream and storing bytes...";
					$MemoryStream = New-Object IO.MemoryStream;
					PsCmdBot_CopyToStream -From $ResponseStream -To $MemoryStream
					$ResponseStream.Dispose();
					$ResponseStream = $null;


					#If content type is text/html, then parse it!
					if($HttpResponse.contentType -like 'text/html;*'){
						write-verbose "$($MyInvocation.InvocationName): Creating streamreader to parse html response..."
						$MemoryStream.Position = 0;
						$StreamReader = New-Object System.IO.StreamReader($MemoryStream);
						write-verbose "$($MyInvocation.InvocationName): Reading the response stream!"
						$ResponseContent =  $StreamReader.ReadToEnd();
						write-verbose "$($MyInvocation.InvocationName): Using HAP to load HTML..."
						$HAPHtml = New-Object HtmlAgilityPack.HtmlDocument
						$HAPHtml.LoadHtml($ResponseContent);
						$Result.html = $HAPHtml;
					}
					
					write-verbose "$($MyInvocation.InvocationName): Copying bytes of result to raw content!";
					$MemoryStream.Position = 0;
					$Result.raw = $MemoryStream.toArray();
					$MemoryStream.Dispose();
					$MemoryStream = $null;
				}
				
				return $Result;
			} catch {
				throw "INVOKE_HTTP_ERROR: $_"
			} finnaly {
				if($MemoryStream){
					$MemoryStream.Dispose();
				}
				
				if($StreamReader){
					$StreamReader.Dispose();
				}
				
				
				if($ResponseStream){
					$ResponseStream.close();
				}
			
				if($HttpResponse){
					$HttpResponse.close();
				}
				

			}
			
		}
		
	
	
######################### API Implemenations
## All methods parameters wil match name on API. Extensions will be flagged in comments.
## Only parameters that exist on api documentation cannot needs comments.
## All Methods must receive the $token with the token!
## If api call returns error, the methods will trow it. The exception contains same errors returned by api when error.
## https://core.telegram.org/bots/api


# Implementation of getUpdates
# https://core.telegram.org/bots/api#getupdates
function Get-TelegramUpdates {
	[CmdLetBinding()]
	param(
		 [string]$token
		,[int]$offset	= $null
		,[int]$limit 	= $null
		,[int]$timeout 	= $null 
		,[string[]]$allowed_updates = $null
	)
	
	$token = Get-BotToken -token $token;
	$URL_API = "https://api.telegram.org/bot$($token)/getUpdates"
	
	
	$Params = @{};
	
	if($offset){
		$Params.add("offset", $offset);
	}
	
	if($limit){
		$Params.add("limit", $limit);
	}
	
	if($timeout){
		$Params.add("timeout", $timeout);
	}
	
	if($allowed_updates){
		$Params.add("allowed_updates",$allowed_updates);
	}
	
	$APIResponse = CallTelegramURL -Url $URL_API -Data $Params
	
	return (TranslateResponseJson $APIResponse);
}


# Implementation of sendMessage
# https://core.telegram.org/bots/api#sendmessage
function Send-TelegramMessage {
	[CmdLetBinding()]
	param(
		 [string]$token
		,[string]$chat_id
		,[string]$text 
		,[int]$reply_to_message_id = $null
	)
	
	$token = Get-BotToken -token $token;
	$URL_API = "https://api.telegram.org/bot$($token)/sendMessage"
	
	$Params = @{
		chat_id = $chat_id
		text 	= $text
	}
	
	if($reply_to_message_id){
		$Params.add("reply_to_message_id",$reply_to_message_id);
	}
	
	$APIResponse = CallTelegramURL -Url $URL_API -Data $Params
	
	return (TranslateResponseJson $APIResponse);
}

# Implementation of getFile
# https://core.telegram.org/bots/api#getfile
function Get-TelegramFile {
	[CmdLetBinding()]
	param(
		 [string]$token
		,[string]$file_id
	)
	
	$token = Get-BotToken -token $token;
	$URL_API = "https://api.telegram.org/bot$($token)/getFile"
	
	
	$Params = @{
		file_id = $file_id
	};
	
	$APIResponse = CallTelegramURL -Url $URL_API -Data $Params
	
	return (TranslateResponseJson $APIResponse);
}



######################### Module Features	
	
	#REPLY LISTENER
	#The reply listener is a feature that allow a handler to be invoked when a reply to a specific message arrives.
	#Handlers can use this to,for example, ask users some text data that not starts with /.
	$PSCMDBOT_REPLYLISTENER = @{};
	
		#Adds a listener to a reply a message with specific handlers!
		Function PsCmdBot_ReplyListener_Listen {
			param($MessageFilter, $HandlerName, $data = $null, $ReplyCount = 1)
		
			if(!$MessageFilter.message_id){
				throw "PPSCMDBOT_REPLYLISTENER_LISTEN_EMPTYMESSAGEID"
			}
		
			if( $PSCMDBOT_REPLYLISTENER.Contains( $MessageFilter.message_id )  ){
				throw "PPSCMDBOT_REPLYLISTENER_LISTEN_EXISTENTID: $($MessageFilter.message_id)"
			}
			
			$Handler = $HANDLERS[$HandlerName];
			if(!$Handler){
				throw "PPSCMDBOT_REPLYLISTENER_LISTEN_INVALIDMSGHANDLER: $HandlerName"
			}
			
			#Creates a new entry
			$ListenerEntry = New-Object PSObject -prop @{
				MessageFilter 	= $MessageFilter
				Handler 		= $Handler
				Lifetime		= $ReplyCount
				data			= $data
			}
			
			
			$PSCMDBOT_REPLYLISTENER.add( $MessageFilter.message_id, $ListenerEntry );
			
		}
		
		#Removes a listener to a msg reply.
		Function PsCmdBot_ReplyListener_Remove {
			param($MessageFilter)
			
			if($PSCMDBOT_REPLYLISTENER.Contains($MessageFilter.message_id)){
				$PSCMDBOT_REPLYLISTENER.Remove($MessageFilter.message_id)
			}
			
		}
		
		#Check if a message is on list. If is, returns the ListenerEntry associated with it.
		#Else, returns $null.
		#Also, manipulates updates the lifetime counter! This must be only way to access a listener entry.
		Function PsCmdBot_ReplyListener_CheckMessage {
			param($Message)
			
			if( $Message.reply_to_message ){
				
				$ListenerEntry =  $PSCMDBOT_REPLYLISTENER[$Message.reply_to_message.message_id];
				
				if(!$ListenerEntry){
					return $null;
				}
				
				if($ListenerEntry.Lifetime -eq 0){
					return $null;
				} else {
					$ListenerEntry.Lifetime--;
				}
				
				return $ListenerEntry;
			}
			
		}
		
		
		#Gets the data associated with a message listener entry
		Function PsCmdBot_ReplyListener_GetData {
			param($MessageFilter)
			
			$Entry = $PSCMDBOT_REPLYLISTENER[$MessageFilter.message_id]
			if($Entry){
				return $Entry.data;
			}
		}
		
		
		#Get handlers list
		Function PsCmdBot_MsgHandlers_GetHandlers {
			return $HANDLERS;
		}
		
		#Get supported commands list from handlers!
		Function PsCmdBot_MsgHandlers_GetCommandsHelp {
			param(
				$Command = $null
				,[switch]$IncludeHandler = $false
				,[switch]$BotFatherList = $false
			)
			
			$Startbar = "/"
			if($BotFatherList){
				$Startbar = "";
			}
			
			@($HANDLERS.GetEnumerator() | %{
				if($_.Value.COMMANDS){
					$_.Value.COMMANDS.GetEnumerator() | ? {$_.Key -eq $Command -or !$Command }  | %{
						$CommandName 		= $_.Key;
						$CommandDescription	= $_.Value.DESCRIPTION;
						$Aliases = $_.Value.ALIAS;
						
						if($Aliases){
							$AliasText = " (ALIAS: $Aliases)"
						} else {
							$AliasText = "";
						}
						

						
						if($Command){
							$Syntax = $_.Value.SYNTAX;
							$Text = @(
								$Syntax
								$CommandDescription
								$AliasText
							);
						} else {
							$Text = @(
								$Startbar + "$CommandName - $CommandDescription" + $AliasText
							);
						}
						
						
						return ($Text -join "`r`n");
					}
				}
			})
		}
	
	
	
	#DEFAULT COMMAND PARSING
	#The pscmdbot provide a default command parsing (called DCP in functions)
	#This helps new msg handlers easily implements new commands without worry about syntax, parsing, etc.
	#The parsed syntax is:
	#	/CommandName PARAMNAME:VALUE1 PARAMNAME:"VALUE WITH SPACES" VALUE_DEFAULT_PARAM "value default with spaces" PARAMNAME:"VALUE 1 VALUE 3",VALUE3
	#Extracks command name from a message
	#All commands must follow telegram rules (start with a /xxx)
	
		
		#Return all command parts.
		#Will return a object containing the command parts. Properties:
		#	CommandName 	- The commandName
		#	FreeArguments	- Array containing values passed without param specifying
		#	NamedArguments	- Object with each value of parameters. Each property receive same name of parameter. Each prop is array with values.
		#TODO:
		#	PARAMETERS FROM REPLY
		#
		Function PsCmdBot_DCP_GetParts {
			param($message, [switch]$CommandOnly)
	
			$text = $message.text;
			
			#First, lets break the message into the parts separator!
			$DCP_COMMAND_PARTS_SEPARATOR = '(\s+)'
			$DCP_PARAM_VALUE_SEPARATOR = ':'
			$DCP_MULTI_VALUE_SEPARATOR = ','
			$DCP_STRING_DELIMITER = '"'
		
			$Result = New-Object PsObject -Prop @{
					CommandName 	= $null
					NamedArguments	= @{""=@()}
					FreeArguments	= @()
				}
				

			if($CommandOnly){
				$CommandParts = $text -split $DCP_COMMAND_PARTS_SEPARATOR,2
			} else {
				$CommandParts = $text -split $DCP_COMMAND_PARTS_SEPARATOR
			}
			
			if( $CommandParts.length -eq 0 ){
				return $Result;
			}
			
			#Right, at this point we must have, at least, the command name!
			$CommandName = $CommandParts[0] -replace '^/','';
			$Result.CommandName = $CommandName;
			
			if($CommandOnly){
				return $Result;
			}
			
			
			#Now, we will iterate over resulting commands
			$CurrentPart = 2;
			$TotalParts = $CommandParts.length;
			while($CurrentPart -lt $TotalParts){
				
				#First, lest break current part into paramname value...
				
				$ParamValueParts = ($CommandParts[$CurrentPart]) -split $DCP_PARAM_VALUE_SEPARATOR,2;
				 
				#if two parts returned, then have name, else dont have!
				if($ParamValueParts.length -eq 2){
					$ParamName = $ParamValueParts[0]
					$ParamValue = $ParamValueParts[1]
				} else {
					$ParamName 	= ''
					$ParamValue = $ParamValueParts[0];
					$ParamName	= ""
				}
				
			
				#Now, we have the values, lets check if values starts with the string deliimiter, and not ends with it.
				if( $ParamValue -match "^$($DCP_STRING_DELIMITER).+[^$($DCP_STRING_DELIMITER)]$" ){
				
					#concatenate next parts up to found a that ends with string delimiter!
					while($CurrentPart -le $TotalParts -and $CommandParts[$CurrentPart] -match "[^$($DCP_STRING_DELIMITER)]$" ){
						$CurrentPart+=2;
						$ParamValue += $CommandParts[$CurrentPart-1]+$CommandParts[$CurrentPart];
					}

				}
				
				$Result.NamedArguments[$ParamName] += @($ParamValue);
				$CurrentPart+=2;
			}
			
			$Result.FreeArguments = $Result.NamedArguments[""];
			$Result.NamedArguments.remove("");
			
			return $Result;
			
			
			
		}
		
		#Gets only command name from a command!
		Function PsCmdBot_DCP_GetCommandName {
			param($message)
			
			$text = $message.text;
			
			$CommandInfo = PsCmdBot_DCP_GetParts $message -CommandOnly;
			return $CommandInfo.CommandName;
		}
		
	## CONFIGURATION MANAGEMENT
		
	
		Function PsCmdBot_CM_GetConfiguration {
			return $Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE;
		}
		
		Function PsCmdBot_CM_MergeConfig {
			param($Config1, $Config2)
			
			if(!$Config1){
				throw "PSCMDBOT_CM_MERGE_INVALID_CONFIG1"
			}
			
			if(!$Config2){
				throw "PSCMDBOT_CM_MERGE_INVALID_CONFIG2"
			}
			
			return PSCmdBot_MergeHashTables -HashTable1 $Config1 -HashTable2 $Config2 
		}

		Function PsCmdBot_CM_GetUserConfig {
			$WorkingDirectory = PsCmdBot_GetWorkingDirectory;
			
			$UserConfigFile = "$WorkingDirectory\config.ps1";
			$ConfigurationStore = $Global:PSCmdBot_Storage.CONFIGURATION;
			
			#Gets  last modify of last successfully read...
			$LastModifiedTime =  $ConfigurationStore.USER.LAST_FILE_MODIFIED;
			
			#This is useful if file dont exists, or if exists in is deleted!
			if([IO.File]::Exists($UserConfigFile)){
				#Check file last modified time
				$ModifiedTime = (Get-Item $UserConfigFile).LastWriteTime;
				$Updated = ($ModifiedTime -gt $LastModifiedTime) -or $LastModifiedTime -eq $null;
			}
			
			#If are equals...
			if($Updated){
				$ConfigurationStore.USER.LAST_FILE_MODIFIED = $ModifiedTime;
			} else {
				return $null;
			}
			
			try {
				return (& $UserConfigFile);
			} catch {
				throw "PSCMDBOT_CONFIGURATIONMANAGER_GETUSERCONFIG_ERROR: $_"
			}
		}
				
		Function PsCmdBot_CM_GetDefaultConfig {
			$WorkingDirectory = PsCmdBot_GetWorkingDirectory;
			
			try {
				return (& "$ModuleRoot\default.config.ps1");
			} catch {
				throw "PSCMDBOT_CONFIGURATIONMANAGER_GETDEFAULTCONFIG_ERROR: $_"
			}
		}
		
		Function PSCmdBot_CM_UpdateConfig {
		
			$UserConfig 	= PsCmdBot_CM_GetUserConfig;
			
			if($UserConfig){
				write-host "User configurations changes detected. Reloading"
			} else {
				return $null;
			}
			
			$DefaultConfig	= PsCmdBot_CM_GetDefaultConfig;
			
			#Merges differences...
			$CurrentConfig = PsCmdBot_CM_MergeConfig -Config1 $DefaultConfig -Config2 $UserConfig;
		
			if(!$Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE){
				$Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE = $DefaultConfig;
			}
			
			$Global:PSCmdBot_Storage.CONFIGURATION.LAST = $Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE.psobject.copy();
			$Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE = $CurrentConfig;
			
			

				
			#Invokes the configurations updates subscribers.
			if($Global:PSCmdBot_Storage.CONFIGURATION.CHANGE_SUBSCRIBERS){
				$ChangedConfig = PsCmdBot_HashDiff -Table1 $Global:PSCmdBot_Storage.CONFIGURATION.LAST -Table2 $CurrentConfig;
				
				write-host "LAST: $(PsCmdBot_Object2HashString $DefaultConfig -Expand)"
				write-host "LAST: $(PsCmdBot_Object2HashString $UserConfig -Expand)"
				

				$Global:PSCmdBot_Storage.CONFIGURATION.CHANGE_SUBSCRIBERS | %{
					& $_.SCript $ChangedConfig;
				}
			}

			
		}
	
		Function PsCmdBot_CM_AddSubscription {
			param($Name, $Script)
			
			$Global:PSCmdBot_Storage.CONFIGURATION.CHANGE_SUBSCRIBERS += New-Object PsObject -Prop @{Name=$Name; Script=$Script};
		}
		
	
	#Sets current working directory
	Function PsCmdBot_SetWorkingDirectory {
		param($WorkingDirectory)
		
		if(![IO.Directory]::Exists($WorkingDirectory)){
			throw "PSCMDBOT_WORKINGDIRECTORY_NOTFOUND"
		}
		
		$Global:PSCmdBot_Storage.WORKING_DIRECTORY = $WorkingDirectory;
	}
	
	#Sets current working directory
	Function PsCmdBot_GetWorkingDirectory {
		return $Global:PSCmdBot_Storage.WORKING_DIRECTORY;
	}
	
	#Prints a telegram message to a output!
	Function PSCmdBot_PrintTelegramMessage {
		param(
			#Message Object
				$Message
			
			,#Output. Specify destination. 
			 #Can be a scriptblock. Defaults is print to screen.
			 #$_ Contains a object follwoing properties:
			 #		message 		= The message object.
			 #		simpleMessage	= A simple message string.
				$Output = { write-host $_.simpleMessage }
		)
		
		
		 New-Object PsObject -Prop @{
				message = $Message
				simpleMessage = "[$($Message.message_id)] $($Message.from.username): $($Message.text)" 
			} | % {
				#Store output object with messabes...
				$PrintObject = $_;
				
				#For each output, call it!
				$output | %{
					$PrintObject | % $_
				}
			}
	}
	
	
	#Get contents of a file sent to bot!
	#Pass the file object returned by Get-TelegramFile
	Function Get-TelegramFileContent {
		[CmdLetBinding()]
		param($File, $totken = $null)
	
		$token = Get-BotToken -token $token;
		$URL_API = "https://api.telegram.org/file/bot$($token)/$($file.file_path)"
		
		$DocumentEncoding = Get-PsCmdBotOption 'DEFAULT_DOCUMENT_ENCODING';
		
		if(!$DocumentEncoding.Value){
			throw "PSCMDBOT_GETFILECONTENT_NO_DOCUMENT_ENCODING";
		}
		$EncodingName = $DocumentEncoding.Value;
		
		$HttpContent = PSCmdBot_InvokeHttp -URL $URL_API -Method 'GET';
		
		$Encoding = [System.Text.Encoding]::"$EncodingName";
		
		
		$Encoding.GetString($HttpContent.Raw);
	}

	#Message Handlers!
		Function NewHandlerResult {
			param($Handler)
			
			if(!$Handler){
				throw "Must pass handler!"
			}
			
			$o = New-Object PsObject -Prop @{
				handler = $handler
				data = $null
				mustReply=$false;
				reply = @{
					message = $null
					script	= $null #Script to be executed in context of reply. First argumnet is own HandlerResult. SEcond is replyMessage.
				}
			}
			
			return $o;
			
		}
		
		$TELEGRAM_HANDLER_DEFINITIONS = @{}
		$HANDLERS = @{};
		
		Function PSCmdBot_InitializeHandlers {
			[CmdLetBinding()]
			param()
			
			$TELEGRAM_HANDLER_DEFINITIONS.GetEnumerator() | %{
				$HandlerName = $_.Key;
				$HandlerDefinition = $_.Value;
				
				if($HANDLERS.Contains($HandlerName)){
					return;
				}
				
				write-verbose "$($MyInvocation.InvocationName): Initializing handler $HandlerName"
				
				$Handler = New-Object PSObject;
				$HandlerDefinition.GetEnumerator() | %{
					$DefinitionMemberName 	= $_.Key;
					$DefinitionMemberValue 	= $_.Value;
					
					if($DefinitionMemberValue -is [scriptblock]){
						$Handler | Add-Member -Type ScriptMethod -Name $DefinitionMemberName -Value $DefinitionMemberValue
					} else {
						$Handler | Add-Member -Type Noteproperty -Name $DefinitionMemberName -Value $DefinitionMemberValue
					}
					
				}
				
				if( $Handler.PRIORITY -eq $null){
					$Handler | Add-Member -Type Noteproperty -Name PRIORITY -Value 0 -Force;
				}
				
				#Will contains the name of the handler.
				$Handler | Add-Member -Type Noteproperty -Name NAME -Value $HandlerName -Force;
				
				#Will contains the indication of reason for the handler to be used!
				#Values: COMMAND (Command pattern), REPLY_LISTENER (The message is reply to a trackd message in listener)
				$Handler | Add-Member -Type Noteproperty -Name SOURCE -Value "COMMAND" -Force;
				
				#Add methods to manager listener enty
				$Handler | Add-Member -Type ScriptMethod -Name listen -Force -Value {
						param($MessageFilter, $data = $null)
						
						PsCmdBot_ReplyListener_Listen -MessageFilter $MessageFilter  -HandlerName $this.NAME -data $data
						
					};
						
				$Handler | Add-Member -Type ScriptMethod -Name unlisten -Force -Value {
						param($MessageFilter)
						
						PsCmdBot_ReplyListener_Remove -MessageFilter $MessageFilter
						
					};
					
				$Handler | Add-Member -Type ScriptMethod -Name getListenerData -Force -Value {
						param($MessageFilter)
						
						PsCmdBot_ReplyListener_GetData -MessageFilter $MessageFilter
					};

				if(!$Handler.COMMANDS){
					$Handler | Add-Member -Type Noteproperty -Name 'COMMANDS' -Value @{}
				}
				
	
				#The default IS_AUTHORIZED method!
				#This method check if user is authorized to run a command!
				#Note that handlers can define your own way to check authorized.
				#By default, the module architecture define a standard way to provide a minimum authorization check.
				if(!$Handler.IS_AUTHORIZED){
					$Handler | Add-Member -Type ScriptMethod -Name 'IS_AUTHORIZED' -Value {
						param($message)
						
						write-host "Checking for authorized users...."
						
						#Gets current configurations
						$CurrentConfig = PsCmdBot_CM_GetConfiguration;
						write-host "CurrentConfig: $(PsCmdBot_Object2HashString $CurrentConfig -Expand)"
						
						#Gets current command name!
						$CurrentCommand = PsCmdBot_DCP_GetCommandName $message;
						$RealCommand	= $this.getRealCommandName($CurrentCommand)
						write-host "CurrentCommand: $currentCommand | Real: $RealCommand"
						
						#Gets the authorized users for current command
						$CommandConfigurations = $CurrentConfig.COMMANDS[$RealCommand];
						
						if($CommandConfigurations){
							$AuthorizedUsers = $CommandConfigurations['AUTHORIZED_USERS'];
						} else {
							$AuthorizedUsers = @();
						}
						
						
						write-host "	Authorizeds: $AuthorizedUsers"
						
						return ($AuthorizedUsers -Contains $message.from.username -or $AuthorizedUsers -eq '*');
					}
				
				}
				
				#Default CHECK_COMMAND method
				if(!$Handler.CHECK_COMMAND){
					$Handler | Add-Member -Type ScriptMethod -Name 'CHECK_COMMAND' -Value {
						param($message = $null, $command = $null)
						
						#Gets current command name!
						if($command){
							return $this.SupportedCommandNames -Contains $command;
						} else {
							$CurrentCommand = PsCmdBot_DCP_GetCommandName $message;
							return $this.SupportedCommandNames -Contains $CurrentCommand;
						}
						
							
					}
				
				}
				
				
				#Builds a static list of supported commands names and its alias.
				$Handler | Add-Member -Type noteproperty -Name SupportedCommandNames -Value $null -force;
				$Handler.SupportedCommandNames = $Handler.COMMANDS.GetEnumerator() | %{
					$Names = @($_.Key);
					
					if($_.Value.ALIAS){
						$Names += $_.Value.ALIAS
					}
					
					return $Names;
				}
				
				#Buils a alias map to speed up searches...
				$Handler | Add-Member -Type noteproperty -Name Aliases -Value @{} -Force;
				$Handler.COMMANDS.GetEnumerator() | %{
					if($_.Value.ALIAS){
						$CommandName = $_.Key;
						$CommandReference = $_.Value;
						$_.Value.ALIAS | %{
							$Handler.Aliases.add($_, $CommandName); 
						}
					}
				}
				
				#Get real command name, if alias.
				$Handler | Add-Member -Type ScriptMethod -Name getRealCommandName -Value {
					param($name)
					
					if($this.Aliases[$name]){
						return $this.Aliases[$name]
					} else {
						return $name;
					}
					
				}
				

				if($Handler.ON_CONFIG_CHANGE){
					PsCmdBot_CM_AddSubscription -Name "Handler:$HandlerName" -Script ({param($Changed) $Handler.ON_CONFIG_CHANGE($Changed)}.GetNewClosure())
				}
				
				$HANDLERS.add($HandlerName, $Handler);
			}
		
		
		
		} 
		
		Function PSCmdBot_LoadHandlers {
			[CmdLetBinding()]
			param()
			
			
			#Current WorkingDirectory
			$WorkingDirectory = PsCmdBot_GetWorkingDirectory;
			$MsgHandlerExtension = '.msghandler.ps1'
			
			$HandlersToLoad = @(gci $MessageHandlersScripts);
			
			#User message handler!
			$UserHandlersDir = $WorkingDirectory+'\'+'msghandlers'
			
			if( [IO.Directory]::Exists($UserHandlersDir) ){
				$HandlersToLoad += gci $UserHandlersDir+"\*.$MsgHandlerExtension";
			}

			write-verbose "$($MyInvocation.InvocationName): Loading handlers";
			
			write-verbose "$($MyInvocation.InvocationName): Loading handler definitions from scripts..."
			$HandlersToLoad | %{
				$HandlerName = $_.Name.replace($MsgHandlerExtension,'');
				$HandlerDefinition = & $_.FullName;
				
				if(!$TELEGRAM_HANDLER_DEFINITIONS.Contains($HandlerName)){
					write-verbose "$($MyInvocation.InvocationName): Adding the handler $HandlerName from $($_.FullName)"
					$TELEGRAM_HANDLER_DEFINITIONS.add($HandlerName, $HandlerDefinition);
				}
				
			}
			
			PSCmdBot_InitializeHandlers
		}
		
		#Finds the command the current message apply to!
		Function PsCmdBot_GetMessageHandler {
			param($Message)
			
			$ListenerEntry = PsCmdBot_ReplyListener_CheckMessage $Message;
			
			if($ListenerEntry){
				$ListenerEntry.Handler.SOURCE = "REPLY_LISTENER";
				return $ListenerEntry.Handler;
			}
			
			
			$CommandName = PsCmdBot_DCP_GetCommandName $message
			$ElegibleHandler = 	$HANDLERS.Values | ? {  $_.CHECK_COMMAND($null,$CommandName)  } | sort PRIORITY -Desc | select -first 1;
			
			if($ElegibleHandler){
				$ElegibleHandler.SOURCE = "COMMAND";
				return $ElegibleHandler;
			} else {
				return $null;
			}
			
			
			
		}
		
	
	#The bot main!
	Function Start-CmdBot {
		[CmdLetBinding()]
		param(
			#The token to be used.
			$token				= $null
			
			,#Specify pooling time used in getUpdates telegram api 
				$pooling 			= 0
			
			
			,#The working directory is directory where the cmdlet will search for additional configurations files and handlers.
			 #Check WORKINGDIRECTORY.md in doc folder of module.
				$WorkingDirectory = $null
		)
	
		[hashtable]$Parameters = @{
			
		}
		
		#Get the user config
		PsCmdBot_SetWorkingDirectory $WorkingDirectory
		
		#loading the handlers of messages!
		PSCmdBot_LoadHandlers;		

		
		$LastUpdate = 0;
		
		if($token){
			Set-DefaultToken -token $token;
		} else {
			$token = Get-BotToken;
		}
		
		;

		write-host "Starting waiting for updates. Token: $token";
		
		while($true){
			write-verbose "$($MyInvocation.InvocationName): Getting updates... (Offset: $LastUpdate)"
			
				
			#Merges config to determine current configuration!
			#Updates the configuration!
			PSCmdBot_CM_UpdateConfig
		
			
			$resultado = Get-TelegramUpdates -offset $LastUpdate
			
		
			#For each updates...
			if($resultado){
			
				$resultado | %{
					$u = $_;
					$LastUpdate = $u.update_id;
					
					if($u.message){
						$m = $u.message;
						
						
						#Prints the received message!
						PSCmdBot_PrintTelegramMessage $m;
						
						
						#Get the message handler!
						write-verbose "$($MyInvocation.InvocationName): Checking handler..."
						$MessageHandler = PsCmdBot_GetMessageHandler $m;
												
						if(!$MessageHandler){
							throw "CANNOT_HANDLER_THIS_MESSAGE";
							return;
						}
						write-verbose "$($MyInvocation.InvocationName): Handler choosed: $($MessageHandler.NAME). Source:($MessageHandler.SOURCE)"

						if(!$MessageHandler.IS_AUTHORIZED($m) -and $MessageHandler.SOURCE -eq "COMMAND") {
							$HandlerResult = NewHandlerResult $MessageHandler;
							$HandlerResult.mustReply = $true;
							$HandlerResult.reply.message = "Você não está autorizado a executar este comando";
						}
						else {
							#CanRun!
							write-verbose "Invoking handler..."
							try {
								$HandlerResult = $MessageHandler.HANDLER($u);
								if(!$HandlerResult){
									throw "HANDLER_DONT_RETRIVE_HANDLERRESULT";
									return;
								}
							} catch {
								write-host "Handler failed! This is critical!"
							}
						}


						#Check if handler wants a reply from bot
						if($HandlerResult.mustReply){
							write-verbose "$($MyInvocation.InvocationName): Handler request a reply..."
							
							$ReplyText = $HandlerResult.reply.message;
						
							#Replying the message...
							try {
								$MessageReplied = Send-TelegramMessage -chat_id $m.chat.id -text $ReplyText -reply_to_message_id $m.message_id
		
								if($HandlerResult.reply.script){
									write-verbose "$($MyInvocation.InvocationName): WaitForUpdates: Executing the reply script!"
									& $HandlerResult.reply.script $HandlerResult $MessageReplied
								}
								
								
								PSCmdBot_PrintTelegramMessage $MessageReplied;		
							} catch {
								write-host "Error replying: $_";
							}
						}
						
					} else {
						write-host "Unkown update type: $_";
					}
				}
				
				#Increments the LastUpdate to next, because updates have fetched!
				$LastUpdate++;
				
			}
			

			
			write-verbose "$($MyInvocation.InvocationName): Sleeping!"
			Start-Sleep -s 1
		}
	

		
	
	}
param(
	$RecreateStorage = $false
)
#Módulo para o powershell!
$ErrorActionPreference= "Stop";

# GLOBALS

	#Global useful vars...
	$PsCmdBot_ModuleRoot 	= (Split-Path -Parent $MyInvocation.MyCommand.Definition );
	$DirSep					= [IO.Path]::DirectorySeparatorChar.ToString()

	#This will contains the storage!
	if(!$Global:PSCmdBot_Storage -or $RecreateStorage){
		$Global:PSCmdBot_Storage=@{
			DEFAULT_TOKEN 	= $null;
			DEBUG_OPTIONS	= @{
				DUMP_DEFAULT_CONFIG 	= $false
				DUMP_EFFECTIVE_CONFIG	= $false
			}
		};
	}

# AUXILIARY	
	Function PsCmdBot_CheckAssembly {
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
	
	## EXCEPTIONS HANDLING!
	#This is a function to format exceptions.
	Function PsCmdBot_FormatExceptions {
		param($e,$BaseDir = "", $prefix = 'ERR')
		
		$msgTemplate 	= "$($prefix)_{0}[{6}]: {1}[{2}.{3}] >> {4} << --> {5}"
		$msgException	= @()
		
		if($e.IsExceptionContainer){
			$AllExceptions = $e.ExceptionList
		} else {
			$AllExceptions = $e;
		}
		
		
		$AllExceptions | %{
			if($_ -is [System.Exception]){
				$ex = $_;
			} else {
				$ex = $_.Exception;
			}
			
			
			if($_.InvocationInfo){
				$InvocInfo = $_.InvocationInfo
			}
					
			$num = 1;
			$BaseEx = $ex.GetBaseException();
			while($ex) {
				if($InvocInfo)
				{
					$numLinha 	= $InvocInfo.ScriptLineNumber
					$offset 	= $InvocInfo.OffsetInLine
					$linha		= $InvocInfo.Line.trim()
					$ScriptName = $InvocInfo.ScriptName.replace($BaseDir,'')
				} else {
					$numLinha 	= '?'
					$offset 	= '?'
					$linha		= '?'
					$ScriptName = '?'
				}
				
				$msg = $ex.Message
				$msgException += $msgTemplate -f $num,$ScriptName,$numLinha,$offset,$linha,$msg,$ex.getType().FullName
				$num++;
				
				$LastEx		= $ex;
				$ex 		= $ex.InnerException
				$InvocInfo 	= $ex.ErrorRecord.InvocationInfo;
			}
			
			if(!$LastEx.Equals($BaseEx)){
				$ex = $BaseEx;
				$InvocInfo = $ex.InvocationInfo;
				if($InvocInfo){
					$numLinha 	= $InvocInfo.ScriptLineNumber
					$offset 	= $InvocInfo.OffsetInLine
					$linha		= $InvocInfo.Line.trim()
				}
				
				$msgException += $msgTemplate -f $num,$linha,$linhaOffset,$code,$msg
			}
		}
		
		return $msgException -join "`r`n"
	}

	#PSCmdBot exceptions object!
	Function PSCmdBot_GetNewException {
		param(
			$ID
			,$Msg = $null
			, $Inner = $null
			,[switch]$FatalException = $false
		)

		$ExceptionMessage = "$ID";
		
		if($Msg){
			$ExceptionMessage += ':'+$Msg;
		}
		
		
		if($Inner.Exception){
			$ErrorRecord = $Inner;
			$Inner = $Inner.Exception;
			if(!$Inner.ErrorRecord){
				$Inner | Add-Member -type Noteproperty -Name ErrorRecord -Value $ErrorRecord;
			}
		}
		
		$Ex = New-Object Exception($ExceptionMessage, $Inner);
		$Ex | Add-Member -Type Noteproperty -Name FatalException -Value $FatalException;
		return $Ex;
	}

	#Creates a new exception object that with have mulitple exceptions!
	Function PsCmdBot_NewExceptionContainer {
		param($Exceptions = @())
		
		if(!$Exceptions){
			$Exceptions= @();
		}
		
		$Ex = New-Object Exception('EXCEPTION_CONTAINER', $null);
		$Ex | Add-Member -Type Noteproperty -Name ExceptionList -Value $Exceptions;
		$Ex | Add-Member -Type Noteproperty -Name IsExceptionContainer -Value $true;
		return $Ex;
	}

	Function PsCmdBot_LoadJsonEngine {

		$Engine = "System.Web.Extensions"

		if(!(PsCmdBot_CheckAssembly $Engine)){
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
	Function PSCmdBot_EscapeNonUnicodeJson {
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
	Function PSCmdBot_ConvertToJson($o) {
		
		if(Get-Command ConvertTo-Json -EA "SilentlyContinue"){
			return PSCmdBot_EscapeNonUnicodeJson(ConvertTo-Json $o);
		} else {
			PsCmdBot_LoadJsonEngine
			$jo=new-object system.web.script.serialization.javascriptSerializer
			$jo.maxJsonLength=[int32]::maxvalue;
			return PSCmdBot_EscapeNonUnicodeJson ($jo.Serialize($o))
		}
	}

	Function PSCmdBot_ConvertFromJson([string]$json) {
	
		if(Get-Command ConvertFrom-Json  -EA "SilentlyContinue"){
			ConvertFrom-Json $json;
		} else {
			PsCmdBot_LoadJsonEngine
			$jo=new-object system.web.script.serialization.javascriptSerializer
			$jo.maxJsonLength=[int32]::maxvalue;
			return $jo.DeserializeObject($json);
		}
		

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
	#It check just for keys in Table1 thare are updated in Table2, and new keys in Table2.
	#For keys in Table1, removed in Table2, you can use RemovedDefaults to specify a hashtable with default values for removed keys!
	Function PsCmdBot_HashDiff {
		param($Table1, $Table2, $RemovedDefault = $null)
		
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

			
			#If Table2 contains the key1...
			if($Table2.Contains($CurrKey)){
				$CurrValue2 = $Table2[$CurrKey];
			} else {


				#If dont have defaults fors removed, just ignore...
				if(!$RemovedDefault){
					$Diff.add($CurrKey,$null);
					return;
				}

				$CurrValue2 = $RemovedDefault[$CurrKey];
			}
			
			
			#Check if both are hashtables, and if are, recursivelly call this to et differences...
			if($CurrValue1 -is [hashtable] -and $CurrValue2 -is [hashtable]){
				if($RemovedDefault -is [hashtable]){
					if($RemovedDefault.Contains($CurrKey)){
						$CurrRemovedDefault = $RemovedDefault[$CurrKey];
					} else {
						$CurrRemovedDefault = $null;
					}
				}

				$HashDiff = PsCmdBot_HashDiff $CurrValue1 $CurrValue2 $CurrRemovedDefault;
				if($HashDiff.count){
					$Diff.add($CurrKey, $HashDiff);
				}
			} else{
				$V1 = $CurrValue1;
				$V2 = $CurrValue2;
				
				$IsNull1 = [bool]($CurrValue1 -eq $null);
				$IsNull2 = [bool]($CurrValue2 -eq $null);
				
				if(!$IsNull1){
					if($CurrValue1.Length -ne $null){
						if($CurrValue1.Length -eq 0){
							$V1 = $null;
						}
					}
				}
				
				if(!$IsNull2){
					if($CurrValue2.Length -ne $null){
						if($CurrValue2.Length -eq 0){
							$V2 = $null;
						}
					}
				}
				
			
				#Compares each value!
				$VArr1 = @($V1);
				$VArr2 = @($V2);

				if( $VArr1.count -ne $VArr2.count ){ #If counts are different...
					$Diff.add($CurrKey, $CurrValue2);
					return;
				}

				$i = $Varr1.count;
				while($i--){
					if( $Varr1[$i] -ne $Varr2[$i] ){ #If, at least, one value differs, then adds!
						$Diff.add($CurrKey, $CurrValue2);
						return;
					}
				}
			}
		}
		

		#now, check the keys inserted into Table2!
		@($Table2.Keys) | %{
			if( !$Table1.Contains($_) ){
				$Diff.add($_,$Table2[$_]);
			}
		}

		return $Diff;
	}	
	

	#Converts a hashtable into a textual representation strings. Each key is returned a string like KEYNAME = VALUE
	#If the key a another hash, then it will be represented as "PARENTKEYNAME" + $SEPARATOR + "KEYNAME" = VALUE, and so on.
	Function PsCmdBot_Hash2String {
		param($Hash, $Separator='.', $ParentKey=$null, $KeyList = $null, $SensitiveList = @())

		$Results = @();

		$Hash.GetEnumerator() | %{
			$KeyName	= $_.Key;
			$Value 		= $_.Value;
			$Rep		= "";

			if($ParentKey){
				$FullName = $ParentKey+$Separator+$KeyName
			} else {
				$FullName = $KeyName;
			}


			if($Value -is [hashtable]){
				$Rep =  PsCmdBot_Hash2String -Hash $Value -Separator $Separator -ParentKey $FullName -KeyList $KeyList -SensitiveList $SensitiveList
			} else {
				if($KeyList){
					if(-not ($KeyList|?{ $FullName -like $_ -or $FullName+$Separator -like $_ }) ){
						return;
					}
				}

				$ValuePart = ' = '+ $Value
				if($SensitiveList){
					if(($SensitiveList|?{ $FullName -like $_ -or $FullName+$Separator -like $_ }) ){
						$ValuePart = ' = ' + '*' * 3;
					}
				}

				$Rep += $FullName + $ValuePart;
			}
				
			if($Rep){
				$Results += $Rep;
			}
		}

		return $Results;
	}
	
	#Mask keys with sensitive content. Return the new hashtable with masked content
	Function PsCmdBot_HashSensitiveMask {
		param($Hash, $Separator='.', $ParentKey=$null, $SensitiveList = @(), [switch]$RegExp = $false)

		$NewHash = $Hash.psobject.copy();

		$RegExParam = @{RegExp=$RegExp};
		if($RegExp){
			$ScriptMatch = { $FullName -match $_ -or $FullName+$Separator -match $_ }
		} else {
			$ScriptMatch = { $FullName -like $_ -or $FullName+$Separator -like $_ }
		}


		@($NewHash.Keys) | %{
			$KeyName	=$_;
			$Value 		= $NewHash[$_];

			if($ParentKey){
				$FullName = $ParentKey+$Separator+$KeyName
			} else {
				$FullName = $KeyName;
			}


			if($Value -is [hashtable]){

				$Value =  PsCmdBot_HashSensitiveMask -Hash $Value -Separator $Separator -ParentKey $FullName -SensitiveList $SensitiveList @RegExParam;
			} else {
				if($SensitiveList){
					if(($SensitiveList|? $ScriptMatch) ){
						$Value = "****";
					}
				}

			}
				
			$NewHash[$_] = $Value;
		}

		return $NewHash;
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
					
					if($Expand){
						#If all elements of array are primitives, then represent the array as string!
						$IsPrimitiveArray = $true;
						$i = $object.count;
					
						while($i--){
							if($object[$i] -ne $null){
									$PosType = $object[$i].GetType();
									if(-not ($PosType.IsPrimitive -or [decimal],[string],[datetime] -contains $PosType) ){
										$IsPrimitiveArray  = $false;
										break;
									}
							}
						}


						if($IsPrimitiveArray){
							$AllObjects += $object -Join ",";
							continue;
						}

					}
				
					$ALLObjects += "$($type.FullName):$($object.length)";
					continue;
				}
				
				if($Type.IsPrimitive -or [decimal],[string],[datetime] -contains $type ){
					$IsPrimitive = $true;
				}
				
				if($IsPrimitive){
					$ALLObjects += $object.toString();
					continue;
				}

				
			
			}
			

			#if users wants expand and treat hashtable as a object, then convert it to a property of a object...
			if($object -is [hashtable] -and $Expand -and !$PureHashTables){
				if($object.count){
					$object = (New-Object PSObject -Prop $Object);
				} else {
					$object = (New-Object PSObject);
				}
				
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
							if($Expand){
								#If all elements of array are primitives, then represent the array as string!
								$IsPrimitiveArray = $true;
								$i = $PropValue.count;
							
								while($i--){
									if($PropValue[$i] -ne $null){
											$PosType = $PropValue[$i].GetType();
											if(-not ($PosType.IsPrimitive -or [decimal],[string],[datetime] -contains $PosType) ){
												$IsPrimitiveArray  = $false;
												break;
											}
									}
								}
							}

							if($IsPrimitiveArray){
								$PropValue = $PropValue -Join ","
							} else {
								$PropValue = "$($type.FullName):$($PropValue.length)";
							}
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

	#Expands keys that con hold paths or filenames.
	#This expansions turn relatives paths into absolutes ones.
	#Ex.: Example: \abc or /abc will turn C:\abc.
	#Subkeys that are hashes tables will be analyzed by this recursivelly.
	#If key is array, then, each element will be expanded.
	Function PsCmdBot_ExpandDirs($Table, $KeyNames, $BasePath){
			

		@($Table.Keys) |  %{
			$CurrentItem 	= $_;
			$CurrentValue 	= $Table[$CurrentItem];

						#se o valor atual é um hashtable, monta o path e chama a recursividade...
			if($CurrentValue -is [hashtable]){
				
				PsCmdBot_ExpandDirs -Table $CurrentValue -KeyNames $KeyNames -BasePath $BasePath;
				return; #Vai pra próxima key...
			}
			
			#If current key name dont holds a path name...
			if( -not(
					$KeyNames | ?{
						$CurrentItem -match $_ 
					}
				)
			){
				#DOes nothing in current item...
				return;
			}
			
			$ExpandedValue	= @($CurrentValue); #Temporary array...
			$i 				= $ExpandedValue.count
			
			if($CurrentValue){
				#Expands each item on temporary array...
				while($i--){
					if(!$ExpandedValue[$i]){
						continue;
					}
					
					if([Uri]::TryCreate($ExpandedValue[$i],'Absolute', [ref]$null)){
						continue;
					}
					
					
					if($ExpandedValue[$i] -match '[\\/]?(.*)$'){
						if($matches[1]){
							$ExpandedValue[$i] = $BasePath +$DirSep+ $matches[1];
						} else {
							#Case when users specify thingks like "/" or "\" only in string...
							$ExpandedValue[$i] = $BasePath
						}
						
						continue;
					}	
				}
			}
			
			#if original value is array, then just copy back, otherwise, copy first element only...
			if($CurrentValue -is [object[]]){
				$Table[$CurrentItem] = $ExpandedValue;
			} else {
				$Table[$CurrentItem] = $ExpandedValue[0];
			}
		}
	}
	
	#Convert a datetime object to a unix time representation.
	Function PSCmdBot_Datetime2Unix {
		param([datetime]$Datetime)
		
		return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
	}

	#Converts a unixtime representation to a datetime in local time.
	Function PsCmdBot_UnixTime2LocalTime {
		param([uint32]$unixts)
		
		return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
	}
	
	#Appends a root directory to a url if it is relatives
	Function PsCmdBot_MakeAbsolutePath {
		param($Path, $Root)
		
		#TODO!
		return $Path;
	}
	
	#Make calls to a zabbix server url api.
	Function PSCmdBot_CallTelegramURL([object]$data = $null,$url = $null,$method = "POST", $contentType = "application/json"){
		$ErrorActionPreference="Stop";
		
		write-verbose "$($MyInvocation.InvocationName):  URL param is: $Url";
		
		
		try {
			if(!$data){
				$data = "";
			}
		
			if($data -is [hashtable]){
				write-verbose "Converting input object to json string..."
				$data = PSCmdBot_ConvertToJson $data;
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
		$ResponseO = PSCmdBot_ConvertFromJson $Response;
		
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
	Function PSCmdBot_Datetime2Unix {
		param([datetime]$Datetime)
		
		return $Datetime.toUniversalTime().Subtract([datetime]'1970-01-01').totalSeconds;
	}

	#Converts a unixtime representation to a datetime in local time.
	Function PSCmdBot_UnixTime2LocalTime {
		param([uint32]$unixts)
		
		return ([datetime]'1970-01-01').toUniversalTime().addSeconds($unixts).toLocalTime();
	}
	

	#Set value of a option
	Function Set-PsCmdBotOption {
		param($Name,$Value)
		
		if(!$Name){
			$Ex = PSCmdBot_GetNewException -ID 'PSCMDBOT_SETOPTION_EMPTYNAME';
			throw $Ex;
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
			$CurrentConfig = PsCmdBot_CM_GetConfiguration;

			if($CurrentConfig.GLOBAL.BOT_TOKEN){
				return $CurrentConfig.GLOBAL.BOT_TOKEN;
			}


			if($Global:PSCmdBot_Storage.DEFAULT_TOKEN -and !$NoDefault){
				return $Global:PSCmdBot_Storage.DEFAULT_TOKEN;
			} else {
				$Ex = PSCmdBot_GetNewException -ID 'PSCMDBOT_TELEGRAMAPI_NOTOKEN' -Inner $_;
				throw $Ex
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
		
	
	
# TELEGRAM API
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
		
		$APIResponse = PSCmdBot_CallTelegramURL -Url $URL_API -Data $Params
		
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
		
		$APIResponse = PSCmdBot_CallTelegramURL -Url $URL_API -Data $Params
		
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
		
		$APIResponse = PSCmdBot_CallTelegramURL -Url $URL_API -Data $Params
		
		return (TranslateResponseJson $APIResponse);
	}


# GENERAL ACTIONS
	Function PsCmdBot_Initialize {
		PsCmdBot_Stor_InitializeStorage
	}

	#Sets current working directory
	Function PsCmdBot_SetWorkingDirectory {
		param($WorkingDirectory)
		
		$Stor  = PsCmdBot_Stor_GetStorage;
		
		if(![IO.Directory]::Exists($WorkingDirectory)){
			throw "PSCMDBOT_WORKINGDIRECTORY_NOTFOUND"
		}
		
		$Stor.PATHS.WORKING_DIRECTORY = $WorkingDirectory;
	}
	
	#Sets current working directory
	Function PsCmdBot_GetWorkingDirectory {
		$Stor  = PsCmdBot_Stor_GetStorage;
		return $Stor.PATHS.WORKING_DIRECTORY;
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
		
		$Time = (PsCmdBot_UnixTime2LocalTime $Message.date).toString("yyyy-MM-dd HH:mm:ss.fff");
		
		 New-Object PsObject -Prop @{
				message = $Message
				simpleMessage = "$Time [$($Message.message_id)] $($Message.from.username): $($Message.text)" 
			} | % {
				#Store output object with messabes...
				$PrintObject = $_;
				
				#For each output, call it!
				$output | %{
					$PrintObject | % $_
				}
			}
	}
	
	#Sets bot start time
	Function PSCmdBot_SetStartTime {
		param($StartTime = $null)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		
		if(!$StartTime){
			$StartTime = Get-Date;
		}
		
		$Stor.BOT_START_TIME = $StartTime;
		
		
	}
	
	#Gets bot start time
	Function PSCmdBot_GetStartTime {
		param($StartTime = $null)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		
		return $Stor.BOT_START_TIME;
		
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
	
# LOGGING 
	Function PSCmdBot_Log_SetDefaultLevel {
		$PSCMdBotLog | Set-DefaultLogLevel -DefaultLevel "PROGRESS";
	}
	
# STORAGE HANDLING
	
	Function PsCmdBot_Stor_GetStorage {
		return $Global:PSCmdBot_Storage
	}
	
	Function PsCmdBot_Stor_InitializeStorage {
		$Stor = PsCmdBot_Stor_GetStorage;
		
		#Start time
		$Stor["BOT_START_TIME"] = $null;
		
		#Paths 
		$Stor.PATHS = @{
			MODULE_ROOT						= $PsCmdBot_ModuleRoot 
			DEFAULT_MESSAGE_HANDLERS_DIR 	= "$PsCmdBot_ModuleRoot$($DirSep)messagehandlers"
			WORKING_DIRECTORY 				= $null
			ORIGINAL_DIRECTORY				= $null
		}
		
		#Intializa CONFIGURATION slot.
		$Stor.CONFIGURATION = @{
			EFFECTIVE 	= $null		#current effective configuration
			LAST		= @{}		#Last configuration before most recent.
			DEFAULT		= @{}		#defautl configuration
			USER		= @{
					LAST_FILE_MODIFIED = [datetime]'1900-01-01'
					CONFIG = @{}
				}
			CHANGE_SUBSCRIBERS = @()
			EXPANDABLE_DIR_KEYS = @(
				'FILE'
				'DIR'
				'PATH'
				'FILE_.+'
				'[^_]+_FILE'
				'DIR_.+'
				'[^_]+_DIR'
				'PATH_.+'
				'[^_]+_PATH'
			)
			
			#Runtime changed configuration!
			RUNTIME = @{}

			FIRST_USERCONFIG_CHECK = $false
		}
		
		#Reply listener slot
		$Stor.REPLY_LISTENER = @{};
		
		#Handlers
		$Stor.HANDLERS = @{
			DEFINITIONS = @{}
			HANDLERS_LIST = @{};
		}
		
		PsCmdBot_Opts_InitializaOpts
	}
	
# DEPENDENCIES
	Function PsCmdBot_Depends_GetModulesDir {
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$Dirs = @();
		$RelativeModulesDir = "depends$($DirSep)modules";
		
		if(  [IO.Directory]::Exists($Stor.PATHS.WORKING_DIRECTORY+$DirSep+$RelativeModulesDir) ){
			$Dirs += $Stor.PATHS.WORKING_DIRECTORY+$DirSep+$RelativeModulesDir
		}
		
		if(  [IO.Directory]::Exists($Stor.PATHS.MODULE_ROOT+$DirSep+$RelativeModulesDir) ){
			$Dirs += $Stor.PATHS.MODULE_ROOT+$DirSep+$RelativeModulesDir
		}
		
		return $Dirs;
	}

	Function PsCmdBot_Depends_ImportModule {
		param($ModuleName, [switch]$Force = $false)
		
		$ModulesDir = PsCmdBot_Depends_GetModulesDir;
		
		if(!$ModulesDir){
			throw "PSCMDBOT_IMPORTMODULE_NOMODULEDIR";
		}
		
		$ImportParams = @{
			Force = $Force
		}
		
		
		$imported = $false;
		foreach($Dir in $ModulesDir){
			$FullPath = $Dir + $DirSep+ $ModuleName;
			
			try {
				if( [IO.Directory]::Exists($FullPath) ){
					import-module $FullPath @ImportParams;
					$imported = $true;
					break;
				}
			} catch {
				throw "PSCMDBOT_IMPORTMODULE_FAILED: $_";
			}
			
		}	

		if(!$imported){
			throw "PSCMDBOT_IMPORTMODULE_FAILED: NotFound $ModuleName in Directores: `r`n"+$($ModulesDir -Join "`r`n")
		}
		
	}
	
# RUNTIME OPTIONS
	# Options that user can change via bot
	Function PsCmdBot_Opts_InitializaOpts {
			$Stor = PsCmdBot_Stor_GetStorage;
			
			#This will configure OPTIONS of the PsCmdBot...
			if(!$Stor.OPTIONS){
				$Stor.OPTIONS = @{};
			}
			
			$AllPossibleOptions = @{
				DEFAULT_DOCUMENT_ENCODING = 'UTF8'
			}
			
			$AllPossibleOptions.GetEnumerator() | %{
				$OptName 	= $_.Key;
				$OptDefaultValue	= $_.Value;
				
				if($Stor.OPTIONS[$OptName] -eq $null){
					$Stor.OPTIONS[$OptName] = $OptDefaultValue;
				}
				
			}
			
			#Remove invalid options!
			@($Stor.OPTIONS.Keys) | ? { -not ($AllPossibleOptions.Keys -Contains $_) } | %{ $Stor.OPTIONS.remove($_) };
	}

	
	
# REPLY LISTENER
	#The reply listener is a feature that allow a handler to be invoked when a reply to a specific message arrives.
	#Handlers can use this to,for example, ask users some text data that not starts with /.
	
	#Adds a listener to a reply a message with specific handlers!
	Function PsCmdBot_ReplyListener_Listen {
		param($MessageFilter, $HandlerName, $data = $null, $ReplyCount = 1)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ReplyListenerStor = $Stor.REPLY_LISTENER
		$HANDLERS = $Stor.HANDLERS.HANDLERS_LIST;
	
		if(!$MessageFilter.message_id){
			throw "PPSCMDBOT_REPLYLISTENER_LISTEN_EMPTYMESSAGEID"
		}
	
		if( $ReplyListenerStor.Contains( $MessageFilter.message_id )  ){
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
		
		
		$ReplyListenerStor.add( $MessageFilter.message_id, $ListenerEntry );
		
	}
	
	#Removes a listener to a msg reply.
	Function PsCmdBot_ReplyListener_Remove {
		param($MessageFilter)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ReplyListenerStor = $Stor.REPLY_LISTENER
		
		if($ReplyListenerStor.Contains($MessageFilter.message_id)){
			$ReplyListenerStor.Remove($MessageFilter.message_id)
		}
		
	}
	
	#Check if a message is on list. If is, returns the ListenerEntry associated with it.
	#Else, returns $null.
	#Also, manipulates updates the lifetime counter! This must be only way to access a listener entry.
	Function PsCmdBot_ReplyListener_CheckMessage {
		param($Message)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ReplyListenerStor = $Stor.REPLY_LISTENER
		
		if( $Message.reply_to_message ){
			
			$ListenerEntry =  $ReplyListenerStor[$Message.reply_to_message.message_id];
			
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
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ReplyListenerStor = $Stor.REPLY_LISTENER
		
		$Entry = $ReplyListenerStor[$MessageFilter.message_id]
		if($Entry){
			return $Entry.data;
		}
	}
	
	
	#Get handlers list
	Function PsCmdBot_MsgHandlers_GetHandlers {
		$Stor = PsCmdBot_Stor_GetStorage;
		$HANDLERS = $Stor.HANDLERS.HANDLERS_LIST;
		return $HANDLERS;
	}
	
	#Get supported commands list from handlers!
	Function PsCmdBot_MsgHandlers_GetCommandsHelp {
		param(
			$Command = $null
			,[switch]$IncludeHandler = $false
			,[switch]$BotFatherList = $false
		)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$HANDLERS = $Stor.HANDLERS.HANDLERS_LIST;
		
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
	
	
	
# DEFAULT COMMAND PARSER
	#The pscmdbot provide a default command parsing (called DCP in functions)
	#This helps new msg handlers easily implements new commands without worry about syntax, parsing, etc.
	#The parsed syntax is:
	#	/CommandName@botname PARAMNAME:VALUE1 PARAMNAME:"VALUE WITH SPACES" VALUE_DEFAULT_PARAM "value default with spaces" PARAMNAME:"VALUE 1 VALUE 3",VALUE3
	#Extracks command name from a message
	#All commands must follow telegram rules (start with a /xxx)
	
	#Return all command parts.
	#Will return a object containing the command parts. Properties:
	#	CommandName 	- The commandName
	#	Arguments		- Hahstable where each key is the parameter name, nad value are its respective values. Empty key is arguments passed with no param.
	#	error			- Error ocurred in parsing. Can be syntax error only.
	#TODO:
	#	PARAMETERS FROM REPLY
	#
	Function PsCmdBot_DCP_ParseCommand {
		param($message, [switch]$CommandOnly = $false)

		$FullCommand = $message.text;

		#Here we store de results!
		$Result = New-Object PsObject -Prop @{
			CommandName 	= $null
			Arguments	    = @{}
			error           = $null
		}
		
		#DCP PARSING
		#   We will split string into any character that acts a separator/boundary
		#   Each resulting array element will be called a command part, or simply, "part".
		#   A part can be a parameter, a separator command name, etc, raw string, etc. THe parsing will determine this.
		#
		#   Also, will will append a leading parameter separator in order to loop handles last parameter value according.
		
		# Here are our separators!
		$DCP_SEPARATOR_PARAMETER    = '\s';
		$DCP_SEPARATOR_PARAMVALUE   = ':';
		$DCP_SEPARATOR_VALUES       = ',';
		$DCP_SEPARATOR_STRING       = '"';
		$DCP_ERROR_INLINE_CURSOR	= '---->'
		
		
		# Here is our regexp!
		$SeparatorSplitRegex    = "($DCP_SEPARATOR_PARAMETER+|$DCP_SEPARATOR_PARAMVALUE|$DCP_SEPARATOR_VALUES|$DCP_SEPARATOR_STRING)"
		$parts                  = ($FullCommand+' ') -Split $SeparatorSplitRegex
		
		#About to start parts loop. This is where will iterate over parts! Some variables to help us!
		$i = -1; #The $i controls the part number where we are
		$InString=$false; #This controls if a string delimiter was open.
		$StrBuff=""; #This is our buffer string. Here we will store the delimited string contents.
		$LastOpenStringPart=-1; #Here will store last part number where a string delimiter opened
		$LastSeparatorPart=-1; #Will store the position of last param separator.
		$ParamValue=@() #Here will store current parameter values!
		$CurrentParam=""; #Here will store current parameter name.
		[object]$TmpValue=""; #Temporary stores a object of a speific type other than string.
		$TempArrayValues=@(); #Temporary array that will store cluster values arrayis
		$inArrayMode = $false; #Indicates that values separator was specified and values get assigned to same arrya in last position

		$Stop = $false;
		
		$parts | where-object {!$Result.Error -and !$Stop} | foreach-object {
			$i++;
			$TmpValue = $_;

			#Part 0 alwys must be command name!
			if($i -eq 0){
				$CommandName = $_ -replace '^/','';	
				if($CommandName -match '([^@]+)@.+'){
					$CommandName = $matches[1];
				}
				$Result.CommandName = $CommandName;

				if($CommandOnly){
					$Stop = $true;
				}

				return;
			}
		
			#Before any other check, we must verify if we inside a string delimiter.
			#If yes, we must append part value to the string buffer!
			if($InString){
		
				#If the current part is a string delimiter, then, we must end the delimiter and add buffer to ParamValue.
				#Also, we must initialize buffers to avoid previous value be used with next string!
				if($_ -eq $DCP_SEPARATOR_STRING){
					$InString = $false;
					$TmpValue = $StrBuff;
					$StrBuff="";
				} else {
					#Just append current part to the buffer!
					$StrBuff += $_;
					return;
				}
				
				
			}
			#If current part is the parameter separator, then we must assign all values to parameter slot, if aaplicable and reset parameter names and values vars...
			elseif($_ -match "$DCP_SEPARATOR_PARAMETER+"){
				$LastSeparatorPart = $i;
				#Part 1 is the CommandName. Because this, we just need make somehting if we are higher the part 2...
				if($i -ge 2){
					#At this point we are ending interpreting some parameter value.
					#Lets set it to correspoding slot!
					$Result.Arguments[$CurrentParam] += [Object[]]@($ParamValue);
				} 
		
				#Now, its time to initaliza vars!
				$CurrentParam="";
				$ParamValue=@();
				$inArrayMode=$false;
				return;
			}
			#If part is parameter value separator, then the previous part was a parameter name. Because previous part was stored in ParamValue var, we just get it!
			#Because previous part was a parameter name, we must reset paramvalue var.
			elseif($_ -eq $DCP_SEPARATOR_PARAMVALUE){
		
				#Here, we must gurantee that $ParamValue have just one item.
				#If more, means that a values separator was used in parameter part.
				#This is a error!
				if($inArrayMode){
						#Build error!
		
						#($LastSeparatorPart+1)
						$CommandUpToErr     = -Join $Parts[0..$i];
						$LengthUpParamName  = (-Join $Parts[0..$LastSeparatorPart+1]).Length;    
						$ErrorCursor        = "-" * ($LengthUpParamName-1) + "^"
						$Result.error = @(
							"Incorrect parameter name!"
							$CommandUpToErr    
						) -Join "`r`n";
		
						return;
				}
		
				#Here, for cases where user dont specify a name. We will consider like no values...
				if($ParamValue.count -eq 0){
					$CurrentParam = "";
				} else {
					$CurrentParam = $ParamValue[0];
				}
		
				$ParamValue = @();
				$inArrayMode=$false;
				return;
			}
			#If current part is string separator, at this point of code, we not inside a delimiter.
			#THen, this marks a starting string delimiter!
			elseif($_ -eq $DCP_SEPARATOR_STRING){
				$InString = $true;
				$LastOpenStringPart = $i; #Record the part number where we open the string for reports!
				return;
			}
			#If current part is the values separator we just passes to next!
			elseif($_ -eq $DCP_SEPARATOR_VALUES){
				#Creates a new slot on param values!				
				$inArrayMode = $true;
				return;
			}
			#Because the way we split the parts, some parts will a empty string. Ex.: :" (param separator followed by string separator. ITs like 1,,2 )
			#We just ingore it!
			elseif($_.length -eq 0){
				return;
			}
			#if the values is a string containing a boolean value...
			elseif( "TRUE","FALSE" -Contains $_.toUpper() ){
				switch($_.ToUpper()){
					"TRUE" {
						$TmpValue = $true;
					}

					"FALSE" {
						$TmpValue  = $false;
					}
				}
			}
			#If have dots, check if value can be converted to decimal!
			elseif( $_ -like "*.*" ){
				$TmpValue = $_ -as [decimal]
				if(!$TmpValue){
					$TmpValue = $_;
				}
			}
			else {
				#If is a number, convert uses number!
				$TmpValue = $_ -as [int]
				if(!$TmpValue){
					$TmpValue = $_;
				}
			}

			#If in array mode, get eachs value and put in the last array position!
			if( $inArrayMode ){
				$ParamValue[-1] = @($ParamValue[-1]) + @($TmpValue);
				return;
			} else {
				#Concatenates de raw string value!
				$ParamValue += $TmpValue;
			}

		}
		

		#If arrive at this point and inString open, a error exist!
		if(  $InString ){
		
			$CommandUpToErr = -Join $Parts[0..$LastOpenStringPart];
			$ErrorCursor    = "-" * ($CommandUpToErr.Length-1) + "^"
		
			$Result.error = @(
				"Unclosed string"
				$CommandUpToErr   
			) -Join "`r`n";
		}

	

		return $Result;
		
	}
	
	#Gets only command name from a command!
	Function PsCmdBot_DCP_GetCommandName {
		param($message)
		
		$text = $message.text;
		
		$CommandInfo = PsCmdBot_DCP_ParseCommand $message -CommandOnly;

		return $CommandInfo.CommandName;
	}
		
# CONFIGURATION MANAGEMENT
	Function PsCmdBot_CM_GetConfiguration {
		param($Path = $null)

		if($Path -eq $null){
			return $Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE;
		} else {
			$Effective 	= $Global:PSCmdBot_Storage.CONFIGURATION.EFFECTIVE;
			$Current	= $Effective;

			$Path -Split '\.' | ?{$Current} | %{
				if( $Current.Contains($_) ){
					$Current = $Current[$_];
				} else {
					$Current = $null;
				}
			}

			return $Current;
		}

		
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
		$Stor = PsCmdBot_Stor_GetStorage;
		$ConfigurationStore = $Stor.CONFIGURATION;
		$WorkingDirectory = PsCmdBot_GetWorkingDirectory;
		
		$UserConfigFile = "$WorkingDirectory$($DirSep)config.ps1";
		
		#Gets  last modify of last successfully read...
		$LastModifiedTime =  $ConfigurationStore.USER.LAST_FILE_MODIFIED;
		
		if($ConfigurationStore.FIRST_USERCONFIG_CHECK -eq $false){
			$ConfigurationStore.FIRST_USERCONFIG_CHECK = $true;
			PsCmdBot_Log "The expected user configuration file is $UserConfigFile" 
		}
		
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
			return (& "$PsCmdBot_ModuleRoot\default.config.ps1");
		} catch {
			throw "PSCMDBOT_CONFIGURATIONMANAGER_GETDEFAULTCONFIG_ERROR: $_"
		}
	}

	Function PsCmdBot_CM_GetRuntimeConfig {
		$Stor = PsCmdBot_Stor_GetStorage;
		return $Stor.CONFIGURATION.RUNTIME;
	}

	Function PsCmdBot_CM_ModifyConfigRuntime {
		param($ConfigPath, $Value, [switch]$Unset)

		$CurrentRuntime	= PsCmdBot_CM_GetRuntimeConfig;

		if($ConfigPath -like "GLOBAL.ADMIN.*"){
			$ex = PSCmdBot_GetNewException -ID 'INVALID_GLOBAL_ADMIN_OPTION_CHANGE' -Msg "Cannot change a GLOBAL.ADMIN.* option!"
			PsCmdBot_Log "ATTENTION: Someone tried change global admin option!" "PROGRESS"
			throw $Ex;
		}

		#Splits each part...
		$Parts = $ConfigPath -split "\.";

		#Build the path!
		if($Parts.count -gt 1){
			$Limit = $Parts.count - 2;

			$i = 0;
			while($i -le $Limit){
				$PartName 	= $Parts[$i];
				$PartExists = $CurrentRuntime.Contains($PartName)

				#If the part not exists, then, no more check are necessary!
				if(!$PartExists -and $Unset){
					$CurrentRuntime = $null;
					break;
				}

				if(!$PartExists){
					$CurrentRuntime.add($PartName, @{});
				}

				$CurrentRuntime = $CurrentRuntime[$PartName];
				$i++;
			}


		}

		$LastPart = $Parts[-1];

		if($Unset -and $CurrentRuntime -ne $null){
			if($CurrentRuntime.Contains($LastPart)){
				$CurrentRuntime.remove($LastPart);
			}
		}

		if(!$Unset){
			$CurrentRuntime[$LastPart] = @($Value);
		}

		PsCmdBot_Log "	Runtime configuration changed. Path:$ConfigPath Unset:$Unset" "DETAILED";

		#Merging into!
		PSCmdBot_CM_UpdateConfig -Runtime;
	}


	Function PsCmdBot_CM_GetHandlersDefaultConfig {
		PsCmdBot_Log "Loading default handlers config" "DETAILED";
		$Stor = PsCmdBot_Stor_GetStorage;
		$HandlersList = $Stor.HANDLERS.HANDLERS_LIST;
		$HandlersConfig = @{}

		$HandlersList.GetEnumerator() | %{
			if($_.Value.CONFIG -is [hashtable]){
				$HandlersConfig.add($_.Key, $_.Value.CONFIG );
			}
			
		}

		return $HandlersConfig;

	}
	
	Function PSCmdBot_CM_UpdateConfig {
		param([switch]$FirstTime = $false, [switch]$Runtime)
	
		$Stor = PsCmdBot_Stor_GetStorage;
		$ConfigStor = $Stor.CONFIGURATION;
		
		PSCmdBot_Log_SetDefaultLevel "DETAILED";
		$DefaultConfig	= PsCmdBot_CM_GetDefaultConfig;
		$ConfigStor.DEFAULT = $DefaultConfig;
		#Expands the default!
		PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $DefaultConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS


		if( (PsCmdBot_CanLog "DEBUG") -and $Stor.DEBUG_OPTIONS.DUMP_DEFAULT_CONFIG){
			PsCmdBot_Log "	Current expanded *default* config: $(PsCmdBot_Object2HashString $DefaultConfig -Expand)" "DEBUG"
		}

		
		if($FirstTime){
			#Expands the handlers default, and merges into the default!
			$HandlersDefaultConfig 		= PsCmdBot_CM_GetHandlersDefaultConfig;
			PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $HandlersDefaultConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS
			$DefaultConfig.HANDLERS	= PsCmdBot_CM_MergeConfig -Config1 $HandlersDefaultConfig -Config2 $DefaultConfig.HANDLERS;

			PsCmdBot_Log "	The handlers default config was merged into default: $(PsCmdBot_Object2HashString $DefaultConfig.HANDLERS -Expand)" "DETAILED"
			
			$CurrentConfig = $DefaultConfig.psobject.copy();
			$ChangedConfig = $DefaultConfig.psobject.copy();
			PSCmdBot_Log "First time configuration load!"
			$ConfigStor.FIRST_USERCONFIG_CHECK = $true; #Resets in order to load user configuration!
			$ConfigStor.USER.LAST_FILE_MODIFIED = $null
		} else {
			#Have updates?
			$UserConfig 	= PsCmdBot_CM_GetUserConfig;
			$Reasons		= @()
			
			if($Runtime){
				$Reasons += "RUNTIME"
			}

			if($UserConfig){
				$Reasons += "USERCONFIG"
			}

			if(!$Reasons){
				return;
			}

			PSCmdBot_Log "	Configuration was changed. Reloading. Reasons: $Reasons" "DETAILED"

			#Gets the RunTime!
			$RuntimeConfig = PsCmdBot_CM_GetRuntimeConfig;
			#Expands!
			PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $RuntimeConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS;


			#User config check!
			if($UserConfig){
				#Expanding!
				PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $UserConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS
				$ConfigStor.USER.CONFIG = $UserConfig;
			} else {
				$UserConfig  = $ConfigStor.USER.CONFIG;
			}

			$SourceConfig =  PsCmdBot_CM_MergeConfig -Config1 $UserConfig -Config2 $RuntimeConfig;

			#In this part will update the handlers default config in the 
			#Expands the handlers default, and merges into the default!
			$HandlersDefaultConfig 		= PsCmdBot_CM_GetHandlersDefaultConfig;
			PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $HandlersDefaultConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS
			$DefaultConfig.HANDLERS	= PsCmdBot_CM_MergeConfig -Config1 $HandlersDefaultConfig -Config2 $DefaultConfig.HANDLERS;


			$CurrentConfig = PsCmdBot_CM_MergeConfig -Config1 $DefaultConfig -Config2 $SourceConfig;


			$CurrentConfigMasked = PsCmdBot_HashSensitiveMask -Hash $CurrentConfig -SensitiveList $CurrentConfig.GLOBAL.ADMIN.SENSITIVE_CONFIG_KEYS
			PsCmdBot_Log "	Current expanded config: $(PsCmdBot_Object2HashString $CurrentConfigMasked -Expand)" "DEBUG"

			$EffectiveMasked = PsCmdBot_HashSensitiveMask -Hash $ConfigStor.EFFECTIVE -SensitiveList $CurrentConfig.GLOBAL.ADMIN.SENSITIVE_CONFIG_KEYS
			PsCmdBot_Log "	Last config: $(PsCmdBot_Object2HashString $EffectiveMasked -Expand)" "DEBUG"

			#Generate only the change keys!
			$ChangedConfig = PsCmdBot_HashDiff -Table1 $ConfigStor.EFFECTIVE -Table2 $CurrentConfig -RemovedDefault $DefaultConfig;
			#Expand the paths!
			PsCmdBot_ExpandDirs -BasePath (PsCmdBot_GetWorkingDirectory) -Table $ChangedConfig -KeyNames $ConfigStor.EXPANDABLE_DIR_KEYS
		}
					
		if(!$FirstTime -and $ChangedConfig.count -gt 0){
			$ChangedMasked = PsCmdBot_HashSensitiveMask -Hash $ChangedConfig -SensitiveList $CurrentConfig.GLOBAL.ADMIN.SENSITIVE_CONFIG_KEYS
			PSCmdBot_Log "	Configuration changed: $(PsCmdBot_Object2HashString $ChangedMasked -Expand)"
		}


		if(!$ConfigStor.EFFECTIVE){
			$ConfigStor.EFFECTIVE = $DefaultConfig;
		}
		
		$ConfigStor.LAST = $ConfigStor.EFFECTIVE.psobject.copy();
		$ConfigStor.EFFECTIVE = $CurrentConfig;

		#Invokes the configurations updates subscribers.
		#The notify subcrisbers engine is need becase not only handlers can subscriber to them.
		#Others components can!
		PsCmdBot_CM_NotifySubscribers $ChangedConfig
	}

	Function PsCmdBot_CM_AddSubscription {
		param($Name, $Script)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ConfigStor = $Stor.CONFIGURATION;
		
		$ConfigStor.CHANGE_SUBSCRIBERS += New-Object PsObject -Prop @{Name=$Name; Script=$Script};
	}
	
	#Forces susbcribers executes your script to changed configuration!
	#The default parameter send the default configuration (first time loading)
	Function PsCmdBot_CM_NotifySubscribers {
		param($Config)
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$ConfigStor = $Stor.CONFIGURATION;
		
		#Invokes the configurations updates subscribers.
		if($ConfigStor.CHANGE_SUBSCRIBERS){
			PSCmdBot_Log "There are log change subscribers. Invoking it..." "VERBOSE"
		
			$ConfigStor.CHANGE_SUBSCRIBERS | %{
				PSCmdBot_Log "	Calling the subscriber $($_.Name)" "VERBOSE"
				& $_.Script $Config;
			}
		}

		#Fires CHANGED_CONFIG for invoke handlers subscription!
		PsCmdBotI_Handler_FireEvent "CONFIG_CHANGE" -ExtraParams @{ChangedConfig=$ChangedConfig};
	}

	




# MESSAGE HANDLERS
	Function NewHandlerResult {
		param($Handler)
		
		if(!$Handler){
			$Ex = PSCmdBot_GetNewException -ID 'HANDLERRESULT_NEW_EMPTYHANDLER';
			throw $Ex;
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
	
	
	Function PSCmdBot_InitializeHandlers {
		[CmdLetBinding()]
		param()
		
		PSCmdBot_Log_SetDefaultLevel "VERBOSE";
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$HandlerSlot = $Stor.HANDLERS
		$TELEGRAM_HANDLER_DEFINITIONS = $HandlerSlot.DEFINITIONS;
		$HANDLERS = $HandlerSlot.HANDLERS_LIST;
		
		$TELEGRAM_HANDLER_DEFINITIONS.GetEnumerator() | %{
			$HandlerName = $_.Key;
			$HandlerDefinition = $_.Value;
			
			if($HANDLERS.Contains($HandlerName)){
				return;
			}
			
			PSCmdBot_Log "$($MyInvocation.InvocationName): Initializing handler $HandlerName"
			
			#Turn keys in definition into handlers methods and properties...
			$Handler = New-Object PSObject;
			$HandlerDefinition.GetEnumerator() | %{
				$DefinitionMemberName 	= $_.Key;
				$DefinitionMemberValue 	= $_.Value;
				
				#Script block that starts with "ON_" are executed in context of event firing. Because this it cannot be a method! 
				# First parameter is the handler object! If it are method, any things created inside it (like functions) we live just only method runs! This is not indeed behavior.
				#We want the ON_START events able to allow handler writers add functions to current session.
				#It responsbility of them to do all rights!
				#It responsinility of user choose handlers that no unstable engine! If w handler do this, it cannot be a trust handler!
				if($DefinitionMemberValue -is [scriptblock] -and  -not($DefinitionMemberName -like 'ON_*') ){
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
			#Check doc/DEFAULTAUTHORIZATIONCHECK.md for details!
			if(!$Handler.IS_AUTHORIZED){
				$Handler | Add-Member -Type ScriptMethod -Name 'IS_AUTHORIZED' -Value {
					param($message)
					
	
					#Gets current configurations
					$CurrentConfig = PsCmdBot_CM_GetConfiguration;



					#If not defined a configuration for the current handler!
					if( $CurrentConfig.HANDLERS.Contains($this.NAME) ){
						$HandleConfig = $CurrentConfig.HANDLERS[$this.NAME];
						if(PsCmdBot_CanLog "DEBUG"){
							PsCmdBot_Log "	Current handler config key exist!" "DEBUG"
						}
					} else {
						$HandleConfig = @{};
					}
					

					#Gets the authorized users for current command
					if( $HandleConfig.Contains('COMMANDS') ){
						$AllCommandConfigurations = $CurrentConfig.HANDLERS[$this.NAME].COMMANDS;
						if(PsCmdBot_CanLog "DEBUG"){
							PsCmdBot_Log "	COMMANDS key exist!" "DEBUG"
						}
					} else {
						$AllCommandConfigurations = @{}
					};

					#Gets current command name!
					$CurrentCommand = PsCmdBot_DCP_GetCommandName $message;
					$RealCommand	= $this.getRealCommandName($CurrentCommand)
					$CommandConfigurations = $AllCommandConfigurations[$RealCommand];

					if($CommandConfigurations){
						if(PsCmdBot_CanLog "DEBUG"){
							PsCmdBot_Log "	Command configuration exist. Getting permissions from it!" "DEBUG"
						}
						$AuthorizedUsers 	= @($CommandConfigurations['AUTHORIZED_USERS']);
						$DeniedUsers 		= @($CommandConfigurations['DENIED_USERS']);
					} else {
						$AuthorizedUsers 	= @();
						$DeniedUsers 		= @();
					}

					#Default global fo handler...
					if( $AllCommandConfigurations.Contains('*') ){
						if(PsCmdBot_CanLog "DEBUG"){
							PsCmdBot_Log "	* exists for this handler!" "DEBUG"
						}
						$DeniedUsers  += @($AllCommandConfigurations['*'].DENIED_USERS);
						$AuthorizedUsers +=  @($AllCommandConfigurations['*'].AUTHORIZED_USERS);
					}


					#Check if user is explicity denied!
					$IsDenied = $DeniedUsers -Contains $message.from.username -or $DeniedUsers -eq '*';

					if($IsDenied){
						if(PsCmdBot_CanLog "DEBUG"){
							PsCmdBot_Log "	The current command execution is explicity denied!" "DEBUG"
						}
						
						return $false;
					}
					
					$IsAuhtorized = $AuthorizedUsers -Contains $message.from.username -or $AuthorizedUsers -eq '*';

					if($IsAuhtorized){
						return $true;
					}

					
					if(PsCmdBot_CanLog "DEBUG"){
						PsCmdBot_Log "	The current command execution is implicity denied!" "DEBUG"
					}
					return $false;
				}
			
			}
			
			#Default CHECK_COMMAND method
			if(!$Handler.CHECK_COMMAND){
				$Handler | Add-Member -Type ScriptMethod -Name 'CHECK_COMMAND' -Value {
					param($message = $null, $command = $null)
					
					#Gets current command name!
					if($command){
						if(PsCmdBot_CanLog "VERBOSE"){
							PsCmdBot_Log "	Check Command: $Command --> $($this.SupportedCommandNames)" "VERBOSE"
						}

						return $this.SupportedCommandNames -Contains $command;
					} else {
						$CurrentCommand = PsCmdBot_DCP_GetCommandName $message;
						return $this.SupportedCommandNames -Contains $CurrentCommand;
					}
					
						
				}
			
			}
			
			
			#Builds a static list of supported commands names and its alias.
			$Handler | Add-Member -Type noteproperty -Name SupportedCommandNames -Value $null -force;
			$Handler.COMMANDS.GetEnumerator() | %{
				[string[]]$Names = @($_.Key);
				
				if($_.Value.ALIAS){
					$Names += @($_.Value.ALIAS)
				}
				
				$Handler.SupportedCommandNames += @($Names);
			}
			
			#Buils a alias map to speed up searches...
			$Handler | Add-Member -Type noteproperty -Name Aliases -Value @{} -Force;
			$Handler.COMMANDS.GetEnumerator() | %{
				if($_.Value.ALIAS){
					$CommandName = $_.Key;
					$_.Value.ALIAS | %{
						$Handler.Aliases.add($_, $CommandName); 
					}
				}
			}
			
			#Get real command name, if alias.
			$Handler | Add-Member -Type ScriptMethod -Name getRealCommandName -Value {
				param($name) 
				
				if($name -and $this.Aliases[$name]){
					return $this.Aliases[$name]
				} else {
					return $name;
				}

				
			}

			#Check auhtorizaton on chat!
			$Handler | Add-Member -Type ScriptMethod -Name _CHAT_AUTHORIZED -Value {
				param($update)

				$CurrentConfig = PsCmdBot_CM_GetConfiguration;

				if($CurrentConfig.GLOBAL.SECURITY.DISABLE_CHATID_CHECK -eq $true){
					if(PsCmdBot_CanLog "DEBUG"){
						PsCmdBot_Log "	The user handlers was auhtorized on this chat due to DISABLE_CHATID_CHECK option! This is bad =(" "DEBUG"
					}
					return $true;
				}
				
				[string[]]$SYSTEM_HANDLERS = 'AUXCMDS';

				if(  $SYSTEM_HANDLERS -Contains $this.NAME  ){
					$GroupsAuthorizeds 	= $CurrentConfig.GLOBAL.SECURITY.SYSTEMHANDLERS_CHATS | ? {$_ -match '^-?\d+$'-or $_ -eq "*"};
					$UserAuthorizeds	= $CurrentConfig.GLOBAL.SECURITY.SYSTEMHANDLERS_CHATS | ? {$_ -match '^@'};
				} else {
					$GroupsAuthorizeds = $CurrentConfig.GLOBAL.SECURITY.USERHANDLERS_CHATS | ? {$_ -match '^-?\d+$' -or $_ -eq "*"};
					$UserAuthorizeds	= $CurrentConfig.GLOBAL.SECURITY.USERHANDLERS_CHATS | ? {$_ -match '^@'};
				}

				if(PsCmdBot_CanLog "DEBUG"){
					PsCmdBot_Log "	GroupsAuthorized: $GroupsAuthorized. UserAuthorizeds: $UserAuthorizeds" "DEBUG"
				}

				$IsFromAuthorizedUser = @($UserAuthorizeds) -Contains ("@"+$update.message.from.username) -and $update.message.chat.type -eq "private"

				if($IsFromAuthorizedUser){
					return $true;
				}
				
				return ($GroupsAuthorizeds -Contains $update.message.chat.id -or $GroupsAuthorizeds -eq '*');	
			}
			
			#Get handler effective config!
			$Handler | Add-Member -Type ScriptMethod -Name getMyConfig -Value {
				$CurrentConfig = PsCmdBot_CM_GetConfiguration;

				return $CurrentConfig.HANDLERS[$this.NAME];
			}

			<#
			if($Handler.ON_CONFIG_CHANGE){
				PsCmdBot_CM_AddSubscription -Name "Handler:$HandlerName" -Script ({
						param($Changed) & $Handler.ON_CONFIG_CHANGE @{$Changed}
					}.GetNewClosure())
			}
			#>
			
			$HANDLERS.add($HandlerName, $Handler);
		}
	
	
	
	} 
	
	Function PSCmdBot_LoadHandlers {
		[CmdLetBinding()]
		param()
		
		PSCmdBot_Log_SetDefaultLevel "DETAILED";
		
		$Stor = PsCmdBot_Stor_GetStorage;
		$HandlerSlot = $Stor.HANDLERS
		
		
		#Current WorkingDirectory
		$WorkingDirectory = PsCmdBot_GetWorkingDirectory;
		$MsgHandlerExtension = '.msghandler.ps1'
		$MessageHandlersScripts = $Stor.PATHS.DEFAULT_MESSAGE_HANDLERS_DIR+$DirSep+'*'+$MsgHandlerExtension
		
		PSCmdBot_Log "$($MyInvocation.InvocationName): handlers path  $MessageHandlersScripts"
		$HandlersToLoad = @(gci $MessageHandlersScripts);
		
		#User message handler!
		$UserHandlersDir = $WorkingDirectory+$DirSep+'msghandlers'
		PSCmdBot_Log "Expected user handlers path  $UserHandlersDir"
		
		if( [IO.Directory]::Exists($UserHandlersDir) ){
			$UserHandlersLoadPath = $UserHandlersDir+$DirSep+"*$MsgHandlerExtension";
			PSCmdBot_Log "	UserHandlersLoadPath: $UserHandlersLoadPath" "PROGRESS"
			$HandlersToLoad += gci $UserHandlersLoadPath;
		}

		PSCmdBot_Log "$($MyInvocation.InvocationName): Loading handlers definitions..."
		$HandlersToLoad | %{
			$HandlerName = $_.Name.replace($MsgHandlerExtension,'');
			$HandlerDefinition = & $_.FullName;
			
			PSCmdBot_Log "$($MyInvocation.InvocationName): Discovered handler $HandlerName from $($_.FullName)"
			
			
			if(!$HandlerSlot.DEFINITIONS.Contains($HandlerName)){
				$HandlerSlot.DEFINITIONS.add($HandlerName, $HandlerDefinition);
				PSCmdBot_Log  "	Loaded sucessfully!"
			}
			
		}
		
	
		PSCmdBot_InitializeHandlers
	}
	
	#Finds the command the current message apply to!
	Function PsCmdBot_GetMessageHandler {
		param($Message)
		
		PSCmdBot_Log "Determining the message handler!" "VERBOSE"
		
		
		$Stor 			= PSCmdBot_Stor_GetStorage;
		$HANDLERS		= $Stor.HANDLERS.HANDLERS_LIST;
		$ListenerEntry = PsCmdBot_ReplyListener_CheckMessage $Message;
		
		if($ListenerEntry){
			$ListenerEntry.Handler.SOURCE = "REPLY_LISTENER";
			return $ListenerEntry.Handler;
		}
		
		
		$CommandName = PsCmdBot_DCP_GetCommandName $message
		
		if(PsCmdBot_CanLog "VERBOSE"){
				PSCmdBot_Log "	Command is: $CommandName" "VERBOSE"
		}
		
		$ElegibleHandler = 	$HANDLERS.Values | ? {  
			
			if(PsCmdBot_CanLog "VERBOSE"){
				PSCmdBot_Log "	Checking if handle $($_.NAME) can handle!" "VERBOSE"
			}
			
			$_.CHECK_COMMAND($null,$CommandName)  
		} | sort-object PRIORITY -Desc | Select-Object -first 1;
		
		if($ElegibleHandler){
			$ElegibleHandler.SOURCE = "COMMAND";
			return $ElegibleHandler;
		} else {
			return $null;
		}
		
		
		
	}
		
	#Triggers handles event
	Function PsCmdBotI_Handler_FireEvent {
		[CmdLetBinding()]
		param($EventName, $ExtraParams = $null, [switch]$DotSourced = $false)

		if(PsCmdBot_CanLog "DEBUG"){
			PsCmdBot_Log "Fire handler event $EventName" "DEBUG"
		}

		$EventPropName = "ON_"+$EventName;
		$Stor = PsCmdBot_Stor_GetStorage;
		$Handlers = $Stor.HANDLERS;


		$HandlersNames 	= @($Handlers.HANDLERS_LIST.Keys);
		$i				= $HandlersNames.count;
		[hashtable]	$FullParams = $null;

		while($i--){
			$HandlerName = $HandlersNames[$i];
			$Handler = $Handlers.HANDLERS_LIST[$HandlerName];

			if(PsCmdBot_CanLog "DEBUG"){
				PsCmdBot_Log "	Checking if $EventPropName there are on handler $HandlerName" "DEBUG"
			}

			#Property must be a scriptblock!
			$EventScript = $Handler.psobject.properties[$EventPropName].Value;
			
			if(!$EventScript -or -not($EventScript -is [scriptblock])){
				continue;
			}

		
			if(PsCmdBot_CanLog "DEBUG"){
				PsCmdBot_Log "	Firing for handler $HandlerName" "DEBUG"
			}

			$FullParams = @{Handler=$Handler;Params=$ExtraParams};

			if($DotSourced){
				. $EventScript $FullParams
			} else {
				& $EventScript $FullParams
			}
			
		}


		<#
		$Handlers.HANDLERS_LIST.GetEnumerator() | %{
			$HandlerName = $_.Key;
			$Handler = $_.Value;

			#Property must be a scriptblock!
			$EventScript = $Handler.psobject.properties[$EventPropName];

			if(!$EventScript -or -not($EventScript -is [scriptblock])){
				return;
			}

		
			if(PsCmdBot_CanLog "DEBUG"){
				PsCmdBot_CanLog "	Firing for handler $HandlerName" "DEBUG"
			}

			. $EventScript @{Handler=$Handler}
		}
		#>



	}
	
# DEBUG OPTIONS

	Function PsCmdBot_SetDebugOptions {
		param($Options)

		#Debug options
		#This will update the debug options.
		#The debug options controls behaviors of script like add certain outpus in logging message!
		#Check doc/DEBUGGGING.md for a complete reference of this.
		#Because this is indeed to be used by PsCmdBot development team, using this options is not encourajed and some can be undocumented!
		
		$Storage = PsCmdBot_Stor_GetStorage;
		$Storage.DEBUG_OPTIONS  = $Options;
	}
	
	
# THE BOT MAIN
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
	
		[hashtable]$Parameters = @{}
		
		try {
			#Get the user config
			PsCmdBot_SetWorkingDirectory $WorkingDirectory
			

			##Sets start time!
			PSCmdBot_Log "Setting bot start time"
			PSCmdBot_SetStartTime

			#Notify all subscribers of configuration about first loading!
			PSCmdBot_Log "First time configuration load"
			PSCmdBot_CM_UpdateConfig -FirstTime;

			#loading the handlers of messages! 
			PSCmdBot_Log "Loading the message handlers"
 			PSCmdBot_LoadHandlers;		

			
			#Merges config to determine current configuration!
			#Updates the configuration!
			$GetCurrentConfigScript = {
				PSCmdBot_Log "Updating configuration..." "VERBOSE"
				PSCmdBot_CM_UpdateConfig
				return (PsCmdBot_CM_GetConfiguration);
			}

			#CurrentCofnig
			PSCmdBot_Log "Updating configuration!"
			$CurrentConfig = & $GetCurrentConfigScript;

			
			PSCmdBot_Log "Getting toke!"
			if($token){
				PSCmdBot_Log "	Setting the default!"
				Set-DefaultToken -token $token;
			} else {
				PSCmdBot_Log "	Getting a new token!"
				$token = Get-BotToken;
			}

			. PsCmdBotI_Handler_FireEvent "START" -DotSourced;

			PSCmdBot_Log "Starting waiting for updates. Token: $token" "PROGRESS";
			
			#Script to be used when priting a a message object!
			$PrintMessageScript = {
				$Configuration = PsCmdBot_CM_GetConfiguration
				$MessageConfig = $Configuration.GLOBAL.MESSAGES;
				$CanVerboseLog = PsCmdBot_CanLog "VERBOSE";
				
				if($MessageConfig.LOG -or $CanVerboseLog){
					PSCmdBot_Log "	##TELEGRAM_MESSAGE: $($_.simpleMessage)" "PROGRESS"
					
					if( $MessageConfig.LOG_FILE  ){
						try {
							if($CanVerboseLog){
								PSCmdBot_Log "	Logging message to file $($MessageConfig.LOG_FILE)" "VERBOSE"
							}
							
							if($MessageConfig.LOG){
								$_.simpleMessage >> $MessageConfig.LOG_FILE;
							}
						} catch {
							PSCmdBot_Log "	Cannot log message to file $($MessageConfig.LOG_FILE): $_" "PROGRESS"
						}
					}
					
				}
			};
			
			$FailuresCount = 0;
			$LastUpdate = 0;
			while($true){
				try {
					#CurrentCofnig
					$CurrentConfig = & $GetCurrentConfigScript;
					
					
					PSCmdBot_Log "Getting updates... (Offset: $LastUpdate)" "DEBUG"

					PSCmdBot_Log "Waiting for telegram updates..." "VERBOSE"
					$HadUpdates = $false;
					$resultado = Get-TelegramUpdates -offset $LastUpdate
					
					#For each updates...
					if($resultado){
						$HadUpdates = $true;
						PSCmdBot_Log " There are new updates. Starting handling. Count: $($resultado.count)" "DEBUG"
					
						$resultado | %{
							$u = $_;
							$LastUpdate = $u.update_id;
							
							PSCmdBot_Log " Processing update $LastUpdate" "VERBOSE"
							
							if($u.message){
								$m = $u.message;

								#Check if user is a super admin!
								$MsgFromSuper = $CurrentConfig.GLOBAL.ADMIN.SUPER_ADMINS -Contains $m.from.username;
								if($MsgFromSuper){
									if(PsCmdBot_CanLog "DEBUG"){
										PSCmdBot_Log "Current message comes from a super!" "DEBUG"
									}
								}
							
								if(PsCmdBot_CanLog "VERBOSE"){
									PSCmdBot_Log "Update is a message! MessageID: $($m.message_id)" "VERBOSE"
								}
								
								
								#Prints the received message!
								PSCmdBot_PrintTelegramMessage $m $PrintMessageScript
								
								
								#Get the message handler!
								PSCmdBot_Log "Checking the message handler..." "DEBUG"
								$HandlerResult	= $null;
								$MessageHandler = PsCmdBot_GetMessageHandler $m;
														
								if(!$MessageHandler){
									$Ex = PSCmdBot_GetNewException -ID 'PSCMDBOT_NOHANDLER';
									throw $Ex
									return;
								}
								PSCmdBot_Log "Handler choosed: $($MessageHandler.NAME). Source:$($MessageHandler.SOURCE)" "DEBUG"

								if(!$MessageHandler._CHAT_AUTHORIZED($u)){
									$HandlerResult = NewHandlerResult $MessageHandler;
									$HandlerResult.mustReply = $true;
									$HandlerResult.reply.message = "This chat is not authorized process this command!";
								} 
								elseif(!$MessageHandler.IS_AUTHORIZED($m) -and $MessageHandler.SOURCE -eq "COMMAND" -and !$MsgFromSuper ) {
									$HandlerResult = NewHandlerResult $MessageHandler;
									$HandlerResult.mustReply = $true;
									$HandlerResult.reply.message = "Você não está autorizado a executar este comando";
								}
								else {
									#CanRun!
									PSCmdBot_Log "Invoking handler..." "VERBOSE"
									try {
										$HandlerResult = $MessageHandler.HANDLER($u);
										if(!$HandlerResult){
											$Ex = PSCmdBot_GetNewException -ID 'HANDLER_NORESULT' -Inner $_;
											throw $Ex
											return;
										}
									} catch {
										$Ex = PSCmdBot_GetNewException -ID 'HANDLER_FAIL' -Inner $_;
										throw $Ex
									}
								}

								if(PsCmdBot_CanLog "DEBUG"){
									PSCmdBot_Log "HandlerResult: $(PSCmdBot_Object2HashString $HandlerResult -Expand)" "DEBUG" 
								}

								#Check if handler wants a reply from bot
								if($HandlerResult.mustReply){
									PSCmdBot_Log "Handler request a reply..." "VERBOSE"
									
									$ReplyText = $HandlerResult.reply.message;
								
									#Replying the message...
									try {
										PSCmdBot_Log "	Sending reply..." "VERBOSE"
										$MessageReplied = Send-TelegramMessage -chat_id $m.chat.id -text $ReplyText -reply_to_message_id $m.message_id
				
										if($HandlerResult.reply.script){
											PsCmdBot_Log "Executing the reply script!" "VERBOSE"
											& $HandlerResult.reply.script $HandlerResult $MessageReplied
										}
										
										PSCmdBot_PrintTelegramMessage $MessageReplied $PrintMessageScript		
									} catch {
										PsCmdBot_Log "Error replying (LastUpdate: $LastUpdate): $_" "PROGRESS";
									}
								}
								
								
								
							} else {
								PSCmdBot_Log "Cannot process current update type! LastUpdate: $LastUpdate" "PROGRESS";
							}
						}

					}
				} catch {
					$FailuresCount++;
					$Formmated = PsCmdBot_FormatExceptions $_ -BaseDir $PsCmdBot_ModuleRoot;
					
					#Log the failure!
					PSCmdBot_Log "Bot exception occurred! Total: $FailuresCount" "PROGRESS";
					PSCmdBot_Log "BOT_EXCEPTION: $Formmated" "PROGRESS";
					
					
					
					$MaxAllowedFailures = 0;
					
					if( $CurrentConfig.GLOBAL.FAILURES.MAX_FAILURES -ne $null){
						$MaxAllowedFailures = $CurrentConfig.GLOBAL.FAILURES.MAX_FAILURES;
					}
					
					if(  $FailuresCount -gt $MaxAllowedFailures -and $MaxAllowedFailures -ge 0 ){
						
						if($CurrentConfig.GLOBAL.FAILURES.NOTIFICATION_CHATID){
							try {
								$m = Send-TelegramMessage -chat_id $CurrentConfig.GLOBAL.FAILURES.NOTIFICATION_CHATID -text "Bot will end because reached maximum failures ($MaxAllowedFailures)"
							} catch {
								try {
									PSCmdBot_Log "Cannot send failure notificaton to $($CurrentConfig.FAILURES.NOTIFICATION_CHATID)";
								} catch {
									
								}
							}
						}

						
						PSCmdBot_Log "Bot will end because reached maximum failures! (Max: $MaxAllowedFailures)";
						break;
					}
					
				} finally {
					if($HadUpdates){
						#Increments the LastUpdate to next, because updates have fetched!
						$LastUpdate++;	
					}

				}

				
				PSCmdBot_Log "Sleeping before new attempt!" "VERBOSE"
				Start-Sleep -s 1
			}
		} catch {
			$ex = PSCmdBot_GetNewException -ID 'STARTCMDBOT_BUG' -Msg "Exception ocurred in Start-CmdBot! If you dont changed original files, disable all handlers or download original code. If problems persist, contact the developer." -Inner $_;
			$Formmated = PsCmdBot_FormatExceptions $ex -BaseDir $PsCmdBot_ModuleRoot; 
			PSCmdBot_Log $Formmated "PROGRESS";
			throw $ex;
		}

	
	}
	



	
# MODULE INITILIZATION
	PsCmdBot_Initialize


# LOGGING INITIALIZATION
	# Levels defintions:
	# PROGRESS 	- Error and progress messages. Must be logged as macro activity.
	# DETAILED 	- General activity  of the bot.
	# VERBOSE 	- Internals calls to auxiliary functions 
	# DEBUG		- Internals calls to all functions.

	PsCmdBot_Depends_ImportModule 'XLogging' -force;
	$PSCmdBotLog = New-LogObject; 
	$PSCmdBotLog.IgnoreLogFail = $False
	. (  $PSCmdBotLog | New-InvokeLogProxy -Name "PSCmdBot_Log" )
	$PSCmdBotLog.LogLevel = "DETAILED"
	$PSCmdBotLog.LogTo	  = @("#",$null) #Loggin to two targets: A file and the screen, (the # means use write-host).
	$PSCmdBotLog.UseDLD = $false #Not use dynamic discovery of the log level.
	PSCmdBot_Log_SetDefaultLevel "PROGRESS"

	Function PsCmdBot_CanLog {
		param($Level)
		
		return $PSCmdBotLog | Test-LogLevel $Level
	}

	#Adds log change configuration subcription
	PsCmdBot_CM_AddSubscription "LOGGING" {
		param($Changed)
		
		PSCmdBot_Log_SetDefaultLevel "PROGRESS";
		
		#Check if log was changed!
		if(!$Changed.Contains('GLOBAL')){
			return;
		}
		
		if(!$Changed.GLOBAL.Contains('LOGGING')){
			return;
		}
		
		if($Changed.GLOBAL.LOGGING.Contains('LEVEL')){
			$NewLevel = $Changed.GLOBAL.LOGGING.LEVEL;
			PSCmdBot_Log "Logging level will change to $NewLevel "
			$PSCmdBotLog.LogLevel = $NewLevel;
			PSCmdBot_Log "Logging level changed due to configuration file reload. Current: $NewLevel"
		}
		
		if($Changed.GLOBAL.LOGGING.Contains('FILE')){
			$NewFile = $Changed.GLOBAL.LOGGING.FILE;
			PSCmdBot_Log "Log file will be change to $NewFile";
			
			if($Changed.GLOBAL.LOGGING.FILE){
				$PSCmdBotLog.LogTo[1] = $Changed.GLOBAL.LOGGING.FILE.toString();
			} else {
				$PSCmdBotLog.LogTo[1] = $null;
			}
			
			PSCmdBot_Log "Logging file changed due to configuration file reload. New file: $NewFile"
		}

		
	}





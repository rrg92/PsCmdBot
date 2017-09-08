$ex = '/CommandName@botname PARAMNAME:VALUE1 PARA,MNAME:"VALUE WITH SPACES" VALUE_DEFAULT_PARAM "value default with spaces" PARAMNAME:"VALUE 1 VALUE 3,VALUE3,';
$FullCommand = $ex;

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

$parts | where-object {!$Result.Error} | foreach-object {
    $i++;

    #Part 0 alwys must be command name!
    if($i -eq 0){
        $CommandName = $_ -replace '^/','';	
        if($CommandName -match '([^@]+)@.+'){
            $CommandName = $matches[1];
        }
        $Result.CommandName = $CommandName;
        return;
    }

    #Before any other check, we must verify if we inside a string delimiter.
    #If yes, we must append part value to the string buffer!
    if($InString){

        #If the current part is a string delimiter, then, we must end the delimiter and add buffer to ParamValue.
        #Also, we must initialize buffers to avoid previous value be used with next string!
        if($_ -eq $DCP_SEPARATOR_STRING){
            $InString = $false;
            $ParamValue += $StrBuff;
            $StrBuff="";
        } else {
            #Just append current part to the buffer!
            $StrBuff += $_;
        }
        
        return;
    }


    #If current part is the parameter separator, then we must assign all values to parameter slot, if aaplicable and reset parameter names and values vars...
    if($_ -match "$DCP_SEPARATOR_PARAMETER+"){
        $LastSeparatorPart = $i;
        #Part 1 is the CommandName. Because this, we just need make somehting if we are higher the part 2...
        if($i -ge 2){
            #At this point we are ending interpreting some parameter value.
            #Lets set it to correspoding slot!
            $Result.Arguments[$CurrentParam] += [Object[]]@($ParamValue);
        } 

        #Now, its time to initaliza vars!
        $CurrentParam="";
        $ParamValue = @();
        return;
    }
    
    #If part is parameter value separator, then the previous part was a parameter name. Because previous part was stored in ParamValue var, we just get it!
    #Because previous part was a parameter name, we must reset paramvalue var.
    if($_ -eq $DCP_SEPARATOR_PARAMVALUE){

        #Here, we must gurantee that $ParamValue have just one item.
        #If more, means that a values separator was used in parameter part.
        #This is a error!
        if($ParamValue.count -gt 1){
                #Build error!

                #($LastSeparatorPart+1)
                $CommandUpToErr     = -Join $Parts[0..$i];
                $LengthUpParamName  = (-Join $Parts[0..$LastSeparatorPart+1]).Length;    
                $ErrorCursor        = "-" * ($LengthUpParamName-1) + "^"

                $Result.error = @(
                    "Incorrect parameter name!"
                    $CommandUpToErr    
                    $ErrorCursor
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
        return;
    }

    #If current part is string separator, at this point of code, we not inside a delimiter.
    #THen, this marks a starting string delimiter!
    if($_ -eq $DCP_SEPARATOR_STRING){
        $InString = $true;
        $LastOpenStringPart = $i; #Record the part number where we open the string for reports!
        return;
    }

    #If current part is the values separator we just passes to next!
    if($_ -eq $DCP_SEPARATOR_VALUES){
        return;
    }

    #Because the way we split the parts, some parts will a empty string. Ex.: :" (param separator followed by string separator. ITs like 1,,2 )
    #We just ingore it!
    if($_.length -eq 0){
        return;
    }

    #At this point, we just reading a arbitrary value. By default, it is treated a parameter value!
    #If it was a parameter name, then, will access this array to get it!
    $ParamValue += $_;
}


#If arrive at this point and inString open, a error exist!
if(  $InString ){

    $CommandUpToErr = -Join $Parts[0..$LastOpenStringPart];
    $ErrorCursor    = "-" * ($CommandUpToErr.Length-1) + "^"

    $Result.error = @(
        "Unclosed string"
        $CommandUpToErr    
        $ErrorCursor
    ) -Join "`r`n";
}
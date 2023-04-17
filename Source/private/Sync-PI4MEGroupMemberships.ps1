#Specifie Input Parameters here.
#All required Parameters
[Object]$RequiredInputParameters = @{
}
#All optional Parameters
[Object]$OptionalInputParameters = @{
}

#Do not edit behind this line without version change.
#-------------------------------------------------------------------------------------------------
#Required Modules specified by name and version.
$RequiredModules=@(
        @{
            Name= "PIPS.4MEConnector"
            Version = "0.142.6"
        } 
        @{
            Name= "PIPS.4MECore"
            Version = "0.216.15"
        }
        @{
            Name="PIPS.Transform"
            Version="0.7.37"
        }
)

#Constant variables
$PSDefaultParameterValues["*:Verbose"]= $true
[STRING]$TransformPath = "C:\Users\NiemannBenjamin\GitRepo\ABC-Automation\Source\bin\GroupMemberShip_transform.json"
$ExtractParamters= @{
    Authorization = @{
            Environment = "Quality"
            Region = "Global"
            Account = "altenloh-it"
            PresharedKey = 'q0GlFU2ly9uxPtSvtJRHLpRfyuHzDOkndanWBOvohKmxffaWFo31UQvj3zfBQi5P1XCpjVSXhtRuvZtSJDj28eMoo6qf6SgtDHC2iwz6lngQbBKZ'
            ResetDefaultCommandParameters = $false
    }
    Relation = "users"
    Filter = "rule_set=license_certificate"
}
#returnObject is the parsed text/xml returned from the script in the very latest step.
[Object]$ReturnObject= @{
    returnMessage = @() 
    returnObject = @()
    returnCode = 0
}

Try{
    
    #region initialize -----------------------------------------------------------------------------------------------------------------------------
    #Initialize logging function. This function does all the logging stuff. including the switch between running/success.
    #Ensure "failed" status is modfied in catch section.
    $ReturnObject.returnMessage += "Initialize logging function: [RUNNING]"
    function Update-LogArray {
        param (
            [ARRAY]
            $ReturnMessages,

            [STRING]
            $Message
        )

        If($returnMessages.Count -ne 0 ){
            #Update LastMessagePosition
            [Int]$LastMessagePosition = $returnMessages.Count - 1

            #Update last status    
            [STRING]$LastMessage = $returnMessages.GetValue($LastMessagePosition)
            $LastMessage = $LastMessage.Replace("[RUNNING]", "[SUCCESS]")

            #Update Log Array
            $returnMessages.SetValue($LastMessage, $LastMessagePosition)
        }

        $returnMessages += [STRING]::Format("{0}: [RUNNING]", $Message)

        #return the messages.
        $returnMessages
        
    } 
    
    #Explizit import of required modules.
    #1 - Clear all modules
    $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message "Clearing all powershell modules"
    Get-Module | Remove-Module
    #2 - Import needed modules.
    foreach($Module in $RequiredModules){
        $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Importe module '{0}' in version '{1}'", $Module.Name, $Module.Version))
        Import-Module -Name $Module.Name -RequiredVersion $Module.Version
    }

    #Valid each required input parameters and throw an error if an parameter is not initalized.
    Foreach($key in $RequiredInputParameters.Keys){
        $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Initialize InputParameter '{0}'", $key))
        if([STRING]::IsNullOrEmpty($RequiredInputParameters.$key) ){
            throw ([STRING]::Format("InputParameter '{0}' is not initialized", $key))
        }
    }

    #Merge all parameter we have, so we can use a single object.
    $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Merge all parameters"))
    [Object]$InputParameters = $RequiredInputParameters
    foreach($key in $OptionalInputParameters.Keys){
        
        if( !([STRING]::IsNullOrEmpty($OptionalInputParameters.$key))){
            
            $InputParameters += @{$key = $OptionalInputParameters.$key}
        }
    }
    
    #endregion -------------------------------------------------------------------------------------------------------------------------------------

    $DataBucket = @{}
    #region Extract 1 ------------------------------------------------------------------------------------------------------------------------------
    $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Extract configuration items from 4me."))
    $ExtractRequest = Extract-PI4MEConfigurationItem @ExtractParamters
    if(!$ExtractRequest.returnSuccess){
        throw($ExtractRequest.returnMessage)
    }
    $DataBucket = $ExtractRequest.returnObject
    #endregion -------------------------------------------------------------------------------------------------------------------------------------

    #region Transform
    $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Transform 4me configuration items to local active directory group memberships."))
    $TransformRequest = $DataBucket | ConvertTo-PITargetFormat -TransformPath $TransformPath
    if(!$TransformRequest.returnSuccess){
        throw($TransformRequest.returnMessage)
    }
    #endregion -------------------------------------------------------------------------------------------------------------------------------------

    #region load  ----------------------------------------------------------------------------------------------------------------------------------
    foreach($GroupMembership in $TransformRequest.returnObject){
        $ReturnObject.returnMessage = Update-LogArray -ReturnMessages $ReturnObject.returnMessage -Message ([STRING]::Format("Add user $($GroupMembership.Member) to group $($GroupMembership.Group)"))
        $result = Add-ADGroupMember @GroupMembership
    }
    #endregion -------------------------------------------------------------------------------------------------------------------------------------
    $ReturnObject.returnMessage[$ReturnObject.returnMessage.count - 1] = $ReturnObject.returnMessage[$ReturnObject.returnMessage.count - 1].Replace("[RUNNING]", "[SUCCESS]")
}
Catch{
    $ReturnObject.returnCode = -1
    $ReturnObject.returnMessage[$ReturnObject.returnMessage.count - 1] = $ReturnObject.returnMessage[$ReturnObject.returnMessage.count - 1].Replace("[RUNNING]", "[FAILED] - ") + $_
}

#return as json object and readd the "'".
Write-Output (($ReturnObject | ConvertTo-Json).toString()).replace('\u0027',"'")

#Exit powerhsell with defined exit code.
Exit $ReturnObject.returnCode

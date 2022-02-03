# New-ParameterFile.ps1

<#
    Parameter File
    Plain PowerShell Object that implement the schema of a parameter file
#>
class ParameterFile {
    # https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-parameter-files
    [string] $schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    [string] $contentVersion = "1.0.0.0"
    [hashtable] $parameters

    # Accept parameter from a given template and map it to the parameter file schema
    ParameterFile ([array]$Parameters) {
        foreach ($Parameter in $Parameters) {
            $this.parameters += @{
                $Parameter.name = @{
                    value = ""
                }
            }
        }
    }
}

<#
    Parameter File  Generator
    Abstract the creation of a concrete ParameterFile
    The generator needs to be created based on a template
     A file can be created by calling  `GenerateParameterFile`, this function accepts a boolean to include only Mandatory parameters.
#>
class ParameterFileGenerator {

    $Template
    $Parameter
    $MandatoryParameter
	$NonReferencedParameter

    # Accepts the template
    ParameterFileGenerator ($Path) {
        $this.Template = $this._loadTemplate($Path)
        $this.Parameter = $this._getParameter($this.Template)
        $this.MandatoryParameter = $this._getMandatoryParameterByParameter($this.Parameter)
        $this.NonReferencedParameter = $this._getNonReferencedParameterByParameter($this.Parameter)
    }

    # 'private' method to load a given ARM template and create a PowerShell object
    [PSCustomObject] _loadTemplate($Path) {
        Write-Verbose "Read from $Path"
        # Test for template presence
        $null = Test-Path $Path -ErrorAction Stop

        # Test if arm template content is readable
        $TemplateContent = Get-Content $Path -Raw -ErrorAction Stop
        Write-Verbose "Template Content `n $TemplateContent"

        # Convert the ARM template to an Object
        return ConvertFrom-Json $TemplateContent -ErrorAction Stop
    }

    # 'private' function to extract all parameters of a given template
    [Array] _getParameter($Template) {
        # Extract the Parameters properties from JSON
        $ParameterObjects = $Template.Parameters.PSObject.Members | Where-Object MemberType -eq NoteProperty

        $Parameters = @()
        foreach ($ParameterObject in $ParameterObjects) {
            $Key = $ParameterObject.Name
            $Property = $ParameterObject.Value

            $Property | Add-Member -NotePropertyName "Name" -NotePropertyValue $Key
            $Parameters += $Property
            Write-Verbose "Parameter Found $Key"
        }
        return $Parameters
    }

    # 'private' function to extract all mandatory parameters of all parameters
    [Array] _getMandatoryParameterByParameter($Parameter) {
        return $Parameter | Where-Object {
            "" -eq $_.defaultValue -or $null -eq $_.defaultValue
        }
    }

    # 'private' function to extract all mandatory parameters of all parameters
    [Array] _getNonReferencedParameterByParameter($Parameter) {
        return $Parameter | Where-Object {
            $_.defaultValue -notmatch "\(*\)" -or "" -eq $_.defaultValue
        }
    }

    <#
        The generator should expose this method to create a parameter file.
        A file can be created by calling  `GenerateParameterFile`
        This function accepts a boolean to include only Mandatory parameters.
    #>
    [ParameterFile] GenerateParameterFile([boolean] $OnlyMandatoryParameter, [boolean] $OnlyNonReferencedParameter) {
        if ($OnlyMandatoryParameter) {
            return [ParameterFile]::new($this.MandatoryParameter)
        }
        else {
		    if ($OnlyNonReferencedParameter){
			    return [ParameterFile]::new($this.NonReferencedParameter)
                                        }
			else { return [ParameterFile]::new($this.Parameter)}
        }

    }
}

# Exposed function to the user
function New-ParameterFile {
    <#
    .SYNOPSIS
    Creates a parameter file json based on a given ARM template
    .DESCRIPTION
    Creates a parameter file json based on a given ARM template
    .PARAMETER Path
    Path to the ARM template, by default searches the script path for a "azuredeploy.json" file
    .PARAMETER OnlyMandatoryParameter
    Creates parameter file only with Mandatory Parameters ("defaultValue") not present
    .PARAMETER OnlyNonReferencedParameter
    Creates parameter file only with non referenced default values 
    #>

    [CmdletBinding()]
    param (
        [string] $Path = (Join-Path $PSScriptRoot "azuredeploy.json"),
        [switch] $OnlyMandatoryParameter,
        [switch] $OnlyNonReferencedParameter
    )
    process {
        # Instantiate the ParameterFileGenerator and uses the public function to create a file
        # The object is converted to Json as this is expected
        [ParameterFileGenerator]::new($Path).GenerateParameterFile($OnlyMandatoryParameter, $OnlyNonReferencedParameter) | ConvertTo-Json

         # Could be abstract further by using | out-file
    }
}

<#
      .SYNOPSIS 
      Allows easy application migration from XenApp 6.5 -> 7.x

      .DESCRIPTION
      Provides a GUI for migrating published applications from XenApp 6.5 to 7.x. Will take either command line parameters or config.xml for farm configuration.

      .INPUTS    
      OldFarmController (optional if config.xml provided): 
        Hostname of the XenApp 6.5 ZDC.
        
      NewFarmController (optional if config.xml provided):
        Hostname of the XenApp 7.x DDC.

      .EXAMPLE
      C:\PS> AppMigrate.ps1 
      No command line parameters provided. Will look for config.xml

      .EXAMPLE
      C:\PS> AppMigrate.ps1 -OldFarmController CTXZDC01 -NewFarmController CTXDDC01
      Both farm hostnames are provided with command line parameters so no config.xml is checked for.

      .LINK
      https://www.citrix.com/downloads/xenapp/sdks/powershell-sdk.html

      .LINK
      https://docs.citrix.com/en-us/citrix-virtual-apps-desktops-service/sdk-api.html

      .NOTES
      Must be ran from a controller with both the old 6.5 SDK and the 7.x version.

      By Damon Batey January 3, 2019
      damonbatey@gmail.com
#>
Param(
    [string]$OldFarmController,
    [string]$NewFarmController 
)

# Grab the required Snapins
$SnapInsAvailable = Get-PSSnapin -Registered -Name Citrix.XenApp.Commands, Citrix.Broker.Admin.V2, Citrix.Configuration.Admin.V2 -ErrorAction SilentlyContinue
# Get the number of them
$SnapInsAvailableCount = $($SnapInsAvailable | Measure-Object).Count

# Check if all required snapins are registered on this system. There should be 3.
If ($SnapInsAvailableCount -lt 3) {
    Write-Error -Message $("Required PVS/Citrix Snapins not available: Citrix.XenApp.Commands, Citrix.Broker.Admin.V2, Citrix.Configuration.Admin.V2") -ErrorAction Stop
    Exit
}
Else {
    Add-PSSnapin -Name Citrix.XenApp.Commands, Citrix.Broker.Admin.V2, Citrix.Configuration.Admin.V2
}

# The following function is from http://ramblingcookiemonster.github.io/Join-Object/

function Join-Object {
    <#
    .SYNOPSIS
        Join data from two sets of objects based on a common value

    .DESCRIPTION
        Join data from two sets of objects based on a common value

        For more details, see the accompanying blog post:
            http://ramblingcookiemonster.github.io/Join-Object/

        For even more details,  see the original code and discussions that this borrows from:
            Dave Wyatt's Join-Object - http://powershell.org/wp/forums/topic/merging-very-large-collections
            Lucio Silveira's Join-Object - http://blogs.msdn.com/b/powershell/archive/2012/07/13/join-object.aspx

    .PARAMETER Left
        'Left' collection of objects to join.  You can use the pipeline for Left.

        The objects in this collection should be consistent.
        We look at the properties on the first object for a baseline.
    
    .PARAMETER Right
        'Right' collection of objects to join.

        The objects in this collection should be consistent.
        We look at the properties on the first object for a baseline.

    .PARAMETER LeftJoinProperty
        Property on Left collection objects that we match up with RightJoinProperty on the Right collection

    .PARAMETER RightJoinProperty
        Property on Right collection objects that we match up with LeftJoinProperty on the Left collection

    .PARAMETER LeftProperties
        One or more properties to keep from Left.  Default is to keep all Left properties (*).

        Each property can:
            - Be a plain property name like "Name"
            - Contain wildcards like "*"
            - Be a hashtable like @{Name="Product Name";Expression={$_.Name}}.
                 Name is the output property name
                 Expression is the property value ($_ as the current object)
                
                 Alternatively, use the Suffix or Prefix parameter to avoid collisions
                 Each property using this hashtable syntax will be excluded from suffixes and prefixes

    .PARAMETER RightProperties
        One or more properties to keep from Right.  Default is to keep all Right properties (*).

        Each property can:
            - Be a plain property name like "Name"
            - Contain wildcards like "*"
            - Be a hashtable like @{Name="Product Name";Expression={$_.Name}}.
                 Name is the output property name
                 Expression is the property value ($_ as the current object)
                
                 Alternatively, use the Suffix or Prefix parameter to avoid collisions
                 Each property using this hashtable syntax will be excluded from suffixes and prefixes

    .PARAMETER Prefix
        If specified, prepend Right object property names with this prefix to avoid collisions

        Example:
            Property Name                   = 'Name'
            Suffix                          = 'j_'
            Resulting Joined Property Name  = 'j_Name'

    .PARAMETER Suffix
        If specified, append Right object property names with this suffix to avoid collisions

        Example:
            Property Name                   = 'Name'
            Suffix                          = '_j'
            Resulting Joined Property Name  = 'Name_j'

    .PARAMETER Type
        Type of join.  Default is AllInLeft.

        AllInLeft will have all elements from Left at least once in the output, and might appear more than once
          if the where clause is true for more than one element in right, Left elements with matches in Right are
          preceded by elements with no matches.
          SQL equivalent: outer left join (or simply left join)

        AllInRight is similar to AllInLeft.
        
        OnlyIfInBoth will cause all elements from Left to be placed in the output, only if there is at least one
          match in Right.
          SQL equivalent: inner join (or simply join)
         
        AllInBoth will have all entries in right and left in the output. Specifically, it will have all entries
          in right with at least one match in left, followed by all entries in Right with no matches in left, 
          followed by all entries in Left with no matches in Right.
          SQL equivalent: full join

    .EXAMPLE
        #
        #Define some input data.

        $l = 1..5 | Foreach-Object {
            [pscustomobject]@{
                Name = "jsmith$_"
                Birthday = (Get-Date).adddays(-1)
            }
        }

        $r = 4..7 | Foreach-Object{
            [pscustomobject]@{
                Department = "Department $_"
                Name = "Department $_"
                Manager = "jsmith$_"
            }
        }

        #We have a name and Birthday for each manager, how do we find their department, using an inner join?
        Join-Object -Left $l -Right $r -LeftJoinProperty Name -RightJoinProperty Manager -Type OnlyIfInBoth -RightProperties Department


            # Name    Birthday             Department  
            # ----    --------             ----------  
            # jsmith4 4/14/2015 3:27:22 PM Department 4
            # jsmith5 4/14/2015 3:27:22 PM Department 5

    .EXAMPLE  
        #
        #Define some input data.

        $l = 1..5 | Foreach-Object {
            [pscustomobject]@{
                Name = "jsmith$_"
                Birthday = (Get-Date).adddays(-1)
            }
        }

        $r = 4..7 | Foreach-Object{
            [pscustomobject]@{
                Department = "Department $_"
                Name = "Department $_"
                Manager = "jsmith$_"
            }
        }

        #We have a name and Birthday for each manager, how do we find all related department data, even if there are conflicting properties?
        $l | Join-Object -Right $r -LeftJoinProperty Name -RightJoinProperty Manager -Type AllInLeft -Prefix j_

            # Name    Birthday             j_Department j_Name       j_Manager
            # ----    --------             ------------ ------       ---------
            # jsmith1 4/14/2015 3:27:22 PM                                    
            # jsmith2 4/14/2015 3:27:22 PM                                    
            # jsmith3 4/14/2015 3:27:22 PM                                    
            # jsmith4 4/14/2015 3:27:22 PM Department 4 Department 4 jsmith4  
            # jsmith5 4/14/2015 3:27:22 PM Department 5 Department 5 jsmith5  

    .EXAMPLE
        #
        #Hey!  You know how to script right?  Can you merge these two CSVs, where Path1's IP is equal to Path2's IP_ADDRESS?
        
        #Get CSV data
        $s1 = Import-CSV $Path1
        $s2 = Import-CSV $Path2

        #Merge the data, using a full outer join to avoid omitting anything, and export it
        Join-Object -Left $s1 -Right $s2 -LeftJoinProperty IP_ADDRESS -RightJoinProperty IP -Prefix 'j_' -Type AllInBoth |
            Export-CSV $MergePath -NoTypeInformation

    .EXAMPLE
        #
        # "Hey Warren, we need to match up SSNs to Active Directory users, and check if they are enabled or not.
        #  I'll e-mail you an unencrypted CSV with all the SSNs from gmail, what could go wrong?"
        
        # Import some SSNs. 
        $SSNs = Import-CSV -Path D:\SSNs.csv

        #Get AD users, and match up by a common value, samaccountname in this case:
        Get-ADUser -Filter "samaccountname -like 'wframe*'" |
            Join-Object -LeftJoinProperty samaccountname -Right $SSNs `
                        -RightJoinProperty samaccountname -RightProperties ssn `
                        -LeftProperties samaccountname, enabled, objectclass

    .NOTES
        This borrows from:
            Dave Wyatt's Join-Object - http://powershell.org/wp/forums/topic/merging-very-large-collections/
            Lucio Silveira's Join-Object - http://blogs.msdn.com/b/powershell/archive/2012/07/13/join-object.aspx

        Changes:
            Always display full set of properties
            Display properties in order (left first, right second)
            If specified, add suffix or prefix to right object property names to avoid collisions
            Use a hashtable rather than ordereddictionary (avoid case sensitivity)

    .LINK
        http://ramblingcookiemonster.github.io/Join-Object/

    .FUNCTIONALITY
        PowerShell Language

    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeLine = $true)]
        [object[]] $Left,

        # List to join with $Left
        [Parameter(Mandatory = $true)]
        [object[]] $Right,

        [Parameter(Mandatory = $true)]
        [string] $LeftJoinProperty,

        [Parameter(Mandatory = $true)]
        [string] $RightJoinProperty,

        [object[]]$LeftProperties = '*',

        # Properties from $Right we want in the output.
        # Like LeftProperties, each can be a plain name, wildcard or hashtable. See the LeftProperties comments.
        [object[]]$RightProperties = '*',

        [validateset( 'AllInLeft', 'OnlyIfInBoth', 'AllInBoth', 'AllInRight')]
        [Parameter(Mandatory = $false)]
        [string]$Type = 'AllInLeft',

        [string]$Prefix,
        [string]$Suffix
    )
    Begin {
        function AddItemProperties($item, $properties, $hash) {
            if ($null -eq $item) {
                return
            }

            foreach ($property in $properties) {
                $propertyHash = $property -as [hashtable]
                if ($null -ne $propertyHash) {
                    $hashName = $propertyHash["name"] -as [string]         
                    $expression = $propertyHash["expression"] -as [scriptblock]

                    $expressionValue = $expression.Invoke($item)[0]
            
                    $hash[$hashName] = $expressionValue
                }
                else {
                    foreach ($itemProperty in $item.psobject.Properties) {
                        if ($itemProperty.Name -like $property) {
                            $hash[$itemProperty.Name] = $itemProperty.Value
                        }
                    }
                }
            }
        }

        function TranslateProperties {
            [cmdletbinding()]
            param(
                [object[]]$Properties,
                [psobject]$RealObject,
                [string]$Side)

            foreach ($Prop in $Properties) {
                $propertyHash = $Prop -as [hashtable]
                if ($null -ne $propertyHash) {
                    $hashName = $propertyHash["name"] -as [string]         
                    $expression = $propertyHash["expression"] -as [scriptblock]

                    $ScriptString = $expression.tostring()
                    if ($ScriptString -notmatch 'param\(') {
                        Write-Verbose "Property '$HashName'`: Adding param(`$_) to scriptblock '$ScriptString'"
                        $Expression = [ScriptBlock]::Create("param(`$_)`n $ScriptString")
                    }
                
                    $Output = @{Name = $HashName; Expression = $Expression }
                    Write-Verbose "Found $Side property hash with name $($Output.Name), expression:`n$($Output.Expression | out-string)"
                    $Output
                }
                else {
                    foreach ($ThisProp in $RealObject.psobject.Properties) {
                        if ($ThisProp.Name -like $Prop) {
                            Write-Verbose "Found $Side property '$($ThisProp.Name)'"
                            $ThisProp.Name
                        }
                    }
                }
            }
        }

        function WriteJoinObjectOutput($leftItem, $rightItem, $leftProperties, $rightProperties) {
            $properties = @{ }

            AddItemProperties $leftItem $leftProperties $properties
            AddItemProperties $rightItem $rightProperties $properties

            New-Object psobject -Property $properties
        }

        #Translate variations on calculated properties.  Doing this once shouldn't affect perf too much.
        foreach ($Prop in @($LeftProperties + $RightProperties)) {
            if ($Prop -as [hashtable]) {
                foreach ($variation in ('n', 'label', 'l')) {
                    if (-not $Prop.ContainsKey('Name') ) {
                        if ($Prop.ContainsKey($variation) ) {
                            $Prop.Add('Name', $Prop[$Variation])
                        }
                    }
                }
                if (-not $Prop.ContainsKey('Name') -or $Prop['Name'] -like $null ) {
                    Throw "Property is missing a name`n. This should be in calculated property format, with a Name and an Expression:`n@{Name='Something';Expression={`$_.Something}}`nAffected property:`n$($Prop | out-string)"
                }


                if (-not $Prop.ContainsKey('Expression') ) {
                    if ($Prop.ContainsKey('E') ) {
                        $Prop.Add('Expression', $Prop['E'])
                    }
                }
            
                if (-not $Prop.ContainsKey('Expression') -or $Prop['Expression'] -like $null ) {
                    Throw "Property is missing an expression`n. This should be in calculated property format, with a Name and an Expression:`n@{Name='Something';Expression={`$_.Something}}`nAffected property:`n$($Prop | out-string)"
                }
            }        
        }

        $leftHash = @{ }
        $rightHash = @{ }

        # Hashtable keys can't be null; we'll use any old object reference as a placeholder if needed.
        $nullKey = New-Object psobject
        
        $bound = $PSBoundParameters.keys -contains "InputObject"
        if (-not $bound) {
            [System.Collections.ArrayList]$LeftData = @()
        }
    }
    Process {
        #We pull all the data for comparison later, no streaming
        if ($bound) {
            $LeftData = $Left
        }
        Else {
            foreach ($Object in $Left) {
                [void]$LeftData.add($Object)
            }
        }
    }
    End {
        foreach ($item in $Right) {
            $key = $item.$RightJoinProperty

            if ($null -eq $key) {
                $key = $nullKey
            }

            $bucket = $rightHash[$key]

            if ($null -eq $bucket) {
                $bucket = New-Object System.Collections.ArrayList
                $rightHash.Add($key, $bucket)
            }

            $null = $bucket.Add($item)
        }

        foreach ($item in $LeftData) {
            $key = $item.$LeftJoinProperty

            if ($null -eq $key) {
                $key = $nullKey
            }

            $bucket = $leftHash[$key]

            if ($null -eq $bucket) {
                $bucket = New-Object System.Collections.ArrayList
                $leftHash.Add($key, $bucket)
            }

            $null = $bucket.Add($item)
        }

        $LeftProperties = TranslateProperties -Properties $LeftProperties -Side 'Left' -RealObject $LeftData[0]
        $RightProperties = TranslateProperties -Properties $RightProperties -Side 'Right' -RealObject $Right[0]

        #I prefer ordered output. Left properties first.
        [string[]]$AllProps = $LeftProperties

        #Handle prefixes, suffixes, and building AllProps with Name only
        $RightProperties = foreach ($RightProp in $RightProperties) {
            if (-not ($RightProp -as [Hashtable])) {
                Write-Verbose "Transforming property $RightProp to $Prefix$RightProp$Suffix"
                @{
                    Name       = "$Prefix$RightProp$Suffix"
                    Expression = [scriptblock]::create("param(`$_) `$_.'$RightProp'")
                }
                $AllProps += "$Prefix$RightProp$Suffix"
            }
            else {
                Write-Verbose "Skipping transformation of calculated property with name $($RightProp.Name), expression:`n$($RightProp.Expression | out-string)"
                $AllProps += [string]$RightProp["Name"]
                $RightProp
            }
        }

        $AllProps = $AllProps | Select -Unique

        Write-Verbose "Combined set of properties: $($AllProps -join ', ')"

        foreach ( $entry in $leftHash.GetEnumerator() ) {
            $key = $entry.Key
            $leftBucket = $entry.Value

            $rightBucket = $rightHash[$key]

            if ($null -eq $rightBucket) {
                if ($Type -eq 'AllInLeft' -or $Type -eq 'AllInBoth') {
                    foreach ($leftItem in $leftBucket) {
                        WriteJoinObjectOutput $leftItem $null $LeftProperties $RightProperties | Select $AllProps
                    }
                }
            }
            else {
                foreach ($leftItem in $leftBucket) {
                    foreach ($rightItem in $rightBucket) {
                        WriteJoinObjectOutput $leftItem $rightItem $LeftProperties $RightProperties | Select $AllProps
                    }
                }
            }
        }

        if ($Type -eq 'AllInRight' -or $Type -eq 'AllInBoth') {
            foreach ($entry in $rightHash.GetEnumerator()) {
                $key = $entry.Key
                $rightBucket = $entry.Value

                $leftBucket = $leftHash[$key]

                if ($null -eq $leftBucket) {
                    foreach ($rightItem in $rightBucket) {
                        WriteJoinObjectOutput $null $rightItem $LeftProperties $RightProperties | Select $AllProps
                    }
                }
            }
        }
    }
}

# The preceeding function is from http://ramblingcookiemonster.github.io/Join-Object/

# The Following 4 functions are from https://gist.github.com/josheinstein/2559785

function Invoke-ScriptBlock {

    [CmdletBinding()]
    param (
    
        [Parameter(Position = 1, Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
    
        [Parameter(ValueFromPipeline = $true)]
        [Object]$InputObject
    
    )
    
    begin {
        $SessionStateProperty = [ScriptBlock].GetProperty('SessionState', ([System.Reflection.BindingFlags]'NonPublic,Instance'))
        $SessionState = $SessionStateProperty.GetValue($ScriptBlock, $null)
    }
    process {
        $NewUnderBar = $InputObject
        $OldUnderBar = $SessionState.PSVariable.GetValue('_')
        try {
            $SessionState.PSVariable.Set('_', $NewUnderBar)
            $SessionState.InvokeCommand.InvokeScript($SessionState, $ScriptBlock, @())
        }
        finally {
            $SessionState.PSVariable.Set('_', $OldUnderBar)
        }
    }

}

function Invoke-Selector($InputObject, [Object]$Selector) {
    if ($Selector -is [ScriptBlock]) {
        Invoke-ScriptBlock -InputObject:$InputObject -ScriptBlock:$Selector
    }
    elseif ($Selector -is [String]) {
        $InputObject.$Selector
    }
    elseif ($Selector -is [String[]]) {
        Select-Object -InputObject:$InputObject -Property:$Selector
    }
    elseif ($Null -eq $Selector) {
        $InputObject
    }
    else {
        throw 'Selector must be a ScriptBlock, an individual property, or a property set.'
    }
}

function Test-Predicate($InputObject, [Object]$Predicate) {
    if ($Predicate) {
        if (Invoke-ScriptBlock -InputObject:$InputObject -ScriptBlock:$Predicate ) {
            return $true 
        }
        else {
            return $false
        }
    }
    else {
        return $true # no predicate always includes inputobject
    }
}

function Linq-All {

    [CmdletBinding()]
    param ( 

        [Parameter(Position = 1, Mandatory = $true)]
        [ScriptBlock]$Predicate,
    
        [Parameter(ValueFromPipeline = $true)]
        [Object]$InputObject

    )

    begin {
        $AllSoFar = $true
    }
    
    process { 

        # Short Circuit
        # Stop checking once we found one negative
        if (-not $AllSoFar) {
            return
        }

        $AllSoFar = Test-Predicate $InputObject $Predicate
        
    }
    
    end {
        $AllSoFar
    }

}

# The preceeding 4 functions are from https://gist.github.com/josheinstein/2559785

[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$AppMainWindow = @'
    <Window x:Name="MainForm"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Citrix Application Migration" Height="700" Width="540" MinHeight="700" MaxHeight="700" MaxWidth="540" MinWidth="540" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
        <Grid Margin="0,0,-2.6,-2.6" MinHeight="300" MinWidth="525" MaxWidth="540">
            <Label x:Name="oldFarmLabel" Content="" VerticalAlignment="Top" HorizontalAlignment="Left"  Margin="10,10,0,0" />
            <Label x:Name="oldFarmVersionLabel" Content="" VerticalAlignment="Top" HorizontalAlignment="Left"  Margin="72,10,0,0" />
            <Label x:Name="newFarmLabel" Content="" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="133,10,0,0" />
            <Label x:Name="newFarmVersionLabel" Content="" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="197,10,0,0" />
            <ComboBox x:Name="cmboDisplay" IsEditable="False" HorizontalAlignment="Right" Margin="0,10,90,0" VerticalAlignment="Top" Width="105" Height="20" />
            <Button x:Name="btnRefresh" Content="Refresh" HorizontalAlignment="Right" Margin="0,10,10,0" VerticalAlignment="Top" Width="75" Height="20"/>
            <ListView x:Name="listviewMigrateApps" Margin="10,37,0,0" Height="590" VerticalAlignment="Top" HorizontalAlignment="Left" Width="505">
                <ListView.ContextMenu>
                    <ContextMenu x:Name = 'MigrateMenu'>
                        <MenuItem x:Name = 'O2N_Menu' Header = 'Old -> New'/>      
                        <MenuItem x:Name = 'N2O_Menu' Header = 'New -> Old'/>
                        <MenuItem x:Name = 'NewInfo_Menu' Header = 'New Info'/>      
                        <MenuItem x:Name = 'OldInfo_Menu' Header = 'Old Info'/>
                        <MenuItem x:Name = 'CreateAppInNewFarm_Menu' Header = 'Create App in New Farm'/>
                    </ContextMenu>
                </ListView.ContextMenu>
                <ListView.View>
                    <GridView x:Name="gridApps" AllowsColumnReorder="False">
                        <GridView.ColumnHeaderContainerStyle>
                            <Style BasedOn="{StaticResource {x:Type GridViewColumnHeader}}" TargetType="{x:Type GridViewColumnHeader}">
                                <Setter Property="IsHitTestVisible" Value="False"/>
                            </Style>
                        </GridView.ColumnHeaderContainerStyle>
                        <GridViewColumn Header="Application Name" Width="210">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Label Content = "{Binding ApplicationName}" Width="210"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Old Farm Status" Width="100">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Label Content = "{Binding EnabledOld}" Width="100"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="New Farm Status" Width="100">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Label Content = "{Binding EnabledNew}" Width="100"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                    </GridView>
                </ListView.View>
            </ListView>
            <Label x:Name="appLabel" Content="Total Apps: " VerticalAlignment="Top" HorizontalAlignment="Left" Margin="10,637,10,0" />
            <Label x:Name="appCountLabel" Content="" VerticalAlignment="Top" HorizontalAlignment="Left" Margin="70,637,10,0" />
            <Label Content="Right Click for Menu" Margin="120,637,0,0" VerticalAlignment="Top" />
            <!-- 
            <Button x:Name="btnOldInfo" Content="Old Info" HorizontalAlignment="Left" Margin="120,640,0,0" VerticalAlignment="Top" Width="75"/>
            <Button x:Name="btnNewInfo" Content="New Info" HorizontalAlignment="Left" Margin="200,640,0,0" VerticalAlignment="Top" Width="75"/>
            <Button x:Name="btnN2O" Content="New -> Old" HorizontalAlignment="Left" Margin="280,640,0,0" VerticalAlignment="Top" Width="75"/>
            <Button x:Name="btnO2N" Content="Old -> New" HorizontalAlignment="Left" Margin="360,640,0,0" VerticalAlignment="Top" Width="75"/>
            -->
            <Button x:Name="btnCancel" Content="Cancel" HorizontalAlignment="Left" Margin="440,640,0,0" VerticalAlignment="Top" Width="65" IsCancel="True"/>
        </Grid>
    </Window>
'@

#Read XAML
$Reader = (New-Object System.Xml.XmlNodeReader $AppMainWindow) 
$window = [Windows.Markup.XamlReader]::Load( $Reader )

$namespace = @{ x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
$xpath_formobjects = "//*[@*[contains(translate(name(.),'n','N'),'Name')]]" 

# Create a variable for every named xaml element
Select-Xml $AppMainWindow -Namespace $namespace -xpath $xpath_formobjects | ForEach-Object {
    $_.Node | ForEach-Object {
        Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name)
    }
}

# Function to show a simple information window with output from powershell command 
Function Show-Info {
    <#
    .SYNOPSIS
        Display a window with information.

    .DESCRIPTION
        Display a window with information.

        For more details, see the accompanying blog post:
            http://ramblingcookiemonster.github.io/Join-Object/

        For even more details,  see the original code and discussions that this borrows from:
            Dave Wyatt's Join-Object - http://powershell.org/wp/forums/topic/merging-very-large-collections
            Lucio Silveira's Join-Object - http://blogs.msdn.com/b/powershell/archive/2012/07/13/join-object.aspx

    .PARAMETER Title
        'Title' to display in title bar if information window.

    .PARAMETER Info
        'Info' info to display in Information window.
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [PSObject] $Info
    )

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $AppInfo = New-Object system.Windows.Forms.Form
    $AppInfo.ClientSize = '600,600'
    $AppInfo.text = $Title
    $AppInfo.TopMost = $true

    $AppTextBox = New-Object system.Windows.Forms.RichTextBox
    $AppTextBox.width = 580
    $AppTextBox.height = 580
    $AppTextBox.location = New-Object System.Drawing.Point(10, 10)
    $AppTextBox.ReadOnly = $true
    $AppTextBox.Font = 'Lucida Console,8'
    ForEach ($line in $Info) {
        $AppTextBox.AppendText(($line | Select * | Out-String))
    }

    $AppInfo.controls.Add($AppTextBox)


    [void]$AppInfo.ShowDialog()
}


# Fill the list view
Function FillListView($Applications) {
    # Reset itemsource
    $listviewMigrateApps.ItemsSource = $null
    # Start with an empty array for the datasource
    $script:emptyarray = New-Object System.Collections.ArrayList
    ForEach ($item in $Applications) {
        try {

            $tmpObj = New-Object psobject -Property @{
                'ClientFolder'    = $item.ClientFolder
                'ApplicationName' = $item.ApplicationName
                'EnabledOld'      = $item.EnabledOld
                'EnabledNew'      = $item.EnabledNew
            }
            $script:emptyarray += $tmpObj
        }
        catch {
            Write-Host "Error"
            # Apparently something failed, oh well...
        }
    }

    # Set final data source
    $listviewMigrateApps.ItemsSource = $script:emptyarray
}

Function FetchAllData {
    # Reset data to be displayed 
    $global:AppsToDisplay = $null
    # Grab apps from old farm
    $global:OldFarmApps = Get-XAApplication -ComputerName $global:OldFarmHost | Select @{Name = "ApplicationName"; Expression = { $_."BrowserName" } }, @{Name = "EnabledOld"; Expression = { $_."Enabled" } }, ClientFolder, HideWhenDisabled
    # Grab apps from new farm
    $global:NewFarmApps = Get-BrokerApplication -AdminAddress $global:NewFarmHost | Select ApplicationName, @{Name = "EnabledNew"; Expression = { $_."Enabled" } }, ClientFolder, HideWhenDisabled

    # Merge based on combobox selection
    if ($cmboDisplay.SelectedIndex -eq 0) {
        $global:AppsToDisplay = Join-Object -Left $global:OldFarmApps -Right $global:NewFarmApps -LeftJoinProperty ApplicationName -RightJoinProperty ApplicationName -Type AllInBoth | Sort-Object ApplicationName
        $CreateAppInNewFarm_Menu.Visibility = 'Visible'
    }
    ElseIf ($cmboDisplay.SelectedIndex -eq 1) {
        $global:AppsToDisplay = Join-Object -Left $global:OldFarmApps -Right $global:NewFarmApps -LeftJoinProperty ApplicationName -RightJoinProperty ApplicationName -Type OnlyIfInBoth | Sort-Object ApplicationName
        $CreateAppInNewFarm_Menu.Visibility = 'Collapsed'
    }
    Else {
        $global:AppsToDisplay = Join-Object -Left $global:OldFarmApps -Right $global:NewFarmApps -LeftJoinProperty ApplicationName -RightJoinProperty ApplicationName -Type AllInLeft | Sort-Object ApplicationName
        $CreateAppInNewFarm_Menu.Visibility = 'Visible'
    }
    # Populate the list view with previous data
    FillListView($global:AppsToDisplay)
    # Display number of apps in current display
    $appCountLabel.Content = $global:AppsToDisplay.Length
}

Function Initialize {
    
    $global:AppsToDisplay = $null

    # Dropdown combo options. Will be assigned later
    $global:displayOptions = @('All on Both',
        'Only on Both',
        'All on Old')

    # Default action when hitting escape button, closes window
    $window.add_KeyDown( {
            if ($args[1].key -eq 'Escape') {
                $window.Close()        
            }
        })

    # Handle click on Close button
    $btnCancel.add_Click( { $window.Close() })

    Switch ($OldFarmController) {
        "" {
            If ([System.IO.File]::Exists($PSScriptRoot + "\config.xml")) {
                # Grab farm information from config xml file if command line options aren't present
                [System.Xml.XmlDocument]$Config = new-object System.Xml.XmlDocument
                $Config.load($PSScriptRoot + "\config.xml")
                # Load XML config file
                $global:OldFarmHost = ($Config.SelectNodes("FarmMigration/OldFarm/Controller")).hostname
                $global:NewFarmHost = ($Config.SelectNodes("FarmMigration/NewFarm/Controller")).hostname
            }
            Else {
                Try {
                    Write-Error -Message "You must provide Old and New Farm information via either command line or config.xml." -ErrorAction Stop
                }
                Catch {
                    Throw "Please provide config inforamtion."
                }
            }
        }
        default {
            $global:OldFarmHost = $OldFarmController
            $global:NewFarmHost = $NewFarmController
        }
    }

    # Grab farm information from farms. Assumes old farm is version 6.5 and new version is 7.x
    $global:OldFarmVersion = Get-XAFarm -ComputerName $global:OldFarmHost | Select-Object -ExpandProperty ServerVersion
    $global:NewFarmVersion = Get-ConfigSite -AdminAddress $global:NewFarmHost | Select-Object -ExpandProperty ProductVersion

    # Set up information labels
    $oldFarmLabel.Content = "Old Farm -"
    $newFarmLabel.Content = "New Farm -"
    $oldFarmVersionLabel.Content = $global:OldFarmVersion
    $newFarmVersionLabel.Content = $global:NewFarmVersion

    # Handle refresh clicks
    $btnRefresh.Add_Click( {
            $btnRefresh.IsEnabled = $false
            FetchAllData
            $btnRefresh.IsEnabled = $true
        })

    # Set binding for dropdown combo box
    $cmboDisplay.ItemsSource = $global:displayOptions

    # Get application information from old farm. Only works if app exists on old farm
    $btnOldInfo_OnClick = {
        $script:selectedItem = $listviewMigrateApps.SelectedItem
        $script:Info = Get-XAApplicationReport -ComputerName $global:OldFarmHost -BrowserName $script:selectedItem.ApplicationName
        $script:Title = "XenApp " + $global:OldFarmVersion + " Farm: " + $global:OldFarmHost
        Show-Info -Title $script:Title -Info $script:Info
    }
    

    # Create app found only in old farm, in the new farm
    $CreateAppInNewFarm_Menu_OnClick = {
        $script:createdApp = $null
        $script:selectedItem = $listviewMigrateApps.SelectedItem
        $script:Info = Get-XAApplicationReport -ComputerName $global:OldFarmHost -BrowserName $script:selectedItem.ApplicationName
        $script:NewFarmFolders = Get-BrokerAdminFolder -AdminAddress $global:NewFarmHost
        $script:NewFarmDGs = Get-BrokerDesktopGroup -AdminAddress $global:NewFarmHost

        $script:Title = "XenApp " + $global:OldFarmVersion + " Farm: " + $global:OldFarmHost

        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Application]::EnableVisualStyles()

        $CreateNewApp = New-Object system.Windows.Forms.Form
        $CreateNewApp.ClientSize = '480,300'
        $CreateNewApp.text = $script:Title
        $CreateNewApp.TopMost = $true

        $PathListLabel = New-Object system.Windows.Forms.Label
        $PathListLabel.location = New-Object System.Drawing.Point(30, 15)
        $PathListLabel.Text = "Admin Paths"

        $PathListView = New-Object system.Windows.Forms.ListBox
        $PathListView.width = 180
        $PathListView.height = 210
        $PathListView.location = New-Object System.Drawing.Point(30, 30)
        ForEach ($AP in $script:NewFarmFolders | Select -ExpandProperty Name) {
            $PathListView.Items.Add($AP)
        }
    
        $DGListLabel = New-Object system.Windows.Forms.Label
        $DGListLabel.location = New-Object System.Drawing.Point(270, 15)
        $DGListLabel.Text = "Delivery Groups"

        $DGListView = New-Object system.Windows.Forms.ListBox
        $DGListView.width = 180
        $DGListView.height = 210
        $DGListView.location = New-Object System.Drawing.Point(270, 30)
        ForEach ($DG in $script:NewFarmDGs | Select -ExpandProperty Name) {
            $DGListView.Items.Add($DG)
        }

        $CreateButton = New-Object system.Windows.Forms.Button
        $CreateButton.location = New-Object System.Drawing.Point(160, 260)
        $CreateButton.Text = "Create"

        $CancelButton = New-Object system.Windows.Forms.Button
        $CancelButton.location = New-Object System.Drawing.Point(250, 260)
        $CancelButton.Text = "Cancel"
        $CreateButton_OnClick = {
            [void]$CreateNewApp.Close()
            $script:createdApp = ""
            $script:matches = ""
            [string]$script:executable = ""
            [string]$script:arguments = ""
            # Borrowed regex separation logic for command line and arguments from official citrix read/import powershell scripts 
            If ($script:Info.CommandLineExecutable.StartsWith('"')) {
                $script:matches = [Regex]::Match($script:Info.CommandLineExecutable, '\"([^\"]*)\"(.*)')
            }
            Else {
                $script:matches = [Regex]::Match($script:Info.CommandLineExecutable, '(\S+)(.*)')
            }

            If ($script:matches.Success -and $script:matches.Groups.Count -ge 3) {
                $script:executable = $script:matches.Groups[1].Value.Trim().Replace('"', '')
                $script:arguments = $script:matches.Groups[2].Value.Trim().Replace('"', '')
            }

            If ([string]::IsNullOrEmpty($PathListView.SelectedItem)) {
                $script:iconData = New-BrokerIcon -EncodedIconData (Get-XAApplicationIcon -ComputerName $global:OldFarmHost -BrowserName $script:Info.BrowserName).EncodedIconData
                $script:createdApp = New-BrokerApplication -Name $script:Info.BrowserName -DesktopGroup $DGListView.SelectedItem -CommandLineExecutable $script:executable -CommandLineArguments $script:arguments -Enabled (-not [System.Convert]::ToBoolean($script:Info.Enabled)) -IconUid $script:iconData.Uid -Description $script:Info.Description -WorkingDirectory $script:Info.WorkingDirectory
                $script:Info.Accounts | % { Add-BrokerUser -Application $script:createdApp $_.AccountDisplayName }
                Set-BrokerApplication -InputObject $script:createdApp -UserFilterEnabled $true
            }
            Else {
                $script:iconData = New-BrokerIcon -EncodedIconData (Get-XAApplicationIcon -ComputerName $global:OldFarmHost -BrowserName $script:Info.BrowserName).EncodedIconData
                $script:createdApp = New-BrokerApplication -Name $script:Info.BrowserName -DesktopGroup $DGListView.SelectedItem -CommandLineExecutable $script:executable -CommandLineArguments $script:arguments -AdminFolder $PathListView.SelectedItem -Enabled (-not [System.Convert]::ToBoolean($script:Info.Enabled)) -IconUid $script:iconData.Uid  -Description $script:Info.Description -WorkingDirectory $script:Info.WorkingDirectory
                $script:Info.Accounts | % { Add-BrokerUser -Application $script:createdApp $_.AccountDisplayName }
                Set-BrokerApplication -InputObject $script:createdApp -UserFilterEnabled $true
            }

            If ($script:createdApp -ne $null) {
                $script:newTitle = "XenApp " + $global:NewFarmVersion + " Farm: " + $global:NewFarmHost
                Show-Info -Title $script:newTitle -Info $script:createdApp
                FetchAllData
            }
            Else {
                [System.Windows.MessageBox]::Show('There was an error creating application ' + $script:createdApp.ApplicationName + '. Please check application settings and try again. ' )
                FetchAllData
            }
        }
        $CreateButton.Add_Click($CreateButton_OnClick)
        $CancelButton.Add_Click( { [void]$CreateNewApp.Close() })

        $CreateNewApp.controls.Add($PathListView)
        $CreateNewApp.controls.Add($DGListView)
        $CreateNewApp.controls.Add($PathListLabel)
        $CreateNewApp.controls.Add($DGListLabel)
        $CreateNewApp.controls.Add($CreateButton)
        $CreateNewApp.controls.Add($CancelButton)

        [void]$CreateNewApp.ShowDialog()
    }

    # Get application information from new farm. Only works if app exists on new farm
    $btnNewInfo_OnClick = {
        $script:selectedItem = $listviewMigrateApps.SelectedItem
        $script:Info = Get-BrokerApplication -AdminAddress $global:NewFarmHost -ApplicationName $script:selectedItem.ApplicationName
        $script:Title = "XenApp " + $global:NewFarmVersion + " Farm: " + $global:NewFarmHost
        Show-Info -Title $script:Title -Info $script:Info
    }

    # Handle Migrating selected application(s) from Old farm to New farm
    $btnO2N_OnClick = {
        $script:apps = $listviewMigrateApps.SelectedItems
        ForEach ($script:app in $script:apps) {
            Get-XAApplication -ComputerName $global:OldFarmHost -BrowserName $script:app.ApplicationName | Set-XAApplication -ComputerName $global:OldFarmHost -Enabled $false -HideWhenDisabled $true
            Get-BrokerApplication -AdminAddress $global:NewFarmHost -ApplicationName $script:app.ApplicationName | Set-BrokerApplication -Enabled $true -Visible $true
        }
        FetchAllData
        ForEach ($script:item in $script:apps) {
            $listviewMigrateApps.SelectedItems.Add($script:item)
        }
    }

    # Handle Migrating selected application(s) from New farm to Old farm (in case of issues on new farm)
    $btnN2O_OnClick = {
        $script:apps = $listviewMigrateApps.SelectedItems
        ForEach ($script:app in $script:apps) {
            Get-XAApplication -ComputerName $global:OldFarmHost -BrowserName $script:app.ApplicationName | Set-XAApplication -ComputerName $global:OldFarmHost -Enabled $true -HideWhenDisabled $true
            Get-BrokerApplication -AdminAddress $global:NewFarmHost -ApplicationName $script:app.ApplicationName | Set-BrokerApplication -Enabled $false -Visible $false
        }
        FetchAllData
        ForEach ($script:item in $script:apps) {
            $listviewMigrateApps.SelectedItems.Add($script:item)
        }
    }

    $listviewMigrateApps_SelectionChanged = {
        Clear-Host

        $global:currentDisplay = "All"

        # All Buttons are enabled when selection changes
        $global:btnO2OEnable = $false
        $global:btnN2OEnable = $false
        $global:btnOldInfoEnable = $false
        $global:btnNewInfoEnable = $false
        $global:btnNewInfoEnable = $false
        $global:btnCAINFEnable = $false
        
        # Check if any Items are selected
        If ($listviewMigrateApps.SelectedItems.Count -gt 0) {
            # Make sure all selected items for New -> Old are the same
            If (($listviewMigrateApps.SelectedItems | Linq-All { ([System.Convert]::ToBoolean($_.EnabledOld) -eq $true) }) -and ($listviewMigrateApps.SelectedItems | Linq-All { ([System.Convert]::ToBoolean($_.EnabledNew) -eq $false) -and (-not [string]::IsNullOrEmpty($_.EnabledNew)) -and (-not [string]::IsNullOrEmpty($_.EnabledOld)) })) {
                $global:btnO2NEnable = $true
            }
            Else {
                $global:btnO2NEnable = $false
            }
            # Make sure all selected items for Old -> New are the same
            If (($listviewMigrateApps.SelectedItems | Linq-All { ([System.Convert]::ToBoolean($_.EnabledNew) -eq $true) }) -and ($listviewMigrateApps.SelectedItems | Linq-All { ([System.Convert]::ToBoolean($_.EnabledOld) -eq $false) -and (-not [string]::IsNullOrEmpty($_.EnabledOld)) -and (-not [string]::IsNullOrEmpty($_.EnabledNew)) })) {
                $global:btnN2OEnable = $true
            }
            Else {
                $global:btnN2OEnable = $false
            }
            # As long as only 1 item is selected, and those items are applicable, enable the appropriate info button
            If ($listviewMigrateApps.SelectedItems.Count -eq 1) {
                If (-not [string]::IsNullOrEmpty($listviewMigrateApps.SelectedItem.EnabledOld)) {
                    $global:btnOldInfoEnable = $true
                }
                If (-not [string]::IsNullOrEmpty($listviewMigrateApps.SelectedItem.EnabledNew)) {
                    $global:btnNewInfoEnable = $true
                }
                # Check to see if we need to display the "Create app in New Farm option"
                If (($listviewMigrateApps.SelectedItems | Linq-All { (-not [string]::IsNullOrEmpty($_.EnabledOld)) -and ([string]::IsNullOrEmpty($_.EnabledNew)) })) {
                    $global:btnCAINFEnable = $true
                }
                Else {
                    $global:btnCAINFEnable = $false
                }
            }
            # Disable remaining buttons if no selection
        }
        Else {
            $global:btnO2NEnable = $false
            $global:btnN2OEnable = $false
        }

        # Enable/Disable the buttons per previous checks
        $OldInfo_Menu.IsEnabled = $global:btnOldInfoEnable
        $NewInfo_Menu.IsEnabled = $global:btnNewInfoEnable
        $N2O_Menu.IsEnabled = $global:btnN2OEnable
        $O2N_Menu.IsEnabled = $global:btnO2NEnable
        $CreateAppInNewFarm_Menu.IsEnabled = $global:btnCAINFEnable
        # $btnOldInfo.IsEnabled = $global:btnOldInfoEnable
        # $btnNewInfo.IsEnabled = $global:btnNewInfoEnable
        # $btnN2O.IsEnabled = $global:btnN2OEnable
        # $btnO2N.IsEnabled = $global:btnO2NEnable
    }

    $cmboDisplay_SelectionChanged =
    {
        $global:currentDisplay = $cmboDisplay.SelectedValue
        FetchAllData
    }

    # Bind events to GUI elements
    $listviewMigrateApps.add_SelectionChanged($listviewMigrateApps_SelectionChanged)
    $OldInfo_Menu.Add_Click($btnOldInfo_OnClick)
    $NewInfo_Menu.Add_Click($btnNewInfo_OnClick)
    $O2N_Menu.Add_Click($btnO2N_OnClick)
    $N2O_Menu.Add_Click($btnN2O_OnClick)
    # $btnOldInfo.Add_Click($btnOldInfo_OnClick)
    # $btnNewInfo.Add_Click($btnNewInfo_OnClick)
    # $btnO2N.Add_Click($btnO2N_OnClick)
    # $btnN2O.Add_Click($btnN2O_OnClick)
    $CreateAppInNewFarm_Menu.Add_Click($CreateAppInNewFarm_Menu_OnClick)
    $cmboDisplay.Add_SelectionChanged($cmboDisplay_SelectionChanged)
    $cmboDisplay.SelectedIndex = 0

    # Initial Data fetch
    FetchAllData

    # Initial selection of topmost item
    $listviewMigrateApps.SelectedIndex = 0
}

# Start the show
Initialize
$window.ShowDialog() | Out-Null
<# 
Issue:  This script with relevant CSV input data takes 2-3 hours to run. Looking to make faster / more efficient

Story:  There is an existing shop system made by the Flintstones which has very very basic sales data in one CSV table.
        The Jetsons have come along and introduced their system which works in conjunction with the Flintstones system.
        The Jetsons system creates multiple CSV tables but wants ~$20,000 for the module to produce decent reports.
        I don't want to pay that much so have written the below script to join all the Jetsons tables with the Flintstones table.
        I'm pretty much replicating an SQL inner-join.
        I then have other scripts to manipulate the one "MasterTable" to then produce awesome HTML reports (those scripts run fine).

NOTE:   This is actually for a different type of system but I converted all the variables to that of a shop system with faux data
        for security reasons. If you see a possible improvement due to duplicates/patterns in the data, that may as well be ignored
        sorry as I had to mock up a lot of data to replicate the slowness of this script.

My experience:  I'm an old fashioned whiz with BAT/CMD files and have slowly been teaching myself PowerShell by Googling commands.
                I'm sure I can improve by using ForEach as well as an alternative to multidimensional arrays.

THANKS: I thank anyone that can assist with this. I'm always looking for ways to improve by knowledge.
#>

cls
## Record script start date and time
$ScriptStartDate = Get-Date -Format "dd/MM/yyyy"
$ScriptStartTime = Get-Date -Format "HH:mm:ss"
Write-Host Script Start Time: $ScriptStartDate $ScriptStartTime

### Variables
$TempLocation = "C:\Temp\SalesData"

# Old shop system data made by the Flintstones
$FlintstonesShopDataCSV = $TempLocation + "\A1-FlintstonesShopData.csv"

# New shop system data made by the Jetsons
$JetItemIndexCSV = $TempLocation + "\B1-Jet-ItemIndex.csv"
$JetSalesCSV = $TempLocation + "\B2-Jet-Sales.csv"
$JetEffectiveDiscountsCSV = $TempLocation + "\B3-Jet-EffectiveDiscounts.csv"
$JetShelfLocationTranslationCSV = $TempLocation + "\B4-Jet-ShelfLocationTranslation.csv"
$JetItemCategoryTranslationCSV = $TempLocation + "\B5-Jet-ItemCategoryTranslation.csv"

# Output "MasterTable" that joins the Flintstones data and Jetsons data together
$MasterTableCSV = $TempLocation + "\C1-MasterTable.csv"

# MasterTable column headers in preferred order
$MasterTableColumnOrder = @("JetsonItemID", "FlintstoneItemID", "ItemName", "ShelfLocationCode", "ShelfLocationName", "Day", "SaleDate", "Time", "PercentDiscount", "ItemCategoryCode", "ItemCategoryName", "Price")

### Commands
## CSV imports
$FlintstonesShopDataTable = Import-CSV $FlintstonesShopDataCSV
$JetItemIndexTable = Import-CSV $JetItemIndexCSV
$JetSalesTable = Import-CSV $JetSalesCSV | Sort-Object {[datetime]::ParseExact($_.'Time', "H:mm", $null)} -Erroraction 'silentlycontinue' # Ordered by time
$JetEffectiveDiscountsTable = Import-CSV $JetEffectiveDiscountsCSV | Sort-Object {[datetime]::ParseExact($_.'EffectiveDate', "dd/MM/yyyy", $null)} # Ordered by date
$JetShelfLocationTranslation = Import-CSV $JetShelfLocationTranslationCSV
$JetItemCategoryTranslation = Import-CSV $JetItemCategoryTranslationCSV

## MasterTable setup
# Copy FlintstonesShopDataTable as a base for the MasterTable
$MasterTable = $FlintstonesShopDataTable | Select *

# Add other columns to table ready to be filled
$MasterTable | Add-Member -MemberType NoteProperty "JetsonItemID" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "ItemName" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "ShelfLocationCode" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "ShelfLocationName" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "Day" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "PercentDiscount" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "ItemCategoryName" -Value ""
$MasterTable | Add-Member -MemberType NoteProperty "Time" -Value ""

# Update missing column values in MasterTable array by going through every row of the MasterTable array
$MasterTableCount = ($MasterTable | Measure-Object).Count
for ($RowID = 0; $RowID -le $MasterTableCount-1; $RowID++) {
    # Update values in JetsonItemID and ItemName columns in MasterTable array by checking against the FlintStoneItemID
    $TempFilter = $JetItemIndexTable | ?{ $_.FlintstoneItemID -eq $MasterTable[$RowID].FlintstoneItemID }
    $MasterTable[$RowID].JetsonItemID = $TempFilter[0].JetsonItemID
    $MasterTable[$RowID].ItemName = $TempFilter[0].ItemName
    # Update values in ShelfLocationCode and PercentDiscount columns in MasterTable array by checking against the JetsonItemID
    $TempFilter = $JetEffectiveDiscountsTable | ?{ $_.JetsonItemID -eq $MasterTable[$RowID].JetsonItemID }
    $TempFilterRowCount = ($TempFilter | Measure-Object).Count
    If ($TempFilterRowCount -eq 1) {
        # If only one result, then the data there must be what is required
        $MasterTable[$RowID].ShelfLocationCode = $TempFilter[0].ShelfLocationCode
        $MasterTable[$RowID].PercentDiscount = $TempFilter[0].PercentDiscount
    } else {
        # If 0 or more than 1 result, something may have gone wrong in the original Flintstones and/or Jetsons CSV exports. Just in case, the fields will be filled with UN for Unknown for if the next checks fail to provide correct data
        $MasterTable[$RowID].ShelfLocationCode = "UN"
        $MasterTable[$RowID].PercentDiscount = "UN"
        If ($TempFilterRowCount -gt 1) {
            # Runs through every EffectiveDate result to find the last date a DiscountPercentage was implemented relevant to the SaleDate
            for ($TempFilterRowID = 0; $TempFilterRowID -le $TempFilterRowCount-1; $TempFilterRowID++) {
                # Converts date-text to actual date-format so comparisons can be made
                $TempFilterEffectiveDate = $TempFilter[$TempFilterRowID].EffectiveDate
                $TempFilterEffectiveDate = [DateTime]::ParseExact($TempFilterEffectiveDate, "dd/MM/yyyy", $null)
                $MasterTableSaleDate = $MasterTable[$RowID].SaleDate
                $MasterTableSaleDate = [DateTime]::ParseExact($MasterTableSaleDate, "dd/MM/yyyy", $null)
                # The data should be in date order so the last true "If statement" will update the fields correctly
                If ($MasterTableSaleDate -ge $TempFilterEffectiveDate) {
                    $MasterTable[$RowID].ShelfLocationCode = $TempFilter[$TempFilterRowID].ShelfLocationCode
                    $MasterTable[$RowID].PercentDiscount = $TempFilter[$TempFilterRowID].PercentDiscount
                }
            }
        }
    }
    # Update values in Time column in MasterTable array with all Times (separated by commas) for the relevant SaleDate as a string - By checking against the JetsonItemID and SaleDate
    $TempFilter = $JetSalesTable | ?{ $_.JetsonItemID -eq $MasterTable[$RowID].JetsonItemID } | ?{ $_.SaleDate -eq $MasterTable[$RowID].SaleDate }
    $TempFilterRowCount = ($TempFilter | Measure-Object).Count
    for ($TempFilterRowID = 0; $TempFilterRowID -le $TempFilterRowCount-1; $TempFilterRowID++) {
        If ($TempFilterRowID -ne 0) {
            # 'Separating comma' in sting of Times
            $MasterTable[$RowID].Time = $MasterTable[$RowID].Time += ", "
        }
        # Adds the latest Time to the string of Times
        $MasterTable[$RowID].Time = $MasterTable[$RowID].Time += $TempFilter[$TempFilterRowID].Time
    }
    # Update ShelfLocationCode column values to 4 characters from 3 if they aren't already 4 characters. This is just to fix some numerical ShelfLocationCodes that are missing the leading zero.
    If ($MasterTable[$RowID].ShelfLocationCode.Length -eq 3) {
        $MasterTable[$RowID].ShelfLocationCode = "0" + $MasterTable[$RowID].ShelfLocationCode
    }
    # Update values in the ShelfLocationName column in MasterTable array by checking against the ShelfLocationCode
    $TempFilter = $JetShelfLocationTranslation | ?{ $_.ShelfLocationCode -eq $MasterTable[$RowID].ShelfLocationCode }
    $MasterTable[$RowID].ShelfLocationName = $TempFilter[0].ShelfLocationName
    # Update values in Day column in MasterTable array
    $MasterTable[$RowID].Day = (Get-Date $MasterTable[$RowID].SaleDate).ToString("ddd").ToUpper()
    # Update ItemCategoryCode column values to 4 characters from 3 if they aren't already 4 characters. This is just to fix some numerical ItemCategoryCodes that are missing the leading zero.
    If ($MasterTable[$RowID].ItemCategoryCode.Length -eq 3) {
        $MasterTable[$RowID].ItemCategoryCode = "0" + $MasterTable[$RowID].ItemCategoryCode
    }
    # Update values in the ItemCategoryName column in MasterTable array by checking against the ItemCategoryCode
    $TempFilter = $JetItemCategoryTranslation | ?{ $_.ItemCategoryCode -eq $MasterTable[$RowID].ItemCategoryCode }
    $MasterTable[$RowID].ItemCategoryName = $TempFilter[0].ItemCategoryName

    Write-Host $RowID of ($MasterTableCount-1) done
}

## Formatting MasterTable and exporting to CSV (I don't know how to sort an array except when importing a CSV)
# Export MasterTable as CSV in the correct column order
$MasterTable | Select-Object -Property $MasterTableColumnOrder | Export-CSV -notype $MasterTableCSV
# Re-import MasterTable to then order by date
$MasterTable = Import-CSV $MasterTableCSV | Sort-Object {[datetime]::ParseExact($_.'SaleDate', "dd/MM/yyyy", $null)}
# Re-export MasterTable as CSV now that all the formatting changes have been made
$MasterTable | Export-CSV -notype $MasterTableCSV

## Show script start date and time again
Write-Host Script Start Time: $ScriptStartDate $ScriptStartTime

## Record script end date and time
$ScriptEndDate = Get-Date -Format "dd/MM/yyyy"
$ScriptEndTime = Get-Date -Format "HH:mm:ss"
Write-Host "Script End Time:  " $ScriptEndDate $ScriptEndTime
PAUSE

# Corruption text buffer (some antiviruses like to garble the end of my text based files)
# Corruption text buffer (some antiviruses like to garble the end of my text based files)
# Corruption text buffer (some antiviruses like to garble the end of my text based files)

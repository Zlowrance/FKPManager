$SHEET_URL = "https://docs.google.com/spreadsheets/d/1HMhajOv58CHcjiYH6hp1Qtd3HQeG7yySdtZX7iYte1Q/gviz/tq?tqx=out:csv&sheet=!onlyfangs"
$CSV_FILE = "downloaded_sheet.csv"
$LUA_FILE = "FKPData.lua"
$CURRENT_TIMESTAMP = [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s))

# Create TextInfo object
$textInfo = (Get-Culture).TextInfo

# Function to convert to title case (capital first letter, rest lowercase)
function ConvertToTitleCase($name) {
    return $textInfo.ToTitleCase($name.ToLower())
}

# Define column names
$characterColName = "Character"
$fkpColName = "FKP"

# Download CSV
Invoke-WebRequest -Uri $SHEET_URL -OutFile $CSV_FILE

# Read the first few lines and remove rogue newlines
$initialLines = Get-Content $CSV_FILE -Encoding UTF8 | Select-Object -First 5
$mergedHeader = $initialLines -join ""

# Process the rest of the CSV file
$csvData = Get-Content $CSV_FILE -Encoding UTF8 | Select-Object -Skip 5

# Combine the corrected header with the rest of the data
$correctedCSVData = $mergedHeader, $csvData

$correctedCSVData | Out-File -FilePath $CSV_FILE -Encoding UTF8

# Read the first line to identify column indices
$firstLine = Get-Content $CSV_FILE -First 1
$columns = $firstLine -split ','
$characterIndex = $columns.IndexOf("`"$characterColName`"")
$fkpIndex = $columns.IndexOf("`"$fkpColName`"")

# Process CSV File
$csvData = Get-Content $CSV_FILE | Select-Object -Skip 1
$luaContent = @("FKPData = {")
foreach ($line in $csvData) {
    $columns = $line -split ','
    $character = ConvertToTitleCase($columns[$characterIndex].Trim('"'))
    $fkp = $columns[$fkpIndex].Trim('"')
    if ($character -ne "") {
        $fkpValue = if ($fkp -eq "") { "0" } else { $fkp }
        $luaContent += "`t[`"$character`"] = $fkpValue,"
    }
}
$luaContent += "}"
$luaContent += "FKPDataLastUpdated = $CURRENT_TIMESTAMP"

# Write to Lua File
$luaContent | Out-File -FilePath $LUA_FILE -Encoding UTF8

# Cleanup
Remove-Item $CSV_FILE

Write-Host "FKP data table created: $LUA_FILE"

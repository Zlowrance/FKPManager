#!/bin/bash

SHEET_URL="https://docs.google.com/spreadsheets/d/1HMhajOv58CHcjiYH6hp1Qtd3HQeG7yySdtZX7iYte1Q/gviz/tq?tqx=out:csv&sheet=!onlyfangs"

CSV_FILE="downloaded_sheet.csv"

LUA_FILE="FKPData.lua"

CURRENT_TIMESTAMP=$(date +%s)

curl -L "$SHEET_URL" -o "$CSV_FILE"

# Process the first 3 lines HACKY: This is to skip the random \n in some of the column headers, so if those change then this could break
head -n 3 "$CSV_FILE" | tr -d '\r\n' > tmp.csv

# Append the rest of the file as is
tail -n +4 "$CSV_FILE" >> tmp.csv

# Replace the original file with the modified one
mv tmp.csv "$CSV_FILE"

# Create or overwrite the Lua file
echo "FKPData = {" > "$LUA_FILE"

col_a='Character'
col_b='FKP'
loc_col_a=$(head -1 "$CSV_FILE" | tr ',' '\n' | nl | grep -w "$col_a" | tr -d " " | awk '{print $1}')
loc_col_b=$(head -1 "$CSV_FILE" | tr ',' '\n' | nl | grep -w "$col_b" | tr -d " " | awk '{print $1}')

awk -v colA="$loc_col_a" -v colB="$loc_col_b" -F, 'NR > 1 {
    gsub(/"/, "", $colA);
    gsub(/"/, "", $colB);

    if ($colA != "") {                      # Check if the Character column is not empty
        if ($colB == "") $colB = 0;         # Replace empty FKP values with 0
        print "    [\"" $colA "\"] = " $colB ",";
    }
}' "$CSV_FILE" >> "$LUA_FILE"

echo "}" >> "$LUA_FILE"

echo "FKPDataLastUpdated = $CURRENT_TIMESTAMP" >> "$LUA_FILE"

# cleanup csv file
rm "$CSV_FILE"

echo "FKP data table created: $LUA_FILE"

# FKPManager

AddOn for managing FKP item bids/rolls.

- Download FKPManager.zip from latest release
- Extract to AddOns directory
- Double click FKPManager/download_fkp script to pull latest fkp from: https://docs.google.com/spreadsheets/d/1HMhajOv58CHcjiYH6hp1Qtd3HQeG7yySdtZX7iYte1Q/edit#gid=1912415391
- Once in-game type /fkp to begin


# Bidding Flow
- Drag item from bags into slot at the top of FKPManager window
- Click BEGIN BIDDING button
- Users type "bid" in raid chat
- Once everyones bid is in, click END BIDDING
- Users will be messaged the /roll command to use and a table of the rolls will also be printed to raid chat
- As users roll their results will be displayed in the player list
- Once a winner is found, click the checkmark next to that user in the list
- When you select a winner, FKP will be deduected from their cached total. This FKP amount is defined in Globals.lua (default 10)
-   Cached FKP resets when data sheet is downloaded again

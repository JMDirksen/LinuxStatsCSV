# LinuxStatsCSV

## Test scripts
```
cd LinuxStatsCSV
./writestats.sh
cat stats.csv
./listener.sh
```
Go to: http://hostname:57475

## Automate scripts
```
crontab -e
```
```
SHELL=/bin/bash
@reboot ~/LinuxStatsCSV/listener.sh > /dev/null 2>&1
*/15 * * * * ~/LinuxStatsCSV/writestats.sh > /dev/null 2>&1
```
Run listener in background:
```
~/LinuxStatsCSV/listener.sh > /dev/null 2>&1 &
```

## Use CSV in Google Sheets
`=IMPORTDATA("http://hostname:57475")`

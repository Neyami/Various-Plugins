@echo off
setlocal enabledelayedexpansion

set COUNT=0
for /r %%G in (*.bsp) do (
    set /a COUNT+=1
    echo [!COUNT!] Exporting: %%~nxG
    ripent -export "%%G"
)

echo Done! Processed %COUNT% maps.
pause

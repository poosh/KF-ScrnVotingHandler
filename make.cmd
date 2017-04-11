@echo off
color 07

setlocal
set KFDIR=D:\Games\kf
set STEAMDIR=c:\Steam\steamapps\common\KillingFloor
rem remember current directory
set CURDIR=%~dp0

cd /D %KFDIR%\System
del ScrnVotingHandlerV4.*

ucc make
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 goto error
color 0A


del KillingFloor.log
del steam_appid.txt
copy ScrnVotingHandlerV4.* %STEAMDIR%\System\


rem return to previous directory
cd /D %CURDIR%

endlocal

echo --------------------------------
echo Compile successful.
echo --------------------------------
goto end

:error
color 0C
echo ################################
echo Compile ERROR! Code = %ERR%.
echo ################################

:end
pause

set ERRORLEVEL=%ERR%
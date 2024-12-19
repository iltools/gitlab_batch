@echo off
chcp 65001
rem 赋值where git给GITPATH
for /f "delims=" %%i in ('where git') do set GITPATH=%%i
rem 设置git-bash路径
set GITBASHPATH=%GITPATH:cmd\git.exe=git-bash.exe%
echo %GITBASHPATH%
rem pause
start "" "%GITBASHPATH%"  -c "sh gitlab_batch.sh;bash"
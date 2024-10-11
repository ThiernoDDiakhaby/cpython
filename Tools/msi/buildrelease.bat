@setlocal
@echo off

rem Configuration pour la version 3.11.10
set VERSION=3.11.10
set RELEASE_URI=http://www.python.org/amd64

rem Configuration du lien de téléchargement, en remplaçant {version} par 3.11.10 et {arch} par amd64
set DOWNLOAD_URL=https://www.python.org/ftp/python/%VERSION%/amd64/core.msi

set D=%~dp0
set PCBUILD=%D%..\..\PCbuild\
if NOT DEFINED Py_OutDir set Py_OutDir=%PCBUILD%
set EXTERNALS=%D%..\..\externals\windows-installer\

set BUILDX64=1
set TARGET=Rebuild
set TESTTARGETDIR=
set PGO=-m test -q --pgo
set BUILDMSI=1
set BUILDNUGET=1
set BUILDZIP=1

rem Désactiver les autres architectures
set BUILDX86=
set BUILDARM64=

:CheckOpts
if "%1" EQU "-h" goto Help
if "%1" EQU "--build" (set TARGET=Build) && shift && goto CheckOpts
if /I "%1" EQU "-x64" (set BUILDX64=1) && shift && goto CheckOpts
if "%1" NEQ "" echo Invalid option: "%1" && exit /B 1

if not exist "%GIT%" where git > "%TEMP%\git.loc" 2> nul && set /P GIT= < "%TEMP%\git.loc" & del "%TEMP%\git.loc"
if not exist "%GIT%" echo Cannot find Git on PATH && exit /B 1

call "%D%get_externals.bat"
call "%PCBUILD%find_msbuild.bat" %MSBUILD%
if ERRORLEVEL 1 (echo Cannot locate MSBuild.exe on PATH or as MSBUILD variable & exit /b 2)

:builddoc
if "%SKIPDOC%" EQU "1" goto skipdoc

call "%D%..\..\doc\make.bat" html
if errorlevel 1 exit /B %ERRORLEVEL%
:skipdoc

rem Construction pour amd64 uniquement
if defined BUILDX64 (
    call :build x64 "%PGO%"
    if errorlevel 1 exit /B %ERRORLEVEL%
)

if defined TESTTARGETDIR (
    call "%D%testrelease.bat" -t "%TESTTARGETDIR%"
    if errorlevel 1 exit /B %ERRORLEVEL%
)

exit /B 0

:build
@setlocal
@echo off

if "%1" EQU "x64" (
    set BUILD=%Py_OutDir%amd64\
    set PGO=%~2
    set BUILD_PLAT=x64
    set OUTDIR_PLAT=amd64
    set OBJDIR_PLAT=x64
) else (
    echo Unknown platform %1
    exit /B 1
)

if exist "%BUILD%en-us" (
    echo Deleting %BUILD%en-us
    rmdir /q/s "%BUILD%en-us"
    if errorlevel 1 exit /B %ERRORLEVEL%
)

if exist "%D%obj\Release_%OBJDIR_PLAT%" (
    echo Deleting "%D%obj\Release_%OBJDIR_PLAT%"
    rmdir /q/s "%D%obj\Release_%OBJDIR_PLAT%"
    if errorlevel 1 exit /B %ERRORLEVEL%
)

if not "%CERTNAME%" EQU "" (
    set CERTOPTS="/p:SigningCertificate=%CERTNAME%"
) else (
    set CERTOPTS=
)

if not "%PGO%" EQU "" (
    set PGOOPTS=--pgo-job "%PGO%"
) else (
    set PGOOPTS=
)

if not "%SKIPBUILD%" EQU "1" (
    @call "%PCBUILD%build.bat" -e -p %BUILD_PLAT% -t %TARGET% %PGOOPTS% %CERTOPTS%
    if errorlevel 1 exit /B %ERRORLEVEL%
)

rem MSI Build pour amd64
set BUILDOPTS=/p:Platform=%1 /p:BuildForRelease=true /p:DownloadUrl=%DOWNLOAD_URL% /p:ReleaseUri=%RELEASE_URI%
if defined BUILDMSI (
    %MSBUILD% "%D%bundle\releaselocal.wixproj" /t:Rebuild %BUILDOPTS% %CERTOPTS%
    if errorlevel 1 exit /B %ERRORLEVEL%
)

exit /B 0

:Help
echo buildrelease.bat [options]

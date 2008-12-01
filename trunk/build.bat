@echo off
cls
pushd modules
call build.bat
popd
dmd miface.d -run main.d
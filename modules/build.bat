@echo off
REM dmd -version=wa_module -oftemp.dll ../dll.d ../miface.d ../dll.def test.d & move temp.dll ..\wizarc_test.dll > NUL
dmd -version=wa_module -oftemp.dll ../dll.d ../miface.d ../dll.def zip.d & move temp.dll ..\wizarc_zip.dll > NUL
del temp.map 2> NUL
del temp.obj 2> NUL
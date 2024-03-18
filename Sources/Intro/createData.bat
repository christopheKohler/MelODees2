SET GFXCONV=..\..\..\ToolsForFramework\GfxConv\gfxconvd.exe
SET PALSTRIP=..\..\..\ToolsForFramework\StripImagePalette\Release\StripImagePalette.exe

%GFXCONV% data/logo.png data/logo.ami imagepal

%GFXCONV% data/LogoSmall.png data/LogoSmall.ami imagepal

%GFXCONV% data/LogoRSE.png data/LogoRSE.ami imagepal

echo Done!
pause





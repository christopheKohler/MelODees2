SET GFXCONV=..\..\..\ToolsForFramework\GfxConv\gfxconvd.exe
SET PALSTRIP=..\..\..\ToolsForFramework\StripImagePalette\Release\StripImagePalette.exe

%GFXCONV% data/logo_melodees.png data/logo_melodees.ami imagepal
%GFXCONV% data/gui.png data/gui.ami imagepal
%GFXCONV% data/full_background_960x112.png data/full_background_960x112.ami imagepal
%GFXCONV% data/gui_modeloop_rollover.png data/gui_modeloop_rollover.ami imagepal
%GFXCONV% data/gui_modeloop_on.png       data/gui_modeloop_on.ami       imagepal
%GFXCONV% data/gui_modeloop_off.png      data/gui_modeloop_off.ami      imagepal
%GFXCONV% data/gui_modeseq_rollover.png  data/gui_modeseq_rollover.ami  imagepal
%GFXCONV% data/gui_modeseq_on.png        data/gui_modeseq_on.ami        imagepal
%GFXCONV% data/gui_modeseq_off.png       data/gui_modeseq_off.ami       imagepal
%GFXCONV% data/gui_pause_rollover.png    data/gui_pause_rollover.ami    imagepal
%GFXCONV% data/gui_pause_on.png          data/gui_pause_on.ami          imagepal
%GFXCONV% data/gui_pause_off.png         data/gui_pause_off.ami         imagepal
%GFXCONV% data/gui_play_rollover.png     data/gui_play_rollover.ami     imagepal
%GFXCONV% data/gui_play_on.png           data/gui_play_on.ami           imagepal
%GFXCONV% data/gui_play_off.png          data/gui_play_off.ami          imagepal
%GFXCONV% data/gui_next_rollover.png     data/gui_next_rollover.ami     imagepal
%GFXCONV% data/gui_next_on.png           data/gui_next_on.ami           imagepal
%GFXCONV% data/gui_next_off.png          data/gui_next_off.ami          imagepal
%GFXCONV% data/gui_prev_rollover.png     data/gui_prev_rollover.ami     imagepal
%GFXCONV% data/gui_prev_on.png           data/gui_prev_on.ami           imagepal
%GFXCONV% data/gui_prev_off.png          data/gui_prev_off.ami          imagepal

%GFXCONV% data/title_mask_16_2colors.png data/title_mask_16_2colors.ami          imagepal
%GFXCONV% data/song_titles2.png           data/song_titles2.ami          imagepal

echo Done!
pause





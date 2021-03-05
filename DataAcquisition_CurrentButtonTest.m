function f = DataAcquisition;
%% This function runs a GUI to take data with the Andor Ion Ultra, controls
% a Newport ESP 301 stage, and a Keithley model ## ammeter.
% Kyle Wilkin 4-18-2019


f0 = msgbox('Checking for insturments...');
f0.Position([3 4])=f0.Position([3 4])*3;
f0.Position([1 2])=[300 300];
f0.Children(2).Children.FontSize=30;
f0.Children(2).Units='points';
f0.Children(2).Position(1)=200;
f0.Children(2).Position(2)=50;
f0.Children(1).Position(1)=180;
f0.Children(2).Children.VerticalAlignment='middle';
f0.Children(2).Children.HorizontalAlignment='center';
movegui(f0,'center')
drawnow;

%% Connect to picomotor

USBADDR = 1; %Set in the menu of the device, only relevant if multiple are attached
asm = NET.addAssembly('C:\Program Files\New Focus\New Focus Picomotor Application\Bin\UsbDllWrap.dll'); %load UsbDllWrap.dll library
NPASMtype = asm.AssemblyHandle.GetType('Newport.USBComm.USB'); %Get a handle on the USB class
NP_USB = System.Activator.CreateInstance(NPASMtype); %launch the class USB, it constructs and allows to use functions in USB.h
NP_USB.OpenDevices();  %Open the USB device
querydata = System.Text.StringBuilder(64);
NP_USB.Query(USBADDR,'*IDN?',querydata);
if querydata.Length
    isPicoMotorThere = 1;
    querydata = System.Text.StringBuilder(64);
    NP_USB.Query(USBADDR,'1TP?',querydata);
    pause(0.2)
    picoPosi = char(ToString(querydata));
else
    isPicoMotorThere = 0;
    picoPosi = 'N/A';
end


%% Set Up Picoammeter

COM='COM5';
obj1= instrfind({'Port','BaudRate'},{COM,9600});  

if isempty(obj1)
    obj1 = serial(COM, 'Tag', 'Picoammeter');
else
    fclose(obj1);
    obj1 = serial(COM, 'Tag', 'Picoammeter');
%     obj1 = obj1;
end
fopen(obj1); 
fprintf(obj1,'*RST '); %*RST, Returns Model 6485 to the *RST default conditions.
% fprintf(obj1,'*IDN?');  % *IDN?, Returns the manufacturer, model number, serial 
% idn=fscanf(obj1);  % read device information

% fprintf(obj1,'TRIG:DEL 0 ')% Set trigger delay to zero seconds

fprintf(obj1,'SYST:ZCH ON '); % enable zero check
fprintf(obj1,'SENS:CURR:RANG 2e-9 ');% Use 2nA range
fprintf(obj1,'SYST:ZCOR ON'); % enable zero correct
fprintf(obj1,'SYST:ZCH OFF'); % disable zero check
fprintf(obj1,'INIT ');
fprintf(obj1,'CURR:RANG:AUTO ON ');
fprintf(obj1,'READ? ');
rst=fscanf(obj1); % '+3.838254E-15A,+2.570559E+05,+0.000000E+00'
cur=extractBefore(rst,'A');
CurrCurr=str2double(cur); 
% CurrCurr = 1;  % Comment when camera is available

%% Set Up Stage
StageCOM='COM3';
ASM = NET.addAssembly('C:\Users\Centurion\Documents\ESP 301\.NET Assembly\Newport.ESP301.CommandInterface.dll');  %#ok<NASGU> %Load the .NET .dll file for the ESP301 Controller
ESP301 = CommandInterfaceESP301.ESP301; %Create Instance
sl=seriallist; %Check if the specified COM is available
isThere=strfind(sl,StageCOM);
for ii=1:length(isThere)
    if ~isempty(isThere{ii})
        err1 = ESP301.OpenInstrument(StageCOM,921600); %#ok<NASGU> %Open USB connection
        [result,StagePosi,~]=ESP301.PA_Get(1);
        isStageThere=1;
        break
    else
        StagePosi=0;
        isStageThere=0;
    end
end

%% Set Up Camera

ret=AndorInitialize('');                      %   Initialize the camera
% CheckError(ret);
if ret==20003
    CurrGain=0;
    XPixels=1024;
    YPixels=1024;
    CurrTemp=0;
    isCameraThere=0;
else
    [ret,CurrGain]=GetEMCCDGain();
    % CurrGain=0; % Comment when able to connect to the computer
    [ret,XPixels, YPixels]=GetDetector;           %   Get the CCD size
    CheckWarning(ret);
    [ret]=SetImage(1, 1, 1, XPixels, 1, YPixels); %   Set the image size
    CheckWarning(ret);
    % XPixels=1024;YPixels=1024;
    % I=rand(1024,1024); % Comment out when camera is available
    
    
    [ret,CurrTemp]=GetTemperature();
    % CurrTemp = 20;
    isCameraThere=1;
end
I=zeros(YPixels,XPixels);
Back=I;
%% Initilize Values
InitialJogValue=0.05;
InitialJogValueFW=10;
InitialNumImages2Save=1;
InitialStart=StagePosi;
InitialEnd=StagePosi+1;
InitialStep=0.05;
InitialTempValue=-60;
InitialExposureTime=0.01;
InitialGain=2;


DateTime=clock;
Date=num2str(DateTime(3),'%2i');if length(Date) ==1; Date=['0' Date];end
Month=num2str(DateTime(2),'%2i');if length(Month) ==1; Month=['0' Month];end
Year=num2str(DateTime(1),'%4i');
FolderDate=[Month Date Year];
% InitialPath=['D:\experiments\' FolderDate];
InitialPath=['C:\' FolderDate];
if ~exist(InitialPath,'dir')
    mkdir(InitialPath);
end

BackExp=0;
WaitForImages=0;
RotateNum=1;


%% Set up figure
if isCameraThere
    f = figure('Visible','off','Position',[200,50,1310,900],'CloseRequestFcn',@closeFigFcn);
else
    f = figure('Visible','off','Position',[200,50,1310,900]);
end

set(f,'WIndowButtonDownFcn',@Button_Down);

la=215;

haxis = axes('Units','Pixels','Position',[la,100+250,600,540]);  %The +250 is from changing the size of the figure;
imagesc(haxis,I);
zoom('on');
caxis=[500 700];
colorbar;

bRangeSlider = com.jidesoft.swing.RangeSlider(1,1024,1,1024);  % min,max,low,high
[bRangeSlider, bContainer] = javacomponent(bRangeSlider, [la,300,550,30], f);
bRangeSlider = handle(bRangeSlider, 'CallbackProperties');
set(bRangeSlider, 'StateChangedCallback',@Slider_Change);

lRangeSlider = com.jidesoft.swing.RangeSlider(1,1024,1,1024);  % min,max,low,high
[lRangeSlider, lContainer] = javacomponent(lRangeSlider, [150,300,550,30], f);
lRangeSlider = handle(lRangeSlider, 'CallbackProperties');
set(lRangeSlider, 'Orientation',1,'StateChangedCallback',@Slider_Change);
set(lContainer,'position',[150,350,30,540]);


bLowValue = get(bRangeSlider,'lowValue');
bHighValue = get(bRangeSlider,'highValue');
lLowValue = 1024-get(lRangeSlider,'highValue')+1;   % The slider is upside down and this is the easiest way to fix it.
lHighValue = 1024-get(lRangeSlider,'lowValue')+1;


bProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),1);
baxis = axes('Units','Pixels','Position',[la,170,540,125]);
plot(baxis,bLowValue:bHighValue,bProjection);
baxis.XLim=[0 1024];


lProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),2);
laxis = axes('Units','Pixels','Position',[25,350,120,540]);
plot(laxis,lLowValue:lHighValue,lProjection);
camroll(laxis,-90);
laxis.XLim=[0 1024];
laxis.YAxisLocation='right';


%% First Column of callbacks
la=815;
Top=592+250;  %The +250 is from changing the size of the figure;
H20=20;z20=0;H30=30;z30=0;

TempSetTitle = uicontrol('Style','text','String','Enter Cooling Temp','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
hTemp = uicontrol('Style','edit','String',InitialTempValue,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20],'Callback',@Temp_Edit);
z20=z20+1;
TempCurrentTitle = uicontrol('Style','text','String','Current Cooling Temp','Position',[la,Top-z20*(H20+5)-z30*(H30+5),120,H20]);
z20=z20+1;
TempUp = uicontrol('Style','text','String',CurrTemp,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20]);
z20=z20+1;
GetTempButton= uicontrol('Style','togglebutton','String','Get Temp','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Get_Temp_Button);
z30=z30+1;


StartCool = uicontrol('Style','pushbutton','String','Start Cooling','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Start_Cooling);
StartCool.BackgroundColor=[1 0 0];
z30=z30+1;


ExpTimeTitle = uicontrol('Style','text','String','Exposure Time','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
hExpTime = uicontrol('Style','edit','String',InitialExposureTime,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20]);

z20=z20+1;z20=z20+1;
TakeVideo= uicontrol('Style','pushbutton','String','Take Video','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Take_Video);
z30=z30+1;

AbortAcquiVideo= uicontrol('Style','togglebutton','String','Stop Video','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30]);
z30=z30+1;

ShutDownCamera= uicontrol('Style','togglebutton','String','Shut Down Camera','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Shut_Down_Camera);
z30=z30+1;z30=z30+1;

TakeBackTitle = uicontrol('Style','text','String','Number of Background Images','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30]);
z20=z20+1;
hBackNum = uicontrol('Style','edit','String',10,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20]);
z30=z30+1;
hTakeBack = uicontrol('Style','pushbutton','String','Take Background','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Take_Back);
z30=z30+1;
hSubtractBack = uicontrol('Style','togglebutton','String','Subtract Background','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Subtract_Back);
z30=z30+1;
hSaveBack = uicontrol('Style','pushbutton','String','Save Back','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Save_Back);
z20=z20+1;z20=z20+1;


PathChoice = uicontrol('Style','text','String','Choose Path','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
hPath = uicontrol('Style','edit','String',InitialPath,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
% z20=z20+1;
Browse= uicontrol('Style','pushbutton','String','...','Position',[la+102,Top-z20*(H20+5)-z30*(H30+5),20,15],'Callback',@Get_Path);
z30=z30+1;

NumSaveImagesTitle = uicontrol('Style','text','String','Number of Images to Save','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H20]);
z20=z20+1;
hNumSaveImages = uicontrol('Style','edit','String',InitialNumImages2Save,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20]);
z30=z30+1;
hSaveImages = uicontrol('Style','pushbutton','String','Save Images','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Save_Images);
z20=z20+1;z20=z20+1;

CurrentTitle = uicontrol('Style','text','String','Current (pA)','Position',[la,Top-z20*(H20+5)-z30*(H30+5),120,H20]);
z20=z20+1;
CurrentDisplay = uicontrol('Style','text','String',CurrCurr,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20]);
z20=z20+1;
GetCurrentButton= uicontrol('Style','togglebutton','String','Get Current','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Get_Current_Button);
z30=z30+1;
BigCurrentButton= uicontrol('Style','togglebutton','String','Display Large Current','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Big_Current_Button);

align([hTemp,TempSetTitle,TempUp,GetTempButton,TempCurrentTitle,StartCool,TakeVideo,ExpTimeTitle,hExpTime,AbortAcquiVideo,ShutDownCamera,TakeBackTitle,hBackNum,hTakeBack,hSubtractBack,hSaveBack,...
    PathChoice,hPath,NumSaveImagesTitle,hNumSaveImages,hSaveImages,CurrentTitle,CurrentDisplay,GetCurrentButton,BigCurrentButton],'Center','None');
Browse.Position=hPath.Position+[102 0 -85 0];

%% Second Column of Callbacks
la=1040;
Top=592+250;  %The +250 is from changing the size of the figure;
H20=20;z20=0;H30=30;z30=0;
AcquiModeTitle = uicontrol('Style','text','String','Choose Acquisition Mode','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H20]);
z20=z20+1;
AcquiModeList={'Single Scan','Accumulate','Kinetics'};
hAcquiMode = uicontrol('Style','popupmenu','String',AcquiModeList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Callback',@Set_Acqui_Permissions);
z30=z30+1;
StartAcqui = uicontrol('Style','pushbutton','String','Start Acquisition','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Start_Acqui);
z30=z30+1;
AbortAcqui = uicontrol('Style','pushbutton','String','Abort Acquisition','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Abort_Acqui);
z30=z30+1;

GainSetTitle = uicontrol('Style','text','String','Enter Gain','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
hGainSet = uicontrol('Style','edit','String',InitialGain,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),40,H20],'Callback',@Enable_Gain);
z20=z20+1;
CurrGainDisp = uicontrol('Style','text','String',CurrGain,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
GainModeTitle = uicontrol('Style','text','String','Choose Gain Mode','Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20]);
z20=z20+1;
GainModeList={'DAC 0-255 (No Gain)','DAC 0-4095','Linear (EM Gain)','Real EM gain'};
hSetGainMode = uicontrol('Style','popupmenu','String',GainModeList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Callback',@Gain_Mode);
z20=z20+1;z20=z20+1;

VerticalShiftTitle = uicontrol('Style','text','String','Choose Vertical Shift Speed (µs)','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H30]);
z20=z20+1;
VerticalShiftList={'[0.6]','[1.13]','[2.2]','4.33'};
hVertShiftSpeed = uicontrol('Style','popupmenu','String',VerticalShiftList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Value',2);
z20=z20+1;z20=z20+1;

VerticalAmpTitle = uicontrol('Style','text','String','Choose Vertical Voltage Amplitude','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H30]);
z20=z20+1;
VerticalAmpList={'Normal','+1','+2','+3','+4'};
hVertVoltAmp = uicontrol('Style','popupmenu','String',VerticalAmpList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Value',3);
z20=z20+1;z20=z20+1;

PreAmpGainTypeTitle = uicontrol('Style','text','String','Choose Pre Amplifier Gain Type','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H30]);
z20=z20+1;
PreAmpList={'EM Gain','Conventional'};
hPreAmpGain = uicontrol('Style','popupmenu','String',PreAmpList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Callback',@Pre_Amp_Gain);
z20=z20+1;z20=z20+1;

HSSpeedTitle = uicontrol('Style','text','String','Choose HS Speed (MHz)','Position',[la,Top-z20*(H20+5)-z30*(H30+5),150,H30]);
z20=z20+1;
HSSpeedList={'30','20','10','1'};
hHSSpeed = uicontrol('Style','popupmenu','String',HSSpeedList,'Position',[la,Top-z20*(H20+5)-z30*(H30+5),100,H20],'Value',4);
z20=z20+1;z20=z20+1;


align([AcquiModeTitle,hAcquiMode,StartAcqui,AbortAcqui,GainSetTitle,hGainSet,CurrGainDisp,GainModeTitle,hSetGainMode,VerticalShiftTitle,hVertShiftSpeed,...
    VerticalAmpTitle,hVertVoltAmp,PreAmpGainTypeTitle,hPreAmpGain,HSSpeedTitle,hHSSpeed],'Center','None');


%% Stage Controls
Posi=Browse.Position;
Posi(3)=300;
Posi(4)=150;

TabGroup = uitabgroup(f,'Units','pixels');
TabGroup.Position=Posi+[65 -130 0 0];
MoveTab = uitab(TabGroup,'Title','Move Only');
MoveAndSaveTab = uitab(TabGroup,'Title','Move and Save');
TimerTab = uitab(TabGroup,'Title','Timed Move and Save');


% 
la=10;
ba=60;
H5=20;z5=0;H10=10;z10=0;H20=20;z20=0;H30=30;z30=0;
x20=0;w20=20;x50=0;w50=50;x70=0;w70=70;


CurrPosiTitle = uicontrol(MoveAndSaveTab,'Style','text','String','Current Position (mm)','Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H30+10]);
z20=z20+1;z10=z10+1;
hCurrentPosi = uicontrol(MoveAndSaveTab,'Style','text','String',StagePosi,'Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H20]);
hCurrentPosi.BackgroundColor=[0.75 0.75 0.75];
align([CurrPosiTitle,hCurrentPosi],'Center','None');
StartScanTitle = uicontrol(MoveAndSaveTab,'Style','text','String','Start Position (mm)','Position',CurrPosiTitle.Position+[45 0 15 0]);
hStartScan = uicontrol(MoveAndSaveTab,'Style','edit','String',InitialStart,'Position',hCurrentPosi.Position+[50 0 0 0]);
EndScanTitle = uicontrol(MoveAndSaveTab,'Style','text','String','End Position (mm)','Position',StartScanTitle.Position+[45 0 3 0]);
hEndScan = uicontrol(MoveAndSaveTab,'Style','edit','String',InitialEnd,'Position',hStartScan.Position+[50 0 0 0]);
StepScanTitle = uicontrol(MoveAndSaveTab,'Style','text','String','Step Size (mm)','Position',EndScanTitle.Position+[60 0 -20 0]);
hStepScan = uicontrol(MoveAndSaveTab,'Style','edit','String',InitialStep,'Position',hEndScan.Position+[50 0 0 0]);
hMoveAndSave = uicontrol(MoveAndSaveTab,'Style','togglebutton','String','Start Scan','Position',hStepScan.Position+[55 5 40 30],'Callback',@Move_And_Save);
NonLinearBox = uicontrol(MoveAndSaveTab,'Style','checkbox','String','Select for Non-Linear Scan','Position',[CurrPosiTitle.Position(1:2) 100 30]+[0 50 0 0],'Callback',@Non_Linear_Scan);
NonLinearTitle = uicontrol(MoveAndSaveTab,'Style','text','String','Enter Scan Positions (a b:c)','Position',StartScanTitle.Position+[0 0 40 0],'Visible','off');
NonLinearScan = uicontrol(MoveAndSaveTab,'Style','edit','String','','Position',hStartScan.Position+[0 0 40 0],'Visible','off');



la=10;
ba=50;
H5=20;z5=0;H10=10;z10=0;H20=20;z20=0;H30=30;z30=0;
x20=0;w20=20;x50=0;w50=50;x70=0;w70=70;

CurrPosiTitle2 = uicontrol(MoveTab,'Style','text','String','Current Position (mm)','Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H30+10]);
z20=z20+1;
hCurrentPosi2 = uicontrol(MoveTab,'Style','text','String',StagePosi,'Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H20]);
hCurrentPosi2.BackgroundColor=[0.75 0.75 0.75];
align([CurrPosiTitle2,hCurrentPosi2],'Center','None');
StagePosiTitle = uicontrol(MoveTab,'Style','text','String','Enter Position (mm)','Position',CurrPosiTitle2.Position+[45 0 10 0]);
hMoveStage = uicontrol(MoveTab,'Style','edit','String',StagePosi,'Position',hCurrentPosi2.Position+[50 0 0 0],'Callback',@Move_Stage);
JogTitle = uicontrol(MoveTab,'Style','text','String','Jog (mm)','Position',StagePosiTitle.Position+[50 -5 0 -5]);
hJogValue = uicontrol(MoveTab,'Style','edit','String',InitialJogValue,'Position',hMoveStage.Position+[50 0 0 0]);
hJogDown = uicontrol(MoveTab,'Style','pushbutton','String','-','Position',hJogValue.Position+[50 0 0 0],'Callback',@Jog_Down);
hJogUp = uicontrol(MoveTab,'Style','pushbutton','String','+','Position',hJogDown.Position+[50 0 0 0],'Callback',@Jog_Up);




la=10;
ba=60;
H5=20;z5=0;H10=10;z10=0;H20=20;z20=0;H30=30;z30=0;
x20=0;w20=20;x50=0;w50=50;x70=0;w70=70;


Task2ExeTitle = uicontrol(TimerTab,'Style','text','String','Tasks to Execute','Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w70,H30+10]);
z20=z20+1;w20=w20+1;
Task2ExeField = uicontrol(TimerTab,'Style','edit','String',1,'Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H20]);
MinDelayTimeTitle = uicontrol(TimerTab,'Style','text','String','Min Time Between Scans (s)','Position',Task2ExeTitle.Position+[80 0 0 20]);
z20=z20+1;w20=w20+1;
MinDelayTimeField = uicontrol(TimerTab,'Style','edit','String',1,'Position',Task2ExeField.Position+[80 0 0 0]);
hTimerScan = uicontrol(TimerTab,'Style','togglebutton','String','Start Scan','Position',MinDelayTimeField.Position+[80 5 40 30],'Callback',@Timer_Scan);


align([Task2ExeTitle,Task2ExeField],'Center','Center')
align([MinDelayTimeTitle,MinDelayTimeField],'Center','Center')

la=1040;
hEnableButton = uicontrol('Style','pushbutton','String','Enable Buttons','Position',[la,20,100,H30],'Callback',@Enable_Buttons);




%% Under the Image
la=150;
ba=125;

JogTitleFW = uicontrol(MoveTab,'Style','text','String','Jog (Steps)','Position',[la,ba,150,20]);
hJogValueFW = uicontrol(MoveTab,'Style','edit','String',InitialJogValueFW,'Position',JogTitleFW.Position+[50 0 0 0]);
hJogDownFW = uicontrol(MoveTab,'Style','pushbutton','String','-','Position',hJogValueFW.Position+[50 0 0 0],'Callback',@Jog_DownFW);
hJogUpFW = uicontrol(MoveTab,'Style','pushbutton','String','+','Position',hJogDownFW.Position+[50 0 0 0],'Callback',@Jog_UpFW);



la=190;
ba=-125+250;  %The +250 is from changing the size of the figure;
c=caxis;
x100=0;w100=100;
caxisTitle = uicontrol('Style','text','String','Color Axis','Position',[la,ba,150,20]);
x100=x100+1;
hCaxisLSet = uicontrol('Style','edit','String',c(1),'Position',[la+x100*(w100+10),ba,w100,20],'Callback',@caxis_call);
x100=x100+1;
hCaxisHSet = uicontrol('Style','edit','String',c(2),'Position',[la+x100*(w100+10),ba,w100,20],'Callback',@caxis_call);
x100=x100+1;

hAutoScale = uicontrol('Style','togglebutton','String','Reset Scale','Position',[la+x100*(w100+10),ba,w100,20],'Callback',@Auto_Scale);
x100=x100+1;
hSetAutoScale = uicontrol('Style','togglebutton','String','Auto Scale','Position',[la+x100*(w100+10),ba,w100,20],'Value',0,'Callback',@Set_Auto_Scale);


ba=-175+250;  %The +250 is from changing the size of the figure;
x100=0;w100=100;
H20=20;z20=0;H30=30;z30=0;
c500t1000= uicontrol('Style','pushbutton','String','500 - 1000','Position',[la+x100*(w100+10),ba,w100,30],'Callback',@c_500_1000);x100=x100+1;c500t1000.BackgroundColor=[0 .75 .75];
c500t5000= uicontrol('Style','pushbutton','String','500 - 5000','Position',[la+x100*(w100+10),ba,w100,30],'Callback',@c_500_5000);x100=x100+1;c500t5000.BackgroundColor=[0 .75 .75];
c500t10000= uicontrol('Style','pushbutton','String','500 - 10000','Position',[la+x100*(w100+10),ba,w100,30],'Callback',@c_500_10000);x100=x100+1;c500t10000.BackgroundColor=[0 .75 .75];
c500t30000= uicontrol('Style','pushbutton','String','500 - 30000','Position',[la+x100*(w100+10),ba,w100,30],'Callback',@c_500_30000);x100=x100+1;c500t30000.BackgroundColor=[0 .75 .75];
cm200t200= uicontrol('Style','pushbutton','String','-200 - 200','Position',[la+x100*(w100+10),ba,w100,30],'Callback',@c_m200_2000);x100=x100+1;cm200t200.BackgroundColor=[0 .75 .75];

align([caxisTitle,hCaxisLSet,hCaxisHSet,hAutoScale,hSetAutoScale],'None','Center')
align([c500t1000,c500t5000,c500t10000,c500t30000,cm200t200],'None','Center')


ba=-175+250;  %The +250 is from changing the size of the figure;
H5=20;z5=0;H10=10;z10=0;H20=20;z20=0;H30=30;z30=0;
x20=0;w20=20;x50=0;w50=50;x70=0;w70=70;
z20=z20+1;z20=z20+1;
hRotateCC = uicontrol('Style','pushbutton','String','Rotate Counter Clockwise','Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50*3,H30+10],'Callback',@Rotate_CC);
x50=x50+1;x50=x50+1;x50=x50+1;
hRotateCC.BackgroundColor=[0.4660 0.6740 0.1880];
hRotateCW = uicontrol('Style','pushbutton','String','Rotate Clockwise','Position',[la+x20*w20+x50*w50+x70*w70,ba-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50*3,H30+10],'Callback',@Rotate_CW);
x50=x50+1;x50=x50+1;x50=x50+1;
hRotateCW.BackgroundColor=[0.4660 0.6740 0.1880];

changeCurrentTitle = uicontrol('Units','normalized','Style','text','String','Change Current','Position',[.035,0.077,0.06,0.02]);

picoMotorPosition = uicontrol('Units','normalized','Style','text','String',picoPosi,'Position',[.035,0.055,0.06,0.02]);

LowerCurrentLargeF = uicontrol('Units','normalized','FontSize',10,'Style','pushbutton','String',' << ','Value',1,'Position',[.005,.02,.03,.03],'Callback',@Lower_Current_Large);

LowerCurrentSmallF = uicontrol('Units','normalized','FontSize',10,'Style','pushbutton','String',' < ','Value',1,'Position',[.04,.02,.03,.03],'Callback',@Lower_Current_Small);

RaiseCurrentSmallF = uicontrol('Units','normalized','FontSize',10,'Style','pushbutton','String',' > ','Value',1,'Position',[.075,.02,.03,.03],'Callback',@Raise_Current_Small);

RaiseCurrentLargeF = uicontrol('Units','normalized','FontSize',10,'Style','pushbutton','String',' >> ','Value',1,'Position',[.11,.02,.03,.03],'Callback',@Raise_Current_Large);



%% Close things that are not connected
if ~isCameraThere
    text(haxis,513,513,{'Camera';'Not';'Available'},'FontSize',55,'HorizontalAlignment','center');
    DisableAllCameraButtons;
    set(lContainer,'visible','off');
    set(bContainer,'visible','off');
end
if ~isStageThere
    TabGroup.Visible='off';
    sma = axes('Units','Pixels','Position',TabGroup.Position);
    text(sma,0.5,0.5,{'Stage';'Not';'Available'},'FontSize',30,'HorizontalAlignment','center');
    sma.XTickLabel=[];
    sma.YTickLabel=[];
    sma.YTick=[];
    sma.XTick=[];
end
if ~isPicoMotorThere
    LowerCurrentLargeF.Enable = 'off';
    LowerCurrentSmallF.Enable = 'off';
    RaiseCurrentSmallF.Enable = 'off';
    RaiseCurrentLargeF.Enable = 'off';
end



%%  Normalize Units for a Sizeable window. 

haxis.Units='normalized';
baxis.Units='normalized';
laxis.Units='normalized';
set(bContainer,'Units','normalized');
set(lContainer,'Units','normalized');
TempSetTitle.Units='normalized';
hTemp.Units='normalized';
TempCurrentTitle.Units='normalized';
TempUp.Units='normalized';
GetTempButton.Units='normalized';
StartCool.Units='normalized';
ExpTimeTitle.Units='normalized';
hExpTime.Units='normalized';
TakeVideo.Units='normalized';
AbortAcquiVideo.Units='normalized';
ShutDownCamera.Units='normalized';
TakeBackTitle.Units='normalized';
hBackNum.Units='normalized';
hTakeBack.Units='normalized';
hSubtractBack.Units='normalized';
hSaveBack.Units='normalized';
PathChoice.Units='normalized';
hPath.Units='normalized';
Browse.Units='normalized';
NumSaveImagesTitle.Units='normalized';
hNumSaveImages.Units='normalized';
hSaveImages.Units='normalized';
CurrentTitle.Units='normalized';
CurrentDisplay.Units='normalized';
GetCurrentButton.Units='normalized';
BigCurrentButton.Units='normalized';
AcquiModeTitle.Units='normalized';
hAcquiMode.Units='normalized';
StartAcqui.Units='normalized';
AbortAcqui.Units='normalized';
GainSetTitle.Units='normalized';
hGainSet.Units='normalized';
CurrGainDisp.Units='normalized';
GainModeTitle.Units='normalized';
hSetGainMode.Units='normalized';
VerticalShiftTitle.Units='normalized';
hVertShiftSpeed.Units='normalized';
VerticalAmpTitle.Units='normalized';
hVertVoltAmp.Units='normalized';
PreAmpGainTypeTitle.Units='normalized';
hPreAmpGain.Units='normalized';
HSSpeedTitle.Units='normalized';
hHSSpeed.Units='normalized';
TabGroup.Units='normalized';
CurrPosiTitle.Units='normalized';
hCurrentPosi.Units='normalized';
StartScanTitle.Units='normalized';
hStartScan.Units='normalized';
EndScanTitle.Units='normalized';
hEndScan.Units='normalized';
StepScanTitle.Units='normalized';
hStepScan.Units='normalized';
hMoveAndSave.Units='normalized';
CurrPosiTitle2.Units='normalized';
hCurrentPosi2.Units='normalized';
StagePosiTitle.Units='normalized';
hMoveStage.Units='normalized';
NonLinearBox.Units='normalized';
NonLinearTitle.Units='normalized';
NonLinearScan.Units='normalized';
JogTitle.Units='normalized';
hJogValue.Units='normalized';
hJogDown.Units='normalized';
hJogUp.Units='normalized';
Task2ExeTitle.Units='normalized';
Task2ExeField.Units='normalized';
MinDelayTimeTitle.Units='normalized';
MinDelayTimeField.Units='normalized';
hTimerScan.Units='normalized';
hEnableButton.Units='normalized';
caxisTitle.Units='normalized';
hCaxisLSet.Units='normalized';
hCaxisHSet.Units='normalized';
hAutoScale.Units='normalized';
hSetAutoScale.Units='normalized';
c500t1000.Units='normalized';
c500t5000.Units='normalized';
c500t10000.Units='normalized';
c500t30000.Units='normalized';
cm200t200.Units='normalized';
hRotateCC.Units='normalized';
hRotateCW.Units='normalized';

if ishandle(f0)
    close(f0);
end
movegui(f,'center');
f.Visible='on';

%% Callbacks

    function Start_Cooling(source,eventdata)
        if strcmp(StartCool.String,'Start Cooling')
            Temp=str2num(hTemp.String);
            [ret]=CoolerON();                             %   Turn on temperature cooler
            CheckWarning(ret);
            [ret]=SetTemperature(Temp);
            CheckWarning(ret);
            [ret,CurrTemp]=GetTemperature();
            TempUp.String=CurrTemp;
            StartCool.String='Stop Cooling';
            StartCool.BackgroundColor=[0 0.5 0];
            drawnow;
        elseif  strcmp(StartCool.String,'Stop Cooling')
            CoolerOFF;
            StartCool.String='Start Cooling';
            StartCool.BackgroundColor=[1 0 0];
            drawnow;
        end
        %         display('You got to the Start Cooling Callback')
    end

    function Temp_Edit(source,eventdata)
        Temp=str2num(hTemp.String);
        [ret]=SetTemperature(Temp);
        CheckWarning(ret);
        [ret,CurrTemp]=GetTemperature();
        TempUp.String=CurrTemp;
        %         display('You got to the Start Cooling Callback')
    end

    function Take_Video(source,eventdata)
        TakeVideo.String='Acquiring...';
        Disable_Buttons;
        OriginalTemp=GetTempButton.Value;
        GetTempButton.Value=0;
        OriginalCurrent=GetCurrentButton.Value;
        GetCurrentButton.Value=0;
        ExpTime=str2num(hExpTime.String); %#ok<ST2NM>
        VSAmp=hVertVoltAmp.Value-1;
        PreAmp=hPreAmpGain.Value-1;
        VSSpeed=hVertShiftSpeed.Value-1;
        HSSpeed=hHSSpeed.Value-1;
        [ret]=SetShutter(1, 1, 0, 0);                 %   Open Shutter
        CheckWarning(ret);
        [ret] = SetHSSpeed(PreAmp,HSSpeed);
        CheckWarning(ret);
        [ret] = SetVSSpeed(VSSpeed);
        CheckWarning(ret);
        [ret] = SetVSAmplitude(VSAmp);
        CheckWarning(ret);
        [ret] = SetOutputAmplifier(PreAmp);
        CheckWarning(ret);
        [ret]=SetAcquisitionMode(5);                  %   Set acquisition mode; 5 for RTA
        CheckWarning(ret);
        [ret]=SetExposureTime(ExpTime);                  %   Set exposure time in second
        CheckWarning(ret);
        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
        CheckWarning(ret);
        [ret]=SetTriggerMode(10);                     %   Set Software trigger mode; 0 for Internal; 10 for Software
        useSoftwareTrigger = 1;                       %   Should be 0 if Trigger Mode is 0
        CheckWarning(ret);
        [ret,~]=GetTemperature();
        [ret,ExpTimeOut,Acc,Kin]=GetAcquisitionTimings;
        [ret,Size]=GetSizeOfCircularBuffer;
        [ret] = StartAcquisition();
        
        CheckWarning(ret);
        %                 while ret ~= atmcd.DRV_TEMP_STABILIZED
        %                     [ret,CurrTemp]=GetTemperature();
        %                     TempUp.String=CurrTemp;
        %                     pause(1)
        %                 end

        axes(haxis)
        index=0;
        while ~AbortAcquiVideo.Value
            index=index+1;
            if ~mod(index,5) || ExpTime > 0.5
            Get_Current;
            cur=str2num(cur)*1e12;
            CurrCurr=num2str(cur,'%6.2f');
            CurrentDisplay.String=CurrCurr;
            drawnow;
            end
            if useSoftwareTrigger
                [ret] = SendSoftwareTrigger();
                CheckWarning(ret);
%                 if ret == 20002
                [ret] = WaitForAcquisition();
                CheckWarning(ret);
%                 else
%                     errormsg = errordlg('The camera did not respond');
%                     uiwait(errormsg)
%                     break
%                 end
            end
            [ret, imageData] = GetMostRecentImage(XPixels * YPixels);
%             imageData(1:(XPixels * YPixels)/2)=61e3;
            if ret == atmcd.DRV_SUCCESS
                % Check for saturation
                PixelCount=sum(imageData > 60e3);
                Threshold = 0.05;
                if PixelCount/(XPixels * YPixels) > Threshold
                    errordlg('You reached your saturation threshold and acquisition was aborted','Saturation Warning')
                    break
                end
                %display the acquired image
                I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                if hSubtractBack.Value
                    I=double(I)-Back;
                end
                I=rot90(I,RotateNum);
                ZoomX=haxis.XLim;
                ZoomY=haxis.YLim;
                if hSetAutoScale.Value
                    imagesc(haxis,I);
                    colorbar;
%                     drawnow;
                else
                    imagesc(haxis,I);
                    colorbar;
                    haxis.CLim=[str2num(hCaxisLSet.String) str2num(hCaxisHSet.String)]; %#ok<ST2NM>
                end
                haxis.XLim=ZoomX;
                haxis.YLim=ZoomY;
                bProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),1);
                plot(baxis,bLowValue:bHighValue,bProjection);
                baxis.XLim=[0 1024];
                
                lProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),2);
                plot(laxis,lLowValue:lHighValue,lProjection);
                camroll(laxis,-90);
                laxis.XLim=[0 1024];
                laxis.YAxisLocation='right';
                drawnow;
                [ret,CurrTemp]=GetTemperature();
                TempUp.String=CurrTemp;
%                 pause(0.1)
            else
                1;
            end
        end
        [ret]=CancelWait;
        CheckWarning(ret);
        [ret]=AbortAcquisition;
        CheckWarning(ret);
        AbortAcquiVideo.Value=0;
        GetTempButton.Value=OriginalTemp;
        GetCurrentButton.Value=OriginalCurrent;
        TakeVideo.String='Take Video';
        Enable_Buttons;
        Get_Current_Button;
        Get_Temp_Button;
        drawnow;
    end

    function Enable_Gain(source,eventdata)
        GainIn=str2double(hGainSet.String);
        [ret]=SetEMCCDGain(GainIn);
        CheckWarning(ret);
        [ret,CurrGain]=GetEMCCDGain();
        CheckWarning(ret);
        CurrGainDisp.String=CurrGain; %Delete when using camera
        
    end

    function Gain_Mode(source,eventdata)
        GainModeIn=hSetGainMode.Value;
        [ret]=SetEMGainMode(GainModeIn);
        CheckWarning(ret);
        [ret,CurrGain]=GetEMCCDGain();
        CheckWarning(ret);
    end

    function Get_Path(source,eventdata)
        f.Visible='off';
        Path = uigetdir(hPath.String,'Select the folder to save to');
        if Path
        hPath.String=Path;
        end
        f.Visible='on';
    end

    function Pre_Amp_Gain(source,eventdata)
        PreAmpValue=hPreAmpGain.Value;
        switch PreAmpValue
            case 1
                hHSSpeed.String={'30','20','10','1'};
            case 2
                hHSSpeed.String={'1','0.1'};
        end
    end

    function Timer_Scan(source,eventdata)
        if hTimerScan.Value
            hTimerScan.String='Scanning...';
            Disable_Buttons;
            Path=hPath.String;
            fn=ls([Path '\Timed Scan *']);
            if isempty(fn)
                ScanStart=1;
            else
                ScanNum=sort(str2num(fn(:,length('Timed Scan ')+1:end)));
                ScanStart=ScanNum(end)+1;
            end
            FolderPath=[Path '\Timed Scan ' num2str(ScanStart)];
            mkdir(FolderPath);
            hPath.String=FolderPath;
            Time2NextScan=str2double(MinDelayTimeField.String);
            MaSi=ScanStart;
        end
        while MaSi < (ScanStart+str2num(Task2ExeField.String)) && hTimerScan.Value
            if MaSi > ScanStart
                Timer=round(toc);
            else
                Timer=Time2NextScan+1;
            end
            if Timer > Time2NextScan
            tic;
            hMoveAndSave.Value=1;
            Move_And_Save(source,eventdata);
            MaSi=MaSi+1;
            else
                Start_Acqui(source,eventdata)
                pause(1);
            end
        end
        if ~hTimerScan.Value
            hMoveAndSave.Value=0;
        end
        hPath.String=Path;
        hTimerScan.Value=0;
        hTimerScan.String='Start Scan';
        Enable_Buttons;
    end

    function Non_Linear_Scan(~,~)
        if NonLinearBox.Value
            StartScanTitle.Visible='off';
            hStartScan.Visible='off';
            EndScanTitle.Visible='off';
            hEndScan.Visible='off';
            StepScanTitle.Visible='off';
            hStepScan.Visible='off';
            NonLinearTitle.Visible='on';
            NonLinearScan.Visible='on';
        else
            StartScanTitle.Visible='on';
            hStartScan.Visible='on';
            EndScanTitle.Visible='on';
            hEndScan.Visible='on';
            StepScanTitle.Visible='on';
            hStepScan.Visible='on';
            NonLinearTitle.Visible='off';
            NonLinearScan.Visible='off';
        end
    end

    function Move_And_Save(source,eventdata)
        hMoveAndSave.String='Stop Scan';
        
        if NonLinearBox.Value
            MoveVec=str2num(NonLinearScan.String);
        else
            StartPosi=str2num(hStartScan.String);
            EndPosi=str2num(hEndScan.String);
            Steps=str2num(hStepScan.String);
            MoveVec=StartPosi:Steps:EndPosi;
        end
        Path=hPath.String;
        if ~hTimerScan.Value
            Disable_Buttons;
            if ~strcmp(Path(end),'\')
                Path=strcat(Path,'\');
            end
            fn=ls([Path 'scan *']);
            if isempty(fn)
                FolderNum=1;
            else
                ScanNum=sort(str2num(fn(:,6:end)));
                FolderNum=ScanNum(end)+1;
            end
            FolderPath=[Path 'Scan ' num2str(FolderNum)];
            mkdir(FolderPath);
            if ~strcmp(FolderPath(end),'\')
                FolderPath=strcat(FolderPath,'\');
            end
            hPath.String=FolderPath;
        end
        %         RandVec=zeros(frameCount,length(MoveVec));
        for i=1:length(MoveVec)
            Element=MoveVec(i);
            [result,~]=ESP301.PA_Set(1,Element);
            if ~result && hMoveAndSave.Value
                pause(2)
                [result,StagePosi,errString]=ESP301.PA_Get(1);
                if ~result
                    hCurrentPosi.String=StagePosi;
                    hCurrentPosi2.String=StagePosi;
                    hMoveStage.String=StagePosi;
                end
                while int16(1000*(StagePosi-Element))
                    [result,~]=ESP301.PA_Set(1,Element);
                    pause(1);
                    [result,StagePosi,~]=ESP301.PA_Get(1);
                end
                if ~result && hMoveAndSave.Value
                    Save_Images(source,eventdata);
                end
            else
                hMoveAndSave.String='Start Scan';
                hMoveAndSave.Value=0;
                return
            end
        end
        hPath.String=Path;
        hMoveAndSave.Value=0;
        if ~hTimerScan.Value
            Enable_Buttons;
        end
%         pause(10);
    end

    function Move_Stage(source,eventdata)
        StageSet=str2num(hMoveStage.String);
        [result,~]=ESP301.PA_Set(1,StageSet);
        [result,StagePosi,errString]=ESP301.PA_Get(1);
        if ~result
            hCurrentPosi.String=StagePosi;
            hCurrentPosi2.String=StagePosi;
            hMoveStage.String=StagePosi;
        end
    end

    function Jog_Down(source,eventdata)
        [result,StagePosi,errString]=ESP301.PA_Get(1);
        Jogger=str2num(hJogValue.String);
        StageSet=StagePosi-Jogger;
        [result,~]=ESP301.PA_Set(1,StageSet);
        [result,StagePosi,errString]=ESP301.PA_Get(1);
        if ~result
            hCurrentPosi.String=StagePosi;
            hCurrentPosi2.String=StagePosi;
            hMoveStage.String=StagePosi;
        end
    end

    function Jog_Up(source,eventdata)
        [result,StagePosi,errString]=ESP301.PA_Get(1);
        Jogger=str2num(hJogValue.String);
        StageSet=StagePosi+Jogger;
        [result,~]=ESP301.PA_Set(1,StageSet);
        [result,StagePosi,errString]=ESP301.PA_Get(1);
        if ~result
            hCurrentPosi.String=StagePosi;
            hCurrentPosi2.String=StagePosi;
            hMoveStage.String=StagePosi;
        end
    end

    function Jog_DownFW(source,eventdata)
        NP_USB.Write(USBADDR, ['1PR-' hJogValueFW.String]);
    end

    function Jog_UpFW(source,eventdata)
        NP_USB.Write(USBADDR, ['1PR' hJogValueFW.String]);
    end

    function Save_Images(source,eventdata)
        hTimerScanValue=hTimerScan.Value;
        hMoveAndSaveValue=hMoveAndSave.Value;
        TakeVideo.String='Saving Images...';
        hSaveImages.String='Saving Images...';
        OriginalTemp=GetTempButton.Value;
        GetTempButton.Value=0;
        OriginalCurrent=GetCurrentButton.Value;
        GetCurrentButton.Value=0;
        Path=hPath.String;
        
        if ~hTimerScanValue && ~hMoveAndSaveValue
            Disable_Buttons;
            if ~strcmp(Path(end),'\')
                Path=strcat(Path,'\');
            end
            fn=ls([Path 'Images *']);
            if isempty(fn)
                FolderNum=1;
            else
                ScanNum=sort(str2num(fn(:,8:end)));
                FolderNum=ScanNum(end)+1;
            end
            Path=[Path 'Images ' num2str(FolderNum)];
            mkdir(Path);
        end
        if ~strcmp(Path(end),'\')
            Path=strcat(Path,'\');
        end
        
        StagePosi=hCurrentPosi.String;
        StagePosi=str2num(StagePosi);
        StagePosi=num2str(StagePosi,'%6.4f');
        frameCount=str2double(hNumSaveImages.String);
        Mode=hAcquiMode.Value;
        ExpTime=str2num(hExpTime.String); %#ok<ST2NM>
        VSAmp=hVertVoltAmp.Value-1;
        PreAmp=hPreAmpGain.Value-1;
        VSSpeed=hVertShiftSpeed.Value-1;
        HSSpeed=hHSSpeed.Value-1;
        [ret] = SetHSSpeed(PreAmp,HSSpeed);
        CheckWarning(ret);
        [ret] = SetVSSpeed(VSSpeed);
        CheckWarning(ret);
        [ret] = SetVSAmplitude(VSAmp);
        CheckWarning(ret);
        [ret] = SetOutputAmplifier(PreAmp);
        CheckWarning(ret);
        [ret]=SetAcquisitionMode(Mode);                  %   Set acquisition mode; 5 for RTA
        CheckWarning(ret);
        [ret]=SetExposureTime(ExpTime);                  %   Set exposure time in second
        CheckWarning(ret);
        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
        CheckWarning(ret);
        [ret]=SetTriggerMode(0);                     %   Set Software trigger mode 0 for Internal
        CheckWarning(ret);
        [ret,~]=GetTemperature();                
        currentSeries=0;
        axes(haxis)
        while(currentSeries < frameCount)
            CurrentCount=0;
            CurrentTotal=0;
            [ret] = StartAcquisition();
            CheckWarning(ret);
            [ret,Status] = GetStatus;
            TimeCounter=0;
            while Status == 20072
                TimeCounter=TimeCounter+1;
                Get_Current;
                cur=str2num(cur)*1e12;
                if ~mod(TimeCounter,5)
                    CurrCurr=num2str(cur,'%6.2f');
                    CurrentDisplay.String=CurrCurr;
                    drawnow
                end
                CurrentTotal=CurrentTotal+cur;
                CurrentCount=CurrentCount+1;
%                 CurrentCheck(CurrentCount)=cur;
                pause(0.1)
                [ret,Status] = GetStatus;
            end
            CurrentAverage=CurrentTotal/CurrentCount;
%             [ret] = WaitForAcquisition();
            [ret, imageData] = GetMostRecentImage(XPixels * YPixels);
            
            if ret == atmcd.DRV_SUCCESS % data returned
                PixelCount=sum(imageData > 60e3);
                Threshold = 0.05;
                if PixelCount/(XPixels * YPixels) > Threshold
                    errordlg('You reached your saturation threshold and acquisition was aborted','Saturation Warning')
                    break
                end
                thisFilename = strcat(Path,'Image_*_StagePos_', StagePosi, '_Current_*.tiff');
                fn=ls(thisFilename);
                ImNum0=0;
                for ii=1:size(fn,1)
                ImNum=extractBetween(fn(ii,:),'Image_','_Stage');
                ImNum=str2double(ImNum{:});
                ImNum=max([ImNum ImNum0]);
                ImNum0=ImNum;
                end
                
                ImNum=size(ls(thisFilename),1);
                thisFilename = strcat(Path,'Image_', num2str(ImNum+1),'_StagePos_', StagePosi, '_Current_', num2str(CurrentAverage,'%5.2f'), '.tiff');
                %                         disp(['Writing Image ', num2str(currentSeries+1), '/',num2str(frameCount),' to disk']);
                I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                if hSubtractBack.Value
                    I2=double(I)-Back;
                else
                    I2=double(I);
                end
                I=rot90(I,RotateNum);
                I2=rot90(I2,RotateNum);
                ZoomX=haxis.XLim;
                ZoomY=haxis.YLim;
                imagesc(haxis,I2);
                haxis.CLim=[str2num(hCaxisLSet.String) str2num(hCaxisHSet.String)];
                haxis.XLim=ZoomX;
                haxis.YLim=ZoomY;
                colorbar
                bProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),1);
                plot(baxis,bLowValue:bHighValue,bProjection);
                baxis.XLim=[0 1024];
                
                lProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),2);
                plot(laxis,lLowValue:lHighValue,lProjection);
                camroll(laxis,-90);
                laxis.XLim=[0 1024];
                laxis.YAxisLocation='right';
                drawnow;
                imwrite(uint16(I),thisFilename) % saves to supplied path
                currentSeries=currentSeries+1;
            end
        end
%         WaitForImages=0;
        AbortAcquiVideo.Value=0;
        GetTempButton.Value=OriginalTemp;
        GetCurrentButton.Value=OriginalCurrent;
        if ~hTimerScanValue && ~hMoveAndSaveValue
            Enable_Buttons;
        end
        Get_Current_Button;
        Get_Temp_Button;
        drawnow;
    end

%     function Stabilize_Current(~,~)
%         if CalibrateCurrent.Value
%             tic;
%             Timer = toc;
%             InitialCurrent = 0;
%             CurrentCount = 0;
%             while Timer < 5
%                 Get_Current;
%                 cur=str2num(cur)*1e12;
%                 InitialCurrent = InitialCurrent + cur;
%                 CurrentCount = CurrentCount + 1;
%                 pause(0.1)
%                 Timer = toc;
%             end
%             InitialCurrent = InitialCurrent/CurrentCount;
%             
%         else
%             load('FilterWheelSlope')
%         end
%     end

    function Take_Back(source,eventdata)
        hTakeBack.String='Taking background ...';
        Disable_Buttons;
        drawnow;
        BackMat=zeros(YPixels,XPixels);
        NumBackImages=str2double(hBackNum.String);
        NumSuccessfulImages=0;
        ExpTime=str2num(hExpTime.String);
        BackExp=ExpTime;
        Original=GetTempButton.Value;
        GetTempButton.Value=0;
        Mode=1;                                             % 1 for single scan
        [ret]=SetAcquisitionMode(Mode);                  %   Set acquisition mode; 5 for RTA
        CheckWarning(ret);
        [ret]=SetExposureTime(ExpTime);                  %   Set exposure time in second
        CheckWarning(ret);
        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
        CheckWarning(ret);
        [ret]=SetTriggerMode(0);                     %   Set Software trigger mode 0 for Internal
        CheckWarning(ret);
        [ret,~]=GetTemperature();
        for i=1:NumBackImages
            [ret] = StartAcquisition();
            CheckWarning(ret);
            [ret] = WaitForAcquisition();
            [ret, imageData] = GetMostRecentImage(XPixels * YPixels);
            CheckWarning(ret);
            if ret == atmcd.DRV_SUCCESS
                PixelCount=sum(imageData > 60e3);
                Threshold = 0.05;
                if PixelCount/(XPixels * YPixels) > Threshold
                    errordlg('You reached your saturation threshold and acquisition was aborted','Saturation Warning')
                    break
                end
                I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                BackMat=double(I)+BackMat;
                NumSuccessfulImages=NumSuccessfulImages+1;
            else
                warningdlg('Not all of the background images were taken');
            end
            Back=BackMat/NumSuccessfulImages;
        end
        hTakeBack.String='Take Background';
        Enable_Buttons;
    end

    function Subtract_Back(source,eventdata)
        ExpTime=str2num(hExpTime.String);
        if BackExp
            if BackExp~=ExpTime
                warningdlg('Your Exposure time is different than what you took your background with');
            end
        else
            warningdlg('You have not taken a background yet');
        end
        if hSubtractBack.Value
            hSubtractBack.String='Background being subtracted';
        else
            hSubtractBack.String='Subtract Background';
        end
    end

    function Save_Back(source,eventdata)
        Original=hSaveBack.String;
        hSaveBack.String='Saving...';
        drawnow;
        StagePosi=hCurrentPosi.String;
        StagePosi=str2num(StagePosi);
        StagePosi=num2str(StagePosi,'%6.4f');
        Path=hPath.String;
        if ~strcmp(Path(end),'\')
            Path=strcat(Path,'\');
        end
        thisFilename = strcat(Path,'Background_01_StagePos_', StagePosi, '.tiff');
        imwrite(Back,thisFilename) % saves to supplied path
        hSaveBack.String=Original;
        drawnow;
    end

    function Start_Acqui(source,eventdata)
        Disable_Buttons;
        Original=GetTempButton.Value;
        GetTempButton.Value=0;
%         Mode=hAcquiMode.Value;
        Mode=1;     % Only single scan works right now
        ExpTime=str2num(hExpTime.String);
        VSAmp=hVertVoltAmp.Value-1;
        PreAmp=hPreAmpGain.Value-1;
        VSSpeed=hVertShiftSpeed.Value-1;
        HSSpeed=hHSSpeed.Value-1;
        [ret] = SetHSSpeed(PreAmp,HSSpeed);
        CheckWarning(ret);
        [ret] = SetVSSpeed(VSSpeed);
        CheckWarning(ret);
        [ret] = SetVSAmplitude(VSAmp);
        CheckWarning(ret);
        [ret] = SetOutputAmplifier(PreAmp);
        CheckWarning(ret);
        [ret]=SetAcquisitionMode(Mode);                  %   Set acquisition mode; 5 for RTA
        CheckWarning(ret);
        [ret]=SetExposureTime(ExpTime);                  %   Set exposure time in second
        CheckWarning(ret);
        [ret]=SetReadMode(4);                         %   Set read mode; 4 for Image
        CheckWarning(ret);
        [ret]=SetTriggerMode(0);                     %   Set Software trigger mode 0 for Internal
        CheckWarning(ret);
        [ret,~]=GetTemperature();
        switch Mode
            case 1  % Single Scan
                [ret] = StartAcquisition();
                CheckWarning(ret);
                [ret] = WaitForAcquisition();
                [ret, imageData] = GetMostRecentImage(XPixels * YPixels);
                CheckWarning(ret);
                if ret == atmcd.DRV_SUCCESS
                    I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                    if hSubtractBack.Value
                        I=double(I)-Back;
                    end
                    I=rot90(I,RotateNum);
                    imagesc(haxis,I);
                    colorbar
                    haxis.CLim=[str2num(hCaxisLSet.String) str2num(hCaxisHSet.String)];
                    bProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),1);
                    plot(baxis,bLowValue:bHighValue,bProjection);
                    baxis.XLim=[0 1024];
                    
                    lProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),2);
                    plot(laxis,lLowValue:lHighValue,lProjection);
                    camroll(laxis,-90);
                    laxis.XLim=[0 1024];
                    laxis.YAxisLocation='right';
                    drawnow;
                end
                [ret]=AbortAcquisition;
                CheckWarning(ret);
            case 2  % Accumulate
                dlgtitle='Input';
                prompt='Choose the number of images to accumulate';
                dims=[1 20];
                InitialInput={'1'};
                Output = inputdlg(prompt,dlgtitle,dims,InitialInput);
                numberOfImagesToAccumulate = str2num(Output{:});
                [ret]=SetNumberAccumulations(numberOfImagesToAccumulate);
                CheckWarning(ret);
                [ret] = StartAcquisition();
                CheckWarning(ret);
                [ret] = WaitForAcquisition();
                [ret, imageData] = GetMostRecentImage(XPixels * YPixels);
                if ret == atmcd.DRV_SUCCESS
                    I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                    if hSubtractBack.Value
                        I=double(I)-Back;
                    end
                    imagesc(haxis,I);
                    haxis.CLim=[str2double(hCaxisLSet.String) str2double(hCaxisHSet.String)];
                    colorbar
                    drawnow;
                end
            case 3  % Kinetics
                prompt = {'Enter Acquisition name','Enter number of images'};
                dlg_title = 'Configure acquisition';
                num_lines = 1;
                def = {'Scan','10'};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                filename = cell2mat(answer(1));
                frameCount = str2double(cell2mat(answer(2)));
                [ret]=SetNumberKinetics(frameCount);
                CheckWarning(ret);
                [ret] = StartAcquisition();                   
                CheckWarning(ret);
                [ret] = WaitForAcquisition();
                currentSeries = 0;
                while(currentSeries < frameCount)
                    
                    [ret, imageData] = GetOldestImage(XPixels * YPixels);
                    
                    if ret == atmcd.DRV_SUCCESS % data returned
                        thisFilename = strcat(filename, num2str(currentSeries+1), '.tiff');
%                         disp(['Writing Image ', num2str(currentSeries+1), '/',num2str(frameCount),' to disk']);
                        I=flip(transpose(reshape(imageData, XPixels, YPixels)),1);
                        if hSubtractBack.Value
                            I=double(I)-Back;
                        end
                        imagesc(haxis,I);
                        haxis.CLim=[str2double(hCaxisLSet.String) str2double(hCaxisHSet.String)];
                        colorbar
                        drawnow;
                        imwrite(uint16(I),thisFilename) % saves to current directory
                        currentSeries=currentSeries+1;
                    end
                end
        end
        GetTempButton.Value=Original;
        Enable_Buttons;
    end

    function Abort_Acqui(source,eventdata)
        [ret]=CancelWait;
        CheckWarning(ret);
        [ret]=AbortAcquisition;
        CheckWarning(ret);
    end

    function Shut_Down_Camera(source,eventdata)
        [ret]=CancelWait;
        [ret]=AbortAcquisition;
        ShutDownCamera.String='Cancel Shutdown';
        OriginalBackgroundColor=ShutDownCamera.BackgroundColor;
        ShutDownCamera.BackgroundColor=[0.96 0.72 0.70];
        CoolerOFF;
        StartCool.String='Shutting Down';
        StartCool.BackgroundColor=[1 0 0];
        drawnow;
        [ret,CurrTemp]=GetTemperature();
        TempUp.String=CurrTemp;
        while CurrTemp < -10 && ShutDownCamera.Value
            [ret,CurrTemp]=GetTemperature();
            TempUp.String=CurrTemp;
            drawnow;
        end
        if ShutDownCamera.Value
            [ret]=SetShutter(1, 2, 1, 1);                 %   Close Shutter
            CheckWarning(ret);
            [ret]=AndorShutDown;
            CheckWarning(ret);
            close(f)
        elseif ~ShutDownCamera.Value
            ShutDownCamera.String='Shut Down Camera';
            ShutDownCamera.BackgroundColor=OriginalBackgroundColor;
            StartCool.String='Start Cooling';
            drawnow;
        end
    end

    function Get_Temp_Button(source,eventdata)
        if GetTempButton.Value
            GetTempButton.String='Getting Temp';
            drawnow
        end
        while GetTempButton.Value
            pause(1);
%             CurrTemp=int16(rand*10);    % Comment if camera is available
        [ret,CurrTemp]=GetTemperature();      % Uncomment if camera is available
            TempUp.String=CurrTemp;
            drawnow;
        end
        GetTempButton.String='Get Temp';
    end

    function Get_Current_Button(source,eventdata)
        MainFolder = 'C:\experiments\';     %'D:\experiments\';
        if GetCurrentButton.Value
            GetCurrentButton.String='Getting Current';
            drawnow
            DateTime=clock;
            Date=num2str(DateTime(3),'%2i');if length(Date) ==1; Date=['0' Date];end
            Month=num2str(DateTime(2),'%2i');if length(Month) ==1; Month=['0' Month];end
            Year=num2str(DateTime(1),'%4i');
            date=[Month Date Year];
            if exist(['D:\experiments\' date]) == 7
                if exist([MainFolder date '\current']) == 7
                else
                    mkdir([MainFolder date '\current']);
                end
            else
                mkdir([MainFolder date '\current']);
            end
            fn=ls([MainFolder date '\current\curr*']);
            if isempty(fn)
                fileID = fopen([MainFolder date '\current\curr1.txt'],'a');
                LogNum=1;
            else
                LogNum=size(fn,1)+1;
                fileID = fopen([MainFolder date '\current\curr' num2str(LogNum) '.txt'],'a');
            end
            fprintf(fileID,'%10s  %7s\n','Time','Current');
            fclose(fileID);
        end
        while GetCurrentButton.Value
            pause(0.1);
            Get_Current;
            cur=str2num(cur)*1e12;
            CurrCurr=num2str(cur,'%6.2f');
            CurrentDisplay.String=CurrCurr;
            drawnow;
            cl=clock;
            hh=num2str(cl(4));
            mm=num2str(cl(5));
            ss=num2str(cl(6),'%4.1f');
            if length(hh) == 1;hh=['0' hh];end
            if length(mm) == 1;mm=['0' mm];end
            if length(ss) == 3;ss=['0' ss];end
            fileID = fopen([MainFolder date '\current\curr' num2str(LogNum) '.txt'],'a');
            fprintf(fileID,'%2s:%2s:%3s  %7s\n',hh,mm,ss,CurrCurr);
            fclose(fileID);
        end
%         fclose(fileID);
        GetCurrentButton.String='Get Current';
    end

    function Big_Current_Button(source,eventdata)
        if BigCurrentButton.Value
            f.Visible='off';
            BigCurrDisp = figure('Visible','on','Position',[200,50,1300,900]);
            
            BigCurrentTitle = uicontrol('Units','normalized','FontSize',100,'Style','text','String','Current (pA)','Position',[.3,.8,.4,.1]);
            
            BigCurrentDisplay = uicontrol('Units','normalized','FontSize',150,'Style','text','String',CurrCurr,'Position',[.1,.3,.8,.5]);
            
            StopBigCurrentButton = uicontrol('Units','normalized','FontSize',100,'Style','togglebutton','String','Stop Display','Value',1,'Position',[.3,.1,.4,.15]);
            
            LowerCurrentSmall = uicontrol('Units','normalized','FontSize',100,'Style','pushbutton','String',' < ','Value',1,'Position',[.2,.1,.08,.15],'Callback',@Lower_Current_Small);
            
            RaiseCurrentSmall = uicontrol('Units','normalized','FontSize',50,'Style','pushbutton','String',' > ','Value',1,'Position',[.72,.1,.08,.15],'Callback',@Raise_Current_Small);

            LowerCurrentLarge = uicontrol('Units','normalized','FontSize',50,'Style','pushbutton','String',' << ','Value',1,'Position',[.08,.1,.1,.15],'Callback',@Lower_Current_Large);
            
            RaiseCurrentLarge = uicontrol('Units','normalized','FontSize',50,'Style','pushbutton','String',' >> ','Value',1,'Position',[.82,.1,.1,.15],'Callback',@Raise_Current_Large);
            
            BigCurrentDisplay.BackgroundColor=[0.3 0.75 0.933];
            BigCurrentDisplay.Position=[.1,.4,.8,.3];
            StopBigCurrentButton.FontSize=50;
            BigCurrentTitle.FontSize=50;
            LowerCurrentSmall.FontSize=50;
        end
        while StopBigCurrentButton.Value
            pause(0.1);

            fprintf(obj1,'READ? ');
            rst=fscanf(obj1); % '+3.838254E-15A,+2.570559E+05,+0.000000E+00'
            cur=extractBefore(rst,'A');
            cur=str2num(cur)*1e12;
            CurrCurr=num2str(cur,'%6.2f');
            BigCurrentDisplay.String=CurrCurr;
            drawnow;
        end
        close(BigCurrDisp)
        f.Visible='on';
        BigCurrentButton.Value=0;
        BigCurrentButton.String='Display Large Current';
    end

    function Lower_Current_Small(~,~)
        NP_USB.Write(USBADDR, '1PR10');
        pause(0.2)
        NP_USB.Query(USBADDR,'1TP?',querydata);
        picoPosi = char(ToString(querydata));
        picoMotorPosition.String = picoPosi;
    end

    function Raise_Current_Small(~,~)
        NP_USB.Write(USBADDR, '1PR-10');
        pause(0.2)
        NP_USB.Query(USBADDR,'1TP?',querydata);
        picoPosi = char(ToString(querydata));
        picoMotorPosition.String = picoPosi;
    end
    
    function Lower_Current_Large(~,~)
        NP_USB.Write(USBADDR, '1PR100');
        pause(0.2)
        NP_USB.Query(USBADDR,'1TP?',querydata);
        picoPosi = char(ToString(querydata));
        picoMotorPosition.String = picoPosi;
    end

    function Raise_Current_Large(~,~)
        NP_USB.Write(USBADDR, '1PR-100');
        pause(0.2)
        NP_USB.Query(USBADDR,'1TP?',querydata);
        picoPosi = char(ToString(querydata));
        picoMotorPosition.String = picoPosi;
    end

    function caxis_call(source,eventdata)
        haxis.CLim=[str2num(hCaxisLSet.String) str2num(hCaxisHSet.String)];
    end

    function Auto_Scale(~,~)
        imagesc(haxis,I);
        colorbar(haxis)
        CLim=haxis.CLim;
        hCaxisLSet.String=CLim(1);
        hCaxisHSet.String=CLim(2);
        drawnow;
    end

    function Set_Auto_Scale(~,~)
        if hSetAutoScale.Value
            hSetAutoScale.String='Auto Scaling..';
            drawnow;
        else
            CLim=haxis.CLim;
            hCaxisLSet.String=CLim(1);
            hCaxisHSet.String=CLim(2);
            hSetAutoScale.String='Auto Scale';
            drawnow;
        end
    end

    function c_500_1000(source,eventdata)
        haxis.CLim=[500 1000];
        hCaxisLSet.String=num2str(500);
        hCaxisHSet.String=num2str(1000);
    end
    function c_500_5000(source,eventdata)
        haxis.CLim=[500 5000];
        hCaxisLSet.String=num2str(500);
        hCaxisHSet.String=num2str(5000);
    end
    function c_500_10000(source,eventdata)
        haxis.CLim=[500 10000];
        hCaxisLSet.String=num2str(500);
        hCaxisHSet.String=num2str(10000);
    end
    function c_500_30000(source,eventdata)
        haxis.CLim=[500 30000];
        hCaxisLSet.String=num2str(500);
        hCaxisHSet.String=num2str(30000);
    end
    function c_m200_2000(source,eventdata)
        haxis.CLim=[-200 200];
        hCaxisLSet.String=num2str(-200);
        hCaxisHSet.String=num2str(200);
%         colorbar;
    end

    function Rotate_CC(~,~)
        RotateNum=RotateNum+1;
    end

    function Rotate_CW(~,~)
        RotateNum=RotateNum-1;
    end

    function Set_Acqui_Permissions(~,~)
        switch hAcquiMode.Value
            case 1
                StartAcqui.Enable='on';
                AbortAcqui.Enable='on';
            case 2
                StartAcqui.Enable='off';
                AbortAcqui.Enable='off';
            case 3
                StartAcqui.Enable='off';
                AbortAcqui.Enable='off';
        end
    end

    function Button_Down(~,~)
        pause(1);
    end

    function Slider_Change(~,~)
        bLowValue = get(bRangeSlider,'lowValue');
        bHighValue = get(bRangeSlider,'highValue');
        lLowValue = 1024-get(lRangeSlider,'highValue')+1;   % The slider is upside down and this is the easiest way to fix it.
        lHighValue = 1024-get(lRangeSlider,'lowValue')+1;
        
        bProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),1);
        plot(baxis,bLowValue:bHighValue,bProjection);
        baxis.XLim=[0 1024];
        
        lProjection = sum(I(lLowValue:lHighValue,bLowValue:bHighValue),2);
        plot(laxis,lLowValue:lHighValue,lProjection);
        camroll(laxis,-90);
        laxis.XLim=[0 1024];
        laxis.YAxisLocation='right';
        drawnow;
    end

    function Get_Current(~,~)
        fprintf(obj1,'READ? ');
        rst=fscanf(obj1); % '+3.838254E-15A,+2.570559E+05,+0.000000E+00'
        cur=extractBefore(rst,'A');
        
    end

    function DisableAllCameraButtons(~,~)
        baxis.Visible='off';
        laxis.Visible='off';
        hTemp.Enable='off';
        GetTempButton.Enable='off';
        StartCool.Enable='off';
        hExpTime.Enable='off';
        TakeVideo.Enable='off';
        AbortAcquiVideo.Enable='off';
        ShutDownCamera.Enable='off';
        hBackNum.Enable='off';
        hTakeBack.Enable='off';
        hSubtractBack.Enable='off';
        hSaveBack.Enable='off';
        hPath.Enable='off';
        Browse.Enable='off';
        hNumSaveImages.Enable='off';
        hSaveImages.Enable='off';
        hAcquiMode.Enable='off';
        StartAcqui.Enable='off';
        AbortAcqui.Enable='off';
        hGainSet.Enable='off';
        hSetGainMode.Enable='off';
        hVertShiftSpeed.Enable='off';
        hVertVoltAmp.Enable='off';
        hPreAmpGain.Enable='off';
        hHSSpeed.Enable='off';
        hCaxisLSet.Enable='off';
        hCaxisHSet.Enable='off';
        hAutoScale.Enable='off';
        hSetAutoScale.Enable='off';
        c500t1000.Enable='off';
        c500t5000.Enable='off';
        c500t10000.Enable='off';
        c500t30000.Enable='off';
        cm200t200.Enable='off';
        hRotateCC.Enable='off';
        hRotateCW.Enable='off';
        hEnableButton.Enable='off';
        drawnow;
    end

    function Disable_Buttons(~,~)
        hVertShiftSpeed.Enable='off';
        hVertVoltAmp.Enable='off';
        hHSSpeed.Enable='off';
        Browse.Enable='off';
        hTakeBack.Enable='off';
%         hSubtractBack.Enable='off';
        hSaveBack.Enable='off';
        hSaveImages.Enable='off';
        StartAcqui.Enable='off';
%         AbortAcqui.Enable='off';
        TakeVideo.Enable='off';
        GetCurrentButton.Enable='off';
        GetTempButton.Enable='off';
        drawnow;
    end

    function Enable_Buttons(~,~)
        hTimerScan.String='Start Scan';
        hMoveAndSave.String='Start Scan';
        TakeVideo.String='Take Video';
        hSaveImages.String='Save Images';
        hVertShiftSpeed.Enable='on';
        hVertVoltAmp.Enable='on';
        hHSSpeed.Enable='on';
        Browse.Enable='on';
        hTakeBack.Enable='on';
        hSubtractBack.Enable='on';
        hSaveBack.Enable='on';
        hSaveImages.Enable='on';
        StartAcqui.Enable='on';
%         AbortAcqui.Enable='on';
        TakeVideo.Enable='on';
        GetCurrentButton.Enable='on';
        GetTempButton.Enable='on';
        drawnow;
    end

    function closeFigFcn(~,~)
        Answer = questdlg('Did you use the "Shut Down Camera" button to close the program?','Shut Down Camera Check','Yes','No','No');
        switch Answer
            case 'Yes'
                delete(gcf)
            case 'No'
                return
        end
    end

    end %function end
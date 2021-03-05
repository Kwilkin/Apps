function CurrentView


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
CurrCurr=str2double(cur)*1e12; 
CurrCurr=num2str(CurrCurr,'%6.2f');


f = figure('Visible','on','Position',[200,50,1300,900]);



CurrentTitle = uicontrol('Units','normalized','FontSize',100,'Style','text','String','Current (pA)','Position',[.3,.8,.4,.1]);

CurrentDisplay = uicontrol('Units','normalized','FontSize',150,'Style','text','String',CurrCurr,'Position',[.1,.3,.8,.5]);

GetCurrentButton= uicontrol('Units','normalized','FontSize',100,'Style','togglebutton','String','Get Current','Position',[.3,.1,.4,.15],'Callback',@Get_Current_Button);
CurrentDisplay.BackgroundColor=[0.3 0.75 0.933];
CurrentDisplay.Position=[.1,.4,.8,.3];
GetCurrentButton.FontSize=50;
CurrentTitle.FontSize=50;


    function Get_Current_Button(source,eventdata)
        if GetCurrentButton.Value
            GetCurrentButton.String='Getting Current';
            drawnow
        end
        while GetCurrentButton.Value
            pause(0.1);
            fprintf(obj1,'READ? ');
            rst=fscanf(obj1); % '+3.838254E-15A,+2.570559E+05,+0.000000E+00'
            cur=extractBefore(rst,'A');
            cur=str2num(cur)*1e12;
            CurrCurr=num2str(cur,'%6.2f');
            CurrentDisplay.String=CurrCurr;
            drawnow;
        end
        GetCurrentButton.String='Get Current';
    end
end % function end
function [obj1] = controlHV
% For reference polarity = 0
% CurrentCurrent=rand*.1;
% CurrentCurrent=num2str(CurrentCurrent,'%4.2f');
% CurrentVoltage=rand*100;
% CurrentVoltage=num2str(CurrentVoltage,'%4.2f');
Proceed=[];

%% Instrument Connection

% Find a serial port object.
obj1 = instrfind('Type', 'serial', 'Port', 'COM6', 'Tag', '');

% Create the serial port object if it does not exist
% otherwise use the object that was found.
if isempty(obj1)
    obj1 = serial('COM6');
else
    fclose(obj1);
    obj1 = obj1(1);
end
fopen(obj1);
set(obj1, 'Terminator', {'CR','CR'});

fprintf(obj1, '#1 STS');      % Checks the status of the power supply
Status = fscanf(obj1);         % Gets the status: '#1 [Output Mode, CF = Disabled, CO = Enabled] [Remote Control Mode, LO = Disabled, RM = Enabled]'
Output = Status(4:5);
if strcmp(Output,'CF');
    OutputString='Enable';
    Value=0;
elseif strcmp(Output,'CO');
    OutputString='Disable';
    Value=1;
end
Remote = Status(7:8);
% if strcmp(Remote,'LO');
%     fprintf(obj1, '#1 REN');      % Enables remote control of the HV
%     fprintf(obj1, '#1 RST');      % Cancels the cutoff state of the power supply
% end

VoltageSetPoint = query(obj1, '#1 VCN?');       % Checks what the Voltage is currently set at.
CurrentSetPoint = query(obj1, '#1 ICN?');       % Checks what the Current is currently set at.
VoltageSetPoint=num2str(str2num(VoltageSetPoint(5:end)),'%4.2f');
CurrentSetPoint=num2str(15*str2num(CurrentSetPoint(5:end)),'%4.2f');
CurrentVoltage = query(obj1, '#1 VM');
CurrentCurrent = query(obj1, '#1 IM');
CurrentVoltage=num2str(str2num(CurrentVoltage(4:end)),'%4.2f');
CurrentCurrent=num2str(str2num(CurrentCurrent(4:end)),'%4.2f');

f = figure('Visible','on','Position',[200,50,250,300]);

la=20;      % Left align of the first element
Top=250;    % Bottom align of the Top element
H5=5;z5=0;H10=10;z10=0;H20=20;z20=0;H30=30;z30=0;   % Set width counters to zero
x20=0;w20=20;x50=0;w50=50;x70=0;w70=70;             % Set height counters to zero


hControlOutput = uicontrol('Style','togglebutton','String',OutputString,'Position',[la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Control_Output,'Value',Value);  % Change the output of the power supply.
x50=x50+1;x50=x50+1;  % Increment counter
hReadValues = uicontrol('Style','pushbutton','String','Read Values','Position',[la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5),100,H30],'Callback',@Read_Values);  % Reading of the current and voltage is not continuous. This button will check the current values of the power supply.
z30=z30+1;  % Increment counter

la=20;  % Reset Left Align
x20=0;x50=0;x70=0;  % Set the left align counters to zero 
hVoltageTitle = uicontrol('Style','text','String','Enter Voltage (keV)','Position',...      
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50*2,H20+H5]...
    );
x50=x50+1;x50=x50+1;  % Increment counter
VoltageSetPoint=num2str(VoltageSetPoint,'%4.2f');   % Format the voltage display to have 2 decimal places
hVoltage = uicontrol('Style','edit','String',VoltageSetPoint,'Position',...     
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50*2,H30]...  
    ,'Callback',@Edit_Voltage);         % Callback to change voltage. Changing the number in the edit box will change the voltage. 
                                        % The value sent to the power supply is a percent but since the rating is 100 keV it is just keVs

la=20;  % Reset Left Align
x20=0;x50=0;x70=0;  % Set the left align counters to zero
x50=x50+1;  % Increment counter
z30=z30+1;  % Increment counter
hJogTitle = uicontrol('Style','text','String','Enter Jog (keV)','Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50,30]...
    );
x50=x50+1;  % Increment counter
hJogValue = uicontrol('Style','edit','String',0.1,'Position',...        % Set the value for how much each button press will change the voltage
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,30,H30]...
    );
hJogDown = uicontrol('Style','pushbutton','String','+','Position',hJogValue.Position+[30 0 0 0],'Callback',@Jog_Up);    % Increments the voltage up by the amount set in hJogValue
hJogUp = uicontrol('Style','pushbutton','String','-','Position',hJogDown.Position+[30 0 0 0],'Callback',@Jog_Down);    % Increments the voltage down by the amount set in hJogValue



la=20;  % Reset Left Align
x20=0;x50=0;x70=0;  % Set the left align counters to zero
z30=z30+1;  % Increment counter
x50=x50+1;  % Increment counter
CurrentCurrentTitle = uicontrol('Style','text','String','Current (mA)','Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10-5,w50,30]...
    );
x50=x50+1;
CurrentCurrentDisplay = uicontrol('Style','text','String',CurrentCurrent,'Position',[la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,40,H20]); % Displays the current most recently returned from the power supply
CurrentCurrentDisplay.BackgroundColor=[0.75 0.75 0.75]; % Set the background to grey

la=20;  % Reset Left Align
x20=0;x50=0;x70=0;  % Set the left align counters to zero
z30=z30+1;  % Increment counter
x50=x50+1;  % Increment counter
CurrentVoltageTitle = uicontrol('Style','text','String','Voltage (keV)','Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10-5,w50,30]...
    );
x50=x50+1;
CurrentVoltageDisplay = uicontrol('Style','text','String',CurrentVoltage,'Position',[la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,50,H20]); % Displays the voltage most recently returned from the power supply
CurrentVoltageDisplay.BackgroundColor=[0.75 0.75 0.75]; % Set the background to grey


la=20;  % Reset Left Align
x20=0;x50=0;x70=0;  % Set the left align counters to zero
  % Increment counter
z30=z30+1;  % Increment counter
z10=z10+1;  % Increment counter
z5=z5+1;  % Increment counter
hCurrentWarning = uicontrol('Style','text','String','Current Limit should be set at 150 µA (10% rated) when training according to manual','Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50*4,40]...
    );
x50=x50+1;  % Increment counter
z5=z5+1;  % Increment counter
z30=z30+1;  % Increment counter
hCurrentSetTitle = uicontrol('Style','text','String','Current Limit (µA)','Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,w50,30]...
    );
x50=x50+1;  % Increment counter
hCurrentSetValue = uicontrol('Style','edit','String',CurrentSetPoint,'Position',...
    [la+x20*w20+x50*w50+x70*w70,Top-z20*(H20+5)-z30*(H30+5)-z5*H5-z10*H10,30,H30],...
    'Callback',@Set_Current);


movegui(f,'center');
%% Callbacks

    function Control_Output(~,~)
        if hControlOutput.Value
            hControlOutput.String='Connecting...';
            fprintf(obj1, '#1 STS');      % Checks the status of the power supply
            pause(0.1)
            Status = fscanf(obj1);         % Gets the status: '#1 [Output Mode, CF = Disabled, CO = Enabled] [Remote Control Mode, LO = Disabled, RM = Enabled]'
            while length(Status) < 8
                fprintf(obj1, '#1 STS');
                Status = fscanf(obj1); 
                pause(0.1)
            end
            Remote = Status(7:8);
                fprintf(obj1, '#1 REN');      % Enables remote control of the HV
                pause(0.5)
                fprintf(obj1, '#1 RST');      % Cancels the cutoff state of the power supply
                Edit_Voltage
            if strcmp('Yes',Proceed)
                Set_Current;
                fprintf(obj1, '#1 SW1');      % Enables the output of the power supply (turns the red LED on) THE VOLTAGE WILL GO TO WHERE THE SETPOINT IS EVEN IF YOU HAVEN'T SET IT YET
                hControlOutput.String='Disable';
                pause(0.5);
                Read_Values;
            else
                hControlOutput.Value=0;
            end
        else
            fprintf(obj1, '#1 SW0');      % Disables the output of the power supply (turns the red LED off)
            hControlOutput.String='Enable';
        end
    end

    function Edit_Voltage(~,~)
        Voltage=str2num(hVoltage.String);
        Get_Current_Voltage;
        Diff=Voltage-CurrentVoltage;
        if (CurrentVoltage < 60 && Diff > 20) || (CurrentVoltage >= 60 && Diff > 9.99) || (CurrentVoltage >= 76 && Diff > 5) || (CurrentVoltage > 85 && Diff > 2) || (CurrentVoltage > 88 && Diff > 1)
            Proceed = questdlg(['The current voltage is ' num2str(CurrentVoltage) 'keV do you really want to turn it to ' num2str(Voltage) 'keV?'],'High Change Waring','Yes','No','No');
        else
            Proceed='Yes';
        end
        TrainingMode=0;
        %         if TrainingMode       %% TO DO: SET UP TRAINING MODE
        %             Rate=number;
        %         else
        Rate=2;     % kV per second
        %         end
        if strcmp('Yes',Proceed)
            if Voltage < 50
                Set_Voltage
            elseif Voltage < CurrentVoltage
                Set_Voltage
            elseif CurrentVoltage < 50 && Voltage >= 50
                VoltageSetPoint=50;
                Set_Voltage;
                pause(1)
                i=0;
                while VoltageSetPoint < Voltage
                    if VoltageSetPoint+Rate*(i) < Voltage
                        VoltageSetPoint=VoltageSetPoint+Rate*i;
                    else
                        VoltageSetPoint=Voltage;
                    end
                    VoltageSetPoint=num2str(VoltageSetPoint,'%4.2f');
                    hVoltage.String=VoltageSetPoint;
                    VoltageSetPoint=str2num(VoltageSetPoint);
                    Set_Voltage;
                    i=i+1;
                    pause(1)
                end
            elseif CurrentVoltage >= 50 && Voltage > 50
                VoltageSetPoint=round(CurrentVoltage,2);
                i=0;
                while VoltageSetPoint < Voltage
                    if VoltageSetPoint+Rate*(i) < Voltage
                        VoltageSetPoint=VoltageSetPoint+Rate*i;
                    else
                        VoltageSetPoint=Voltage;
                    end
                    VoltageSetPoint=num2str(VoltageSetPoint,'%4.2f');
                    hVoltage.String=VoltageSetPoint;
                    VoltageSetPoint=str2num(VoltageSetPoint);
                    Set_Voltage;
                    i=i+1;
                    pause(1)
                end
            else
                error('Apparently I forgot a case')
            end
        end
    end


    function Jog_Up(~,~)
        JogValue=str2num(hJogValue.String);
        Voltage=str2num(hVoltage.String);
        Voltage=Voltage+JogValue;
        hVoltage.String=Voltage;
        Voltage=num2str(Voltage,'%4.2f');
        hVoltage.String=Voltage;
        fprintf(obj1, ['#1 VCN ' Voltage]);
        pause(0.5);
        Read_Values;
    end
    
    function Jog_Down(~,~)
        JogValue=str2num(hJogValue.String);
        Voltage=str2num(hVoltage.String);
        Voltage=Voltage-JogValue;
        hVoltage.String=Voltage;
        Voltage=num2str(Voltage,'%4.2f');
        hVoltage.String=Voltage;
        fprintf(obj1, ['#1 VCN ' Voltage]);
        pause(0.5);
        Read_Values;
    end

    function Read_Values(~,~)
%         CurrentVoltage=rand*100;
%         CurrentCurrent=rand*.1;
%         CurrentCurrent=num2str(CurrentCurrent,'%4.2f');
%         CurrentCurrentDisplay.String=CurrentCurrent;
%         CurrentVoltage=rand*100;
        Get_Current_Voltage;
        Get_Current_Current;
        CurrentVoltage=num2str(CurrentVoltage,'%4.2f');
        CurrentCurrent=num2str(CurrentCurrent,'%4.2f');
        CurrentVoltageDisplay.String=CurrentVoltage;
        CurrentCurrentDisplay.String=CurrentCurrent;
    end

    function Set_Voltage(~,~)
        Voltage=str2num(hVoltage.String);
        Voltage=num2str(Voltage,'%4.2f');
        hVoltage.String=Voltage;
        fprintf(obj1, ['#1 VCN ' Voltage]);
        pause(0.5);
        Read_Values;
    end

    function Set_Current(~,~)
        Num=str2num(hCurrentSetValue.String);
        Percent=Num/1500*100;
        SetCurrentInput=strcat("#1 ICN ",num2str(Percent,'%4.2f'));
        fprintf(obj1, SetCurrentInput);
    end

    function Get_Current_Voltage(~,~)
        CurrentVoltage = query(obj1, '#1 VM');
        Iter=0;
        while isempty(CurrentVoltage)
            CurrentVoltage = query(obj1, '#1 VM');
            pause(0.1)
            Iter=Iter+1;
            if Iter==100
                error('Time limit reached to get voltage from power supply')
            end
        end
        Iter=1;
        while ~strcmp('VM=',CurrentVoltage(1:3))
            if mod(Iter,2)
                CurrentVoltage = query(obj1, '#1 IM');
            else
                CurrentVoltage = query(obj1, '#1 VM');
            end
            Iter=Iter+1;
            if Iter==100
                error('Voltage could not decide between voltage or current')
            end
            pause(0.1)
        end
        CurrentVoltage=str2num(CurrentVoltage(4:end));
    end

    function Get_Current_Current(~,~)
        CurrentCurrent = query(obj1, '#1 IM');
        Iter=0;
        while isempty(CurrentCurrent)
            CurrentCurrent = query(obj1, '#1 IM');
            pause(0.1)
            Iter=Iter+1;
            if Iter==100
                error('Time limit reached to get current from power supply')
            end
        end
        Iter=1;
        while ~strcmp('IM=',CurrentCurrent(1:3))
            if mod(Iter,2)
                CurrentCurrent = query(obj1, '#1 VM');
            else
                CurrentCurrent = query(obj1, '#1 IM');
            end
            Iter=Iter+1;
            if Iter==100
                error('Current could not decide between voltage or current')
            end
        end
        CurrentCurrent=str2num(CurrentCurrent(4:end));
    end


end  % Function End
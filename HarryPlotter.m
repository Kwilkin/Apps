function f = HarryPlotter(xStruct,yStruct)
%% Function to more easily look at 1-D plots

l = length(fieldnames(yStruct));
xChoice = nargin;
if xChoice == 1 % if you don't give it an x value. This is easier than if statements later. If the inputs were huge if statements would be better.
    for ii = 1:l
        xStruct.(genvarname(['Scan' num2str(ii)])) = 1:length(yStruct.(genvarname(['Scan' num2str(j)])));
    end
end

ScanNumStr = cell(1,l);
for ii = 1:l % Set the input cell of scan numbers.
    ScanNumStr{ii} = ['Scan ' num2str(ii)]; 
end
f = figure('Visible','on','Position',[400,100,800,500]);

haxis = axes('Units','Normalized','Position',[.05,.15,.9,.8]);

goBack = uicontrol('Units','Normalized','Style','pushbutton','String',...
    '<<','Position',[0.8,.02,0.05,0.05],'Callback',@go_Back);

goForward = uicontrol('Units','Normalized','Style','pushbutton','String',...
    '>>','Position',[0.87,.02,0.05,0.05],'Callback',@go_Forward);

pickEm = uicontrol('Units','Normalized','Style','popupmenu','String',ScanNumStr,'Position',[.1,0.02,.2,0.05],'Callback',@pick_Em);

plot(haxis,xStruct.Scan1,yStruct.Scan1)
Ind = 1;
xlabel(haxis,['Scan ' num2str(Ind) ' of ' num2str(l)])

    function go_Back(~,~)
        if Ind == 1
            Ind = l;
        else
            Ind = Ind - 1;
        end
        plot(haxis,xStruct.(genvarname(['Scan' num2str(Ind)])),yStruct.(genvarname(['Scan' num2str(Ind)])))
        xlabel(haxis,['Scan ' num2str(Ind) ' of ' num2str(l)])
        pickEm.Value = Ind;
    end

    function go_Forward(~,~)
        if Ind == l
            Ind = 1;
        else
            Ind = Ind + 1;
        end
        plot(haxis,xStruct.(genvarname(['Scan' num2str(Ind)])),yStruct.(genvarname(['Scan' num2str(Ind)])))
        xlabel(haxis,['Scan ' num2str(Ind) ' of ' num2str(l)])
        pickEm.Value = Ind;
    end

    function pick_Em(~,~)
        Ind = pickEm.Value;
        plot(haxis,xStruct.(genvarname(['Scan' num2str(Ind)])),yStruct.(genvarname(['Scan' num2str(Ind)])))
        xlabel(haxis,['Scan ' num2str(Ind) ' of ' num2str(l)])
    end

end

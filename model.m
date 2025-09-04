function build_RCCG_custom_model()
    modelName = 'RCCG_CustomGrid';
    new_system(modelName);
    open_system(modelName);

    % Add bus blocks (11kV and 33kV)
    add_block('simulink/Signal Routing/Bus Creator',[modelName '/Bus11kV'],...
        'Position',[400 150 430 250]);
    add_block('simulink/Signal Routing/Bus Creator',[modelName '/Bus33kV'],...
        'Position',[800 150 830 300]);

    % Add 2 Custom Generators (5 MW each)
    for i = 1:2
        genName = ['Gen' num2str(i)];
        add_block('built-in/Subsystem',[modelName '/' genName],...
            'Position',[100 50+200*(i-1) 300 200+200*(i-1)]);
        build_custom_gen_subsystem([modelName '/' genName]);
    end

    % Step-up Transformer (11/33kV simplified as Gain)
    add_block('simulink/Math Operations/Gain',[modelName '/Transformer'],...
        'Gain','(33/11)','Position',[550 180 600 220]);

    % 7 Feeders at 33kV Bus
    for i = 1:7
        feeder = ['Feeder' num2str(i)];
        add_block('simulink/Sinks/Out1',[modelName '/' feeder],...
            'Position',[1000 50*i+100 1050 50*i+120]);
    end

    % Connections
    % Generators → 11kV bus
    add_line(modelName,'Gen1/1','Bus11kV/1'); % Pe1
    add_line(modelName,'Gen2/1','Bus11kV/2'); % Pe2

    % Bus11kV → Transformer → Bus33kV
    add_line(modelName,'Bus11kV/1','Transformer/1');
    add_line(modelName,'Transformer/1','Bus33kV/1');

    % 33kV Bus → Feeders
    for i = 1:7
        add_line(modelName,['Bus33kV/' num2str(i)],['Feeder' num2str(i) '/1']);
    end

    save_system(modelName);
    disp(['✅ RCCG custom model "' modelName '" built successfully.']);
end

%% --- Subsystem builder (same as before) ---
function build_custom_gen_subsystem(sysPath)
    % Inputs
    add_block('simulink/Sources/In1',[sysPath '/Pm_ref'], 'Position',[30 40 60 60]);
    add_block('simulink/Sources/In1',[sysPath '/Vref'], 'Position',[30 90 60 110]);
    add_block('simulink/Sources/In1',[sysPath '/Vt'], 'Position',[30 140 60 160]);
    add_block('simulink/Sources/In1',[sysPath '/w_ref'], 'Position',[30 190 60 210]);

    % Outputs
    add_block('simulink/Sinks/Out1',[sysPath '/Pe'], 'Position',[650 50 680 70]);
    add_block('simulink/Sinks/Out1',[sysPath '/w'], 'Position',[650 100 680 120]);
    add_block('simulink/Sinks/Out1',[sysPath '/delta'], 'Position',[650 150 680 170]);
    add_block('simulink/Sinks/Out1',[sysPath '/Efd'], 'Position',[650 200 680 220]);

    % Governor (1st order)
    add_block('simulink/Math Operations/Subtract',[sysPath '/SpeedError'],...
        'Position',[100 180 130 210]);
    add_block('simulink/Continuous/Transfer Fcn',[sysPath '/GovernorTf'],...
        'Numerator','[1]','Denominator','[0.2 1]',...
        'Position',[160 180 220 210]);

    % AVR
    add_block('simulink/Math Operations/Subtract',[sysPath '/VoltageError'],...
        'Position',[100 80 130 110]);
    add_block('simulink/Math Operations/Gain',[sysPath '/AVRgain'],...
        'Gain','50','Position',[160 80 200 110]);
    add_block('simulink/Discontinuities/Saturation',[sysPath '/AVRsat'],...
        'UpperLimit','5','LowerLimit','-5','Position',[240 80 280 110]);

    % Swing eqn
    add_block('simulink/Math Operations/Subtract',[sysPath '/Pm_minus_Pe'],...
        'Position',[300 50 330 80]);
    add_block('simulink/Math Operations/Gain',[sysPath '/InertiaGain'],...
        'Gain','1/(2*3.5)',...
        'Position',[360 50 420 80]);
    add_block('simulink/Continuous/Integrator',[sysPath '/Integrator_w'],...
        'InitialCondition','1','Position',[450 50 480 80]);

    % Delta integrator
    add_block('simulink/Math Operations/Subtract',[sysPath '/SpeedDev'],...
        'Position',[300 100 330 130]);
    add_block('simulink/Continuous/Integrator',[sysPath '/Integrator_delta'],...
        'InitialCondition','0','Position',[360 100 390 130]);

    % Electrical Power Pe
    add_block('simulink/Math Operations/Product',[sysPath '/Mult1'],...
        'Position',[420 200 450 230]);
    add_block('simulink/Math Operations/Product',[sysPath '/Mult2'],...
        'Position',[480 200 510 230]);
    add_block('simulink/Math Operations/Gain',[sysPath '/XdGain'],...
        'Gain','1/1.8',...
        'Position',[540 200 580 230]);
    add_block('simulink/Math Operations/Trigonometric Function',[sysPath '/Sine'],...
        'Operator','sin','Position',[420 140 450 170]);

    % Connections
    add_line(sysPath,'w_ref/1','SpeedError/1');
    add_line(sysPath,'Integrator_w/1','SpeedError/2');
    add_line(sysPath,'SpeedError/1','GovernorTf/1');
    add_line(sysPath,'GovernorTf/1','Pm_minus_Pe/1');

    add_line(sysPath,'Vref/1','VoltageError/1');
    add_line(sysPath,'Vt/1','VoltageError/2');
    add_line(sysPath,'VoltageError/1','AVRgain/1');
    add_line(sysPath,'AVRgain/1','AVRsat/1');
    add_line(sysPath,'AVRsat/1','Mult1/1');
    add_line(sysPath,'AVRsat/1','Efd/1');

    add_line(sysPath,'Pm_minus_Pe/1','InertiaGain/1');
    add_line(sysPath,'InertiaGain/1','Integrator_w/1');
    add_line(sysPath,'Integrator_w/1','w/1');

    add_line(sysPath,'Integrator_w/1','SpeedDev/1');
    add_line(sysPath,'w_ref/1','SpeedDev/2');
    add_line(sysPath,'SpeedDev/1','Integrator_delta/1');
    add_line(sysPath,'Integrator_delta/1','delta/1');
    add_line(sysPath,'Integrator_delta/1','Sine/1');

    add_line(sysPath,'Vt/1','Mult1/2');
    add_line(sysPath,'Mult1/1','Mult2/1');
    add_line(sysPath,'Sine/1','Mult2/2');
    add_line(sysPath,'Mult2/1','XdGain/1');
    add_line(sysPath,'XdGain/1','Pe/1');
end

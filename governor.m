function build_custom_generator()
    modelName = 'CustomGenDemo';
    new_system(modelName);
    open_system(modelName);

    % Create subsystem
    genPath = [modelName '/CustomGen'];
    add_block('built-in/Subsystem', genPath, 'Position',[100 100 400 300]);

    % Build internals
    build_custom_gen_subsystem(genPath);

    save_system(modelName);
    disp(['Custom generator model "' modelName '" built successfully.']);
end

%% --- Build internals of custom generator subsystem ---
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

    % Governor (1st order: Pm = (1/(1+Ts)) * (w_ref - w))
    add_block('simulink/Math Operations/Subtract',[sysPath '/SpeedError'],...
        'Position',[100 180 130 210]);
    add_block('simulink/Continuous/Transfer Fcn',[sysPath '/GovernorTf'],...
        'Numerator','[1]','Denominator','[0.2 1]',...
        'Position',[160 180 220 210]);

    % AVR: Efd = sat(Ka*(Vref - Vt))
    add_block('simulink/Math Operations/Subtract',[sysPath '/VoltageError'],...
        'Position',[100 80 130 110]);
    add_block('simulink/Math Operations/Gain',[sysPath '/AVRgain'],...
        'Gain','50','Position',[160 80 200 110]);
    add_block('simulink/Discontinuities/Saturation',[sysPath '/AVRsat'],...
        'UpperLimit','5','LowerLimit','-5','Position',[240 80 280 110]);

    % Swing equation
    % d(w)/dt = (Pm - Pe - D*(w-1))/(2H)
    add_block('simulink/Math Operations/Subtract',[sysPath '/Pm_minus_Pe'],...
        'Position',[300 50 330 80]);
    add_block('simulink/Math Operations/Gain',[sysPath '/InertiaGain'],...
        'Gain','1/(2*3.5)',... % H = 3.5s
        'Position',[360 50 420 80]);
    add_block('simulink/Continuous/Integrator',[sysPath '/Integrator_w'],...
        'InitialCondition','1','Position',[450 50 480 80]);

    % Delta integrator (δ_dot = w - 1)
    add_block('simulink/Math Operations/Subtract',[sysPath '/SpeedDev'],...
        'Position',[300 100 330 130]);
    add_block('simulink/Continuous/Integrator',[sysPath '/Integrator_delta'],...
        'InitialCondition','0','Position',[360 100 390 130]);

    % Electrical Power Pe = (Efd*Vt/Xd)*sin(delta)
    add_block('simulink/Math Operations/Product',[sysPath '/Mult1'],...
        'Position',[420 200 450 230]);
    add_block('simulink/Math Operations/Product',[sysPath '/Mult2'],...
        'Position',[480 200 510 230]);
    add_block('simulink/Math Operations/Gain',[sysPath '/XdGain'],...
        'Gain','1/1.8',... % Xd
        'Position',[540 200 580 230]);
    add_block('simulink/Math Operations/Trigonometric Function',[sysPath '/Sine'],...
        'Operator','sin','Position',[420 140 450 170]);

    % Connections
    % Governor
    add_line(sysPath,'w_ref/1','SpeedError/1');
    add_line(sysPath,'Integrator_w/1','SpeedError/2');
    add_line(sysPath,'SpeedError/1','GovernorTf/1');
    add_line(sysPath,'GovernorTf/1','Pm_minus_Pe/1');

    % AVR
    add_line(sysPath,'Vref/1','VoltageError/1');
    add_line(sysPath,'Vt/1','VoltageError/2');
    add_line(sysPath,'VoltageError/1','AVRgain/1');
    add_line(sysPath,'AVRgain/1','AVRsat/1');
    add_line(sysPath,'AVRsat/1','Mult1/1'); % Efd to Pe
    add_line(sysPath,'AVRsat/1','Efd/1');   % output

    % Swing equation
    add_line(sysPath,'Pm_minus_Pe/1','InertiaGain/1');
    add_line(sysPath,'InertiaGain/1','Integrator_w/1');
    add_line(sysPath,'Integrator_w/1','w/1'); % output

    % Delta dynamics
    add_line(sysPath,'Integrator_w/1','SpeedDev/1');
    add_line(sysPath,'w_ref/1','SpeedDev/2');
    add_line(sysPath,'SpeedDev/1','Integrator_delta/1');
    add_line(sysPath,'Integrator_delta/1','delta/1');
    add_line(sysPath,'Integrator_delta/1','Sine/1');

    % Electrical Power Pe calc
    add_line(sysPath,'AVRsat/1','Mult1/1'); % Efd
    add_line(sysPath,'Vt/1','Mult1/2');     % Vt
    add_line(sysPath,'Mult1/1','Mult2/1');  % Efd*Vt
    add_line(sysPath,'Sine/1','Mult2/2');   % sin(delta)
    add_line(sysPath,'Mult2/1','XdGain/1');
    add_line(sysPath,'XdGain/1','Pe/1');    % output

end

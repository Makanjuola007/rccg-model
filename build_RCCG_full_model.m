function build_RCCG_model()

    % Create new model
    new_system('RCCG');
    open_system('RCCG');

    %% === Subsystems for Generators ===
    add_block('simulink/Ports & Subsystems/Subsystem', 'RCCG/Gen1');
    add_block('simulink/Ports & Subsystems/Subsystem', 'RCCG/Gen2');

    set_param('RCCG/Gen1','Position',[100,100,200,200]);
    set_param('RCCG/Gen2','Position',[100,300,200,400]);

    % Inside each generator (placeholder simple generator)
    for k = 1:2
        genPath = sprintf('RCCG/Gen%d',k);
        open_system(genPath);

        % Inputs: Pm_ref, Vref, Vt, w_ref
        add_block('simulink/Sources/In1', [genPath '/Pm_ref'],'Position',[30,30,60,50]);
        add_block('simulink/Sources/In1', [genPath '/Vref'],'Position',[30,70,60,90]);
        add_block('simulink/Sources/In1', [genPath '/Vt'],'Position',[30,110,60,130]);
        add_block('simulink/Sources/In1', [genPath '/w_ref'],'Position',[30,150,60,170]);

        % Outputs: Pe, w, δ, Efd
        add_block('simulink/Sinks/Out1', [genPath '/Pe'],'Position',[300,50,330,70]);
        add_block('simulink/Sinks/Out1', [genPath '/w'],'Position',[300,90,330,110]);
        add_block('simulink/Sinks/Out1', [genPath '/delta'],'Position',[300,130,330,150]);
        add_block('simulink/Sinks/Out1', [genPath '/Efd'],'Position',[300,170,330,190]);

        % Simplified gen model: Pm_ref passes through to Pe
        add_block('simulink/Math Operations/Gain', [genPath '/Gain'],'Gain','1','Position',[150,40,180,70]);
        add_line(genPath,'Pm_ref/1','Gain/1');
        add_line(genPath,'Gain/1','Pe/1');
    end

    %% === Bus 11kV Node ===
    add_block('simulink/Signal Routing/Bus Creator','RCCG/Bus11kV');
    set_param('RCCG/Bus11kV','Position',[500,200,530,260]);

    %% === Voltage Measurement ===
    add_block('powerlib/Measurements/Voltage Measurement','RCCG/Vmeas');
    set_param('RCCG/Vmeas','Position',[400,220,440,260]);
    %% === Create 11kV Bus (3-phase busbar) ===
    add_block('powerlib/Elements/Three-Phase Parallel RLC Branch', 'RCCG/Bus11kV');
    set_param('RCCG/Bus11kV','BranchType','B'); % acts like a bus node
    set_param('RCCG/Bus11kV','Position',[600,200,650,260]);

    %% === Voltage Measurement connected to Bus ===
    add_block('powerlib/Measurements/Voltage Measurement','RCCG/Vmeas');
    set_param('RCCG/Vmeas','Position',[700,220,740,260]);

    % Connect Bus to Voltage Measurement
    add_line('RCCG','Bus11kV/1','Vmeas/1');
    add_line('RCCG','Bus11kV/2','Vmeas/2');

    %% === Constant Inputs ===
    % Generator setpoints
    add_block('simulink/Sources/Constant','RCCG/Pm1_ref','Value','2.5e6','Position',[10,120,40,140]);
    add_block('simulink/Sources/Constant','RCCG/Pm2_ref','Value','2.5e6','Position',[10,320,40,340]);

    add_block('simulink/Sources/Constant','RCCG/Vref','Value','1','Position',[10,30,40,50]);
    add_block('simulink/Sources/Constant','RCCG/w_ref','Value','1','Position',[10,70,40,90]);

    %% === Connect Gen1 ===
    add_line('RCCG','Pm1_ref/1','Gen1/1');
    add_line('RCCG','Vref/1','Gen1/2');
    add_line('RCCG','w_ref/1','Gen1/4');
    add_line('RCCG','Gen1/1','Vmeas/1'); % Pe feeds bus input

    %% === Connect Gen2 ===
    add_line('RCCG','Pm2_ref/1','Gen2/1');
    add_line('RCCG','Vref/1','Gen2/2');
    add_line('RCCG','w_ref/1','Gen2/4');
    add_line('RCCG','Gen2/1','Vmeas/1','autorouting','on');

    %% === Voltage Feedback ===
    add_line('RCCG','Vmeas/1','Gen1/3');
    add_line('RCCG','Vmeas/1','Gen2/3','autorouting','on');

    save_system('RCCG');
    disp('✅ RCCG model built successfully.');
end

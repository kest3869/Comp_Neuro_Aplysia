close all
clear all

% Parameters
aplysia = AplysiaFeeding();
suffix = '2023 Comp. Neuro';
xlimits = [0 40];

%% Classify a Single Sensory State 
%aplysia = AplysiaFeeding();
%aplysia = aplysia.setSensoryStates('swallow');
%aplysia = aplysia.runSimulation();
%classify(aplysia)
%aplysia.generatePlots(['swallow' '_test_plot'],[0 40]);

%% Classify a Behavior Switch
t_switch = 35;                    % swallow, reject, bite
aplysia = aplysia.setSensoryStates('bite','swallow',t_switch);
aplysia = aplysia.runSimulation();
switch_time = classify_switch(aplysia)
switch_time = switch_time * (1/aplysia.TimeStep);
classify(aplysia,[2:switch_time])
classify(aplysia,[switch_time:length(aplysia.B4B5)])
%aplysia.generatePlots(['swallow_reject' suffix],xlimits);

%% Classify Itermediate Sensory States
%{
aplysia = AplysiaFeeding();
aplysia.use_hypothesized_connections = 1;
t_transitionidx_1 = 1;
t_transition_B4duration = 1/aplysia.TimeStep;
aplysia = aplysia.setSensoryStates('swallow');
                 %setStimulationTrains(neuron,onTime,           duration)
aplysia = aplysia.setStimulationTrains('B4B5',t_transitionidx_1,t_transition_B4duration);
aplysia = aplysia.runSimulation();
classify(aplysia)
aplysia.generatePlots(['B4B5_stimulation' suffix],[5 40]);
%}

%% Classify a sesory state (using nerves) 
function action = classify(aplysia, indices)

    % uses the full array if indices aren't provided
    if nargin < 2
        indices = [2, length(aplysia.B38)];
    end

    % Only need information of 2 neurons to classify actions
    B4B5 = sum(aplysia.B4B5(indices)) > 1;
    B38 = sum(aplysia.B38(indices)) > 1;

    % Boolean logic to determine action
    if B38
        action = 'swallow';
    elseif B4B5
        action = 'reject';
    else
        action = 'bite';
    end
end

%% Find Switches in Sensory State (using interneurons) 
function change_times = classify_switch(aplysia)

    % Initialize change_times as an empty array
    change_times = [];

    % find initial state 
    CBI_3_i = aplysia.CBI3(2);
    CBI_4_i = aplysia.CBI4(2);

    % check for changes in state 
    for i = 3:length(aplysia.CBI3) - 1
        CBI_3_n = aplysia.CBI3(i);
        CBI_4_n = aplysia.CBI4(i);

        % detects a change in state
        if CBI_3_i ~= CBI_3_n || CBI_4_i ~= CBI_4_n

            % calculate the time when the change occurred 
            time = (i-1) * aplysia.TimeStep;

            % save for later
            change_times = [change_times, time];

            % update initial conditions 
            CBI_3_i = CBI_3_n;
            CBI_4_i = CBI_4_n;

        end
    end 
end



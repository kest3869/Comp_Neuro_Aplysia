close all
clear all

%% Specify label suffix for saving figures
suffix = '_8_9_2020';
xlimits = [0 40];

%% Initialize simulation object
aplysia = AplysiaFeeding();

%% B4/B5 Stimulation

aplysia.use_hypothesized_connections = 1;

t_transitionidx_1 = fix(length(aplysia.B4B5)/2);
t_transition_B4duration = 1/aplysia.TimeStep; % in timesteps

aplysia = aplysia.setSensoryStates('swallow');
                 %setStimulationTrains(neuron,onTime,           duration)
aplysia = aplysia.setStimulationTrains('B4B5',t_transitionidx_1,t_transition_B4duration);

tic
aplysia = aplysia.runSimulation();
toc

aplysia.generatePlots(['B4B5_stimulation' suffix],[5 40]);
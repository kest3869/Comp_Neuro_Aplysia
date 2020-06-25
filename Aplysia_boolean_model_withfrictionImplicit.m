% Discrete time, discrete state representation of Aplysia central pattern
% generator for multifunctional feeding behavior,
% coupled to continuous, (relatively) low biomechanics.  
%
% Vickie Webster Wood, CMU.
% Peter Thomas, CWRU.
% in consultation with Hillel Chiel, CWRU.
% in consultation with Jeff Gill, CWRU
%
%
% Last Update: 5/26/2020

function [avec,bvec,cvec] = Aplysia_boolean_model_withfrictionImplicit(chemicalAtLips,mechanicalAtLips,mechanicalInGrasper,params,thresholds,modulation,stim,seaweed_strength, object_fixation)


%% Preallocate arrays
dt=params{1,1}; % Time units in seconds
t0=params{2,1};
tmax=params{3,1}; % Basic period should be about 5 sec.
t=t0:dt:tmax;
nt=length(t); % number of time points

na_units=13; % dimension of neural representation
nb_units=21; % dimension of body representation
nc_units=7; % dimension of "external world" representation

avec=zeros(na_units,nt);
bvec=zeros(nb_units,nt);
cvec=zeros(nc_units,nt);

% Organization of avec -- "neural activation" state vector
% avec(1,:): B8a/b (closes grasper)
% avec(2,:): B38 (activates anterior pinch)
% avec(3,:): B4/B5 (who knows what they do?  But see below.)
% avec(4,:): B31/B32 + B61/B62 (activate the I2 muscle)
% avec(5,:): B6/B9 + B3 (activate the I3 muscle)
% avec(6,:): Metacerebral cell (generalized excitation of feeding circuit)
% avec(7,:): CBI2 
% avec(8,:): CBI3
% avec(9,:): B64 - retraction interneuron
% avec(10,:): B20 - should be active during egestion, silent during ing.
% avec(11,:): B7 - only relevent in egestion
% avec(12,:): CBI4
% avec(13,:): B40/B30

% Organization of bvec -- "body" state vector
% bvec(1,:): grasper state (0: open, 1: closed)
% bvec(2,:): pressure exerted by grasper (0 to pmax)
% bvec(3,:): activation of I3, rectractor muscle (0 to b3max)
% bvec(4,:): activation of I2, protractor muscle (0 to b4max)
% bvec(5,:): state of anterior pinch (0: open/relaxed, 1:closed/taught)
% bvec(6,:): position of grasper along protration(1)/retraction(0) axis
% bvec(7,:): force exerted by grasper on seaweed
% bvec(8,:): position of buccal mass relative to 'ground'
% bvec(9,:): pinch force
% bvec(10,:): "positive mechanical input" encouraging ingestion, e.g.
% "feel" of seaweed 
% bvec(11,:): activation of Grapser pull
% bvec(12,:): activation of hinge
% bvec 

% Organization of cvec -- "environment" state vector i.e. external world
% cvec(1,:): position of seaweed relative to jaws
% cvec(2,:): load applied to seaweed?  What if seaweed is just held fixed
% in place, so load is generated by the animal and not "generated"
% externally?  
% cvec(3,:): "positive chemical input" encouraging ingestion, e.g. taste of
% seaweed
% Extracellular electrodes:
% cvec(4,:): Extracellular electrode positioned over B4/B5.  
% cvec(5,:): Extracellular electrode positioned over CBI2.  
% When equal to zero, no change to existing code.
% When equal to +one, unit is forced to turn on no matter what.
% When equal to -one, unit is forced to turn off no matter what.

%% Set parameters
pmax = params{4,1}; % maximum pressure grasper can exert on food (an arbitrary numb.)
tau_p = params{5,1}; % time constant (in seconds) for pressure applied by grasper - orginial is 1.0
tau_pinch = params{6,1}; % time constant (in seconds) for pressure of pinch - original is 2.0
tau_pull = params{7,1}; %time constant (in seconds) for B8 pulling
tau_m = params{8,1}; % time constant (in seconds) for I2 and I3 muscles
c_g = params{9,1}; % time constant (in seconds) for grapser motion - original 1.0
c_b = params{10,1}; % time constant (in seconds) for body motion
prot_pas = params{11,1}; % passive protractive force - original 0.01
retr_pas = params{12,1}; % passive retractive force - original 0.015
K_h = params{13,1}; % spring constant representing boddy from buccal mass to ground
x_h_ref = params{14,1}; % resting position of body
pinch_max = params{15,1}; % pinch force, original 0.15
force_scaler = params{16,1}; % 
gap = params{17,1}; % influence of CBI2-CBI3 gap junction on a scale of 0 to 1.  Not used yet...
CBI3_refractoryDuration = params{18,1}/1000/dt; %converted to timesteps
B40B30_postExcitationDuration = params{19,1}/1000/dt;
max_I3 = params{20,1}; %Maximum I3 force
max_I2 = params{21,1}; %Maximum I2 force
max_hinge = params{22,1}; %Maximum hinge force
K_g = params{23,1}; %grasperSpring_K spring constant representing attachment between buccal mass and head
x_gh_ref = params{24,1}; %grasperSpring_rest resting position of the buccal mass within the head
mu_s_g = params{25,1}; %mu_s coefficient of static friction at grasper
mu_k_g = params{26,1}; %mu_k coefficient of kinetic friction at grasper
mu_s_h = params{27,1}; %mu_s coefficient of static friction at jaws
mu_k_h = params{28,1}; %mu_k coefficient of kinetic friction at jaws


prot_thresh = thresholds{1,1}; % threshold for having reached sufficient protraction - original 0.8
ret_thresh = thresholds{2,1}; % threshold for having reached sufficient retraction - original 0.4
B38ingest_thresh = thresholds{3,1}; % threshold for activing B38 when B20 is silent (retraction/ingestion)
B38egest_thresh = thresholds{4,1}; % threshold for activing B38 when B20 is active (protraction/egestion)
B64_thresh_retract_biting = thresholds{5,1};
B64_thresh_retract_swallowing = thresholds{6,1};
B64_thresh_retract_reject = thresholds{7,1};
B64_thresh_protract_biting = thresholds{8,1};
B64_thresh_protract_swallowing = thresholds{9,1};
B64_thresh_protract_reject = thresholds{10,1};
B4B5_threshold = thresholds{11,1};
B31_thresh_protract_swallow = thresholds{12,1}; %B31/B32 threshold for protraction during swallowing
B31_thresh_retract_swallow = thresholds{13,1}; %B31/B32 threshold for retraction during swallowing
B31_thresh_protract_reject = thresholds{14,1}; %B31/B32 threshold for protraction during rejection
B31_thresh_retract_reject = thresholds{15,1}; %B31/B32 threshold for retraction during rejection
B31_thresh_protract_bite = thresholds{16,1}; %B31/B32 threshold for protraction during biting
B31_thresh_retract_bite = thresholds{17,1}; %B31/B32 threshold for retraction during biting
B7_thresh_protract_reject = thresholds{18,1}; %B7_thersh_protract_reject threshold for protraction during rejection
B7_thresh_protract_biting = thresholds{19,1}; %B7_thresh_protract_biting threshold for protraction during biting
B6B9B3_pressure_thresh_swallowing = thresholds{20,1}; %B6B9B3_pressure_thresh_swallowing
B6B9B3_pressure_thresh_biting = thresholds{21,1}; %B6B9B3_pressure_thresh_biting
B6B9B3_pressure_thresh_reject = thresholds{22,1}; %B6B9B3_pressure_thresh_reject

I2_tau_ingestion = modulation{1,1};
I2_tau_egestion = modulation{2,1};


CBI3_stimON = 0;
CBI3_stimOFF = 0;
CBI3_refractory = 0;
B40B30_onTime = 0;
B40B30_offTime = 0;

%% Initial conditions: Let's start while B38 and B31/32 etc. are turned on,
% at the start of the protraction phase, so the grasper is retracted and
% starting to protract.  
%
% Specify first two states so we can calculate rates of change.

avec(:,1:2)=[...
    0,0;      % B8a/b are off
    1,1;      % B38 is on
    0,0;      % B4/B5 are off
    1,1;      % B31/32 are on (they just turned on)
    0,0;      % B6/B9/B3 are off
    1,1;      % General feeding arousal is "on"; stays on for this script.
    1,1;      % start with CBI2 on
    0,0;      % start with CBI3 on
    0,0;      % start with B64 off
    0,0;      % start with B20 off for ingestive behavior?
    0,0;      % start with B7 off for ingestive behavior
    0,0;      % start with CBI4 off
    0,0];     % start with B40/B30 off
    
bvec(:,1:2)=[...
    0,0;        % 1. grasper is open
    0,0;        % 2. no grasper pressure is exerted
    0.05,.05;   % 3. I3 not activated much
    0.05,.05;   % 4. I2 also not activated much
    1,1;        % 5. anterior pinch is closed
    0.1,0.1;    % 6. start with grasper mostly retracted?
    0.2,0.2;    % 7. grasper force is low, but not at minimum yet.
    0,0;        % 8. relative position of buccal mass is neutral
    0,0;        % 9. pinch force is zero
    1,1;        % 10. positive mechanical input is present
    0,0;        % 11. activation of grasper pull
    0,0;        % 12. activation of hinge
    0.05,0.05;  % 13. aux. var. I3 activation (input from B3/B6/B9)
    0.05,0.05;  % 14. aux. var. I2 activation (input from B31/B32)
    0.05,0.05;  % 15. aux. var. grasper pull (?)
    0.05,0.05;  % 16. aux. var. grasper pinch (input from B8)
    0.05,0.05; % 17. aux. var. hinge (input from ??)
    0.0,0.0; % 18. aux. var. grasper static friction boolean (tracks if grasper is firmly holding seaweed)
    0.0,0.0; %19 aux variable pinch static friction boolean
    0,0; %20 aux var. grasper static friction force
    0,0];%21 aux var. pinch static friction force

cvec(1:3,1:2)=[...
    0,0;    % initial 'position' of seaweed relative to jaws (arbitrary)
    1,1;    % interpret 1 as "seaweed held fixed"?  Not using this for now.
    1,1];   % positive chemical input is present

cvec(3,1:nt) = chemicalAtLips(1,1:nt);
cvec(4,1:nt) = stim(3,1:nt); % turn on extracellular stimulation of B4/B5
cvec(5,1:nt) = zeros(1,nt); % turn on extracellular suppression of CBI2
cvec(6,1:nt) = mechanicalInGrasper(1,1:nt); %seaweed in grasper
cvec(7,1:nt) = mechanicalAtLips(1,1:nt); %mechanical stimulation at lips

%tracking variable to keep track of seaweed being broken off during feeding
unbroken = 1;

%% Main Loop

for j=2:(nt-1)

    electrode_CBI2 = cvec(5,j);
    stimuli_chem_last = cvec(3,j);
    mechanical_in_grasper = cvec(6,j);
    object_type = object_fixation(1,j); 

    
    MCC_last = avec(6,j);%: Metacerebral cell (generalized excitation of feeding circuit)
    CBI2_last = avec(7,j);%: CBI2 
    CBI3_last = avec(8,j);%: CBI3
    CBI4_last = avec(12,j);%: CBI3
    
    B8ab_last = avec(1,j);%: B8a/b (closes grasper)
    B38_last = avec(2,j);%: B38 (activates anterior pinch)
    B4B5_last = avec(3,j);%: B4/B5 (who knows what they do?  But see below.)
    B31B32_last = avec(4,j);%: B31/B32 + B61/B62 (activate the I2 muscle)
    B6B9B3_last = avec(5,j);%: B6/B9 + B3 (activate the I3 muscle)
    B64_last = avec(9,j);%: B64 - retraction interneuron
    B20_last = avec(10,j);%: B20 - should be active during egestion, silent during ing.
    B7_last = avec(11,j);%: B7 - only relevent in egestion
    B40B30_last = avec(13,j);%: B40/B30

    %Organization of bvec -- "body" state vector
%    GrasperState_last = bvec(1,j);%: grasper state (0: open, 1: closed) -- not used in this model
    P_I4 = bvec(2,j);%: pressure exerted by grasper (0 to pmax)
    
    %uncomment to remove periphery
    %GrapserPressure_last = 0;%: pressure exerted by grasper (0 to pmax)
    
    T_I3 = bvec(3,j);%: activation of I3, rectractor muscle (0 to b3max)
    T_I2 = bvec(4,j);%: activation of I2, protractor muscle (0 to b4max)
    %PinchState_last = bvec(5,j);%: state of anterior pinch (0:
    %open/relaxed, 1:closed/taught) -- not used in this model
    x_g = bvec(6,j);%: position of grasper along protration(1)/retraction(0) axis
    x_h = bvec(8,j);%: position of buccal mass relative to 'ground'
    stimuli_mech_last = cvec(7,j);%: "positive mechanical input" encouraging ingestion, e.g. "feel" of seaweed %
%    GrasperPull_last = bvec(11,j);%: activation of Grapser pull - not
%    included in this model
    T_Hi = bvec(12,j);%: activation of hinge

    x_gh = x_g-x_h;
    P_I3_anterior = bvec(9,j);

    % All neural elements require avec(6) to be on (general feeding
    % arousal) to remain active.
    
    %% Update Metacerebral cell: 
    % assume here feeding arousal continues
    % indefinitely, once started. 
    %{
    MCC is active IF
        General Food arousal is on
    %}

    avec(6,j+1)=MCC_last;
   
    %% Update CBI-2
    %{
    CBI2 is active IF
        MCC is on 
        AND (
            (Mechanical Stimulation at Lips AND Chemical Stimulation at Lips AND No mechanical stimuli in grasper)
            OR 
            (Mechanical in grasper and no Chemical Stimulation at Lips)
            OR
            (B4/B5 is firing strongly (>=2)))
    %}

    %CBI2 - updated 6/7/2020
    %with hypothesized connections from B4/B5
%     avec(7,j+1) = (electrode_CBI2==0)*... if electrode above CBI-2 is off, do this:
%         MCC_last*(~B64_last)*((stimuli_mech_last&&stimuli_chem_last&&(~mechanical_in_grasper))||(mechanical_in_grasper&&(~stimuli_chem_last))||(B4B5_last>=2))+...
%         (electrode_CBI2==1);
    %without hypothesized connections from B4/B5
    avec(7,j+1) = (electrode_CBI2==0)*... if electrode above CBI-2 is off, do this:
        MCC_last*(~B64_last)*((stimuli_mech_last&&stimuli_chem_last&&(~mechanical_in_grasper))||(mechanical_in_grasper&&(~stimuli_chem_last)))+...
        (electrode_CBI2==1);

    %% Update CBI-3
    % requires stimuli_mech_last AND stimuli_chem_last
    %{
    CBI3 is active IF
        MCC is on
        AND
        Mechanical Simulation at Lips
        AND
        Chemical Stimulation at Lips
        AND
        B4/B5 is NOT firing strongly
        AND
        CBI3 is NOT in a refractory period
    %}
    
    %CBI3 can experieince a refractory period following strong inhibition from B4/B5
    %check if a refractory period is occuring
%     if((B4B5_last>=2) && (CBI3_stimTime==0))
%        CBI3_stimTime = j;   
%        CBI3_refractory = 1;
%     end
%     if(CBI3_refractory && j<(CBI3_stimTime+CBI3_refractoryDuration))
%        CBI3_refractory = 1; 
%     else
%         CBI3_stimTime = 0;
%         CBI3_refractory = 0; 
%     end

%modified to only turn on refreactory after the strong stimulation
    if((B4B5_last>=2) && (CBI3_stimON==0))
       CBI3_stimON = j;   
       %CBI3_refractory = 1;
    end
    if ((CBI3_stimON ~=0) && (B4B5_last<2))
       CBI3_refractory = 1;
       CBI3_stimOFF = j;  
       CBI3_stimON = 0;    
    end 

    if(CBI3_refractory && j<(CBI3_stimOFF+CBI3_refractoryDuration))
       CBI3_refractory = 1; 
    else
        CBI3_stimOFF = 0;
        CBI3_refractory = 0; 
    end


    %CBI3 - updated 6/7/2020    
    %with hypothesized connections from B4/B5
%     avec(8,j+1) = MCC_last*(stimuli_mech_last*stimuli_chem_last)*((B4B5_last<2))*(~CBI3_refractory);   
    %without hypothesized connections from B4/B5  
    avec(8,j+1) = MCC_last*(stimuli_mech_last*stimuli_chem_last); 


    
    %% Update CBI4 - added 2/27/2020
    %{
    CBI4 is active IF � mediates swallowing and rejection
        MCC is on
        AND
            (Mechanical Stimulation at Lips
            OR
            Chemical Stimulation at Lips)
        AND
        Mechanical Stimulation in grasper
    %}
    avec(12,j+1) = MCC_last*(stimuli_mech_last||stimuli_chem_last)*mechanical_in_grasper;
    
    %% Update B64
    % list of inputs
    % Protraction threshold excites
    % grasper pressure excites - still figuring out how to implement
    % retraction threshold inhibits
    % B31/32 inhibits
    
    %If there is mechanical and chemical stimuli at the lips and there is
    %seaweed in the grasper -> swallow
    
    %If there is mechanical and chemical stimuli at the lips and there is
    %NOT seaweed in the grasper -> bite
    
    %If there is not chemical stimuli at the lips but there is mechanical
    %stimuli ->reject
    
    %{
    B64 is active IF
        MCC is on
        AND
        IF CBI3 is active (ingestion)
            IF mechanical stimulation is in grasper (swallowing)
                Relative Grasper Position is Greater than B64 Swallowing Protraction threshold
            IF mechanical stimulation is NOT in grasper (biting)
                Relative Grasper Position is Greater than B64 Biting Protraction threshold
        IF CBI3 is NOT active (rejection)
            Relative Grasper Position is Greater than B64 Rejection Protraction threshold
        AND
        B31/B32 is NOT active
        AND
        IF CBI3 is active (ingestion)
            IF mechanical stimulation is in grasper (swallowing)
                NOT (Relative Grasper Position is less than B64 Swallow Retraction threshold)
            IF mechanical stimulation is NOT in grasper (biting)
                NOT(Relative Grasper Position is less than B64 Biting Retraction threshold)
        IF CBI3 is NOT active (rejection)
            NOT(Relative Grasper Position is less than B64 Rejection Retraction threshold)
    %}
    
    B64_proprioception = (CBI3_last*(... % checks protraction threshold - original 0.5
                                    (  mechanical_in_grasper *(x_gh>B64_thresh_retract_swallowing))||...
                                    ((~mechanical_in_grasper)*(x_gh>B64_thresh_retract_biting))))...
                                ||...
                                ((~CBI3_last)                *(x_gh>B64_thresh_retract_reject));

    %B64
    avec(9,j+1)=MCC_last*(~B31B32_last)*... % update B64
        B64_proprioception;

    %% Update B4/B5: 
    %{
    B4/B5 is active IF
        MCC is ON
        AND
        IF stimulating electrode is off
            Strongly firing IF CBI3 is NOT active (rejection)
                AND
                B64 is active (retraction)
                AND
                Relative grasper position is greater than B4/B5 threshold (early retraction)
            weakly firing IF CBI3 is active (ingestion)
                AND
                B64 is active (retraction)
                AND
                mechanical stimulation is in grasper (swallowing)
        If stimulating electrode is on
            Activity is set to 2 to designate strong firing
    %}
    
    B4B5_electrode = cvec(4,j);
    
    %B4B5
    avec(3,j+1)=MCC_last*...
                ((~B4B5_electrode)*... % when B4/B5 electrode is off
                    (2*(~CBI3_last)*...% if egestion
                        B64_last*(x_gh>B4B5_threshold)) +... 
                    ((CBI3_last)*(mechanical_in_grasper)*B64_last))... % if swallowing
        +2*B4B5_electrode; % when B4/B5 electrode is on (and +1) then turn B4/B5 on to "emergency" mode
    
    %% Update B20 - updated 2/27/2020
    % Not active if CB1-3 is on (strongly inhibited)
    %excited by CBI2 but excitation is weaker than inhibition from CBI3
    %{
    (CBI2 is active
        OR	
        CBI4 is active
        OR
        B63 (B31/32) is active)
            AND
            CBI3 is NOT active
            AND
            B64 is NOT active
		
    %}
    avec(10,j+1) = MCC_last*((CBI2_last||CBI4_last)||B31B32_last)*(~CBI3_last)*(~B64_last);
    
   %% Update B40/B30
    %{
    B40/B30 is active IF
        MCC is ON
        AND
        (CBI2 is active
        OR 
        CBI4 is active
        OR 
        B63 (B31/32) is active)
        AND 
        B64 is not active
    %}
   
    % B30/B40 have a fast inhibitory and slow excitatory connection with
    % B8a/b. To accomodate this, we track when B30/B40 goes from a quiescent
    % state to a active state and vice versa after calculateing the new
    % value.
    
    avec(13,j+1) = MCC_last*((CBI2_last||CBI4_last)||B31B32_last)*(~B64_last);
    
    %check if B30/B40 has gone from quiescent to active
    if((B40B30_last ==0) && (avec(13,j+1)==1))
       B40B30_onTime = j;
    end
    %check if B30/B40 has gone from quiescent to active
    if((B40B30_last ==1) && (avec(13,j+1)==0))
       B40B30_offTime = j;
    end
    
    %% Update B31/B32: -updated 2/27/2020
    % activated if grasper retracted enough, inhibited if
    % pressure exceeds a threshold or grasper is protracted far enough
    %{
    B31/B32 is active IF
        MCC is ON
        AND
        IF CBI3 is active (ingestion)
            B64 is NOT active (protraction)
            AND
                Graper pressure is less than half of its maximum (open)
                OR
                CBI2 is active (biting)
            AND
            IF B31/B32 is NOT firing (switching to protraction)
                The relative grasper position is less than the retraction threshold
            IF B31/B32 is firing (protraction)
                The relative grasper position is less than the protraction threshold
        IF CBI3 is NOT active (rejection)
            B64 is NOT active (protraction)
            AND
            Grasper Pressure is greater than a quarter of the maximum (closing or closed)
            AND
                CBI2 is active
                OR
                CBI4 is active
            AND
            IF B31/B32 is NOT firing (switching to protraction)
                The relative grasper position is less than the retraction threshold
            IF B31/B32 is firing (protraction)
                The relative grasper position is less than the protraction threshold
    %}
    
    %B31/B32s thresholds may vary for different behaviors. These are set
    %here
    if (mechanical_in_grasper && CBI3_last) %swallowing
        prot_thresh = B31_thresh_protract_swallow;
        ret_thresh = B31_thresh_retract_swallow;
    elseif (mechanical_in_grasper && (~CBI3_last)) %rejection
        prot_thresh = B31_thresh_protract_reject;
        ret_thresh = B31_thresh_retract_reject;
    else %biting
        prot_thresh = B31_thresh_protract_bite;
        ret_thresh = B31_thresh_retract_bite;        
    end

    avec(4,j+1)=MCC_last*(...
        CBI3_last*... %if ingestion
            ((~B64_last)*((P_I4<(1/2))||CBI2_last)*... 
                ((~B31B32_last)*(x_gh<ret_thresh)+...
                   B31B32_last *(x_gh<prot_thresh)))+...
      (~CBI3_last)*... %if egestion
            ((~B64_last)*(P_I4>(1/4))*(CBI2_last||CBI4_last)*...
                ((~B31B32_last)*(x_gh<ret_thresh)+...
                   B31B32_last *(x_gh<prot_thresh))));
             
    %% Update B6/B9/B3: 
    % activate once pressure is high enough in ingestion, or low enough in
    % rejection
    %{
    OLD VERSION:
    B6/B9/B3 is active IF
        MCC is active
        AND
        IF CBI3 is active (ingestion)
            B64 is active (retraction)
            AND
            Grasper pressure is greater than B6/B3/B9 pressure threshold (closed)
        IF CBI3 is not active (rejection)
            B64 is active (retraction)
            AND
                B4/B5 is NOT active
                OR
                Relative grasper position is less than 0.7
            AND
            Grasper pressure is less than 0.75 of maximum (open)

    NEW VERSION:
    B6/B9/B3 is active IF
        MCC is active
        AND
        B4/B5 is NOT firing strongly
        AND
        IF CBI3 is active (ingestion)
            B64 is active (retraction)
            AND
            Grasper pressure is greater than B6/B3/B9 pressure threshold (closed)
        IF CBI3 is not active (rejection)
            B64 is active (retraction)
            AND
            Grasper pressure is less than B6/B3/B9 pressure threshold (open)
    %}

    %B6/B9/B3s thresholds may vary for different behaviors. These are set
    %here
    if (mechanical_in_grasper && CBI3_last)
        B6B9B3_pressure_thresh = B6B9B3_pressure_thresh_swallowing;
    elseif (~mechanical_in_grasper && CBI3_last)
        B6B9B3_pressure_thresh = B6B9B3_pressure_thresh_biting;
    else
        B6B9B3_pressure_thresh = B6B9B3_pressure_thresh_reject;
    end

    %B6/B9/B3
%     avec(5,j+1)=MCC_last*((CBI3_last)*... Ingestion / CBI3 active
%        (B64_last)*(GrapserPressure_last>(B6B9B3_pressure_thresh*pmax))...
%        +...
%        (~CBI3_last)*...Egestion / CBI3 inactive
%        ((B4B5_last>=2)||((position_grasper_relative)<0.7))*... 
%        (B64_last)*(GrapserPressure_last<(.75*pmax))); 

    avec(5,j+1)=MCC_last*(~(B4B5_last>=2))*(...
        (CBI3_last)*... Ingestion / CBI3 active
            (B64_last)*(P_I4>(B6B9B3_pressure_thresh))...
        +...
        (~CBI3_last)*...Egestion / CBI3 inactive
            (B64_last)*(P_I4<(B6B9B3_pressure_thresh)));

    
    %% Update B8a/b
    % active if excitation from B6/B9/B3 plus protracted
    % sensory feedback exceeds threshold of 1.9, and not inhibited by
    % either B31/B32 or by sensory feedback from being retracted. If B4/B5 is
    % highly excited (activation level is 2 instead of just 1) then shut
    % down B8a/b.
    %{
    B8a/b is active IF
        MCC is on
        AND
            B64 is active
            OR
            B40/B30 is NOT active
            OR
            B20 is active
        AND
        B4/B5 is not active
        AND
            B20 is active
            OR
            B31/B32 is NOT active
    %}
    
    %B8a/b recieves slow exitatory input from B30/B40 functionally this
    %causes strong firing immediatly following B30/B40 cessation in biting
    %and swallowing
    if(B40B30_last==0 && j<(B40B30_offTime+B40B30_postExcitationDuration))
       B40B30_excite = 1; 
    else
        B40B30_excite = 0; 
    end
    
    %B8a/b - updated 5/25/2020   
      avec(1,j+1)=MCC_last*(~(B4B5_last>=2))*(...%B4/5 inhibits when strongly active
        CBI3_last*(... % if ingestion
            B20_last||(B40B30_excite)*(~B31B32_last))+...
        (~CBI3_last)*(... % if rejection
            B20_last)); 
    
    %% Update B7 - ONLY ACTIVE DURING EGESTION and BITING
    % turn on as you get to peak protraction
    %in biting this has a threshold that it stops applying effective force -
    %biomechanics
    %{
    B7 is active IF
        (The relative position of the grasper is greater than the protraction threshold
        OR
        Grasper pressure is very high) (closed)
        AND
            CBI3 is NOT active (rejection)
            OR
            There is NOT mechanical stimulation in mouth (biting)
    %}
    if (mechanical_in_grasper && (~CBI3_last)) %rejection
        B7_thresh = B7_thresh_protract_reject;
    else %biting
        B7_thresh = B7_thresh_protract_biting;       
    end
    avec(11,j+1) = MCC_last*((~CBI3_last)||(~mechanical_in_grasper))*((x_gh>=B7_thresh)||(P_I4>(.97)));
      
    %% Update B38: 
    % If already active, remain active until protracted past
    % 0.5.  If inactive, become active if retracted to 0.1 or further. 
    %{
    B38 is active IF
        MCC is ON
        AND
        mechanical stimulation in the grasper (swallowing or rejection)
        AND
        IF CBI3 is active (ingestion)
            Relative grasper position is less than B38 ingestion threshold
        IF CBI3 is not active (rejection)
            Turn off B38
    %}
    
    %B38

    avec(2,j+1)=MCC_last*(mechanical_in_grasper)*(...
        (CBI3_last)*(... % if CBI3 active do the following:
            ((x_gh)<B38ingest_thresh)));
     
    %% Update Grasper state (open/closed): if B8a/b fires, grasper closes,
    % otherwise it opens.
    bvec(1,j+1)=B8ab_last>=1;
   
    %% Update pressure: If food present, and grasper closed, then approaches
    % pmax pressure as dp/dt=(B8*pmax-p)/tau_p.  Use a quasi-backward-Euler
    bvec(2,j+1)=((tau_p*P_I4+B8ab_last*dt)/(tau_p+dt));%old -- keep this version

    %% Update pinch force: If food present, and grasper closed, then approaches
    % pmax pressure as dp/dt=(B8*pmax-p)/tau_p.  Use a quasi-backward-Euler
    bvec(9,j+1)=(tau_pinch*P_I3_anterior+(B38_last+B6B9B3_last)*dt)/(tau_pinch+dt);
    
    %bvec(9,j+1)=(tau_pinch*force_pinch+bvec(16,j)*F_pinch*dt)/(tau_pinch+dt);
    %bvec(16,j+1)=(tau_pinch*bvec(16,j)+B38_last*dt)/(tau_pinch+dt);
    % PT suggestion: maybe also multiply by stimuli_mech_last, "positive mechanical
    % input"?
   
    %% Update I3 (retractor) activation: dm/dt=(B6-m)/tau_m
    bvec(3,j+1)=(tau_m*T_I3+dt*bvec(13,j))/(tau_m+dt);
    bvec(13,j+1)=(tau_m*bvec(13,j)+dt*B6B9B3_last)/(tau_m+dt);

    %% Update I2 (protractor) activation: dm/dt=(B31-m)/tau_m.  quasi-B-Eul.
    bvec(4,j+1)=((I2_tau_ingestion*CBI3_last+I2_tau_egestion*(1-CBI3_last))*tau_m*T_I2+dt*bvec(14,j))/((I2_tau_ingestion*CBI3_last+I2_tau_egestion*(1-CBI3_last))*tau_m+dt);
    bvec(14,j+1)=((I2_tau_ingestion*CBI3_last+I2_tau_egestion*(1-CBI3_last))*tau_m*bvec(14,j)+dt*B31B32_last)/((I2_tau_ingestion*CBI3_last+I2_tau_egestion*(1-CBI3_last))*tau_m+dt);

    %% Update state of anterior I3 pinch: if B38 is active and B4/B5 not
    % overactive, then pinch, otherwise release.
    bvec(5,j+1)=(B4B5_last<2)*B38_last;

    %% Update Hinge activation: dm/dt=(B7-m)/tau_m.  quasi-B-Eul.
    %bvec(12,j+1)=(tau_m*hinge_last+dt*B7_last)/(tau_m+dt);%old
    bvec(12,j+1)=(tau_m*T_Hi+dt*bvec(17,j))/(tau_m+dt);%new
    bvec(17,j+1)=(tau_m*bvec(17,j)+dt*B7_last)/(tau_m+dt);
    
    %% Update Grasper Pull (retractor) activation: dm/dt=(B8-m)/tau_m - not included in this model
    %bvec(11,j+1) = (tau_pull*GrasperPull_last+dt*B8ab_last)/(tau_pull+dt);%old
%    bvec(11,j+1) = (tau_pull*GrasperPull_last+dt*bvec(15,j))/(tau_pull+dt);%new
%    bvec(15,j+1) = (tau_pull*bvec(15,j)+dt*B8ab_last)/(tau_pull+dt);       
   
%% NEW biomechanics

%% Grasper Forces
%all forces in form F = Ax+b
    F_I2 = max_I2*T_I2*[1,-1]*[x_h;x_g] + max_I2*T_I2*1;
    F_I3 = max_I3*T_I3*[-1,1]*[x_h;x_g]-max_I3*T_I3*0;
    F_Hi = max_hinge*T_Hi*(x_gh>0.5)*[-1,1]*[x_h;x_g]-max_hinge*T_Hi*0.5;
    F_sp_g = K_g*[1,-1]*[x_h;x_g]+K_g*x_gh_ref;
    
    F_I4 = pmax*P_I4;
    F_I3_ant = pinch_max*P_I3_anterior*[1,-1]*[x_h;x_g]+pinch_max*P_I3_anterior*1;%: pinch force
    
    %calculate F_f for grasper
    if(object_type == 0) %object is not fixed to a contrained surface
        F_g = F_I2+F_sp_g-F_I3-F_Hi; %if the object is unconstrained it does not apply a resistive force back on the grasper. Therefore the force is just due to the muscles
        
        A2 = 1/c_g*(max_I2*T_I2*[1,-1]+K_g*[1,-1]-max_I3*T_I3*[-1,1]-max_hinge*T_Hi*(x_gh>0.5)*[-1,1]);
        B2 = 1/c_g*(max_I2*T_I2*1+K_g*x_gh_ref+max_I3*T_I3*0+max_hinge*T_Hi*0.5);
        
        A21 = A2(1);
        A22 = A2(2);
        
        %the force on the object is approximated based on the friction
        if(abs(F_I2+F_sp_g-F_I3-F_Hi) <= abs(mu_s_g*F_I4)) % static friction is true
            %disp('static')
            static=1;
            F_f_g = -mechanical_in_grasper*(F_I2+F_sp_g-F_I3-F_Hi);
            bvec(18,j+1) = 1;
        else
            %disp('kinetic')
            static=0;
            F_f_g = mechanical_in_grasper*mu_k_g*F_I4;
            %specify sign of friction force
            F_f_g = -(F_I2+F_sp_g-F_I3-F_Hi)/abs(F_I2+F_sp_g-F_I3-F_Hi)*F_f_g;
            bvec(18,j+1) = 0;
        end
        
    elseif (object_type == 1) %object is fixed to a contrained surface
        if(abs(F_I2+F_sp_g-F_I3-F_Hi) <= abs(mu_s_g*F_I4)) % static friction is true
            %disp('static')
            static=1;
            F_f_g = -mechanical_in_grasper*(F_I2+F_sp_g-F_I3-F_Hi);
            F_g = F_I2+F_sp_g-F_I3-F_Hi + F_f_g;
            bvec(18,j+1) = 1;
            
            %identify matrix components for semi-implicit integration
            A21 = 0;
            A22 = 0;
            B2 = 0;
        else
            %disp('kinetic')
            static=0;
            F_f_g = -sign(F_I2+F_sp_g-F_I3-F_Hi)*mechanical_in_grasper*mu_k_g*F_I4;
            %specify sign of friction force
            F_g = F_I2+F_sp_g-F_I3-F_Hi + F_f_g;
            bvec(18,j+1) = 0;
            

            %identify matrix components for semi-implicit integration
            A2 = 1/c_g*(max_I2*T_I2*[1,-1]+K_g*[1,-1]-max_I3*T_I3*[-1,1]-max_hinge*T_Hi*(x_gh>0.5)*[-1,1]);
            B2 = 1/c_g*(max_I2*T_I2*1+K_g*x_gh_ref+max_I3*T_I3*0+max_hinge*T_Hi*0.5+F_f_g);

            A21 = A2(1);
            A22 = A2(2);
        end
    end
    %[j*dt position_grasper_relative I2 F_sp I3 hinge GrapserPressure_last F_g]

%% Body Forces
%all forces in the form F = Ax+b
    F_sp_h = K_h*[-1,0]*[x_h;x_g]+x_h_ref*K_h;
    %all muscle forces are equal and opposite
    if(object_type == 0)     
        F_h = F_sp_h; %If the object is unconstrained it does not apply a force back on the head. Therefore the force is just due to the head spring.
        
        A1 = 1/c_b*K_h*[-1,0];
        B1 = 1/c_b*x_h_ref*K_h;
        
        A11 = A1(1);
        A12 = A1(2);
        
        if(abs(F_sp_h+F_f_g) <= abs(mu_s_h*F_I3_ant)) % static friction is true
            %disp('static2')
            F_f_h = -mechanical_in_grasper*(F_sp_h+F_f_g); %only calculate the force if an object is actually present
            bvec(19,j+1) = 1;
        else
            %disp('kinetic2')
            F_f_h = mechanical_in_grasper*mu_k_h*F_I3_ant; %only calculate the force if an object is actually present
            %specify sign of friction force
            F_f_h = -(F_sp_h+F_f_g)/abs(F_sp_h+F_f_g)*F_f_h;
            bvec(19,j+1) = 0;
        end
    elseif (object_type == 1)
        %calcuate friction due to jaws
        if(abs(F_sp_h+F_f_g) <= abs(mu_s_h*F_I3_ant)) % static friction is true
            %disp('static2')
            F_f_h = -mechanical_in_grasper*(F_sp_h+F_f_g); %only calculate the force if an object is actually present
            F_h = F_sp_h+F_f_g + F_f_h;
            bvec(19,j+1) = 1;
            
            A11 = 0;
            A12 = 0;
            B1 = 0;
        
        else
            %disp('kinetic2')
            F_f_h = -sign(F_sp_h+F_f_g)*mechanical_in_grasper*mu_k_h*F_I3_ant; %only calculate the force if an object is actually present
            %specify sign of friction force
            F_h = F_sp_h+F_f_g + F_f_h;
            
            bvec(19,j+1) = 0;
            
            if (bvec(18,j+1) == 1) %object is fixed and grasper is static  
            % F_f_g = -mechanical_in_grasper*(F_I2+F_sp_g-F_I3-F_Hi);
                A1 = 1/c_b*(K_h*[-1,0]+(-mechanical_in_grasper*(max_I2*T_I2*[1,-1]+K_g*[1,-1]-max_I3*T_I3*[-1,1]-max_hinge*T_Hi*(x_gh>0.5)*[-1,1]))...
                    -sign(F_sp_h+F_f_g)*mechanical_in_grasper*mu_k_h*pinch_max*P_I3_anterior*[1,-1]);
                B1 = 1/c_b*(x_h_ref*K_h+(-mechanical_in_grasper*(max_I2*T_I2*1+K_g*x_gh_ref+max_I3*T_I3*0+max_hinge*T_Hi*0.5))...
                    -sign(F_sp_h+F_f_g)*mechanical_in_grasper*mu_k_h*pinch_max*P_I3_anterior*1);
                
            else %both are kinetic
            %F_f_g = -sign(F_I2+F_sp_g-F_I3-F_Hi)*mechanical_in_grasper*mu_k_g*F_I4;
                A1 = 1/c_b*(K_h*[-1,0]-sign(F_sp_h+F_f_g)*mechanical_in_grasper*mu_k_h*pinch_max*P_I3_anterior*[1,-1]);
                B1 = 1/c_b*(x_h_ref*K_h-sign(F_I2+F_sp_g-F_I3-F_Hi)*mechanical_in_grasper*mu_k_g*F_I4...
                    -sign(F_sp_h+F_f_g)*mechanical_in_grasper*mu_k_h*pinch_max*P_I3_anterior*1);                
            end
            A11= A1(1);
            A12 = A1(2);
        end
    end
    %[position_buccal_last F_h F_sp I3 hinge force_pinch F_H]
    
 

%% calculate force on object
force_on_object = F_f_g+F_f_h;
bvec(20,j+1) = F_f_g;
bvec(21,j+1) = F_f_h;

%check if seaweek is broken
if (object_type ==1)
    if (force_on_object>seaweed_strength)
        unbroken = 0;
    end
    %check to see if a new cycle has started
    if (~unbroken && x_gh>0.8 && (P_I4>(.6)))
       unbroken = 1; 
    end
    bvec(7,j+1)= unbroken*force_on_object;
    
    %correct forces on bodies for broken seaweed
    if (~unbroken)       
        F_h = F_sp_h;
        F_g = F_I2+F_sp_g-F_I3-F_Hi; 
    end
else
    bvec(7,j+1)= force_on_object;
end
    
    
%% Integrate body motions
%uncomment to remove periphery
%F_g = 0;
%F_H = 0;

A = [A11,A12;A21,A22];
B = [B1;B2];

x_last = [x_h;x_g];

x_new = 1/(1-dt*trace(A))*((eye(2)+dt*[-A22,A12;A21,-A11])*x_last+dt*B);

bvec(6,j+1) = x_new(2); %x_g+F_g/c_g*dt;
bvec(8,j+1) = x_new(1); %x_h + F_h/c_b*dt;
%% OLD biomechanics
%     %% Update force exerted by grasper on seaweed --this doesn't seem quite right yet...
%     %- updated 6/11/2020
%     force_on_seaweed = mechanical_in_grasper*CBI3_last*...%ingestion
%         ((GrapserPressure_last<(.6*pmax))*(force_pinch)+...
%         (GrapserPressure_last>(.6*pmax))*(0-(buccalM_rest-position_buccal_last)*buccalM_K))+...
%         (~CBI3_last)*mechanical_in_grasper*(force_scaler*(-(buccalM_rest-position_buccal_last)*buccalM_K -... %egestion
%        max_I2*I2_last*(1-(position_grasper_relative))));
% 
%     %check if seaweek is broken
%     if (force_on_seaweed>seaweed_strength)
%         unbroken = 0;
%     end
%     %check to see if a new cycle has started
%     if (~unbroken && position_grasper_relative>0.8 && (GrapserPressure_last>(.6*pmax)))
%        unbroken = 1; 
%     end
%     bvec(7,j+1)= unbroken*force_on_seaweed;
%     
%     %% Update forces on buccal mass and update
% %     body_forces = CBI3_last*(... %if ingestion
% %         (((force_on_seaweed<=seaweed_strength)*PinchState_last*force_pinch*mechanical_in_grasper-...
% %          (~PinchState_last)*...
% %          (max_I3*I3_last*(0-(position_grasper_relative)))*(mechanical_in_grasper)*(force_on_seaweed<=seaweed_strength))+... %I3 moves body forward when the grasper is strongly grasping seaweed and the seaweed has not broken
% %          (buccalM_rest-position_buccal_last)*buccalM_K))+... 
% %          ((~CBI3_last)*(... %if egestion 
% %          (buccalM_rest-position_buccal_last)*buccalM_K)); %the ever present spring
% 
%     body_forces = CBI3_last*(... %if ingestion
%         (((force_on_seaweed<=seaweed_strength)*force_pinch*mechanical_in_grasper-...
%          (max_I3*I3_last*(0-(position_grasper_relative)))*(mechanical_in_grasper)*(force_on_seaweed<=seaweed_strength))+... %I3 moves body forward when the grasper is strongly grasping seaweed and the seaweed has not broken
%          (buccalM_rest-position_buccal_last)*buccalM_K))+... 
%          ((~CBI3_last)*(... %if egestion 
%          (buccalM_rest-position_buccal_last)*buccalM_K)); %the ever present spring
% 
%     bvec(8,j+1) = position_buccal_last + body_forces/tau_y*dt; %pinch force and integrate
%       
%     %% Update the position X of the grasper relative to ground. 
%     %When it is
%     %grasping the seaweed firmly it cannot move relative to the ground. When
%     %it is not grasping the seaweed its motion will be both because of
%     %muscle activity and the frame of teh buccal mass moving. ***This
%     %implementation likely still needs work.
% 
%     %ROPE ATTACHED TO WALL - Stationary when pulling but not when pushin
%     grasper_forces = ...
%        CBI3_last*mechanical_in_grasper*(... %if swallowing
%        (~((GrapserPressure_last>(.6*pmax))*(mechanical_in_grasper)*(force_on_seaweed<=seaweed_strength)))*... % AND grasper does not move if strongly holding seaweed that is in the grasper and seaweed has not broken
%        (body_forces +... %body forces
%        max_I3*I3_last*(0-(position_grasper_relative))+... %I3 force
%        max_I2*I2_last*(1-(position_grasper_relative))))+...
%        (~CBI3_last)*(body_forces +... %if rejection
%        max_I2*I2_last*(1-(position_grasper_relative))+... %I2 force   
%        (max_I3*I3_last*(0-(position_grasper_relative)))+... %I3 force
%        max_hinge*hinge_last*(position_grasper_relative>0.5)*(0.5-(position_grasper_relative)))+...%hinge force if in egestion
%        CBI3_last*(~mechanical_in_grasper)*... %if biting
%        (body_forces +... %body forces
%        max_I3*I3_last*(0-(position_grasper_relative))+... %I3 force
%        max_I2*I2_last*(1-(position_grasper_relative))+...
%        max_hinge*hinge_last*(position_grasper_relative>0.5)*(0.5-(position_grasper_relative))); 
% 
%     bvec(6,j+1) = position_grasper_last+...
%        grasper_forces/tau_x*dt;

    %% Update feel of seaweed
    bvec(10,j+1) = 1;

   %% Update Relative position of seaweed. - need to add this kinematically
   %cvec(1,j+1)=cvec(1,j);
   %if seaweed is firmly grasped then the motion is the same as that of the
   %grasper, otherwise it is the same as the body?
%    cvec(1,j+1) = (GrapserPressure_last>(.5*pmax))*(mechanical_in_grasper)*...
%        (cvec(1,j)+grasper_forces/tau_x*dt)+...
%        (GrapserPressure_last<(.5*pmax))*(mechanical_in_grasper)*...
%        (cvec(1,j)+body_forces/tau_y*dt);
   
   %% Update external load on seaweed - remains the same for the fixed seaweed tests
   cvec(2,j+1)=cvec(2,j);
   
end

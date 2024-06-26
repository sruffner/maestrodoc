function examplemdoc(f)
%EXAMPLEMDOC Sample Matlab function that uses MAESTRODOC() to create a JSON-formatted Maestro experiment document.
% EXAMPLEMDOC(F) constucts a JSON-formatted Maestro experiment document using the M-file function MAESTRODOC(), saving
% the document to the file path specified in the Matlab string argument F. It serves as an example which users can copy 
% and modify for their own purposes. It can also be used to test MAESTRODOC() functionality.
%
% 
% Scott Ruffner
% sruffner@srscicomp.com
%

% must be a single argument, a non-empty Matlab string
assert( (nargin == 1) && ischar(f) && isvector(f) && (~isempty(f)), 'examplemdoc:argchk', 'Arg F must be a string');

% open a brand-new document
maestrodoc('open', '');

% application settings =================================================================================================
% settings.xy = [width height depth delay dur fix? seed]
% settings.rmv = [width height depth bkgRGB syncSpotSz, syncFlashDur]
% settings.fix = [hAccuracy vAccuracy]
% settings.other = [fixDur rew1 rew2 ovride? varatio audiorew beep? vstabwin]
settings.xy = [400 300 600 10 1 0 12345];
settings.rmv = [390 290 450 hex2dec('00808080') 15 6];
settings.fix = [2.5 2.5];
settings.other = [2500 10 10 0 1 0 0 10];
maestrodoc('settings', settings);

% define one custom channel configuration ==============================================================================
chcfg.name = 'myChannels';
chcfg.channels = {
   'hgpos' 1 1 2000 0 'red';
   'vepos' 1 1 2000 0 'green';
   'hevel' 1 1 0 1 'magenta';
   'vevel' 1 1 0 1 'cyan';
   'fix1_hvel' 0 1 0 1 'white';
   'fix1_vvel' 0 1 0 1 'med gray';
   'di0' 1 1 -2000 0 'yellow';
};
maestrodoc('chancfg', chcfg);

% define some perturbation objects =====================================================================================
% pert = {name type dur p1 p2} or {name type dur p1 p2 p3}
maestrodoc('pert', {'sine_2Hz' 'sinusoid' 1000 500 0});
maestrodoc('pert', {'pulse_50_100' 'pulse train' 2000 0 50 100});
maestrodoc('pert', {'unif_2ms_0.5' 'uniform noise' 5000 2 0.5 12345});
maestrodoc('pert', {'gauss_5ms_1.0' 'gaussian noise' 5000 5 1.0 6789});

% define RMVideo dot-patch targets of various sizes with similar dot density, plus a fixation spot with flicker ========
% also include an RMVideo dot-patch target in two-color contrast mode ==================================================
maestrodoc('tgset', 'RMVDotPatches');
target.set = 'RMVDotPatches';
target.isxy = 0;
target.type = 'dotpatch';
for sz=2:2:20
  target.name = sprintf('rectpatch_%d', sz);
  target.params = {'ndots' 2*sz*sz 'dotsize' 2 'dim' [sz sz]};   % rely on defaults for all other parameters!!
  maestrodoc('target', target);
end;

target.type = 'spot';
target.name = 'fixPt';
target.params = {'dim' [0.1 0.1] 'flicker' [2 5 3]};
maestrodoc('target', target);

target.type = 'dotpatch';
target.name = 'twoColorPatch';
target.params = {'ndots' 500 'dotsize' 4 'dim' [10 10] 'rgbcon' hex2dec('00323232')};
maestrodoc('target', target);

% define RMVideo grating targets with 5 different spatial frequences and 5 different contrasts =========================
maestrodoc('tgset', 'RMVGratings');
target.set = 'RMVGratings';
target.isxy = 0;
target.type = 'grating';
for freq=[0.2 0.5 1.0 1.5 2.0]
   for con=[10 25 50 75 100]
      target.name = sprintf('grat_sf=%.1f_con=%d', freq, con);
      gratSpec = [hex2dec('00808080') (con*(2^16) + con*(2^8) + con) freq 0 0];
      target.params = {'aperture' 'oval' 'dim' [20 20] 'sigma' [3 3] 'oriadj' 1 'grat1' gratSpec};
      maestrodoc('target', target);
   end;
end;

% define trial set "assessRF" that presents dot-patch targets of 4 different sizes (2, 4, 8, 16 deg) at 25 different 
% locations. During each "test condition" (size, location), the dots pan left, right, up, and down for 100ms at a fixed
% speed of 10 deg/sec. Thus, each test condition consists of 4 100-ms segments. Four randomly selected test conditions
% per trial; 25 trials altogether. Each test condition is marked by a tagged segment. Throughout each trial, subject is
% expected to fixate on a central spot. Each trial begins with a random-duration segment during which fixation is 
% established.
% 21may2019: Added random reward withholding on reward pulse #1, disabled on reward pulse #2.
maestrodoc('trset', 'assessRF');

% set trial info that is the same for all of the trials in this set
trial.set = 'assessRF';
trial.params = {'chancfg' 'myChannels' 'startseg' 2 'rewWHVR' [2 10 0 1]};
trial.psgm = [];
trial.perts = {};
trial.tgts = {
   'RMVDotPatches/fixPt' 
   'RMVDotPatches/rectpatch_2' 
   'RMVDotPatches/rectpatch_4'
   'RMVDotPatches/rectpatch_8'
   'RMVDotPatches/rectpatch_16'
};

% the 100 different test conditions: 4 patch sizes x 25 different locations x=[-10:5:10], y=[-10:5:10]. We include the
% tag section label for each condition, in the form 'sz_at_(x,y)'.
i = 1;
tgtSizes = [2 4 8 16];
for sz = tgtSizes
   for x = [-10 -5 0 5 10]
      for y = [-10 -5 0 5 10]
         condition(i).x = x;
         condition(i).y = y;
         condition(i).sz = sz;
         condition(i).tag = sprintf('%d_at_(%d,%d)', sz, x, y);
         i = i+1;
      end;
   end;
end;

% random permutation of the integers 1:100 -- so we present a random sequence of the 100 test conditions across the
% 25 trials we will create (4 conditions per trial)
sequence = randperm(100);

% the first segment of all trials: random-duration segment during which fixation is established. Turn on the fixation
% target only at (0,0), no movement. All other targets off.
firstSeg.hdr = {'dur' [300 400] 'fix1' 1 'fixacc' [2.5 2.5] 'grace' 200};
firstSeg.traj = {{'on' 1} {} {} {} {}};

% common segment header for all other segments in a trial: 100ms dur, fix1 is always the 'fixPt' target, no grace
% period, and fixation window 2.5 deg square.
commonSegHdr = {'dur' [100 100] 'fix1' 1 'fixacc' [2.5 2.5]};

% construct the 25 trials
for i=1:25
   trial.name = sprintf('trial_%d', i);
   trial.segs = struct('hdr', {}, 'traj', {});
   trial.tags = {};
   
   trial.segs(1) = firstSeg;
   segIdx = 2;
   
   for j=1:4
      testCond = condition(sequence((i-1)*4 + j));
      
      % the tagged section spans the four segments during which test condition is presented
      trial.tags{j} = {testCond.tag segIdx segIdx+3};
      
      % which target will be used for this test condition? Only one test target is on per condition! We have to add 1
      % to account for the fixPt target, which is the first in the target list!
      tgtIndex = find(tgtSizes == testCond.sz) + 1;
      
      % implement test condition: move target absolutely to test location during first segment and drift dot pattern
      % 10deg/sec to the right (target window does not move). During remaining segments, drift dot pattern 10d/s to the
      % left, up, and down. Also turn on VStab for those segments, with "snap to eye" on first.
      seg.hdr = commonSegHdr;
      seg.traj = firstSeg.traj;
      seg.traj{tgtIndex} = {'on' 1 'abs' 1 'pos' [testCond.x testCond.y] 'patvel' [10 0]};
      trial.segs(segIdx) = seg;
      segIdx = segIdx + 1;
      
      seg.traj = firstSeg.traj;
      seg.traj{tgtIndex} = {'on' 1 'patvel' [10 180] 'vstab' 'hv' 'snap' 1};
      trial.segs(segIdx) = seg;
      segIdx = segIdx + 1;

      seg.traj = firstSeg.traj;
      seg.traj{tgtIndex} = {'on' 1 'patvel' [10 90] 'vstab' 'h'};
      trial.segs(segIdx) = seg;
      segIdx = segIdx + 1;

      seg.traj = firstSeg.traj;
      seg.traj{tgtIndex} = {'on' 1 'patvel' [10 270] 'vstab' 'v'};
      trial.segs(segIdx) = seg;
      segIdx = segIdx + 1;
   end;
   
   maestrodoc('trial', trial);
end;

% define XYScope 'opt center' targets of various sizes with density 2 dots per sq deg, plus a fixation spot ============
maestrodoc('tgset', 'XYDotPatches');
target.set = 'XYDotPatches';
target.isxy = 1;
target.type = 'optcenter';
for sz=2:2:20
  target.name = sprintf('xypatch_%d', sz);
  target.params = {'ndots' 2*sz*sz 'dim' [sz sz]};
  maestrodoc('target', target);
end;

target.type = 'rectdot';
target.name = 'fix';
target.params = {'ndots' 5 'dim' [1 0]};
maestrodoc('target', target);

% define a single trial set 'xytuning' comprised of 4 subsets of trials assessing direction and speed tuning over 4
% different RF sizes. Each subset is called "dirAndSpeedTune_szDeg", where "sz" is one of [4 8 16 20]. 32 test 
% conditions (4 speeds x 8 directions) are repeated 8 times each over the course of a single block of 32 trials (eight 
% conditions presented per trial). Each test condition pans a single segment. Between each test segment is a pause 
% segment during which the target remains on but does not move. The trials uses the "xypatch_sz" targets; the target 
% window does not move, only the target dot pattern. Throughout the trial a fixation target remains on at (-15, 0). The 
% test target is displayed at (0,0). Each trial begins with a random-duration segment during which fixation is
% established. Fixation must be maintained during the remainder of the trial. Each test condition is marked by a tagged 
% section that spans the test segment and the following pause. There are a total of 8*2 + 1 = 17 segments per trial.
maestrodoc('trset', 'xytuning');
trSubset.set = 'xytuning';
trSubset.name = '';
for sz=[4 8 16 20]
   trSubset.name = sprintf('dirAndSpeedTune_%dDeg', sz);
   maestrodoc('trsub', trSubset);

   % set trial info that is the same for all of the trials in this trial subset
   trial.set = trSubset.set;
   trial.subset = trSubset.name;
   trial.params = {'chancfg' 'myChannels' 'startseg' 2};
   trial.psgm = [];
   trial.perts = {};
   trial.tgts = {'XYDotPatches/fix' sprintf('XYDotPatches/xypatch_%d', sz)};
   
   % the 32 different test conditions: 4 speeds [4 8 16 32] deg/sec x 8 directions [0:45:315] deg.  We include the tag
   % section label for each condition, in the form 'Vd/s_Pdeg'.
   i = 1;
   for speed = [4 8 16 32]
      for dir = [0:45:315]
         condition(i).speed = speed;
         condition(i).dir = dir;
         condition(i).tag = sprintf('%dd/s_%ddeg', speed, dir);
         i = i+1;
      end;
   end;

   % concatenate 8 random permutation of the integers 1:32 -- so we present a random sequence of the 32 test conditions 
   % eight times across the 32 trials we will create (8 conditions per trial). This ensures the same condition is never
   % presented twice in the same trial, which would cause a problem because we use tagged sections to mark the test
   % conditions, and no two tagged sections in a trial can have the same label!
   sequence = [randperm(32) randperm(32) randperm(32) randperm(32) randperm(32) randperm(32) randperm(32) randperm(32)];

   % the first segment of all trials: random-duration segment during which fixation is established. Turn on the fixation
   % target only at (-15,0), no movement. The test target is off.
   firstSeg.hdr = {'dur' [600 800] 'fix1' 1 'fixacc' [2.5 2.5] 'grace' 400};
   firstSeg.traj = {{'on' 1 'abs' 1 'pos' [-15 0]} {}};

   % common segment header for all other segments in a trial: 100ms dur, fix1 is always the first target, no grace
   % period, and fixation window 2.5 deg square.
   commonSegHdr = {'dur' [100 100] 'fix1' 1 'fixacc' [2.5 2.5]};

   % construct the 32 trials
   for i=1:32
      trial.name = sprintf('trial_%dDeg_%d', sz, i);
      trial.segs = struct('hdr', {}, 'traj', {});
      trial.tags = {};
   
      trial.segs(1) = firstSeg;
      segIdx = 2;
   
      for j=1:8
         testCond = condition(sequence((i-1)*8 + j));
      
         % each test consist of a "test" and a "pause" segment -- corres. tagged section spans the two segments
         trial.tags{j} = {testCond.tag segIdx segIdx+1};
         
         % implement test condition: Target on. During "test" segment, test target's dot pattern drifts IAW test speed 
         % and direction. During subsequent "pause" segment, target is on but dots do not move. Target window never 
         % moves -- only the dot pattern. Fixation target remains on always and does not move from the position to which
         % it was set during the first trial segment.
         seg.hdr = commonSegHdr;
         seg.traj = {{'on' 1} {'on' 1 'patvel' [testCond.speed testCond.dir]}};
         trial.segs(segIdx) = seg;
         segIdx = segIdx + 1;
         
         seg.traj = {{'on' 1} {'on' 1}};
         trial.segs(segIdx) = seg;
         segIdx = segIdx + 1;
      end;
   
      maestrodoc('trial', trial);
   end;
   
end;


% close the document, saving it to the file path specified =============================================================
maestrodoc('close', f);
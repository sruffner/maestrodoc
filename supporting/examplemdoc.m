function examplemdoc(f)
%EXAMPLEMDOC Sample Matlab function that uses MAESTRODOC() to create a JSON-formatted Maestro experiment document.
% EXAMPLEMDOC(F) constucts a JSON-formatted Maestro experiment document using the M-file function MAESTRODOC(), saving
% the document to the file path specified in the Matlab string argument F. It serves as an example which users can copy 
% and modify for their own purposes. It can also be used to test MAESTRODOC() functionality.
%
% Scott Ruffner
% sruffner@srscicomp.com
%

% must be a single argument, a non-empty Matlab string
assert( (nargin == 1) && ischar(f) && isvector(f) && (~isempty(f)), 'examplemdoc:argchk', 'Arg F must be a string');

% open a brand-new document
maestrodoc('open', '');

% application settings =================================================================================================
% settings.rmv = [width height depth bkgRGB syncSpotSz, syncFlashDur]
% settings.fix = [hAccuracy vAccuracy]
% settings.other = [fixDur rew1 rew2 ovride? varatio audiorew beep? vstabwin]
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
target.type = 'dotpatch';
for sz=2:2:20
  target.name = sprintf('rectpatch_%d', sz);
  target.params = {'ndots' 2*sz*sz 'dotsize' 2 'dim' [sz sz]};   % rely on defaults for all other parameters!!
  maestrodoc('target', target);
end

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
target.type = 'grating';
for freq=[0.2 0.5 1.0 1.5 2.0]
   for con=[10 25 50 75 100]
      target.name = sprintf('grat_sf=%.1f_con=%d', freq, con);
      gratSpec = [hex2dec('00808080') (con*(2^16) + con*(2^8) + con) freq 0 0];
      target.params = {'aperture' 'oval' 'dim' [20 20] 'sigma' [3 3] 'oriadj' 1 'grat1' gratSpec};
      maestrodoc('target', target);
   end
end

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
      end
   end
end

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
   end
   
   maestrodoc('trial', trial);
end

% a target set with 3 uniform spot targets =============================================================================
maestrodoc('tgset', 'RMVSpots');
target.set = 'RMVSpots';
target.type = 'spot';

target.name = 'whiteDot';
target.params = {'dim' [0.05 0.05]};
maestrodoc('target', target);

target.name = 'greenCircle';
target.params = {'dim' [0.25 0.25] 'rgb' (0x0000ff00) 'aperture' 'oval'};
maestrodoc('target', target);

target.name = 'redOval';
target.params = {'dim' [0.25 0.5] 'rgb' (0x000000ff) 'aperture' 'oval'};
maestrodoc('target', target);

% the "miscellaneous" trial set contains the remaining trials defined below...
maestrodoc('trset', 'miscellaneous');

% trial "altHV": A made-up trial that tries out RVs to control segment duration and H/V target position.
trial.name = 'altHV';
trial.set = 'miscellaneous';
trial.params = {'rewpulses' [25 25]};
trial.perts = {};
trial.tags = {};
trial.segs = struct('hdr', {}, 'traj', {});

% we will use these targets and RVs in both the "altHV" and "selDurByFix" trials
trial.tgts = {
   'RMVSpots/whiteDot'
   'RMVSpots/greenCircle'
   'RMVSpots/redOval'
};
trial.rvs = {
   {'uniform', 2334, 500, 800}
   {'uniform', 0, 200, 400}
   {'function', 'x1 + 500'}
   {'normal', 9999, 10.0, 2.5, 9.0}
   {'function', '-x3'}
};


% first segment - subject must fixate on whiteDot with a grace period of 200ms. Dur will be governed by RV.
seg.hdr = {'dur' [200 200] 'fix1' 1 'fixacc' [4.3 4.3] 'grace' 200};
seg.traj = {{'on' 1} {} {} };
trial.segs(1) = seg;
% remaining segments are 500ms long, have all targets on. Subject continues to fixate on whiteSpot (no grace period).
seg.hdr = {'dur' [500 500] 'fix1' 1 'fixacc' [4.3 4.3] 'grace' 0};
seg.traj ={{'on' 1} {'on' 1} {'on' 1} };
trial.segs(2) = seg;
trial.segs(3) = seg;
trial.segs(4) = seg;
% use RVs to control duration of first segment and horiz or vert position of the greenCircle and redOval targets
trial.rvuse = {
   {1, 'mindur', 1, 0}
   {1, 'maxdur', 1, 0}
   {4, 'hpos', 2, 2}
   {5, 'hpos', 2, 3}
   {4, 'vpos', 3, 2}
   {5, 'vpos', 3, 3}
   {5, 'hpos', 4, 2}
   {4, 'hpos', 4, 3}
};
maestrodoc('trial', trial);

% trial "selDurByFix": A trial that uses the "selDurByFix" special feature. Four segments, second is special segment,
% mindur of following segment controlled by a uniform RV, and maxdur is set to 500ms longer using a function RV. In
% first segment, subject must fixate on whiteDot with 200ms grace period. For remaining segments, that target is off
% and the green and red targets are on. Reward Pulse 2 3x longer than reward pulse 1
trial.name = 'selDurByFix';
trial.params = {'rewpulses' [25 75] 'specialseg' 2 'specialop' 'selectDur'};
trial.segs = struct('hdr', {}, 'traj', {});

% initial fixation segment
seg.hdr = {'dur' [500 750] 'fix1' 1 'fixacc' [5 5] 'grace' 200};
seg.traj = {{'on' 1} {} {}};
trial.segs(1) = seg;
% the special segment - fix spot turned off; green and red targets turned on at (10,0) and (-10, 0). Subject must
% choose one of the targets during this 750ms segment.
seg.hdr = {'dur' [750 750] 'fix1' 2 'fix2' 3 'fixacc' [5 5] 'grace' 0};
seg.traj = {{'on' 0} {'on' 1 'pos' [10 0]} {'on' 1 'pos' [-10 0]}};
trial.segs(2) = seg;
% the subsequent segment - targets unchanged; min/max dur will be governed by RVs
seg.traj = {{'on' 0} {'on' 1 'pos' [0 0]} {'on' 1 'pos' [0 0]}};
trial.segs(3) = seg;
% last segment - targets unchanged, 300ms duration
seg.hdr = {'dur' [300 300] 'fix1' 2 'fix2' 3 'fixacc' [5 5] 'grace' 0};
seg.traj = {{'on' 0} {'on' 1} {'on' 1}};
trial.segs(4) = seg;
% min and max dur of segment following special segment is controlled by RVs
trial.rvuse = {
   {2, 'mindur', 3, 0}
   {3, 'maxdur', 3, 0}
};
maestrodoc('trial', trial);

% trial "findAndWait": A trial using the "findAndWait" special op. Two segments, special segment is the last. Same
% targets as "selDurByFix" trial. No RVs involved. In first seg, subject must fixate on "whiteDot" with 300ms grace
% period. In 5-sec special segment, "whiteDot" is off while the other two are on, with "greenCircle" designated as
% "Fix1" -- the correct target in a "findAndWait" trial. Grace period of 500ms indicates how long the animal must fixate
% either target to consider that target "chosen".
trial.name = 'findAndWait';
trial.params = {'rewpulses' [100 10] 'specialseg' 2 'specialop' 'findAndWait'};
trial.segs = struct('hdr', {}, 'traj', {});
trial.rvs = {};
trial.rvuse = {};

% initial fixation segment
seg.hdr = {'dur' [1000 1250] 'fix1' 1 'fixacc' [5 5] 'grace' 300};
seg.traj = {{'on' 1} {} {}};
trial.segs(1) = seg;
% the special segment - fix spot turned off; green and red targets turned on at (10,0) and (-10, 0). Subject chooses
% one of these by fixating on it for 'grace' millisecs. The "greenCircle" is "fix1", the correct target.
seg.hdr = {'dur' [5000 5000] 'fix1' 2 'fixacc' [5 5] 'grace' 500};
seg.traj = {{'on' 0} {'on' 1 'pos' [10 0]} {'on' 1 'pos' [-10 0]}};
trial.segs(2) = seg;
maestrodoc('trial', trial);

% define a set of identical dot patch targets to be used in "checkerboard" trial. (Maestro 5.0.2 increased max number
% of trial targets from 25 to 50.) Targets are named "square_i_j", with i=[0..6] and j=[0..6].
maestrodoc('tgset', 'CheckerBoardSet');
target.set = 'CheckerBoardSet';
target.type = 'dotpatch';
target.params = {'ndots' 50 'dotsize' 2 'dim' [5 5]};
for i=0:6
   for j=0:6
      target.name = sprintf('square_%d_%d', i, j);
      maestrodoc('target', target);
   end
end

% the "miscellaneous/checkerboard" trial: Lays out the 49 5deg-by-5deg targets in a 7x7 array with centers at (-15, -15)
% to (+15, +15) in 5 deg increments. Three segments. Targets are on and not moving in seg 0 and seg 2. Target patterns
% move in different directions/speeds in seg 1.
trial.name = 'checkerboard';
trial.set = 'miscellaneous';
trial.params = {'rewpulses' [50 50]};
trial.segs = struct('hdr', {}, 'traj', {});
trial.perts = {};
trial.tags = {};
trial.rvs = {};
trial.rvuse = {};

trial.tgts = cell(49, 1);
for i=0:6
   for j=0:6
      trial.tgts{i*7 + j + 1} = sprintf('CheckerBoardSet/square_%d_%d', i, j);
   end
end

% seg 0: All targets on and laid out in 7x7 array.
seg.hdr = {'dur' [1000 1000]};
seg.traj = cell(49, 1);
for i=0:6
   x = -15 + i*5;
   for j=0:6
      y = -15 + j*5;
      seg.traj{i*7+ j + 1} = {'on' 1 'abs' 1 'pos' [x y]};
   end
end
trial.segs(1) = seg;

% seg 1: Target patterns move in different directions
% NOTE use of round() to limit number of significant digits after decimal point. The JSON parser in Maestro cannot
% handle too many decimal digits.
seg.hdr = {'dur' [3000 3000]};
seg.traj = cell(49, 1);
for i=0:6
   x = -15 + i*5;
   for j=0:6
      y = -15 + j*5;
      seg.traj{i*7+ j + 1} = {'on' 1 'patvel' [round(sqrt(x*x + y*y), 6) round(atan2d(y, x), 6)]};
   end
end
trial.segs(2) = seg;

% seg 2: Targets still on but pattern stationary
seg.hdr = {'dur' [1000 1000]};
seg.traj = cell(49, 1);
for i=0:6
   for j=0:6
      seg.traj{i*7+ j + 1} = {'on' 1 'patvel' [0 0]};
   end
end
trial.segs(3) = seg;

maestrodoc('trial', trial);

% close the document, saving it to the file path specified =============================================================
maestrodoc('close', f);
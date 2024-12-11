function maestrodoc(op, arg)
%MAESTRODOC Utility function to facilitate creation of a JSON-formatted Maestro experiment document within Matlab.
% MAESTRODOC(op, arg) provides a mechanism by which Maestro users can automatically generate a Maestro experimental
% protocol, saved in a Javascript Objection Notation (JSON)-formatted file that can be opened in Maestro as an 
% "experiment document". It is intended for use in user-developed scripts to enable rapid and mistake-free generation of
% Maestro experiments.
%
% Maestro is a Windows application developed in the Lisberger laboratory to conduct a wide variety of behavioral
% and neurophysiological experiments focusing on certain aspects of the visual system. It provides real-time data 
% acquisition and stimulus control to meet the particular research needs of the laboratory, and it is specifically 
% tailored to the experimental apparatus employed there. For more information, go to 
% https://sites.google.com/a/srscicomp.com/maestro.
%
% The native experiment document read and written by Maestro itself is in a condensed, binary format the details of 
% which are handled by Microsoft-provided support code. MAESTRODOC does NOT save the experiment document in this format,
% but instead writes a JSON-formatted plain-text file with the extension ".jmx". Throughout this help guide, we will
% refer to the JSON-formatted Maestro experiment document as the "JMX document" for short. Maestro can import a JMX 
% document, but it cannot export one.
%
% IMPORTANT USAGE INFO:
% 1) MAESTRODOC relies on Java code to do its work. The JAR file HHMI-MS-MAESTRO.JAR must be on the Matlab Java
% classpath. You can call JAVACLASSPATH(P) on the Matlab command line, where P is the full pathname to a required JAR.
% More conveniently, include a JAVAADDPATH commands for the JAR file in your STARTUP.M file.
% 2) MAESTRODOC checks all input arguments for any illegal or out-of-range parameter values. It will throw an exception 
% if any such bad parameter value is found. Exceptions will also be thrown if an argument is incorrectly formatted. IT
% IS ESSENTIAL THAT YOU READ THIS HELP GUIDE THOROUGHLY AND WRITE YOUR SCRIPTS WITH CARE!!!
% 3) MAESTRODOC maintains a persistent variable behind the scenes: the Java object encapsulating the JMX document
% currently being created/edited. Thus, you can perform many operations on the document without having to reopen it each
% time. You can only operate on one JMX document at a time.
% 5) Some aspects of the native Maestro experiment document -- such as stimulus runs -- are not currently supported by 
% MAESTRODOC and the JMX document format.
% 6) As of v1.2.2, MAESTRODOC does not support the XYScope display or targets. The XYScope platform has not been
% supported since Maestro V4.0. The old predefined targets 'FIBER*' and 'REDLED*' are also no longer supported.
% 7) Support for specifying trial random variables was added in V1.2.2. Maestro 5.0.2 or later can process trial RV
% definitions in the JMX document; earlier versions of Maestro will simply ignore them.
% 8) As of v1.2.3, MAESTRODOC does not support use of the pulse stimulus generator module (PSGM) in a trial. The PSGM
% was conceptually designed but never built, and it no longer appears as an option in Maestro 5.0.2.
%
% REQUIRED INPUT ARGS: (While shown in capital letters, all argument and structure field names should be lowercase!!!!!)
% OP - [in] Character string holding the desired operation. The supported operations are described below.
% ARG - [in] The operation argument. Its nature and content vary with the operation, as described in detail below.
%
% USAGE:
%
% MAESTRODOC('open', FILEPATH): Create a new JMX document or open an existing one. Here FILEPATH is a character string 
% specifying the file-system path. If it is an empty string, a brand-new, empty document object is created. Otherwise, 
% the specified file is opened and parsed as an existing JMX document; the filename extension MUST be ".jmx". Operation
% fails, throwing Matlab exception, if: (1) a JMX document is already open; (2) the specified file does not exist, does 
% not end in ".jmx", or cannot be parsed as a JMX document.
%
%
% MAESTRODOC('close', SAVEFILEPATH): Close the JMX document that is currently open, optionally saving it. The JMX 
% document is saved only if SAVEFILEPATH is specified and can be created (existing file, if any, is overwritten); if 
% SAVEFILEPATH='', the in-memory JMX document is simply discarded. It is essential to close the document when you are
% done in order to save all the changes made since you opened it. Even if you do not save changes, you should still
% close the document, else you will leave a persistent object (in the private workspace of the function) lying around
% that potentially consumes a significant amount of heap space, hurting overall Matlab performance. Operation fails,
% throwing a Matlab exception, if file cannot be created or if an error occurs while writing the file. Regardless of
% success or failure, the current JMX document will be closed.
%
%
% MAESTRODOC('settings', S): Change the Maestro document application settings. Here S is a Matlab structure that must
% contain the following fields.
%
%    S.RMV: A numeric vector containing RMVideo display properties [W H D BKG SZ DUR], where:
%       -- W, H, D = width, height of visible display area in mm, and (perpendicular) distance from eye to screen center
%          in mm. All are integers restricted to [50..5000].
%       -- BKG = display background color packed into a 32-bit integer 0x00RRGGBB (byte 2 = red, byte 1 = green, 
%          byte 0 = blue. Uppermost byte ignored.
%       -- SZ = Spot size for RMVideo VSync flash feature, in mm. Integer restricted to [0..50]; 0 disables feature.
%       -- DUR = Flash duration for VSync flash, in # of video frames. Integer restricted to [1..9].
%
%    S.FIX: A numeric vector setting horizontal and vertical fixation accuracy [H V] in Continuous mode, in deg. H and V 
%       are floating-point values restricted to [0.1 .. 50].
%
%    S.OTHER: A numeric vector containing other fixation/reward-related properties [D P1 P2 OVRIDE? VARATIO AUDIOREW 
%       BEEP? VSTABWIN], where:
%       -- D = Fixation duration in ms for Continuous mode. Integer restricted to [100..10000].
%       -- P1,P2 = Reward pulse lengths in ms for Continuous mode. Integers restricted to [1..999].
%       -- OVRIDE? = Flag. If nonzero, reward pulse lengths P1,P2 override the same values specified in the individual
%          trial definitions. Rarely used.
%       -- VARATIO = The variable ratio for random withholding of rewards. Integer restricted to [1..10], where 1 
%          disables random withholding. Rarely used.
%       -- AUDIOREW = Duration of a tone played as an "audio reward", in ms. Integer restricted to [100..1000] or 0,
%          which disables the feature. Rarely used. 
%       -- BEEP? = Flag. If nonzero, a computer beep is sounded whenever a reward is delivered. 
%       -- VSTABWIN = Length of sliding-average window for velocity stabilization, in ms. Integer in [1..20].
%
% The operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (2) S is incorrectly 
% formatted; (3) any of the property values in S are invalid.
%
%
% MAESTRODOC('chancfg', CHCFG): Add a new channel configuration to the currently open JMX document, or replace an 
% existing one. In Maestro, a trial channel configuration tells the program which data signals should be recorded
% during that trial and which should be displayed in the Data Trace display. It also includes display offset, gain, and
% trace color for each signal. The channel configuration itself is a distinct Maestro object containing 38 channel 
% descriptions (16 analog, 16 digital, and six "computed" signals). It would be EXTREMELY tedious to specify a 
% description for every possible channel when you will typically only examine a small subset. You do NOT need to do so
% here -- just specify channel descriptions for the channels you care about!
% 
% CHCFG is a Matlab structure with two fields:
%
%    CHCFG.NAME: The object name. Like all Maestro object names, it can be up to 50 characters long and can include any 
%       ASCII alphanumeric character or any of the characters enclosed in quotes here: ".,_[]():;#@!$%*-+=<>?". No 
%       spaces are allowed. If the JMX document already contains a channel configuration with this name, it is replaced
%       accordingly. Otherwise, a new configuration is created.
%
%    CHCFG.CHANNELS: A Nx6 cell array holding N individual channel descriptions. If it is empty, you will create a
%       default channel configuration. Each row {CH REC? DSP? OFFSET GAIN COLOR} in the cell array describes one
%       channel, where:
%
%       CH = Channel name, a Matlab string. Recognized values (note alternate values in parentheses): analog input 
%           channels 'hgpos' ('ai0'), 'vepos' ('ai1'), 'hevel' ('ai2'), 'vevel' ('ai3'), 'htpos' ('ai4'), 'vtpos' 
%           ('ai5'), 'hhvel' ('ai6'), 'hhpos' ('ai7'), 'hdvel' ('ai8'), 'htpos2' ('ai9'), 'vtpos2' ('ai10'), 'vepos2'
%           ('ai11'), 'ai12', 'ai13', 'hgpos2' ('ai14'), 'spwav' ('ai15'); digital input channels 'di0' to 'di15'; and 
%           computed channels 'fix1_hvel', 'fix1_vvel', 'fix1_hpos', 'fix1_vpos', 'fix2_hvel', 'fix2_vvel'.
%       REC? = Record flag, a scalar. Channel recorded if nonzero. Ignored for digital and computed channels.
%       DSP? = Display flag, a scalar. Channel is displayed in Data Trace window if nonzero.
%       OFFSET = Display offset in mV, an integer restricted to [-90000..90000].
%       GAIN = Display gain, an integer restricted to [-5..5].
%       COLOR = Display trace color, a string: 'white', 'red', 'green', 'blue', 'yellow', 'magenta', 'cyan', 'dk green',
%          'orange', 'purple', 'pink', and 'med gray'.
%
% The operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (2) CHCFG is formatted
% incorrectly; (3) CHCFG.NAME is not a valid Maestro object name; (3) any channel description parameter is invalid.
%
%
% MAESTRODOC('pert', PERT): Add a new perturbation object to the currently open JMX document, or relace an existing one.
% In Maestro, a trial can include up to 4 different "velocity perturbation waveforms". The perturbation waveform itself 
% is a distinct Maestro object. Four types of perturbations are supported.
%
% PERT is a Matlab cell array defining the perturbation waveform object: {NAME, TYPE, DUR, P1, P2[, P3]}, where:
%
%    NAME = The pertubation waveform object name. Again, it can be up to 50 characters long and can include any ASCII
%       alphanumeric character or any of the characters enclosed in quotes here: ".,_[]():;#@!$%*-+=<>?". No spaces are
%       allowed. If the JMX document already contains a perturbation with this name, it is replaced accordingly. 
%       Otherwise, a new perturbation is created.
%    TYPE = 'sinusoid', 'pulse train', 'uniform noise', or 'gaussian noise'.
%    DUR = Perturbation duration in ms. Integer >= 10.
%    P1..P3 = Two or three additional parameters IAW the perturbation TYPE:
%       'sinusoid': P1 = period in ms, integer >= 10. P2 = phase in deg, integer in [-180..180]. 
%       'pulse train': P1 = ramp duration in ms, an integer >= 0. P2 = pulse duration in ms, integer >= 10. P3 = pulse 
%          interval in ms, an integer >= P2 + 2*P1.
%       'uniform noise': P1 = noise update interval in ms, an integer >= 1. P2 = mean level, a floating-pt value in
%          [-1.0 .. 1.0]. P3 = seed for random number generation, an integer in [-9999999 .. 10000000].
%       'gaussian noise': Same as for 'uniform noise'.
%
% The operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (1) PERT is formatted
% incorrectly; (2) the perturbation name is not a valid Maestro object name; (3) any other perturbation parameter value 
% is invalid.
%
%
% MAESTRODOC('tgset', NAME): Add a new target set to the currently open JMX document. NAME is a Matlab string containing
% the name for the new target set. It must satisfy the usual Maestro object naming rules. Operation fails, throwing a
% Matlab exception, if: (1) a JMX document is not currently open; (2) NAME is not a valid Maestro object name, or a
% target set with that name already exists; (3) NAME = 'Predefined', which is reserved in Maestro 2.x. While the
% 'Predefined' set no longer exists as of Maestro 3, it is still disallowed.
%
%
% MAESTRODOC('trset', NAME): Add a new trial set to the currently open JMX document. NAME is a Matlab string containing 
% the name for the new trial set. It must satisfy the usual Maestro object naming rules. Operation fails, throwing a 
% Matlab exception, if: (1) a JMX document is not currently open; (2) NAME is not a valid Maestro object name, or a 
% trial set with that name already exists.
%
%
% MAESTRODOC('trsub', S): Add a new, empty trial subset to the currently open JMX document. S is a Matlab structure 
% containing two fields:
%
%    S.SET: The name of the trial set in which the new subset should appear. The set must already exist.
%    S.NAME: The name assigned to the new trial subset. Must satisfy the usual Maestro object naming rules, and it must
%       not match the name of an existing trial or trial subset in the specified trial set.
%
% Operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (2) the parent trial set
% S.SET does not exist; (3) S.NAME is not a valid Maestro object name, or duplicates the name of any existing child in
% the parent trial set.
%
%
% MAESTRODOC('target', TGT): Add a new target definition to the currently open JMX document, or replace an existing one.
% A Maestro target describes a visual stimulus, and a trial defines how one or more such targets are animated. You can 
% create/edit RMVideo targets with this operation. TGT must be a Matlab structure with five fields:
%
%    TGT.SET: The name of the target set in which this target should appear. Target set must already exist.
%    TGT.NAME: The RMVideo target object name. Must follow the usual Maestro object naming rules. If the specified
%       target set already contains a target with this name, it is replaced accordingly. Otherwise, a new target is
%       created.
%    TGT.TYPE: A string defining the RMVideo target type. The type names are abbreviations of what you see in the
%       Maestro GUI: 'point', 'dotpatch', 'flowfield', 'bar', 'spot', 'grating', 'plaid', 'movie', 'image'.
%    TGT.PARAMS: Cell array containing a sequence of one or more ('param-name', param-value) pairs. Specify only those
%       parameters applicable to the target type. All unspecified parameters will be set to default values.
%
% Operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (3) TGT is incorrectly
% formatted; (2) TGT.SET does not identify an existing target set in the document; (3) TGT.NAME is not a valid Maestro 
% object name; (4) TGT.TYPE is not a recognized target type; (5) TGT.PARAMS contains a bad parameter name or an invalid
% parameter value.
%
% RMVideo target parameter names, allowed values, and default values. Below is the list of recognized target types 
% (TGT.TYPE) for the the RMVideo display, along with the names of the relevant parameters for that type. The default 
% value assigned to a parameter (if it is not explicitly specified in TGT.PARAMS) is listed in parentheses after the
% parameter name. Again, note that some parameters are really arrays of several related parameter values which are 
% almost always specified together. The parameter descriptions follow.
%    'point'      : 'dotsize' (1), 'rgb' (0x00ffffff), 'flicker' ([0 0 0]), 'disparity' (0)
%    'dotpatch'   : 'dotsize' (1), 'rgb' (0x00ffffff), 'rgbcon' (0x00000000), 'ndots' (100), 'aperture' ('rect'), 
%                   'dim' ([10 10 5 5]), 'sigma' ([0 0]), 'seed' (0), 'pct' (100), 'dotlf' [1 0], 'noise' [0 0 100 0], 
%                   'wrtscreen' (0), 'flicker' ([0 0 0]), 'disparity' (0)
%    'flowfield'  : 'dotsize' (1), 'rgb' (0x00ffffff), 'ndots' (100), 'dim' ([30 0.5]), 'seed' (0), 'flicker' ([0 0 0]),
%                   'disparity' (0)
%    'bar'        : 'rgb' (0x00ffffff), 'dim' ([10 10 0]), 'flicker' ([0 0 0])
%    'spot'       : 'rgb' (0x00ffffff), 'aperture' ('rect'), 'dim' ([10 10 5 5]), 'sigma' ([0 0]), 'flicker' ([0 0 0])
%    'grating'    : 'aperture' ('rect'), 'dim' ([10 10]), 'sigma' ([0 0]), 'square' (0), 'oriadj' (0),
%                   'grat1' ([0x00808080 0x00646464 1.0 0 0]), 'flicker' ([0 0 0])
%    'plaid'      : 'aperture' ('rect'), 'dim' ([10 10]), 'sigma' ([0 0]), 'square' (0), 'oriadj' (0), 'indep' (0),
%                   'grat1' ([0x00808080 0x00646464 1.0 0 0]), 'grat2' ([0x00808080 0x00646464 1.0 0 0]), 
%                   'flicker' ([0 0 0])
%    'movie'      : 'folder' ('folderName'), 'file' ('fileName'), 'flags' ([0 0 0]), 'flicker' ([0 0 0])
%    'image'      : 'folder' ('folderName'), 'file' ('fileName'), 'flicker' ([0 0 0])
%
%    'dotsize': Dot size in pixels. Integer restricted to [1..25].
%    'rgb': Target color packed into a 32-bit integer 0x00BBGGRR (byte 2 = blue, byte 1 = green, byte 0 = red).
%    'rgbcon' : RGB contrast for 'dotpatch' target two-color contrast mode. Same format as 'rgb'. If any color
%      component is non-zero, then half the dots will be one color and half another color -- as described in the
%      Maestro online guide.
%    'ndots': Number of dots. Integer restricted to [0..9999].
%    'aperture': Target aperture shape. Recognized values: 'rect' (or 'rectangular'), 'oval' (or 'elliptical'), 
%       'rectannu' (or 'rectangular annulus'), 'ovalannu' (or 'elliptical annulus'). For 'grating' and 'plaid' targets, 
%       only the first two are allowed.
%    'dim': Target window dimensions in deg. This is an array of 2-4 elements, depending on the target type: [w h daxis]
%       for 'bar', [or ir] for 'flowfield', [w h] for 'grating' and 'plaid', and [w h] or [w h iw ih] for 'dotpatch'
%       and 'spot'. Extra elements are ignored.  Missing elements generate a Matlab exception!
%       -- w = target window width in deg, range-restricted to [0.01 .. 120.0], [0.0 ..120.0] for 'bar' target.
%       -- h = target window height in deg, range-restricted to [0.01 .. 120.0].
%       -- iw = target hole width in deg for annular apertures, restricted to [0.01 .. 120.0]. Also, iw < w.
%       -- ih = target hole height in deg for annular apertures, restricted to [0.01 .. 120.0]. Also, ih < h.
%       -- daxis = Drift axis of 'bar' target in deg CCW from +x-axis, restricted to [0.0 .. 360.0).
%       -- or,ir = Outer and inner radii for optic flow field, in deg, restricted to [0.01 .. 120.0]. Also ir < or.
%    'sigma': [xs ys], the X- and Y-standard deviations of Gaussian window masking target, in deg. xs >= 0 and ys >=0,
%       floating-pt values. A value of 0 disables Gaussian windowing in that direction.
%    'seed': Initial seed for random-number generator that randomizes dot locations for 'dotpatch' and 'flowfield', and
%       for a second RNG for dot direction or speed noise generation.
%    'pct': Percent coherence. Integer restricted to [0..100].
%    'dotlf': Finite dotlife target parameters, a 2-element array [lifeinms maxlife]. 
%       -- lifeinms = Flag selecting dot lifetime units: milliseconds (nonzero) or deg travelled (zero).
%       -- maxlife = Maximum dot lifetime, in ms or deg. Must be >= 0.0. 0 disables the finite dotlife feature.
%    'noise': Dot noise parameters for 'dotpatch' target, [dir? mult? rng intv], where:
%       -- dir? : Nonzero for dot direction noise, zero dot speed noise.
%       -- mult? : Nonzero for multiplicative speed noise algorithm, zero for additive speed noise.
%       -- rng : Dot noise range limit. Integer restricted to [0..180] for directional noise, [0..300] for additive
%        speed noise, and [1..7] for multiplicative speed noise.
%       -- intv : Noise update interval in ms, integer >= 0. A value of 0 disables dot noise.
%    'wrtscreen': Scalar flag. Nonzero => Target dot pattern motion as specified in trial is WRT the global screen
%       frame of reference; zero => pattern motion is WRT target window frame of reference. 
%    'square': Scalar flag. Nonzero => squarewave grating waveform; 0 => sinewave grating waveform.
%    'oriadj': Scalar flag indicates whether or not grating orientation adjusts during a trial so that it is always
%       perpendicular to the direction of motion. Nonzero = true; zero = false. 
%    'indep': "Independent Gratings?" flag. If set (nonzero), the gratings move independently rather than as a unified
%        unified plaid pattern. This flag and 'oriadj' are mutually exclusive. If 'oriadj' is set, this flag is cleared.
%    'grat1', 'grat2': Grating component parameters for the 'grating' and 'plaid' targets. Each is a five-element array
%        [mean con sfrq sphase daxis], where:
%       -- mean = Mean RGB grating color, specified in same manner as the 'rgb' parameter.
%       -- con = RGB grating contrast, with the R,G,B components packed into a single 32-bit integer 0x00BBGGRR, where
%          each byte value is restricted to [0..100], the contrast percentage for that color component.
%       -- sfrq = spatial frequency in cycles/deg. Must be >= 0.01. (Practical upper and lower limits are determined 
%          by RMVideo monitor capabilities and are not enforced here.) 
%       -- sphase = initial spatial phase in deg. Range-restricted to [0.0 .. 360.0).
%       -- daxis = drift axis in deg CCW from +x-axis. Range-restricted to [-180.0 .. 180.0].
%    'folder': Matlab string holding name of folder in RMVideo media store containing the movie file. 1-30 characters in
%       length. Only ASCII alphanumeric characters, the period, or underscore are allowed.
%    'file': Matlab string holding media file name. Same constraints as on 'folder'.
%    'flags': Set of three integer flags [rep? pause? dsprate?] for the 'movie' target:
%       -- rep? : If set (nonzero), movie plays back repeatedly until trial ends; else, single playback.
%       -- pause?: If set (nonzero), movie is paused when it is turned off during a trial; else it is never paused.
%       -- dsprate?: If set (nonzero), movie is played at the display frame rate. Otherwise, it is displayed at the
%          frame rate specified in the movie file.
%    'flicker': Target flicker paramers, a 3-element array of integers [on off delay] specifying the duration of the 
%       "on" and "off" phases of the target flicker cycle, as well as an initial delay preceding the first "on" phase.
%       Units are number of RMVideo frame periods, range-restricted to [0..99]. If on=0 or off=0, target flicker is
%       disabled.
%    'disparity': Stereo dot disparity in visual degrees, for the 'point', 'dotpatch', or 'flowfield' targets. Must be
%       non-negative.
%    
%
% MAESTRODOC('trial', TRIAL): Add a new trial definition to the currently open JMX document, or replace an existing one.
% A Maestro trial describes the animation of one or more targets over time and is, by far, the most complex object in a 
% JMX document. Its definition depends on other objects -- a channel configuration, one or more targets, and (possibly) 
% perturbations. All such objects are identified by name, and this operation will fail if any of them do not exist in 
% the JMX document. TRIAL must be a Matlab structure containing 7 required and 3 optional fields:
%
% NOTE: We use Matlab convention of 1-based indexing of arrays for specifying target and segment indices. Thus, for
% example, valid segment indices are [1..#segs], where #segs = length(TRIAL.SEGS);
%
%    TRIAL.SET: The name of the trial set in which this trial should appear. The trial set must already exist.
% 
%    TRIAL.SUBSET: [Optional] The name of the trial subset in which this trial should appear. If specified, then the
%       identified trial subset must already exist as a child of the trial identified by TRIAL.SET, and the trial is
%       added as a child of this subset. If not specified, then the trial will be a direct child of TRIAL.SET.
%
%    TRIAL.NAME: The trial name. Must follow the usual Maestro object naming rules. If the specified trial set (or 
%       subset) already contains a trial with this name, it is replaced accordingly. Otherwise, a new trial is created.
%
%    TRIAL.PARAMS: General trial parameters. Cell array holding a sequence of zero or more ('param-name', param-value)
%       pairs. There is no need to specify a value for every parameter listed here; most are rarely used. Only specify
%       those for which the default value is not satisfactory. In fact, if ALL default values are acceptable, then just
%       set TRIAL.PARAMS = {}.
%       
%       'chancfg': Name of the channel configuration applicable to this trial. If specified, it must exist in JMX 
%          document. Default = 'default'. The 'default' configuration always exists because it is predefined when you
%          open a brand-new experiment document in Maestro.
%       'wt': Trial weight governing frequency of presentation in a "Randomized" sequence. An integer range-restricted
%          to [0..255]. Default = 1.
%       'keep': Save (nonzero) or discard (zero) data recorded during trial. Default = 1.
%       'startseg': Turn on data recording at the beginning of this segment. Integer in [0..#segs]. If 0, the entire 
%          trial is recorded. Default = 0.
%       'failsafeseg': If trial cut short because subject broke fixation, data is still saved trial reached the start of
%          this segment. Integer in [0..#segs], where 0 => trial must finish. Default = 0.
%       'specialop': Special feature. Recognized values: 'none', 'skip', 'selbyfix', 'selbyfix2', 'switchfix', 
%          'rpdistro', 'choosefix1', 'choosefix2', 'search', 'selectDur', 'findAndWait'. See Maestro Users Guide for a
%          full description. Default = 'none'.
%       'specialseg': Index of segment during which special feature operation occurs. Ignored if 'specialop'=='none'.
%          Integer in [1..#segs]. Default = 1.
%       'saccvt': Saccade threshold velocity in deg/sec for saccade-triggered special features. Integer value 
%          range-restricted to [0..999]. Default = 100.
%       'marksegs': Display marker segments, [M1 M2]. If either element is a valid segment index in [1..#segs], a marker
%          is drawn in the Maestro data trace window at the starting time for that segment. Default = [0 0].
%       'mtr': Mid-trial reward feature. Parameter value is a three-element array [M L D], where M is the mode (0 = 
%          periodic, delivered at regular intervals; nonzero = delivered at the end of each segment for which mid-trial
%          rewards are enabled), L = reward pulse length in milliseconds (integer, range [1..999], and D = reward pulse 
%          interval in milliseconds, for periodic mode only (integer, range [100..9999]). Default = [0 10 1000].
%       'rewpulses': Lengths of end-of-trial reward pulses, [P1 P2]. The second reward pulse only applies to the special
%          operations that involve the subject selecting one of two fixation targets. Each pulse length is an integer
%          range-restricted to [1..999]. Default = [10 10].
%       'rewWHVR': Random reward withholding variable ratio N/D for the two reward pulses, [N1 D1 N2 D2], where integers
%          (Nm, Dm) must satisfy 0 <= Nm < Dm <= 100. Out of every Dm reps of the trial, the reward will be withheld in 
%          a randomly selected Nm reps. Default = [0 1 0 1], which disables withholding for both pulses.
%       'stair': Staircase sequencing parameters [N S I]. N = the staircase number, an integer in [0..5], where 0 means
%          that trial is NOT part of a staircase sequence. S = the staircase strength value assigned to the trial, 
%          a floating-point value restricted to [0..1000). I = the correct-response input channel (zero = AI12 and
%          nonzero = AI13). Default = [0 1.0 0] (NOT a staircase trial).
%
%    TRIAL.PERTS: List of perturbations participating in trial, with control parameters. This must be an cell vector of
%       up to four cell vectors of the form {NAME, A, S, T, C}, where:
%
%       NAME = the name of the perturbation waveform. It must exist in the JMX document, or the operation fails.
%       A = Perturbation amplitude, range-restricted to +/-999.99.
%       S = Index of segment at which perturbation starts. Must be a valid segment index in [1..#segs].
%       T = Index of affected target. Must be a valid index into the participating target list, [1..#tgts].
%       C = Affected trajectory component. Must be one of: 'winH', 'winV', 'patH', 'patV', 'winDir', 'patDir', 'winSpd',
%          'patSpd', 'speed', or 'direc'. 
%
%       Perturbations are rarely used. If the trial includes no perturbations, simply set TRIAL.PERTS = {}.
%
%    TRIAL.TGTS: Trial target list, a NON-EMPTY cell array of strings, each identifying a target participating in the 
%       trial. The targets will appear in the trial segment table in the order listed. Each entry in the array must have
%       the form 'setName/tgtName', where 'setName' is the name of an EXISTING target set in the JMX document and 
%       'tgtName' is the name of an EXISTING target within that set. Note that the forward slash ('/') separating the 
%       name tokens is not a valid character in a Maestro object name. 
%
%       It is also possible to specify the predefined 'CHAIR' target, which has no containing target set. Note that the
%       old 'FIBER*' and 'REDLED*' predefined targets are not supported since Maestro 4 and are no longer supported by
%       maestrodoc().
%
%    TRIAL.TAGS: List of tagged sections in the trials segment table. A "tagged section" attaches a label to a single
%       segment in the trial, or a contiguous span of segments. It is characterized by a label string and the indices of
%       the first and last segments in the section. If there are no tagged sections, simply set TRIAL.TAGS = {}. 
%       Otherwise, it should be a cell array of cell arrays of the form {LABEL, START, END}, where:
%
%       LABEL = The section tag. It must contain 1-17 characters. No restriction on character content.
%       START = Index of the first segment in the section. Must be a valid segment index in [1..#segs].
%       END = Index of last segment in the section. Must be a valid segment index >= START.
%
%       No two tagged sections can have the same label, and the defined sections cannot overlap. If either of these
%       rules are violated, the operation fails.
%
%    TRIAL.RVS : [Optional] A cell array of 0 to 10 cell arrays, where the i-th cell array defines the i-th random
%      variable, which are labelled "x0" to "x9" in Maestro. Each cell array must have one of the following forms:
%         {'uniform', seed, A, B} : A uniform distribution over the interval [A, B], where A < B.
%         {'normal', seed, M, D, S} : A normal distribution with mean M, standard deviation D > 0, and a maximum spread
%            S >= 3*D. During trial sequencing, any time a generated value falls outside [M-S, M+S], that value is
%            rejected and another generated in its place.
%         {'exponential', seed, L, S} : An exponential distribution with rate L > 0 and maximum spread S >= 3/L.
%         {'gamma', seed, K, T, S} : A gamma distribution with shape parameter K > 0, scale parameter T > 0, and a
%            maximum spread S. The mean is KT and variance KT^2. The spread S must be at least 3 standard deviations
%            beyond the mean, ie, S >= T*(K + 3*sqrt(K)).
%      For all of the above distributions, the nonnegative integer seed parameter initializes the random number
%      generator each time trial sequencing begins. If 0, then a different seed is chosen for each trial sequence.
%         {'function', formula} : An RV expressed as a function of one or more other RVs. An RV is referenced in the
%            formula string by its variable name, "x0" to "x9" ("x0" corresponds to the 1st cell array in TRIAL.RVS,
%            etc). In addition to these variables, the formula can contain integer or floating-point numeric constants;
%            the named constant "pi"; the four standard arithmetic binary operators -, +, *, /; the unary - operator
%            (as in "-2*x1"); left and right parentheses for grouping; and three named mathematical functions - sin(a),
%            cos(a), and pow(a,b). Note that the pow() function includes a comma operator to separate its two arguments.
%            Standard operator precedence rules are observed. It is an ERROR for a function RV to depend on itself, on
%            another function RV, or on an RV that was not defined in TRIAL.RVs.
%       *** NOTE: Be careful to make sure the formula string is valid, as maestrodoc() does not currently validate
%       function RVs. That will happen when the JMX document is imported by Maestro.
%
%    TRIAL.RVUSE : [Optional] A cell array, possibly empty, indicating what trial segment parameters are governed
%       by the trial random variables. Each element of the array must have the form {rvIdx, 'paramName', segIdx, tgIdx},
%       where rvIdx is the 1-based index of a random variable defined in TRIAL.RVS, segIdx is the 1-based index of the
%       affected segment, tgIdx is the 1-based index of the affected target trajectory parameter, and 'paramName'
%       identifies the affected parameter:
%           'mindur', 'maxdur' : Minimum or maximum segment duration. (tgIdx ignored in this case)
%           'hpos', 'vpos' : Horizontal or vertical target position.
%           'hvel', 'vvel', 'hacc', 'vacc': Horizontal or vertical target velocity or acceleration.
%           'hpatvel', 'vpatvel': Horizontal or vertical target pattern valocity.
%           'hpatacc', 'vpatacc': Horizontal or vertical target pattern acceleration.
%       Note that any defined RV can control the value of more than one segment parameter.
%
%    TRIAL.SEGS: The trials segment table. This is a NON-EMPTY structure array with fields HDR and TRAJ, as described
%       below. Number of structures in the array is the number of segments in the trial.
%
%       HDR: The segment header, which is the list of parameters shown in the top six rows of the segment table in
%       Maestro. The header is specified, once again, as a cell array of zero or more ('param-name', param-value) pairs.
%       There is no need to specify a value for every parameter listed here; only specify those for which the default
%       value is not correct.
%
%          'dur': The segment duration range in milliseconds, [D1 D2], where integers 0 <= D1 <= D2. When D1 < D2, the 
%             actual segment duration is randomized within the specified range. Default = [1000 1000].
%          'rmvsync': Enable the RMVideo VSync spot flash during the first frame marking the start of the trial segment.
%             Nonzero = enable. Default = 0 (disabled).
%          'fix1': Index of the first fixation target for this segment. Must be 0 ("NONE") or a valid index
%             into the list of participating targets, [1..#tgts]. Default = 0.
%          'fix2': Similarly for the second fixation target. Default = 0.
%          'fixacc': Horizontal and vertical fixation accuracy [H V] in degrees. Each must be >=0.1. Default= [5.0 5.0].
%          'grace': Grace period in ms for this segment. Integer >= 0. Default = 0.
%          'mtrena': Enable mid-trial reward feature for this segment? Nonzero = enable. Default = 0 (disabled).
%          'chkrsp': Enable checking for correct/incorrect response from subject during this segment. Applicable to
%             staircase trials only. Nonzero = enable. Default = 0 (disabled).
%          'marker': Digital output channel number for a marker pulse delivered at the start of this segment. Integer 
%             value restricted to [0..10]; 0 = no marker, 1..10 selects DO1 - DO10, respectively. Default = 0.
%             
%      TRAJ: A cell array of M cell arrays defining the trajectories of the M participating targets during this segment
%      of the trial. Each of the M cell arrays is, again, a cell array of ('param-name', param-value) pairs. Each
%      trajectory parameter has a default value; only supply a trajectory parameter value if it is different from the
%      default. If all parameters should be set to the defaults for target T, then SEG.TRAJ{T} = {}.
%
%         'on': Target ON (nonzero) or OFF (zero). Default = 0 (OFF).
%         'abs': Target position specified ABSolutely (nonzero) or RELative to last position (zero). Default = 0 (REL).
%         'vstab': Target velocity stabilization mode: 'none', 'h', 'v', 'hv'. Default = 'none'.
%         'snap': Velocity stabilization "snap to eye" flag: Enabled (nonzero) or disabled (0). Default = 0.
%         'pos': Target horizontal and vertical position in deg, [H V]. Default = [0 0].
%         'vel': Target window vector velocity specified as [MAG DIR], where MAG is the vector magniture and DIR is the 
%            vector direction in deg counterclockwise from +X-axis. Note that this representation is different from what 
%            appears in Maestro -- the horizontal and vertical components of the vector velocity. Maestro handles the
%            conversion when the JMX document is imported. If MAG=0, DIR=0. Default = [0 0].
%         'acc': Target window vector acceleration specified in the same manner as 'vel'. Default = [0 0].
%         'patvel': Target pattern vector velocity specified in the same manner as 'vel'. Default = [0 0].
%         'patacc': Target pattern vector acceleration specified in the same manner as 'vel'. Default = [0 0].
%
%      There are a couple special cases in which the 'patvel' and 'patacc' variables must be treated differently.
%         (1) If the target is an optic flow field, there is no pattern velocity velocity -- there
%      is just a "flow velocity" (positive or negative). In this case, DIR is ignored and MAG is taken as the flow 
%      velocity (for 'patacc', DIR is ignored and MAG is taken as the flow acceleration).
%         (2) For an RMVideo 'grating' target with the 'oriadj' flag cleared, DIR is ignored and MAG is taken as the
%      gratings drift velocity (for 'patvel') or drift acceleration (for 'patacc').
%         (3) For an RMVideo 'plaid' target with the 'indep' flag set, the component gratings move independently, not as
%      a cohesive pattern. In this case, DIR is taken as the drift velocity (for 'patvel') or acceleration (for 
%      'patacc') of the first component grating, while MAG is taken as the drift velocity or acceleration of the second
%      component.
%
% Operation fails, throwing a Matlab exception, if: (1) a JMX document is not currently open; (3) TRIAL is incorrectly
% formatted; (2) TRIAL.SET does not identify an existing trial set in the document; (2a) optional field TRIAL.SUBSET is
% defined, yet does not identify an existing trial subset within the set specified by TRIAL.SET; (3) TRIAL.NAME is not a
% valid Maestro object name; (4) TRIAL.PARAMS contains a bad parameter name or invalid parameter value; (5) TRIAL.PSGM 
% contains a bad parameter name or an invalid parameter value; (6) TRIAL.PERTS specifies a non-existent perturbation 
% object or contains a bad parameter value; (7) TRIAL.TGTS names a target that does not exist; (8) TRIAL.TAGS contains 
% duplicate tags, or overlapping/invalid sections; (9) TRIAL.SEGS contains an invalid parameter name or value; or (10)
% the length of TRIAL.SEGS(segIdx).TRAJ does not equal the length of TRIAL.TGTS. BE CAREFUL!!!
%
% [Version 1.2.3, Dec 2024]
%
% Scott Ruffner
% sruffner@srscicomp.com
%


% the Java object representing the currently open JMX document is a persistent object. Null if no document is open.
persistent jmxDoc;

% perform the operation specified by the OP argument
assert( (nargin == 2), 'maestrodoc:argchk', 'Invalid number of input arguments');
assert( ischar(op), 'maestrodoc:argchk', 'Arg OP must be a string');

if(strcmp(op, 'open'))
   md_open(arg);
elseif(strcmp(op, 'close'))
   md_close(arg);
elseif(strcmp(op, 'settings'))
   md_settings(arg);
elseif(strcmp(op, 'chancfg'))
   md_addchancfg(arg);
elseif(strcmp(op, 'pert'))
   md_addpert(arg);
elseif(strcmp(op, 'tgset'))
   md_addtargetset(arg);
elseif(strcmp(op, 'trset'))
   md_addtrialset(arg);
elseif(strcmp(op, 'trsub'))
   md_addtrialsubset(arg);
elseif(strcmp(op, 'target'))
   md_addtarget(arg);
elseif(strcmp(op, 'trial'))
   md_addtrial(arg);
else
   error('maestrodoc:argchk', 'Unrecognized operation: %s', op);
end


   %=== md_open: Nested function handles the operation MAESTRODOC('open', FILEPATH). ===================================
   function md_open(arg)
      import com.srscicomp.maestro.*
   
      % if JMX document is already open, fail. Current document must be closed before opening another.
      assert(~isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_open', 'JMX document already open. You must close it before opening another.');
      
      % validate the ARGument
      assert( ischar(arg), 'maestrodoc:md_open', 'FILEPATH argument must be a string');

      % open existing/create new JMX document
      errBuf = java.lang.StringBuffer;
      jmxDoc = JMXDoc.openDocument(arg, errBuf);
      if(~isjava(jmxDoc) || isempty(jmxDoc))
         jmxDoc = [];
         error('maestrodoc:md_open', char(errBuf.toString()));
      end
   end
   %=== end of nested function md_open(arg) ============================================================================


   %=== md_close: Nested function handles the operation MAESTRODOC('close', SAVEFILEPATH). =============================
   function md_close(arg)
      import com.srscicomp.maestro.*
      
      % if there is no currently open document, we are done!
      if(~isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'))
         return;
      end
      
      % validate the ARGument
      assert( ischar(arg), 'maestrodoc:md_close', ...
         'Argument must be file path to which document is saved (empty string to closed without saving)');
      
      % if argument is not an empty string, attempt to save document
      emsg = '';
      if(~isempty(arg))
         emsg = char(JMXDoc.saveDocument(jmxDoc, arg));
      end
      
      % reset and clear document regardless of success/failure
      jmxDoc.reset();
      jmxDoc = [];
      
      assert( isempty(emsg), 'maestrodoc:md_close', emsg);
   end
   %=== end of nested function md_close(arg) ===========================================================================


   %=== md_settings: Nested function handles the operation MAESTRODOC('settings', S). ==================================
   function md_settings(arg)
      import com.srscicomp.maestro.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_settings', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(isstruct(arg), 'maestrodoc:md_settings', 'Argument must be a Matlab structure');
      assert(isfield(arg, 'rmv') && isnumeric(arg.rmv) && isvector(arg.rmv) && (length(arg.rmv) == 6), ...
         'maestrodoc:md_settings', 'S.RMV -- Field missing or incorrectly formatted');
      assert(isfield(arg, 'fix') && isnumeric(arg.fix) && isvector(arg.fix) && (length(arg.fix) == 2), ...
         'maestrodoc:md_settings', 'S.FIX -- Field missing or incorrectly formatted');
      assert(isfield(arg, 'other') && isnumeric(arg.other) && isvector(arg.other) && (length(arg.other) == 8), ...
         'maestrodoc:md_settings', 'S.OTHER-- Field missing or incorrectly formatted');
      
      % perform the operation and check for failure
      emsg = char(jmxDoc.changeSettings(arg.rmv, arg.fix, arg.other));
      if(~isempty(emsg))
         error('maestrodoc:md_settings', emsg);
      end
   end
   %=== end of nested function md_settings(arg) ========================================================================


   %=== md_addchancfg: Nested function handles the operation MAESTRODOC('chancfg', CHCFG). =============================
   function md_addchancfg(arg)
      import com.srscicomp.maestro.*
      import org.json.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addchancfg', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(isstruct(arg), 'maestrodoc:md_addchan', 'Argument must be a Matlab structure');
      assert(isfield(arg, 'name') && ischar(arg.name) && isvector(arg.name) && (~isempty(arg.name)), ...
         'maestrodoc:md_addchancfg', 'CHCFG.NAME -- Field missing or incorrectly formatted');
      assert(isfield(arg, 'channels') && (iscell(arg.channels) || isempty(arg.channels)), ...
         'maestrodoc:md_addchancfg', 'CHCFG.CHANNELS -- Field missing or incorrectly formatted');
      [nChans, nParams] = size(arg.channels);
      assert(nParams == 6, 'maestrodoc:md_addchancfg', 'CHCFG.CHANNELS -- Must be Nx6 cell array');
         
      % convert CHCFG.CHANNELS to a JSON array of JSON arrays, each of which holds a channel description in the 
      % expected format
      channelDescs = org.json.JSONArray;
      for ch=1:nChans
         channel = arg.channels(ch,:);
         desc = org.json.JSONArray;
         try
            for j=1:6
               assert(ischar(channel{j}) || (isnumeric(channel{j}) && isscalar(channel{j})), 'Bad channel descriptor');
               desc.put(channel{j});
            end
         catch
            error('maestrodoc:md_addchancfg', 'CHCFG.CHANNELS(%d) is incorrectly formatted', ch);
         end
         channelDescs.put(desc);
      end
      
      % perform the operation and check for failure
      emsg = char(jmxDoc.addChanCfg(arg.name, channelDescs));
      if(~isempty(emsg))
         error('maestrodoc:md_addchancfg', emsg);
      end
   end
   %=== end of nested function md_addchancfg(arg) ======================================================================


   %=== md_addpert: Nested function handles the operation MAESTRODOC('pert', PERT). ====================================
   function md_addpert(arg)
      import com.srscicomp.maestro.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addpert', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(iscell(arg) && isvector(arg) && (length(arg) >= 5) && (length(arg) <= 6), ...
         'maestrodoc:md_addpert', 'PERT must be a cell vector of length 5 or 6');
      assert(ischar(arg{1}) && ischar(arg{2}) && isnumeric(arg{3}) && isscalar(arg{3}), ...
         'maestrodoc:md_addpert', 'PERT is incorrectly formatted');
      
      params = zeros(length(arg)-3, 1);
      for i=4:length(arg)
         assert(isnumeric(arg{i}) && isscalar(arg{i}), 'maestrodoc:md_addpert', 'PERT is incorrectly formatted');
         params(i-3) = arg{i};
      end
 
      % perform the operation and check for failure
      emsg = char(jmxDoc.addPert(arg{1}, arg{2}, int32(arg{3}), params));
      if(~isempty(emsg))
         error('maestrodoc:md_addpert', emsg);
      end
   end
   %=== end of nested function md_addpert(arg) =========================================================================


   %=== md_addtargetset: Nested function handles the operation MAESTRODOC('tgset', NAME). ==============================
   function md_addtargetset(arg)
      import com.srscicomp.maestro.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addtargetset', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(ischar(arg) && (~isempty(arg)), 'maestrodoc:md_addtargetset', 'NAME must be a non-empty string');
 
      % perform the operation and check for failure
      emsg = char(jmxDoc.addTargetSet(arg));
      if(~isempty(emsg))
         error('maestrodoc:md_addtargetset', emsg);
      end
   end
   %=== end of nested function md_addtargetset(arg) ====================================================================


   %=== md_addtrialset: Nested function handles the operation MAESTRODOC('trset', NAME). ===============================
   function md_addtrialset(arg)
      import com.srscicomp.maestro.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addtrialset', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(ischar(arg) && (~isempty(arg)), 'maestrodoc:md_addtrialset', 'NAME must be a non-empty string');
 
      % perform the operation and check for failure
      emsg = char(jmxDoc.addTrialSet(arg));
      if(~isempty(emsg))
         error('maestrodoc:md_addtrialset', emsg);
      end
   end
   %=== end of nested function md_addtrialset(arg) =====================================================================


   %=== md_addtrialsubset: Nested function handles the operation MAESTRODOC('trsub', S). ===============================
   function md_addtrialsubset(arg)
      import com.srscicomp.maestro.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addtrialsubset', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(isstruct(arg), 'maestrodoc:md_addtrialsubset', 'S must be a Matlab structure');
      assert(isfield(arg, 'set') && ischar(arg.set) && isvector(arg.set) && (~isempty(arg.set)), ...
         'maestrodoc:md_addtrialsubset', 'S.SET -- Field missing or invalid; should be a non-empty string');
      assert(isfield(arg, 'name') && ischar(arg.name) && isvector(arg.name) && (~isempty(arg.name)), ...
         'maestrodoc:md_addtrialsubset', 'S.NAME -- Field missing or invalid; should be a non-empty string');
 
      % perform the operation and check for failure
      emsg = char(jmxDoc.addTrialSubset(arg.set, arg.name));
      if(~isempty(emsg))
         error('maestrodoc:md_addtrialsubset', emsg);
      end
   end
   %=== end of nested function md_addtrialsubset(arg) ==================================================================


   %=== md_addtarget: Nested function handles the operation MAESTRODOC('target', TGT). =================================
   function md_addtarget(arg)
      import com.srscicomp.maestro.*
      import org.json.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addtarget', 'You must open a document first before making changes to it!');
      
      % validate the ARGument
      assert(isstruct(arg), 'maestrodoc:md_addtarget', 'TGT must be a Matlab structure');
      assert(isfield(arg, 'set') && ischar(arg.set) && isvector(arg.set) && (~isempty(arg.set)), ...
         'maestrodoc:md_addtarget', 'TGT.SET -- Field missing or invalid; should be a non-empty string');
      assert(isfield(arg, 'name') && ischar(arg.name) && isvector(arg.name) && (~isempty(arg.name)), ...
         'maestrodoc:md_addtarget', 'TGT.NAME -- Field missing or invalid; should be a non-empty string');
      assert(isfield(arg, 'type') && ischar(arg.type) && isvector(arg.type) && (~isempty(arg.type)), ...
         'maestrodoc:md_addtarget', 'TGT.TYPE -- Field missing or invalid; should be a non-empty string');
      assert(isfield(arg, 'params') && iscell(arg.params) && (isvector(arg.params) || isempty(arg.params)), ...
         'maestrodoc:md_addtarget', 'TGT.PARAMS -- Field missing or not a cell array');
      assert(mod(length(arg.params), 2) == 0, ...
         'maestrodoc:md_target', 'TGT.PARAMS -- Must contain an even number of elements');
      
      % convert TGT.PARAMS to a JSON array while verifying expected format -- a sequence of 'param-name', param-value
      % pairs, where each param value is a string, a numeric scalar, or a numeric vector.
      tgtParams = org.json.JSONArray;
      for i=1:2:length(arg.params)
         pname = arg.params{i};
         pval = arg.params{i+1};
         assert(ischar(pname) && (~isempty(pname)), ...
            'maestrodoc:md_addtarget', 'TGT.PARAMS -- %d-th parameter name invalid', i/2);
         assert(ischar(pval) || (isnumeric(pval) && (isscalar(pval) || isvector(pval))), ...
            'maestrodoc:md_addtarget', 'TGT.PARAMS -- %d-th parameter value is invalid', i/2);
         tgtParams.put(pname);
         if(ischar(pval) || isscalar(pval))
            tgtParams.put(pval);
         else
            pvalAr = org.json.JSONArray;
            for j=1:length(pval), pvalAr.put(pval(j)); end
            tgtParams.put(pvalAr);
         end
      end
      
      % perform the operation and check for failure
      emsg = char(jmxDoc.addTarget(arg.set, arg.name, arg.type, tgtParams));
      if(~isempty(emsg))
         error('maestrodoc:md_addtarget', emsg);
      end
   end
   %=== end of nested function md_addtarget(arg) =======================================================================


   %=== md_addtrial: Nested function handles the operation MAESTRODOC('trial', TRIAL). =================================
   function md_addtrial(arg)
      import com.srscicomp.maestro.*
      import org.json.*
      
      % cannot proceed if no document is currently open!
      assert(isa(jmxDoc, 'com.srscicomp.maestro.JMXDoc'), ...
         'maestrodoc:md_addtrial', 'You must open a document first before making changes to it!');
      
      % validate the ARGument and, if possible, convert it to a JSON object conforming to format expected of a trial
      % definition stored in the JMX document
      
      % TRIAL.SET and TRIAL.NAME -- Non-empty strings
      assert(isstruct(arg), 'maestrodoc:md_addtrial', 'TRIAL must be a Matlab structure');
      assert(isfield(arg, 'set') && ischar(arg.set) && isvector(arg.set) && (~isempty(arg.set)), ...
         'maestrodoc:md_addtrial', 'TRIAL.SET -- Field missing or invalid; should be a non-empty string');
      assert(isfield(arg, 'name') && ischar(arg.name) && isvector(arg.name) && (~isempty(arg.name)), ...
         'maestrodoc:md_addtrial', 'TRIAL.NAME -- Field missing or invalid; should be a non-empty string');
      
      % optional field TRIAL.SUBSET -- If defined, it must be a non-empty string
      isSubset = false;
      if(isfield(arg, 'subset'))
         assert(ischar(arg.subset) && isvector(arg.subset) && (~isempty(arg.subset)), ...
            'maestrodoc:md_addtrial', 'TRIAL.SUBSET -- Field is invalid; should be a non-empty string');
         isSubset = true;
      end
      
      trObj = org.json.JSONObject;
      trObj.put('name', arg.name);
      
      % TRIAL.PARAMS -- name,value cell vector; possibly empty
      assert(isfield(arg, 'params') && iscell(arg.params) && (isvector(arg.params) || isempty(arg.params)), ...
         'maestrodoc:md_addtrial', 'TRIAL.PARAMS -- Field missing or not a cell array');
      assert(mod(length(arg.params), 2) == 0, ...
         'maestrodoc:md_addtrial', 'TRIAL.PARAMS -- Must contain an even number of elements');
      trParams = org.json.JSONArray;
      for i=1:2:length(arg.params)
         pname = arg.params{i};
         pval = arg.params{i+1};
         assert(ischar(pname) && (~isempty(pname)), ...
            'maestrodoc:md_addtrial', 'TRIAL.PARAMS -- %d-th parameter name invalid', i/2);
         assert(ischar(pval) || (isnumeric(pval) && (isscalar(pval) || isvector(pval))), ...
            'maestrodoc:md_addtrial', 'TRIAL.PARAMS -- %d-th parameter value is invalid', i/2);
         trParams.put(pname);
         if(ischar(pval) || isscalar(pval))
            trParams.put(pval);
         else
            pvalAr = org.json.JSONArray;
            for j=1:length(pval), pvalAr.put(pval(j)); end
            trParams.put(pvalAr);
         end
      end
      trObj.put('params', trParams);
      
      % TRIAL.PERTS -- Cell vector of up to 4 cell vectors of the form {string, scalar, scalar, scalar, string}
      assert(isfield(arg, 'perts') && iscell(arg.perts) && (isempty(arg.perts) ||isvector(arg.perts)), ...
         'maestrodoc:md_addtrial', 'TRIAL.PERTS -- Field missing or incorrectly formatted');
      assert(length(arg.perts) <= 4, 'maestrodoc:md_addtrial', 'TRIAL.PERTS -- Too many trial perturbations defined');
      pertsUsed = org.json.JSONArray;
      for i=1:length(arg.perts)
         pert = arg.perts{i};
         assert(iscell(pert) && isvector(pert) && (length(pert) == 5), ...
            'maestrodoc:md_addtrial', 'TRIAL.PERTS(%d) is incorrectly formatted', i);
         assert(ischar(pert{1}) && ischar(pert{5}), ...
            'maestrodoc:md_addtrial', 'TRIAL.PERTS(%d) is incorrectly formatted', i);
         for j=2:4
            assert(isnumeric(pert{j}) && isscalar(pert{j}), ...
               'maestrodoc:md_addtrial', 'TRIAL.PERTS(%d) is incorrectly formatted', i);
         end
         
         pertAr = org.json.JSONArray;
         for j=1:5, pertAr.put(pert{j}); end
         
         pertsUsed.put(pertAr);
      end
      trObj.put('perts', pertsUsed);
      
      % TRIAL.TGTS -- non-empty cell array of strings
      assert(isfield(arg, 'tgts') && iscellstr(arg.tgts) && isvector(arg.tgts) && (~isempty(arg.tgts)), ...
         'maestrodoc:md_addtrial', 'TRIAL.TGTS -- Field missing, empty, or incorrectly formatted');
      tgtsUsed = org.json.JSONArray;
      for i=1:length(arg.tgts)
        tgtsUsed.put(arg.tgts{i});
      end
      trObj.put('tgts', tgtsUsed);
      
      % TRIAL.TAGS -- possibly empty vector of cell vectors of the form {string, scalar, scalar}
      assert(isfield(arg, 'tags') && (isempty(arg.tags) || (isvector(arg.tags) && iscell(arg.tags))), ...
         'maestrodoc:md_addtrial', 'TRIAL.TAGS -- Field missing or incorrectly formatted');
      tagSects = org.json.JSONArray;
      for i=1:length(arg.tags)
         tag = arg.tags{i};
         assert(iscell(tag) && isvector(tag) && (length(tag) == 3), ...
            'maestrodoc:md_addtrial', 'TRIAL.TAGS(%d) is incorrectly formatted', i);
         assert(ischar(tag{1}) && isnumeric(tag{2}) && isscalar(tag{2}) && isnumeric(tag{3}) && isscalar(tag{3}), ...
            'maestrodoc:md_addtrial', 'TRIAL.TAGS(%d) is incorrectly formatted', i);
         tagAr = org.json.JSONArray;
         for j=1:3, tagAr.put(tag{j}); end
         
         tagSects.put(tagAr);
      end
      trObj.put('tags', tagSects);

      % TRIAL.RVS -- optional cell array of cell arrays defining the trial random variables
      randVars = org.json.JSONArray;
      if(isfield(arg, 'rvs'))
         assert(isempty(arg.rvs) || (isvector(arg.rvs) && iscell(arg.rvs) && length(arg.rvs) <= 10), ...
            'maestrodoc:md_addtrial', 'TRIAL.RVS -- Field incorrectly formatted');
         for i=1:length(arg.rvs)
            rv = arg.rvs{i};
            assert(iscell(rv) && isvector(rv) && (length(rv) >= 2) && (length(rv) <= 5), ...
               'maestrodoc:md_addtrial', 'TRIAL.RVS(%d) is invalid', i);
            rvAr = org.json.JSONArray;
            for j=1:length(rv), rvAr.put(rv{j}); end

            randVars.put(rvAr);
         end
      end
      trObj.put('rvs', randVars);

      % TRIAL.RVUSE -- optional cell array of cell arrays assigning trial RVs to segment table parameters
      rvUse = org.json.JSONArray;
      if(isfield(arg, 'rvuse'))
         assert(isempty(arg.rvuse) || (isvector(arg.rvuse) && iscell(arg.rvuse)), ...
            'maestrodoc:md_addtrial', 'TRIAL.RVUSE -- Field incorrectly formatted');
         for i=1:length(arg.rvuse)
            rv = arg.rvuse{i};
            assert(iscell(rv) && isvector(rv) && (length(rv)== 4) && ischar(rv{2}), ...
                       'maestrodoc:md_addtrial', 'TRIAL.RVUSE(%d) is invalid', i);
            rvAr = org.json.JSONArray;
            for j=1:length(rv), rvAr.put(rv{j}); end

            rvUse.put(rvAr);
         end
      end
      trObj.put('rvuse', rvUse);

      % TRIAL.SEGS -- NON-EMPTY vector of structures, one per segment; each structure has fields HDR and TRAJ. HDR is a 
      % name,value cell vector, possibly empty. TRAJ is a cell vector of possibly empty name,value cell vectors, and 
      % length(TRAJ) == length(TRIAL.TGTS)
      assert(isfield(arg, 'segs') && (~isempty(arg.segs)) && isvector(arg.segs), ...
         'maestrodoc:md_addtrial', 'TRIAL.SEGS -- Field missing or incorrectly formatted');
      segments = org.json.JSONArray;
      for i=1:length(arg.segs)
         seg = arg.segs(i);
         assert(isstruct(seg), 'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d) is not a Matlab struct', i);
         
         segObj = org.json.JSONObject;
         
         assert(isfield(seg, 'hdr') && iscell(seg.hdr) && (mod(length(seg.hdr), 2) == 0), ...
            'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).HDR -- Field missing or incorrectly formatted', i);
         segHdr = org.json.JSONArray;
         for j=1:2:length(seg.hdr)
            pname = seg.hdr{j};
            pval = seg.hdr{j+1};
            assert(ischar(pname) && (~isempty(pname)), ...
               'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).HDR -- %d-th parameter name invalid', i, j/2);
            assert(isnumeric(pval) && (isscalar(pval) || isvector(pval)), ...
               'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).HDR -- %d-th parameter value is invalid', i, j/2);
            segHdr.put(pname);
            if(isscalar(pval))
               segHdr.put(pval);
            else
               pvalAr = org.json.JSONArray;
               for k=1:length(pval), pvalAr.put(pval(k)); end
               segHdr.put(pvalAr);
            end
         end
         segObj.put('hdr', segHdr);
         
         assert(isfield(seg, 'traj') && iscell(seg.traj) && isvector(seg.traj) && (length(seg.traj) == length(arg.tgts)), ...
            'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).TRAJ -- Field missing or length ~= #targets', i);
         trajectories = org.json.JSONArray;
         for j=1:length(seg.traj)
            traj = seg.traj{j};
            assert(iscell(traj) && (mod(length(traj), 2) == 0), ...
               'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).TRAJ(%d) -- Invalid format', i, j);
               
            trajAr = org.json.JSONArray;
            for k=1:2:length(traj)
               pname = traj{k};
               pval = traj{k+1};
               
               assert(ischar(pname) && (~isempty(pname)), ...
                  'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).TRAJ(%d) -- %d-th parameter name invalid', i, j, k/2);
               assert(ischar(pval) || (isnumeric(pval) && (isscalar(pval) || isvector(pval))), ...
                  'maestrodoc:md_addtrial', 'TRIAL.SEGS(%d).TRAJ(%d} -- %d-th parameter value is invalid', i, j, k/2);
               
               trajAr.put(pname);
               if(ischar(pval) || isscalar(pval))
                  trajAr.put(pval);
               else
                  pvalAr = org.json.JSONArray;
                  for m=1:length(pval), pvalAr.put(pval(m)); end
                  trajAr.put(pvalAr);
               end
            end
            trajectories.put(trajAr);
         end
         segObj.put('traj', trajectories);
         
         segments.put(segObj);
      end
      trObj.put('segs', segments);
      
      % perform the operation and check for failure
      if(isSubset)
         emsg = char(jmxDoc.addTrialToSubset(arg.set, arg.subset, trObj));
      else
         emsg = char(jmxDoc.addTrial(arg.set, trObj));
      end
      if(~isempty(emsg))
         error('maestrodoc:md_addtrial', emsg);
      end
   end
   %=== end of nested function md_addtrial(arg) ========================================================================

end
%=== end of primary function maestrodoc(op, arg) =======================================================================

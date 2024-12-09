# Changelog

This file contains a version history describing changes to maestrodoc() and its supporting Java code since it was
first introduced in May 2010. Maestro version 2.6.0 and later are capable of importing the JSON document constructed
with the help of maestrodoc().

## v1.2.3 (Dec 2024)
- Dropped support for the Pulse Stimulus Generator Module (PSGM) in a trial. The module was never actually built, and
it is removed entirely from Maestro as of Maestro v5.0.2.
- Added support for another special feature, `findAndWait`, added in Maestro v5.0.2.
- Added a trial that uses 49 targets to `examplemdoc.m`. Maestro v5.0.2 increased the maximum number of targets 
participating in trial from 25 to 50.

## v1.2.2 (Nov 2024)
- Added support for defining and using random variables in trials.
- Removed support for specifying XYScope display settings, XYScope targets, and XYScope-related trial features.
- Updated `examplemdoc.m` -- removing all XYScope-related definitions and adding a few trials to test the use of random
variables and the new "selDurByFix" special feature.

## v1.2.1 (Nov 2024)
- Added the `selectDur` option for the trial parameter `specialop`, corresponding to the new special feature 
"selDurByFix" which was added in Maestro 5.0.1. See Maestro online user guide for more information.

## v1.2.0 (Jun 2024)
Rebuilt after migrating code to IntelliJ IDEA and compiling against JDK11. _**No functional changes.**_

## v1.1.2 (Aug 2019)
Updated maestrodoc() and JMXDoc IAW these minor changes introduced in Maestro 4.1.1:
- Added support for specifying the VStab "snap to eye" flag on a per-target, per-segment basis in a trial.
- The VStab sliding-average window length is now a persisted application setting. In JMXDoc, it is stored as the
  8th parameter in the settings.other field. Restricted to [1..20] ms; defaults to 1.

## v1.1.1 (May 2019)
Updated maestrodoc() and JMXDoc to support two new features introduced in Maestro 4.1.0:
- RMVideo target "flicker". The target's flicker cycle is defined by "on" and "off" phases and an initial delay
  prior to the first "on" phase. All three are specified as a set number of frame periods, restricted to [0..99]. Added
  RMVideo target parameter 'flicker'; its value is a 3-int array [on off delay]. Default value is [0 0 0], which disables
  target flicker.
- Random reward withholding variable ratio for both reward pulses #1 and #2 defined in a trial. The variable ratio
  is defined by a numerator N and denominator D: the reward is withheld in N randomly selected trial reps out of every D
  reps. Added field 'rewWHVR' to the JSON array 'params' of a trial definition. Its value is a 4-int array defining
  numerator and denominator for each reward pulse, [N1 D1 N2 D2]. It defaults to [0 1 0 1], which disables the feature.

## v1.1.0 (Oct 2018)
- Updated maestrodoc() and JMXDoc to support the new RMVideo "vertical sync flash" feature added in
  Maestro 4.0.0 and RMVideo V8. The user can optionally trigger, on the first video frame marking the start of a trial
  segment, a brief flash in a small square region in the top-left corner of the display. The intent is to drive a
  photodiode assembly that generates a TTL pulse which can then be timestamped by Maestro -- thereby providing a more
  precise measure of when the segment actually began on the display. New application settings govern the spot size and
  flash duration, while a new segment header flag determines whether or not the flash is delivered for each segment.

- Belatedly updated maestrodoc() to support defining an RMVideo "image" target. This target type was
  introduced in Maestro 3.3.1 (fall 2016).

## v1.0.5 (Jan 2017)
- Updated maestrodoc() to use new package name exported by the supporting JAR: org.hhmi.maestro is
  now com.srscicomp.maestro.
- The JAR is now compiled with a Java 7 SDK, so a Java 7 runtime (or better) must be embedded in Matlab to use it.
  Matlab began using Java 7 with R2014a and still uses it as of Jan 2017. Finally, the ZIP distribution no longer
  includes HHMI-MS-COMMON.JAR (from the "common" project). Instead, we made a few changes so that the only dependencies
  in the "common" project are for the package org.json, which is stable. The ZIP distribution now only includes
  HHMI-MS-MAESTRO.JAR, and the classes from org.json are included in that JAR. _We did this because we have not yet
  released Figure Composer 5.1.0, in which the org.hhmi package is replaced across the board by com.srscicomp and affects
  most packages in HHMI-MS-COMMON.JAR. Now we no longer have to worry about a user replacing HHMI-MS-COMMON.JAR
  inappropriately, causing weird "Java class not found" errors_.

## v1.0.4 (Nov 2016)
- Updated documentation to correct the definition of the RMVideo target parameter 'rgb'. The
  parameter value is a packed integer in BGR format (rather than RGB), with the blue component in byte 2, and so on.
- JMXDoc now recognizes these options for the RMVideo target 'aperture' parameter: 'rectangular', 'elliptical',
  'rectangular annulus', and 'elliptical annulus'. These are the same strings that actually appear in the Maestro GUI.

## v1.0.3 (Dec 2014)
- Modified JMXDoc and maestrodoc() to support a new feature: a trial subset, ie, a group of related
  trials that can appear as a child of a trial set. A trial subset can contain only trial objects and must be a child of
  a trial set, while a trial set can contain any number of trial subsets or individual trial objects. The trial subset
  object was introduced in Maestro v3.1.2 to allow the user to control sequencing of trials at two levels -- the different
  subsets comprising a set, and the trials within each subset.

- Also modified the sample script examplemdoc.m to generate some trial subsets in order to test the new feature.

## v1.0.2 (May 2012)
- Modified JMXDoc to recognize generic AI channel IDs 'ai0' - 'ai15'. Also added comments regarding
  changes in Maestro 3 and backwards-compatibility of the maestrodoc()-created JMX document with Maestro 2.x. Essentially,
  the document created with maestrodoc() can be imported by any version of Maestro 2.6.0 and later, as long as you don't
  try to use an older version of Maestro to import a JMX document that makes use of a feature introduced in a more recent
  version.

- Changed the ANT script that builds the current release so that it places the ZIP archive maestrodoc.zip (containing
  maestrodoc.m, the example script examplemdoc.m, and the supporting JAR file) in ../../forUserguides. This is where I'm
  now putting archives containing apps that will be made available for download via the Maestro online user guide.

- Update (Jun 2013) - Changed ANT script to separate the supporting JAR into two pieces: hhmi-ms-common.jar and
  hhmi-ms-maestro.jar. (The 'hhmi-ms-' prefix was added b/c Matlab's Java comes with a 'common.jar' file.) The first JAR
  is the entire 'common' package (even though we only need some classes from it), while the second is the Java code in
  com.srscicomp.maestro. We did this because the Matlab support package for DataNav also requires code in the 'common'
  package. Users updating Matlab JARs for either Maestro-specific or DataNav-specific Matlab support functions are warned
  to defer to that version of hhmi-ms-common.jar that has the most recent modification date.

## v1.0.1 (Feb 2011)
Modified JMXDoc to support adding trials with the new "searchTask" special operation. To do so,
specify param name-value pair {'specialop', 'search'} in the TRIAL.PARAMS field for maestrodoc('trial', TRIAL) command.

## v1.0.0 (May 2010) 
Initial version.

# Matlab utility maestrodoc()

<mark>**NOTE**: I am no longer actively developing **Maestro** or its related Matlab utilities. I have made this small
repo available for anyone in the neuroscience community that continues to use **Maestro** and might wish to fork the 
repo to adapt the `maestrodoc()` script for their own use.</mark>

Designing experimental protocols in **Maestro**'s user interface can become quite tedious, particularly when it 
requires defining many complex trials involving many segments and more than a few participating targets. If the trials 
vary with the response characteristics of the neural unit acquired during an experiment, it may be impossible to edit 
the trial definitions before the unit is "lost". To address these concerns, the Matlab M-function `maestrodoc()` was 
introduced in May 2010 to support script-based generation of an entire **Maestro** experiment document. It allows you 
to specify all aspects of an experiment except for Continuous-mode stimulus runs, and saves the document in a 
JSON file format that **Maestro** (as of v2.6.0) can import.

For further details and usage information, see the 
[online Maestro user's guide](https://sites.google.com/a/srscicomp.com/maestro/operation/scripting-experiments-in-matlab).

The `maestrodoc()` function is implemented by a Matlab script, `maestrodoc.m,` and an accompanying Java class, `JMXDoc`. 
The `JMXDoc` class file and a small JavaScript Object Notation (JSON) library,`org.json`, are archived together in
`hhmi-ms-maestro.jar`, which must be added to Matlab's Java class path for `maestrodoc()` to work. An Ant build file, 
`release.xml`, prepares this JAR file and packages it in a ZIP file with `maestrodoc.m` and a sample script, 
`examplemdoc.m,` that demonstrates how to use `maestrodoc()` to generate a **Maestro** JMX experiment document. This
ZIP file is available for [download from the **Maestro** user's 
guide](https://sites.google.com/a/srscicomp.com/maestro/downloads).


## Making changes
The repo is set up as an IntelliJ IDEA project. If you wish to make your own changes, clone/fork this repo to your 
machine, make it an IntelliJ IDEA project, and start coding!

## License
The `maestrodoc()` script and its supporting JAR were created by [Scott Ruffner](mailto:sruffner@srscicomp.com). It is licensed under the terms of 
the MIT license.

## Credits
**Maestro** and related Matlab utilties like maestrodoc() were developed for and with funding provided by the Stephen G. 
Lisberger laboratory in the Department of Neurobiology at Duke University.


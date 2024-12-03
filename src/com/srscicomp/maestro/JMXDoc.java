package com.srscicomp.maestro;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.regex.Pattern;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONUtilities;


/**
 * A <i>Maestro</i> experiment document persisted in JavaScript Object Notation (JSON) format.
 * 
 * <p>As the number of segments and/or the number of participating targets in a trial grows, it becomes increasingly 
 * tedious to fill out the trial definition in the <i>Maestro</i> user interface and not make entry errors. It would be
 * useful to have a means of generating such trials programmatically -- especially if there's a need to create many sets
 * of very similar trials.</p>
 * 
 * <p>Since <i>Maestro</i> users rely heavily on <i>Matlab</i> and are accustomed to writing <i>Matlab</i> scripts, we
 * decided to develop a means of creating/editing a <i>Maestro</i> experiment document via a <i>Matlab</i> script. 
 * However, it would be very difficult to reproduce the native binary format of the experiment document without the
 * Microsoft Foundation Classes upon which we rely for reading/writing the document in <i>Maestro</i>. Instead, we chose
 * to introduce an alternate version of the experiment document, stored as a JSON text file. We refer to this 
 * <b>J</b>SON-formatted, <i><b>M</b>aestro</i> e<b>X</b>periment document as a <b>JMX</b> document; the document file 
 * ends in the extension ".jmx". <i>Maestro</i>, of course, can read in a JMX file, but it cannot write one.</p>
 * 
 * <p><code>JMXDoc</code> encapsulates a JMX document. The <i>Matlab</i> utility function <i>maestroDoc()</i> uses an 
 * instance of <code>JMXDoc</code> to open/create, edit, and save a JMX file. <i>Maestro</i> users then can write their
 * own scripts with <i>maestroDoc()</i> (and a JAR file that includes <code>JMXDoc</code> and supporting classes) to 
 * generate the trial sets for their experimental work.</p>
 *
 * <p>Note that, in its current design, <code>JMXDoc</code> lacks support for defining continuous-mode stimulus runs, a
 * rarely used feature in <i>Maestro</i>. All other aspects of the native experiment document -- application settings,
 * channel configurations, perturbations, targets, and trials -- can be reproduced in a JMX document.</p>
 * 
 * <h2>Document format specification</h2>
 * <p>The document is persisted as a JSON object <i>doc</i> with the fields listed below.
 * <ol>
 *    <li><i>doc.version</i> : The document version number, an integer.</li>
 *    <li><i>doc.settings</i> : The application settings.</li>
 *    <li><i>doc.chancfgs</i> : List of channel configurations.</li>
 *    <li><i>doc.perts</i> : List of perturbation waveforms.</li>
 *    <li><i>doc.targetSets</i> : List of target sets</li>
 *    <li><i>doc.trialSets</i> : List of trial sets.</li>
 * </ol>
 * </p>
 * <p>The <i>settings</i> field. A JSON object holding all Maestro application settings, as follows:</p>
 * <ul>
 *    <li><i>settings.rmv</i> : RMVideo display properties. This is a 6-element JSON array of integers <i>[w h d b 
 *    s p]</i>, where: <i>w,h,d</i> are as described above and <i>b</i> is a packed RGB integer specifying the display's
 *    uniform background color, <i>s</i> is the spot size in mm and <i>p</i> is the flash duration in #frames for the
 *    RMVideo "vertical sync flash" feature, added in Maestro 4.0.0. Prior to this change, array only contained the
 *    first 4 integers.</li>
 *    <li><i>settings.fix</i> : Fixation accuracy in Continous mode. This is a 2-element JSON array of doubles <i>[h 
 *    v]</i>, the horizontal and vertical accuracy in deg.</li>
 *    <li><i>settings.other</i> : Other properties. This is an 8-element JSON array of integers <i>[d p1 p2 ovride 
 *    varatio audiorew beep vstabwin]</i>, where: <i>d</i> is the fixation duration in ms; <i>p1, p2</i> are the first 
 *    and second reward pulse lengths in ms; <i>ovride</i> is the global trial reward pulse length override flag 
 *    (nonzero = true); <i>varatio</i> is the variable ratio for random withholding; <i>audiorew</i> is the audio reward
 *    pulse length in ms; <i>beep</i> is the reward indicator beep enable; and <i>vstabwin<i> is the length of the 
 *    sliding-average window for the velocity stabilization feature. This last parameter was added as a persisted 
 *    application setting in Maestro 4.1.1. Prior to this change, the array only contained the first 7 elements.</li>
 * </ul>
 * 
 * <p>The <i>chancfgs</i> field. A JSON array of length N &ge; 0. Each entry in the array is a JSON object representing
 * a <i>Maestro</i> channel configuration. Its definition exactly parallels that of the Matlab structure 
 * <code>CHCFG</code> that is an argument to <code>maestroDoc('chancfg', CHCFG)</code>. See MAESTRODOC.M for details.
 * Remember that <i>chancfgs[n].channels</i> will typically contain entries for only a small subset of the 38 different 
 * displayable data channels in <i>Maestro</i>. It may not contain multiple entries for the same channel.</p>
 * 
 * <p>The <i>perts</i> field. A JSON array of length N &ge; 0. Each entry in the array is a JSON array defining a 
 * <i>Maestro</i> perturbation waveform <i>[name, type, dur, param1, param2, param3]</i>, exactly analogous to the 
 * Matlab structure <code>PERT</code> that is an argument to <code>maestroDoc('pert', PERT)</code>. See MAESTRODOC.M for
 * details.</p>
 * 
 * <p>The <i>targetSets</i> field. A JSON array of length N &ge; 0. Each element is a JSON object defining a target set;
 * it has two fields:
 * <ul>
 *    <li><i>name</i> : The target set's name. Must be a valid <i>Maestro</i> object name, and no two target sets can
 *    have the same name. Cannot be "Predefined", which is reserved in <i>Maestro</i> 2.x. While it no longer exists in
 *    Maestro 3, we still disallow it to maintain backwards-compatibility with version 2.x.</li>
 *    <li><i>targets</i> : A JSON array of JSON objects, each of which is the definition of an RMVideo target in this
 *    set. Each JSON target object has 3 fields:</li>
 *    <ul>
 *       <li><i>name</i> : The target name. Must be a valid <i>Maestro</i> object name, and no two targets in the parent
 *       set can have the same name.</li>
 *       <li><i>type</i> : RMVideo target type, a string.</li>
 *       <li><i>params</i> : Target parameters. A (possibly empty) JSON array containing a sequence of <i>param-name,
 *       param-value</i> pairs, where <i>param-name</i> is a string and the data type of <i>param-value</i> depends on
 *       the specific parameter. Parameters which do not apply to the specified target type need not be included in the 
 *       sequence, nor those parameters which are already set to their default value.</li>
 *    </ul>
 *    The JSON target object format is analogous to the Matlab structure <code>TGT</code> that is an argument to 
 *    <code>maestroDoc('target', TGT)</code>, except the JSON object has no <i>set</i> field. See MAESTRODOC.M for a 
 *    full listing of all target type names, target parameter names, allowed parameter values, and default parameter 
 *    values.</li>
 * </ul>
 * 
 * <p>The <i>trialSets</i> field. A JSON array of length N &ge; 0. Each element is a JSON object defining a trial set;
 * it has two fields:
 * <ul>
 *    <li><i>name</i> : The trial set's name. Must be a valid <i>Maestro</i> object name, and no two trial sets can
 *    have the same name.</li>
 *    <li><i>trials</i> : A JSON array of JSON objects, each of which is the definition of a <b>trial</b> or <b>trial
 *    subset</b> that is a child of this set. Each JSON trial object has 7-10 fields:</li>
 *    <ul>
 *       <li><i>name</i> : The trial name. Must be a valid <i>Maestro</i> object name, and no two trials in the parent
 *       set can have the same name.</li>
 *       
 *       <li><i>params</i> : General trial parameters. A (possibly empty) JSON array containing a sequence of 
 *       <i>param-name, param-value</i> pairs, where <i>param-name</i> is a string and the type of <i>param-value</i> 
 *       depends on the specific parameter. Parameters which do not apply to the specified target type need not be 
 *       included in the sequence, nor those parameters which are already set to their default value.</li>
 *       
 *       <li><i>perts</i> : List of perturbations participating in trial, with control parameters. This will be a JSON
 *       array of up to 4 elements, each of which is a JSON array of the form <i>[pertName A S T C]</i>, where:
 *       <ol> 
 *          <li><i>pertName</i> = the name of the perturbation waveform. It must exist in the JMX document, or the 
 *          document is considered inconsistent.</li>
 *          <li><i>A</i> = perturbation amplitude in [-999.99 .. 999.99].</li>
 *          <li><i>S</i> = index of segment at which perturbation starts. Must be a valid segment index in [1..#segs].
 *          <b>NOTE that we're using Matlab-style indices starting at 1, not C-based indices starting at 0!</b></li>
 *          <li><i>T</i> = index of affected target. Must be valid index into the trial's participating target list, 
 *          [1..#tgts].</li>
 *          <li><i>C</i> = affected trajectory component. Must be one of these strings: <i>winH, winV, patH, patV, 
 *          winDir, patDir, winSpd, patSpd, speed, or direc</i>.</li>
 *       </ol>
 *       Perturbations are rarely used. If the trial includes no perturbations, the JSON array should be empty.</li>
 *       
 *       <li><i>tgts</i> : Trial target list, a NON-EMPTY JSON array of strings, each identifying a target participating
 *       in the trial. The targets will appear in the trial segment table in the order listed. Each entry in the array 
 *       must have the form "setName/tgtName", where "setName" is the name of an EXISTING target set in the JMX document
 *       and "tgtName" is the name of an EXISTING target within that set. Else, the JMX document is invalid. There are 
 *       five rarely used, parameter-less targets in <i>Maestro</i> that may be specified without the containing target 
 *       set: <i>CHAIR, FIBER1, FIBER2, REDLED1, REDLED2</i>. These are found in the "Predefined" target set.</li>
 *       
 *       <li><i>tags</i> : List of tagged sections in the trial's segment table. This field is a (possibly empty) JSON
 *       array, each element of which is a JSON array <i>[L S E]</i> defining a tagged section, where:
 *       <ol>
 *          <li><i>L</i> = The section tag. It must contain 1-17 characters. No restriction on character content.</li>
 *          <li><i>S</i> = Index of first segment in the section. Must be a valid segment index in [1..#segs].</li>
 *          <li><i>E</i> = Index of last segment in the section. Must be a valid segment index <i>&ge; S</i>.</li>
 *       </ol>
 *       No two tagged sections can have the same label, and the defined sections cannot overlap. If either of these 
 *       rules are violated, the JMX document is considered invalid.</li>
 *
 *      <li><i>rvs</i>: [Optional] If present, a list of random variables used in the trial. It is a JSON array of 0 to
 *      10 JSON arrays, where the i-th array defines the i-th random variable, which are labelled "x0" to "x9" in
 *      Maestro. Each array will have one of the following forms:
 *      <ol>
 *         <li>['uniform', seed, A, B] - A uniform distribution over the interval [A, B], A < B.</li>
 *         <li>['normal', seed, M, D, S] - A normal distribution with mean M, standard deviation S > 0, and a maximum
 *         spread S >= 3*D.</li>
 *         <li>['exponential', seed, L, S] - An exponential distribution with rate L > 0 and max spread S > 3/L.</li>
 *         <li>['gamma', seed, K, T, S] - A gamma distribution with shape parameter K > 0, scale parameter T > 0, and
 *         max spread S >= T*(K + 3*sqrt(K)).</li>
 *         <li>['function', formula] - An RV expressed as a funciton of one or more other RVs. An RV is referenced in
 *         the formula string by its variable name, "x0" to "x9" ("x0" corresponds to the 1st element <i>rvs</i>,
 *         etc). In addition to these variables, the formula can contain integer or floating-point numeric constants;
 *         the named constant "pi"; the four standard arithmetic binary operators -, +, *, /; the unary - operator (as
 *         in "-2*x1"); left and right parentheses for grouping; and three named mathematical functions - sin(a),
 *         cos(a), and pow(a,b). Note that the pow() function includes a comma operator to separate its two arguments.
 *         Standard operator precedence rules are observed. It is an ERROR for a function RV to depend on itself, on
 *         another function RV, or on an undefined RV.</li>
 *      </ol>
 *      </li>
 *
 *      <li><i>rvuse</i> : [Optional] A JSON array, possibly empty, indicating what trial segment parameters are
 *      governed by the trial random variables. Each element of the array will be a 4-element JSON array <i>[rvIdx,
 *      'paramName', segIdx, tgIdx]</i>, where <i>rvIdx</i> is the 1-based index of a random variable defined in
 *      <i>rvs</i>, <i>segIdx</i> is the 1-based index of the affected segment, <i>tgIdx</i> is the 1-based index of
 *      the affected target trajectory parameter, and <i>'paramName'</i> identifies the affected parameter:
 *      <ul>
 *         <li>'mindur', 'maxdur' : Minimum or maximum segment duration. (tgIdx ignored in this case).</li>
 *         <li>'hpos', 'vpos' : Horizontal or vertical target position.</li>
 *         <li>'hvel', 'vvel', 'hacc', 'vacc': Horizontal or vertical target velocity or acceleration.</li>
 *         <li>'hpatvel', 'vpatvel': Horizontal or vertical target pattern valocity.</li>
 *         <li>'hpatacc', 'vpatacc': Horizontal or vertical target pattern acceleration.</li>
 *      </ul>
 *      </li>
 *
 *       <li><i>segs</i> : The trial's segment table. This is a NON-EMPTY JSON array of JSON objects, one per trial 
 *       segment. Each JSON segment object <i>seg</i> contains two fields, as described below.
 *       <ol>
 *          <li><i>seg.hdr</i> :  The segment's header, which is the list of parameters shown in the top six rows of the
 *          segment table in <i>Maestro</i>. This field contains a cell array of zero or more <i>param-name, 
 *          param-value</i> pairs. Again, there's no need to specify a value for every segment header parameter; only 
 *          specify those for which the default value is not correct.</li>
 *          <li><i>seg.traj</i> : A JSON array containing the trajectory variables for all participating targets during 
 *          this segment. The array length should match the number of targets specified in the <i>tgts</i> field. Each 
 *          entry in the array is, again, a JSON array of <i>param-name, param-value</i> pairs. Each trajectory 
 *          parameter has a default value; a given trajectory parameter is specified in this JSON array only if its 
 *          value is different from the default. If all parameters should be set to the defaults for target T, then 
 *          <i>seg.traj[T]</i> should be an empty JSON array.</li>
 *       </ol>
 *    </ul>
 *    The JSON trial object format is exactly analogous to the Matlab structure <code>TRIAL</code> that is an argument 
 *    to <code>maestroDoc('trial', TRIAL)</code>, except the JSON object has no <i>set</i> field. See MAESTRODOC.M for
 *    a full explanation of the content and format of <code>TRIAL</code>, including parameter names, allowed parameter
 *    values, and default parameter values.
 *    <p>
 *    The notion of a <b>trial subset</b> was introduced in Maestro v3.1.2. A subset is merely a set of related trials;
 *    however, unlike a trial set, a trial subset may NOT contain any trial subsets -- thereby restricting the trial
 *    tree structure to at most two levels. A trial subset is defined by two fields:
 *    <ul>
 *    <li><i>subset</i> : The subset's name. Must be a valid <i>Maestro</i> object name, and it must be unique among
 *    the trials and other trial subsets within the parent trial set.</li>
 *    <li><i>trials</i> : A JSON array of JSON objects, each of which is the definition of a trial within the subset. It
 *    CANNOT contain any trial subset objects, and each trial object is exactly as described above.</li>
 *    </ul>
 *    </p>
 *    </li>
 * </ul>
 *
 * [08nov2024] maestrodoc() v1.2.2 dropped support for the XYScope platform, which has not been supported by Maestro
 * since V4.0 (Nov 2018). {@link #changeSettings}, {@link #addTarget}, and {@link #addTrial} updated accordingly.
 * [18nov2024] maestrodoc() v1.2.3 dropped support for the PSGM, which was never actually built and is removed from
 * Maestro entirely.
 * [03dec2024] REVISED maestrodoc() v1.2.3 to support new special feature option "findAndWait", added in Maestro 5.0.2.
 *
 * @author sruffner
 */
@SuppressWarnings("unused")
public class JMXDoc
{
   /**
    * Open a new or existing JSON-formatted Maestro experiment (JMX) document.
    * @param path File system path. Ignored if null or empty, in which case a brand-new document object is returned.
    * Otherwise, this must specify an existing JMX file. File extension must be ".jmx".
    * @param errBuf Optional error message buffer. If specified and operation fails, it will hold an error message; 
    * otherwise, it will be empty.
    * @return A <code>JMXDoc</code> initialized IAW the contents of the file specified, or null if operation failed.
    */
   public static JMXDoc openDocument(String path, StringBuffer errBuf)
   {
      if(errBuf != null) errBuf.setLength(0);
      if(path == null || path.isEmpty()) return(new JMXDoc());
      
      if(!path.endsWith(".jmx"))
      {
         if(errBuf != null) errBuf.append("Filename must end with .jmx");
         return(null);
      }
      
      File f = new File(path);
      if(!f.isFile())
      {
         if(errBuf != null) errBuf.append("Specified file does not exist");
         return(null);
      }
      
      JMXDoc jmxDoc = new JMXDoc();
      boolean ok = false;
      try
      {
         JSONObject jsonObj = JSONUtilities.readJSONObject(f);
         jmxDoc.fromJSON(jsonObj);
         ok = true;
      }
      catch(IOException ioe)
      {
         if(errBuf != null) errBuf.append("IO exception while reading file:\n  ").append(ioe.getMessage());
      }
      catch(JSONException jse)
      {
         if(errBuf != null) errBuf.append("Unable to parse file as JMX document:\n  ").append(jse.getMessage());
      }
      
      if(!ok) jmxDoc.reset();
      return(ok ? jmxDoc : null);
   }
   
   /**
    * Save the contents of a JSON-formatted Maestro experiment (JMX) document to file.
    * @param doc The JMX document to be persisted to file.
    * @param savePath File system path. File extension must be ".jmx". If file already exists, it is overwritten.
    * @return An empty string if operation is successful; else, a brief description of the reason for failure.
     */
   public static String saveDocument(JMXDoc doc, String savePath)
   {
      if(doc == null) return("No document specified");
      if(savePath == null || !savePath.endsWith(".jmx"))
         return("No save file path specified, or filename extension is not .jmx.");
      
      File f = new File(savePath);
      if(f.getParentFile() == null || !f.getParentFile().isDirectory())
         return("Save file path cannot be found.");
      
      String errMsg = "";
      try
      {
         JSONUtilities.writeJSONObject(f, doc.toJSON(), true);
      }
      catch(IOException ioe)
      {
         errMsg = "IO exception while writing file:\n  " + ioe.getMessage();
      }
      catch(JSONException jse)
      {
         errMsg = "JSON formatting exception while writing file:\n  " + jse.getMessage();
      }
      
      return(errMsg);
   }
   
   /** 
    * Construct a new, empty JMX document. The new document contains no channel configurations, perturbation waveforms,
    * target sets or trial sets. All application settings are set to default values.
    */
   private JMXDoc() { reset(); }
   
   /**
    * Prepare a single JSON object encapsulating the entire content of this JMX document. See class header for a 
    * description of the document format.
    * @return JSON object encapsulating document contents.
    */
   private JSONObject toJSON()
   {
      JSONObject jsonDoc = new JSONObject();
      try
      {
         jsonDoc.put("version", CURRVERSION);
         jsonDoc.put("settings", settings);
         jsonDoc.put("chancfgs", chancfgs);
         jsonDoc.put("perts", perts);
         jsonDoc.put("targetSets", targetSets);
         jsonDoc.put("trialSets", trialSets);
      }
      catch(JSONException jse) { /* should never happen */ } 
      
      return(jsonDoc);
   }
   
   /**
    * Reset this JMX document, then initialize its content IAW the JSON object provided, which should be formatted as
    * described in the class header. If the JSON object is not correctly formatted, an exception is thrown and this
    * JMX document will be left in an empty state (so any previous content is lost).
    * 
    * <p>On migrating older versions to the latest version:
    * <ul>
    * <li>V<3. As of V=3, the settings.rmv field contains 2 additional integer parameters: [W H D BKG SZ DUR], where
    * SZ is the spot size in mm and DUR is the flash duration in #frames for the new RMVideo "vertical sync flash"
    * feature. If the field only has 4 parameters, then default values (SZ=0, DUR=1) ar added for the new settings.
    * Also, an integer flag 'rmvsync' has been added to the 'hdr' field of a trial segment object. No migration needed
    * in that case, since the omission of the flag means that it is not on, which is the default. Also added support
    * for the RMVideo "image" target; no migration required.</li>
    * <li>V<4. As of V=4, the window length for velocity stabilization is the 8th parameter in settings.other. For 
    * earlier versions, we append a default value of 1ms to the field.</li>
    * </ul>
    * </p>
    * @param jsonDoc JSON object encapsulating a JMX document's contents.
    * @throws JSONException if the argument cannot be parsed as a JMX document object.
    */
   private void fromJSON(JSONObject jsonDoc) throws JSONException
   {
      reset();
      try
      {
         int v = jsonDoc.getInt("version");
         if(v < 1 || v > CURRVERSION) throw new JSONException("Invalid JMX version = " + v);
         
         settings = jsonDoc.getJSONObject("settings");
         if(v < 3)
         {
            // new RMVideo VSync flash feature: add default spot size (0=disabled) and flash duration
            JSONArray rmv = settings.getJSONArray("rmv");
            rmv.put(0);
            rmv.put(1);
         }
         if(v < 4)
         {
            // VStab window length added as a persisted application setting in Maestro 4.1.1.
            JSONArray other = settings.getJSONArray("other");
            other.put(1);
         }
         checkSettings();
         
         chancfgs = jsonDoc.getJSONArray("chancfgs");
         checkChanCfgs();
         
         perts = jsonDoc.getJSONArray("perts");
         checkPerts();
         
         targetSets = jsonDoc.getJSONArray("targetSets");
         checkTargetSets();
         
         trialSets = jsonDoc.getJSONArray("trialSets");
         checkTrialSets();
      }
      finally { reset(); }
   }
   
   /**
    * Reset this JMX document: no channel configurations, perturbations, target sets or trial sets defined; all 
    * application settings set to their default values.
    */
   public void reset()
   {
      try
      {
         // initialize all Maestro application settings to their default values
         settings = new JSONObject();
         settings.put("rmv", new JSONArray(SETTINGS_RMV_DEFAULTS));
         settings.put("fix", new JSONArray(SETTINGS_FIX_DEFAULTS));
         settings.put("other", new JSONArray(SETTINGS_OTHER_DEFAULTS));
         
         chancfgs = new JSONArray();
         perts = new JSONArray();
         targetSets = new JSONArray();
         trialSets = new JSONArray();
      }
      catch(JSONException jse) { /* should never happen */ }
   }
   
   /**
    * Change the application settings in this JMX document.
    * @param rmvparams RMVideo display properties <i>[w h d b sz dur]</i>.
    * @param fixacc Cont-mode horizontal and vertical fixation accuracy <i>[h v]</i> in deg.
    * @param other  Other properties <i>[d p1 p2 ovride varatio audiorew beep vstabwin]</i>.
    * @return On failure, the settings are left unchanged and a descriptive error message is returned; if successful, an
    * empty string is returned.
    */
   public String changeSettings(int[] rmvparams, double[] fixacc, int[] other)
   {
      JSONObject old = settings;
      String errMsg = "";
      try
      {
         settings = new JSONObject();
         
         JSONArray ar = new JSONArray();
         if(rmvparams != null) for(int rmvparam : rmvparams) ar.put(rmvparam);
         settings.put("rmv", ar);
                  
         ar = new JSONArray(); 
         if(fixacc != null) for(double v : fixacc) ar.put(v);
         settings.put("fix", ar);
         
         ar = new JSONArray(); 
         if(other != null) for(int j : other) ar.put(j);
         settings.put("other", ar);
         checkSettings();
      }
      catch(JSONException jse)
      {
         errMsg = jse.getMessage();
      }
      
      if(!errMsg.isEmpty()) settings = old;
      return(errMsg);
   }
   
   /**
    * Helper method validates the content of the JSON object encapsulating the current application settings.
    * @throws JSONException if the application settings object is incorrectly formatted or any parameter therein has an
    * invalid value. The exception message gives a rough idea of where the problem lies, for debugging purposes.
    */
   private void checkSettings() throws JSONException
   {
      // RMVideo settings
      JSONArray rmv = settings.getJSONArray("rmv");
      if(rmv.length() != 6) throw new JSONException("Incorrect number of elements in settings.rmv");
      for(int i=0; i<3; i++) if(rmv.getInt(i) < 50 || rmv.getInt(i) > 50000)
         throw new JSONException("Bad RMVideo display geometry in settings.rmv");
      if(rmv.getInt(4) < 0 || rmv.getInt(4) > 50)
         throw new JSONException("Bad RMVideo VSync flash spot size in settings.rmv");
      if(rmv.getInt(5) < 1 || rmv.getInt(5) > 9)
         throw new JSONException("Bad RMVideo VSync flash duration in settings.rmv");
      
      // fixation accuracy
      JSONArray fix = settings.getJSONArray("fix");
      if(fix.length() != 2) throw new JSONException("Incorrect number of elements in settings.fix");
      for(int i=0; i<fix.length(); i++) if(fix.getDouble(i) < 0.1 || fix.getDouble(i) > 50)
         throw new JSONException("Bad fixation accuracy in settings.fix");
      
      // other properties
      JSONArray other = settings.getJSONArray("other");
      if(other.length() != 8) throw new JSONException("Incorrect number of elements in settings.other");
      if(other.getInt(0) < 100 || other.getInt(0) > 10000) 
         throw new JSONException("Bad fixation duration in settings.other");
      for(int i=1; i<=2; i++) if(other.getInt(i) < 1 || other.getInt(i) > 999) 
         throw new JSONException("Bad reward pulse length in settings.other");
      if(other.getInt(4) < 1 || other.getInt(4) > 10) 
         throw new JSONException("Bad variable withholding ratio in settings.other");
      if(other.getInt(5) != 0 && (other.getInt(5) < 100 || other.getInt(5) > 1000))
         throw new JSONException("Bad audio reward length in settings.other");
      if(other.getInt(7) < 1 || other.getInt(7) > 20) 
         throw new JSONException("Bad VStab sliding window length in settings.other");
   }

   /**
    * Add a new channel configuration or replace an existing channel configuration in this JMX document.
    * @param name The name of the channel configuration. If another configuration with this name already exists, it is
    * replaced by the channel configuration provided.
    * @param channels List of zero or more channel descriptions in the new channel configuration. Each element of the
    * array is a single channel description: a JSON of six elements <i>[ch rec? dsp? ofs gain color]</i>. See class 
    * header for a complete description. The list can be empty. If it contains more than one description for the same
    * channel ID <i>ch</i>, the last description is used.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addChanCfg(String name, JSONArray channels)
   {
      // validate channel configuration name
      if(isNotValidObjectName(name))
         return("Object name violates Maestro naming rules");
      
      // validate the channel descriptions
      String errMsg = "";
      try { checkChannels(channels); } catch(JSONException jse) { errMsg = jse.getMessage(); }
      if(!errMsg.isEmpty()) return(errMsg);
      
      // append the new channel configuration, or replace an existing one with the same name.
      try
      {
         boolean found = false;
         for(int i=0; i<chancfgs.length() && !found; i++)
         {
            JSONObject cfg = chancfgs.getJSONObject(i);
            if(name.equals(cfg.getString("name")))
            {
               cfg.put("channels", channels);
               found = true;
            }
         }
         
         if(!found)
         {
            JSONObject chCfg = new JSONObject();
            chCfg.put("name", name);
            chCfg.put("channels", channels);
            chancfgs.put(chCfg);
         }
      }
      catch(JSONException jse) { /* should never happen */ }
      
      return("");
   }
   
   /**
    * Helper method validates the JSON array holding all channel configurations defined in this JMX document. Each 
    * element of the array must be a JSON object defining a single channel configuration. See class header for a 
    * complete description of a channel configuration object. 
    * @throws JSONException if any channel configuration object is incorrectly formatted, if any such object has an 
    * invalid or duplicate name, or if any channel description within a given channel configuration includes an invalid
    * parameter value. The exception message gives a rough idea of where the problem lies, for debugging purposes.
    */
   private void checkChanCfgs() throws JSONException
   {
      if(chancfgs.length() == 0) return;
      
      HashMap<String, Object> chanNamesUsed = new HashMap<>();
      for(int i=0; i<chancfgs.length(); i++)
      {
         JSONObject cfg = chancfgs.getJSONObject(i);
         String name = cfg.getString("name");
         if(chanNamesUsed.containsKey(name))
            throw new JSONException("Channel configuration " + i + " --Found duplicate name: " + name);
         chanNamesUsed.put(name, null);
         if(isNotValidObjectName(name))
            throw new JSONException("Channel configuration " + i + " --Invalid object name: " + name);

         try
         {
            checkChannels(cfg.getJSONArray("channels"));
         }
         catch(JSONException jse)
         {
            throw new JSONException("Channel configuration " + i + ", " + jse.getMessage());
         }
      }
   }
   
   /**
    * Helper method validates the JSON array provided as a list of channel descriptions, as would be stored in the field
    * "channels" of a JSON object encapsulating a single channel configuration. Each element of the array must be a JSON
    * array of six elements <i>[ch rec? dsp? ofs gain color]</i>. See class header for a complete description. 
    * <p>
    * 17may2012: Extended to support generic channel IDs of the form 'aiN', N=0..15, for the analog input channels. The
    * method replaces the generic ID with its use-specific ID (eg, 'ai0' --> 'hgpos'), since Maestro only recognizes the
    * use-specific IDs.
    * 
    * @param channels JSON array containing a list of channel descriptions to be validated.
    * @throws JSONException if any element in the array is an incorrectly formatted channel description or if any 
    * parameter value therein is invalid. The exception message gives a rough idea of where the problem lies, for 
    * debugging purposes.
    */
   private static void checkChannels(JSONArray channels) throws JSONException
   {
      HashMap<String, Object> channelsDefined = new HashMap<>();
      for(int i=0; i<channels.length(); i++)
      {
         JSONArray params = channels.getJSONArray(i);
         if(params.length() != 6) 
            throw new JSONException("ch# " + i + " --Incorrect number of elements");
         
         String ch = params.getString(0);
         if(!CHANNEL_NAMES.containsKey(ch))
         {
            // channel ID might be one of the alternate generic IDs for the AI channels. If so, replace the
            // generic ID with its use-specific ID.
            if(!ALT_CHANNEL_NAMES.containsKey(ch))
               throw new JSONException("ch# " + i + " --Unrecognized channel id = " + ch);
            String chUse = ALT_CHANNEL_NAMES.get(ch);
            params.put(0, chUse);
            ch = chUse;
         }
         if(channelsDefined.containsKey(ch))
            throw new JSONException("ch# " + i + " --Duplicate channel desc for " + ch);
         channelsDefined.put(ch, null);
         
         params.getInt(1);
         params.getInt(2);
         if(params.getInt(3) < -90000 || params.getInt(3) > 90000)
            throw new JSONException("ch# " + i + " --Illegal offset = " + params.getInt(3));
         if(params.getInt(4) < -5 || params.getInt(4) > 5)
            throw new JSONException("ch# " + i + " --Illegal gain = " + params.getInt(4));
         
         String color = params.getString(5);
         if(!CHANNEL_COLORS.containsKey(color))
            throw new JSONException("ch# " + i + " --Illegal trace color = " + color);
      }
   }
   
   
   /**
    * Add a new pertubation waveform object or replace an existing perturbation in this JMX document.
    * @param name The name of the perturbation object. If another perturbation with this name already exists, it is
    * replaced by the one provided.
    * @param type The perturbation type. Must be "sinusoid", "pulse train", "uniform noise", or "gaussian noise".
    * @param dur Duration in ms. Must be &ge; 10.
    * @param params Additional defining parameters <i>[p1 p2 p3]</i>. Content and range of allowed values varies with
    * perturbation type. See class header for more info. Note that <i>p3</i> is ignored and may be omitted for a
    * "sinusoid" perturbation.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addPert(String name, String type, int dur, double[] params)
   {
      if(params == null || params.length < 2 || (params.length == 2 && !type.equals("sinusoid")))
         return("Missing one or more defining perturbation parameters");

      // validate the perturbation waveform definition
      JSONArray added;
      try
      {
         added = new JSONArray();
         added.put(name).put(type).put(dur);
         int nParams = type.equals("sinusoid") ? 2 : 3;
         for(int i=0; i<nParams; i++) added.put(params[i]);
         
         checkPertParams(added);
      }
      catch(JSONException jse)
      {
         return(jse.getMessage());
      }
      
      // append the new perturbation waveform, or replace an existing one with the same name.
      try
      {
         boolean found = false;
         for(int i=0; i<perts.length() && !found; i++)
         {
            JSONArray p = perts.getJSONArray(i);
            if(name.equals(p.getString(0)))
            {
               perts.put(i, added);
               found = true;
            }
         }
         
         if(!found) perts.put(added);
      }
      catch(JSONException jse) { /* should never happen */ }
      
      return("");
   }
   
   /**
    * Helper method validates the JSON array holding all perturbation waveforms defined in this JMX document. Each 
    * element of the array must be a JSON array defining a single perturbation. See class header for a complete 
    * description of a perturbation waveform object. 
    * @throws JSONException if any perturbation waveform object is incorrectly formatted, if any such object has an 
    * invalid or duplicate name, or if any perturbation definition includes an invalid parameter value. The exception 
    * message gives a rough idea of where the problem lies, for debugging purposes.
    */
   private void checkPerts() throws JSONException
   {
      if(perts.length() == 0) return;
      
      HashMap<String, Object>pertNamesUsed = new HashMap<>();
      for(int i=0; i<perts.length(); i++)
      {
         JSONArray pertAr = perts.getJSONArray(i);
         try { checkPertParams(pertAr); }
         catch(JSONException jse)
         {
            throw new JSONException("Perturbation " + i + " --" + jse.getMessage());
         }
         String name = pertAr.getString(0);
         if(pertNamesUsed.containsKey(name))
            throw new JSONException("Perturbation " + i + " --Found duplicate name = " + name);
         pertNamesUsed.put(name, null);
      }
   }
   
   /**
    * Helper method validates the JSON array provided as a perturbation waveform definition, as it would be stored in 
    * a JMX document. 
    * @param pert JSONArray of 5-6 elements defining a perturbation waveform: <i>[name type dur p1 p2 p3]</i>, where 
    * <i>p3</i> is ignored and may be omitted if <i>type="sinusoid"</i>. See class header for a complete description of
    * a valid perturbation waveform definition.
    * @throws JSONException if the array is incorrectly formatted for a perturbation definition or if any parameter 
    * value therein is invalid. The exception message gives a rough idea of where the problem lies, for debugging 
    * purposes.
    */
   private static void checkPertParams(JSONArray pert) throws JSONException
   {
      if(pert == null || pert.length() < 5 || pert.length() > 6)
         throw new JSONException("Invalid array length = " + ((pert != null) ? pert.length() : 0));
      
      String name = pert.getString(0);
      if(isNotValidObjectName(name)) throw new JSONException("Invalid object name: " + name);
      
      String type = pert.getString(1);
      if(!PERT_TYPES.containsKey(type))
         throw new JSONException("Unrecognized waveform type = " + type);
      
      int dur = pert.getInt(2);
      if(dur < 10) throw new JSONException("Invalid duration = " + dur);
      
      // check other definining parameters
      int minLen = type.equals("sinusoid") ? 5 : 6;
      if(pert.length() < minLen) throw new JSONException("Invalid array length = " + pert.length());
      
      if(type.equals("sinusoid"))
      {
         int t = pert.getInt(3);
         if(t < 10) throw new JSONException("Invalid period = " + t);
         int ph = pert.getInt(4);
         if(ph < -180 || ph > 180) throw new JSONException("Invalid phase = " + ph);
      }
      else if(type.equals("pulse train"))
      {
         int rd = pert.getInt(3);
         if(rd < 0) throw new JSONException("Invalid ramp duration = " + rd);
         int pd = pert.getInt(4);
         if(pd < 10) throw new JSONException("Invalid pulse duration = " + pd);
         int pi = pert.getInt(5);
         if(pi < pd + 2*rd) throw new JSONException("Invalid pulse interval = " + pi);
      }
      else
      {
         int intv = pert.getInt(3);
         if(intv < 1) throw new JSONException("Invalid noise update interval = " + intv);
         double m = pert.getDouble(4);
         if(m < -1 || m > 1) throw new JSONException("Invalid mean level = " + m);
         int seed = pert.getInt(5);
         if(seed < -9999999 || seed > 10000000) 
            throw new JSONException("Invalid noise seed = " + seed);
      }
   }
   
   /** 
    * Append a new, empty target set to this JMX document.
    * @param name The name to be assigned to the target set. It must satisfy <i>Maestro</i> object naming rules and 
    * cannot duplicate the name of an existing target set.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTargetSet(String name)
   {
      if(isNotValidObjectName(name)) return("Object name violates Maestro naming rules");
      
      try
      {
         for(int i=0; i<targetSets.length(); i++)
         {
            JSONObject tgSet = targetSets.getJSONObject(i);
            if(name.equals(tgSet.getString("name")))
               return("Duplicate target set name!");
         }
         
         JSONObject setAdded = new JSONObject();
         setAdded.put("name", name);
         setAdded.put("targets", new JSONArray());
         targetSets.put(setAdded);
      }
      catch(JSONException jse) { /* should never happen */ }
      
      return("");
   }
   
   /**
    * Helper method validates the JSON array holding all target sets defined in this JMX document. Each element of the
    * array is a JSONObject <i>tgSet</i>. See class header for a complete description of a target set object. 
    * @throws JSONException if any target set object in the document is incorrectly formatted, as more fully described
    * in the class header. The exception message gives a rough idea of where the problem lies, for debugging purposes.
    */
   private void checkTargetSets() throws JSONException
   {
      if(targetSets.length() == 0) return;
      
      HashMap<String, Object> tgsetNamesUsed = new HashMap<>();
      HashMap<String, Object> targetNamesUsed = new HashMap<>();
      for(int i=0; i<targetSets.length(); i++)
      {
         JSONObject tgSet = targetSets.getJSONObject(i);
         String name = tgSet.getString("name");
         if(tgsetNamesUsed.containsKey(name))
            throw new JSONException("Target set " + i + " --Found duplicate name: " + name);
         tgsetNamesUsed.put(name, null);
         if(isNotValidObjectName(name))
            throw new JSONException("Target set " + i + " --Invalid object name: " + name);
         else if(name.equals("Predefined"))
            throw new JSONException("Target set " + i + " --'Predefined' cannot be used to name a target set!");
         
         JSONArray targets = tgSet.getJSONArray("targets");
         targetNamesUsed.clear();
         for(int j=0; j<targets.length(); j++)
         {
            JSONObject target = targets.getJSONObject(j);
            String tgName = target.getString("name");
            if(targetNamesUsed.containsKey(tgName))
               throw new JSONException("Target " + j + " in set " + name + " --Duplicate target name: " + tgName);
            targetNamesUsed.put(tgName, null);
            if(isNotValidObjectName(tgName))
               throw new JSONException("Target " + j + " in set " + name + " --Invalid object name: " + tgName);
            
            try
            {
               checkRMVideoTarget(target);
            }
            catch(JSONException jse) 
            { 
               throw new JSONException("Target " + j + " in set " + name + " --" + jse.getMessage()); 
            }
         }
      }
   }

   /**
    * Append a new RMVideo target to the specified target set in this JMX document, or replace an existing target in
    * that set.
    * @param set Name of destination target set. Must exist in document.
    * @param name Name of the target. If another target with this name already exists in the set, its definition is 
    * replaced by the one provided.
    * @param type The RMVideo target type.
    * @param params A (possibly empty) JSON array containing a sequence of ('param-name', param-value) pairs that 
    * complete the target definition. If a relevant parameter is omitted from this array, it is assumed to be set to a
    * default value.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTarget(String set, String name, String type, JSONArray params)
   {
      // find the target set named
      JSONObject tgSet = null;
      try
      {
         for(int i=0; i<targetSets.length(); i++)
         {
            JSONObject obj = targetSets.getJSONObject(i);
            if(set.equals(obj.getString("name")))
            {
               tgSet = obj;
               break;
            }
         }
      }
      catch(JSONException jse) { /* should never happen */ }
      
      if(tgSet == null) return("Destination target set does not exist: " + set);
      
      // validate the target name
      if(isNotValidObjectName(name)) return("Object name violates Maestro naming rules");
      
      // create the JSON target object and validate the target definition. Then append it to the target set's list of
      // targets (or replace an existing target definition with the same name.
      JSONObject tgt;
      try
      {
         tgt = new JSONObject();
         tgt.put("name", name);
         tgt.put("type", type);
         tgt.put("params", params);
         
         checkRMVideoTarget(tgt);
         
         JSONArray targets = tgSet.getJSONArray("targets");
         boolean found = false;
         for(int i=0; i<targets.length(); i++)
         {
            JSONObject t = targets.getJSONObject(i);
            if(name.equals(t.getString("name")))
            {
               targets.put(i, tgt);
               found = true;
            }
         }
         
         if(!found) targets.put(tgt);
      }
      catch(JSONException jse)
      {
         return(jse.getMessage());
      }
      
      return("");
   }
   
   /**
    * Helper method validates a JSON object encapsulating an RMVideo target definition, as it would be stored in a
    * JMX document. 
    * @param target A target definition object, as more fully described in the class header. This method only validates
    * the <i>type</i> and <i>params</i> fields of the target object. It is assumed that the caller has already validated
    * the <i>name</i> field.
    * @throws JSONException if the object is not consistent with the definition of an RMVideo target, or if there are
    * any invalid parameter names or values in its <i>params</i> field. The exception message gives a rough idea of 
    * where the problem lies, for debugging purposes.
    */
   private void checkRMVideoTarget(JSONObject target) throws JSONException
   {
      String type = target.getString("type");
      if(!RMVTYPES.containsKey(type))
         throw new JSONException("Invalid target type: " + type);
      
      JSONArray params = target.getJSONArray("params");
      if(params.length() % 2 != 0) throw new JSONException("Params array must have an even number of elements!");
      
      // validate parameters
      for(int i=0; i<params.length(); i+=2)
      {
         String pname = params.getString(i);
         boolean ok = false;
         boolean hasAperture = type.equals("dotpatch") || type.equals("spot") || type.equals("grating") || type.equals("plaid");
         switch(pname)
         {
         case "dotsize":
            ok = type.equals("point") || type.equals("dotpatch") || type.equals("flowfield");
            if(ok)
            {
               int dotsz = params.getInt(i + 1);
               ok = (dotsz >= 1) && (dotsz <= 10);
            }
            break;
         case "rgb":
            ok = type.equals("point") || type.equals("dotpatch") || type.equals("flowfield") || type.equals("bar") ||
                  type.equals("spot");
            if(ok) params.getInt(i + 1);
            break;
         case "rgbcon":
         case "seed":
         case "wrtscreen":
            ok = type.equals("dotpatch");
            if(ok) params.getInt(i + 1);
            break;
         case "ndots":
            ok = type.equals("dotpatch") || type.equals("flowfield");
            if(ok)
            {
               int ndots = params.getInt(i + 1);
               ok = (ndots >= 0) && (ndots <= 9999);
            }
            break;
         case "aperture":
            ok = hasAperture;
            if(ok)
            {
               String s = params.getString(i + 1);
               ok = RMVAPERTURES.containsKey(s);

               // user may use the aperture shape names from the Maestro GUI; map these to the names used in JMXDoc.
               if((!ok) && RMVAPERTURES_ALT.containsKey(s))
               {
                  s = RMVAPERTURES_ALT.get(s);
                  ok = true;
               }

               if(ok && (type.equals("grating") || type.equals("plaid"))) ok = !s.contains("annu");
            }
            break;
         case "dim":
            ok = !(type.equals("point") || type.equals("movie"));
            if(ok)
            {
               JSONArray dim = params.getJSONArray(i + 1);
               ok = (dim.length() >= 2) && (dim.length() <= 4);
               if(ok)
               {
                  double w = dim.getDouble(0);
                  double h = dim.getDouble(1);
                  double minW = type.equals("bar") ? 0 : 0.01;
                  ok = (w >= minW) && (w <= 120) && (h >= 0.01) && (h <= 120);

                  if(ok && type.equals("flowfield"))
                     ok = (h < w);
                  if(ok && dim.length() >= 3 && type.equals("bar"))
                  {
                     double daxis = dim.getDouble(2);
                     ok = (daxis >= 0) && (daxis < 360);
                  }
                  if(ok && (type.equals("dotpatch") || type.equals("spot")))
                  {
                     if(dim.length() >= 3)
                     {
                        double iw = dim.getDouble(2);
                        ok = (iw >= 0.01 && iw < w);
                     }
                     if(ok && dim.length() == 4)
                     {
                        double ih = dim.getDouble(3);
                        ok = (ih >= 0.01 && ih < h);
                     }
                  }
               }
            }
            break;
         case "sigma":
            ok = hasAperture;
            if(ok)
            {
               JSONArray sigma = params.getJSONArray(i + 1);
               ok = (sigma.length() == 2) && (sigma.getDouble(0) >= 0) && (sigma.getDouble(1) >= 0);
            }
            break;
         case "pct":
            ok = type.equals("dotpatch");
            if(ok)
            {
               int pct = params.getInt(i + 1);
               ok = pct >= 0 && pct <= 100;
            }
            break;
         case "dotlf":
            ok = type.equals("dotpatch");
            if(ok)
            {
               JSONArray dotlf = params.getJSONArray(i + 1);
               ok = (dotlf.length() == 2) && (dotlf.getDouble(1) >= 0);
               if(ok) dotlf.getInt(0);  // make sure it's parsable as an integer!
            }
            break;
         case "noise":
            ok = type.equals("dotpatch");
            if(ok)
            {
               JSONArray noise = params.getJSONArray(i + 1);
               ok = (noise.length() == 4);
               if(ok)
               {
                  boolean isDir = (noise.getInt(0) != 0);
                  boolean isMult = (noise.getInt(1) != 0);
                  int rng = noise.getInt(2);
                  int intv = noise.getInt(3);
                  int minRng = isDir ? 0 : (isMult ? 1 : 0);
                  int maxRng = isDir ? 180 : (isMult ? 7 : 300);

                  ok = (rng >= minRng) && (rng <= maxRng) && (intv >= 0);
               }
            }
            break;
         case "square":
         case "oriadj":
            ok = type.equals("grating") || (type.equals("plaid"));
            if(ok) params.getInt(i + 1);
            break;
         case "indep":
            ok = type.equals("plaid");
            if(ok) params.getInt(i + 1);
            break;
         case "grat1":
         case "grat2":
            ok = pname.equals("grat1") ? (type.equals("grating") || type.equals("plaid")) : type.equals("plaid");
            if(ok)
            {
               JSONArray grat = params.getJSONArray(i + 1);
               ok = (grat.length() == 5);
               if(ok) grat.getInt(0);
               if(ok)
               {
                  int conRGB = grat.getInt(1);
                  int conR = (conRGB >> 16) & 0x00FF;
                  int conG = (conRGB >> 16) & 0x00FF;
                  int conB = conRGB & 0x00FF;
                  ok = (conR <= 100) && (conG <= 100) && (conB <= 100);
               }
               if(ok)
                  ok = (grat.getDouble(2) >= 0.01) && (grat.getDouble(3) >= 0) && (grat.getDouble(3) < 360) &&
                        (grat.getDouble(4) >= -180) && (grat.getDouble(4) <= 180);
            }
            break;
         case "folder":
         case "file":
            ok = type.equals("movie") || type.equals("image");
            if(ok)
            {
               String s = params.getString(i + 1);
               ok = (!s.isEmpty()) && (s.length() <= RMV_MVF_LEN) && mediaNameVerifier.matcher(s).matches();
            }
            break;
         case "flags":
            ok = type.equals("movie");
            if(ok)
            {
               JSONArray flags = params.getJSONArray(i + 1);
               ok = flags.length() == 3;
               if(ok) for(int j = 0; j < 3; j++) flags.getInt(j);
            }
            break;
         case "flicker":
            JSONArray flickerParams = params.getJSONArray(i + 1);
            ok = (flickerParams.length() == 3);
            for(int j = 0; ok && j < 3; j++)
            {
               int val = flickerParams.getInt(j);
               ok = (val >= 0) && (val <= 99);
            }
            break;
         }
         
         if(!ok)
            throw new JSONException("Bad parameter (name = " + pname + ") for target type = " + type);
      }
   }
   
   /** 
    * Append a new, empty trial set to this JMX document.
    * @param name The name to be assigned to the trial set. It must satisfy <i>Maestro</i> object naming rules and 
    * cannot duplicate the name of an existing trial set.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTrialSet(String name)
   {
      if(isNotValidObjectName(name))
         return("Object name violates Maestro naming rules");
      
      try
      {
         for(int i=0; i<trialSets.length(); i++)
         {
            JSONObject trSet = trialSets.getJSONObject(i);
            if(name.equals(trSet.getString("name")))
               return("Duplicate trial set name!");
         }
         
         JSONObject setAdded = new JSONObject();
         setAdded.put("name", name);
         setAdded.put("trials", new JSONArray());
         trialSets.put(setAdded);
      }
      catch(JSONException jse) { /* should never happen */ }
      
      return("");
   }
   
   private void checkTrialSets() throws JSONException
   {
      if(trialSets.length() == 0) return;
      
      HashMap<String, Object> trsetNamesUsed = new HashMap<>();
      HashMap<String, Object> namesUsedInSet = new HashMap<>();
      for(int i=0; i<trialSets.length(); i++)
      {
         JSONObject trSet = trialSets.getJSONObject(i);
         String name = trSet.getString("name");
         if(trsetNamesUsed.containsKey(name))
            throw new JSONException("Trial set " + i + " --Found duplicate name: " + name);
         trsetNamesUsed.put(name, null);
         if(isNotValidObjectName(name))
            throw new JSONException("Trial set " + i + " --Invalid object name: " + name);
         
         // a trial set con contain individual trial objects or trial subsets, which are groups of related trials
         JSONArray kids = trSet.getJSONArray("trials");
         namesUsedInSet.clear();
         for(int j=0; j<kids.length(); j++)
         {
            JSONObject kid = kids.getJSONObject(j);
            boolean isSubset = kid.has("subset");
            
            String kidName = kid.getString(isSubset ? "subset" : "name");
            if(namesUsedInSet.containsKey(kidName))
               throw new JSONException("Child " + j + " in trial set " + name + " --Duplicate name: " + kidName);
            namesUsedInSet.put(kidName, null);
            if(isNotValidObjectName(kidName))
               throw new JSONException("Child " + j + " in trial set " + name + " --Invalid object name: " + kidName);
            
            try
            { 
               if(isSubset) checkTrialSubset(kid);
               else checkTrial(kid); 
            }
            catch(JSONException jse)
            {
               throw new JSONException("Child " + j + " in trial set " + name + " --" + jse.getMessage());
            }
         }
      }
   }
   
   /**
    * Helper method validates a JSON object encapsulating a <i>Maestro</i> trial subset definition, as it would be 
    * stored in a JMX document. A trial subset, introduced in Maestro v3.1.2, is simply a group of trials that is a 
    * child of a trial set object. A trial subset can only contain trial objects, while a trial set can contain both
    * subsets and individual trials.
    * 
    * @param sub A trial subset definition object, as more fully described in the class header. This method validates
    * the content of the object's "trials" field, which should be a JSON array containing only JSON trial object, no two
    * of which can share the same name. The object's "subset" field, which contains the name of the subset itself, must
    * be validated by the caller.
    * @throws JSONException if the object is not consistent with the definition of a trial subset. The exception message
    * gives a rough idea of where the problem lies, for debugging purposes.
    */
   private void checkTrialSubset(JSONObject sub) throws JSONException
   {
      try
      {
         HashMap<String, Object> trialNamesUsed = new HashMap<>();
         JSONArray jsonTrials = sub.getJSONArray("trials");
         for(int i=0; i<jsonTrials.length(); i++)
         {
            JSONObject trial = jsonTrials.getJSONObject(i);
            String name = trial.getString("name");
            if(trialNamesUsed.containsKey(name))
               throw new JSONException("Trial " + i + " in subset --Duplicate name: " + name);
            trialNamesUsed.put(name, null);
            if(isNotValidObjectName(name))
               throw new JSONException("Trial " + i + " in subset --Invalid object name: " + name);

            checkTrial(trial);
         }
      }
      catch(JSONException jse)
      {
         throw new JSONException("Bad trial subset (" + jse.getMessage() + ")");
      }
   }
   
   /**
    * Append a new trial to the specified trial set in this JMX document, or replace an existing trial in that set.
    * @param set Name of destination trial set. Must exist in document.
    * @param trialObj The trial definition. The required content/format of this <code>JSONObject</code> is described
    * in detail in the class header.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTrial(String set, JSONObject trialObj)
   {
      // find the trial set named
      JSONObject trialSet = null;
      try
      {
         for(int i=0; i<trialSets.length(); i++)
         {
            JSONObject obj = trialSets.getJSONObject(i);
            if(set.equals(obj.getString("name")))
            {
               trialSet = obj;
               break;
            }
         }
      }
      catch(JSONException jse) { /* should never happen */ }
      
      if(trialSet == null) return("Destination trial set does not exist: " + set);
      
      // validate the trial object. If successful, replace a trial with the same name under the destination trial set,
      // or append the new trial to that set.
      try
      {
         // check trial name, which is not checked by checkTrial().
         String trName = trialObj.getString("name");
         if(isNotValidObjectName(trName)) throw new JSONException("Invalid trial name: " + trName);

         checkTrial(trialObj);
         
         JSONArray trials = trialSet.getJSONArray("trials");
         boolean found = false;
         for(int i=0; i<trials.length(); i++)
         {
            JSONObject t = trials.getJSONObject(i);
            if(trName.equals(t.getString("name")))
            {
               trials.put(i, trialObj);
               found = true;
            }
         }
         
         if(!found) trials.put(trialObj);
      }
      catch(JSONException jse)
      {
         return(jse.getMessage());
      }
      
      return("");
   }
   
   /**
    * Helper method validates a JSON object encapsulating a <i>Maestro</i> trial definition, as it would be stored in a
    * JMX document. 
    * @param trial A trial definition object, as more fully described in the class header. This method validates all
    * fields except <i>name</i>, which must be validated by the caller.
    * @throws JSONException if the object is not consistent with the definition of a trial, or if there are any invalid
    * parameter names or values in any of its fields. The exception message gives a rough idea of where the problem 
    * lies, for debugging purposes.
    */
   private void checkTrial(JSONObject trial) throws JSONException
   {
      // this string is included in the JSONException message to help indicate where the problem occurred
      String what = "";
      
      try
      {
         // get number of participating targets and number of segments in trial. We need these to validate trial params.
         int nTgts = trial.getJSONArray("tgts").length();
         if(nTgts == 0) throw new JSONException("Trial target list is empty!");
         int nSegs = trial.getJSONArray("segs").length();
         if(nSegs == 0) throw new JSONException("Trial has no segments!");
         
         // validate general trial parameters in "params" field
         what = "params";
         JSONArray params = trial.getJSONArray("params");
         if(params.length() % 2 != 0) throw new JSONException("Params array must have an even number of elements!");
         
         for(int i=0; i<params.length(); i+=2)
         {
            String pname = params.getString(i);
            boolean ok;
            switch(pname)
            {
            case "chancfg":
               String chcfg = params.getString(i + 1);
               ok = false;
               for(int j = 0; j < chancfgs.length() && !ok; j++)
               {
                  JSONObject chObj = chancfgs.getJSONObject(j);
                  ok = chObj.getString("name").equals(chcfg);
               }
               if(!ok) ok = chcfg.equals("default");  // Maestro predefined channel configuration
               break;
            case "wt":
               int wt = params.getInt(i + 1);
               ok = (wt >= 0) && (wt <= 255);
               break;
            case "keep":
               params.getInt(i + 1);
               ok = true;
               break;
            case "startseg":
            case "failsafeseg":
            case "specialseg":
               int iSeg = params.getInt(i + 1);
               int min = pname.equals("specialseg") ? 1 : 0;
               ok = (min <= iSeg) && (iSeg <= nSegs);
               break;
            case "specialop":
               ok = SPECIALOPS.containsKey(params.getString(i + 1));
               break;
            case "saccvt":
               int vt = params.getInt(i + 1);
               ok = (0 <= vt) && (vt <= 999);
               break;
            case "marksegs":
            {
               JSONArray ar = params.getJSONArray(i + 1);
               ok = ar.length() == 2;
               for(int j = 0; ok && j < 2; j++) ok = (0 <= ar.getInt(j)) && (ar.getInt(j) <= nSegs);
               break;
            }
            case "mtr":
            {
               JSONArray ar = params.getJSONArray(i + 1);
               ok = ar.length() == 3;
               if(ok)
               {
                  ar.getInt(0);
                  int len = ar.getInt(1);
                  int intv = ar.getInt(2);
                  ok = (1 <= len) && (len <= 999) && (100 <= intv) && (intv <= 9999);
               }
               break;
            }
            case "rewpulses":
            {
               JSONArray ar = params.getJSONArray(i + 1);
               ok = ar.length() == 2;
               for(int j = 0; ok && j < 2; j++) ok = (1 <= ar.getInt(j)) && (ar.getInt(j) <= 999);
               break;
            }
            case "rewWHVR":
            {
               // [N1 D1 N2 D2], where 0 <= Nj < Dj <= 100
               JSONArray ar = params.getJSONArray(i + 1);
               ok = ar.length() == 4;
               for(int j = 0; ok && j <= 2; j += 2)
               {
                  ok = (0 <= ar.getInt(j)) && (ar.getInt(j) < ar.getInt(j + 1)) && (ar.getInt(j + 1) <= 100);
               }
               break;
            }
            case "stair":
            {
               JSONArray ar = params.getJSONArray(i + 1);
               ok = ar.length() == 3;
               if(ok)
               {
                  int stairNum = ar.getInt(0);
                  double stairStren = ar.getDouble(1);
                  ar.getInt(2);
                  ok = (0 <= stairNum) && (stairNum <= 5) && (0 <= stairStren) && (stairStren < 1000);
               }
               break;
            }
            default:
               // obsolete XYScope-related trial params are simply ignored
               ok = ("xydotseedalt".equals(pname) || "xyinterleave".equals(pname));
               if(!ok)
                  throw new JSONException("Unrecognized general trial param: " + pname);
            }
            
            if(!ok)
               throw new JSONException("Invalid value specified for general trial param: " + pname);
         }
         
         // validate any perturbations used during trial
         what = "perts";
         JSONArray pertsUsed = trial.getJSONArray("perts");
         if(pertsUsed.length() > 4) throw new JSONException("Too many perturbations in trial");
         for(int i=0; i<pertsUsed.length(); i++)
         {
            JSONArray pert = pertsUsed.getJSONArray(i);
            boolean ok = (pert.length() == 5);
            if(ok)
            {
               String pertName = pert.getString(0);
               ok = false;
               for(int j=0; j<perts.length() && !ok; j++)
               {
                  JSONArray pertDef = perts.getJSONArray(j);
                  ok = pertName.equals(pertDef.getString(0));
               }
            }
            if(ok)
            {
               double amp = pert.getDouble(1);
               ok = (-999.99 <= amp) && (amp <= 999.99);
            }
            if(ok)
            {
               int iSeg = pert.getInt(2);
               ok = (1 <= iSeg) && (iSeg <= nSegs);
            }
            if(ok)
            {
               int iTgt = pert.getInt(3);
               ok = (1 <= iTgt) && (iTgt <= nTgts);
            }
            if(ok)
               ok = PERT_TRAJCMPTS.containsKey(pert.getString(4));

            if(!ok)
               throw new JSONException("Entry " + i + " in trial perturbation table is invalid");
         }

         // validate participating target list -- all targets must exist, and no duplicates.
         what = "tgts";
         JSONArray tgts = trial.getJSONArray("tgts");
         HashMap<String, Object> tgtsInUse = new HashMap<>();
         for(int i=0; i<tgts.length(); i++)
         {
            String s = tgts.getString(i);
            if(tgtsInUse.containsKey(s))
               throw new JSONException("Duplicate entry in trial target list: " + s);
            tgtsInUse.put(s, null);

            if("CHAIR".equals(s)) continue;  // the only remaining supported Maestro 2-era "predefined" target
            
            boolean found = false;
            int slash = s.indexOf('/');
            if(slash > 0 && slash == s.lastIndexOf('/'))
            {
               String set = s.substring(0, slash);
               JSONObject tgSetObj = null;
               for(int j=0; j<targetSets.length(); j++)
               {
                  tgSetObj = targetSets.getJSONObject(j);
                  if(set.equals(tgSetObj.getString("name")))
                     break;
               }
               
               if(tgSetObj != null)
               {
                  JSONArray tgtsInSet = tgSetObj.getJSONArray("targets");
                  String tgname = s.substring(slash+1);
                  for(int j=0; j<tgtsInSet.length() && !found; j++)
                     found = tgname.equals(tgtsInSet.getJSONObject(j).getString("name"));
               }
            }
            
            if(!found) throw new JSONException("Trial target does not exist: " + s);
         }
         
         // validate tagged sections, if any
         what = "tags";
         JSONArray tagSects = trial.getJSONArray("tags");
         HashMap<String, Object> tagsInUse = new HashMap<>();
         List<Integer> segIndices = new ArrayList<>();
         for(int i=0; i<tagSects.length(); i++)
         {
            JSONArray sect = tagSects.getJSONArray(i);
            if(sect.length() != 3) 
               throw new JSONException("Tagged section " + i + " is invalid.");
            
            String tag = sect.getString(0);
            int start = sect.getInt(1);
            int end = sect.getInt(2);
               
            if(tagsInUse.containsKey(tag)) 
               throw new JSONException("Tagged section " + i + " has duplicate label: " + tag);
            tagsInUse.put(tag, null);
            
            if(start < 1 || end < start || end > nSegs)
               throw new JSONException("Tagged section " + i + " has an invalid segment index");
            
            int insPos = -1;
            for(int j=0; j<segIndices.size(); j+=2)
            {
               if((start >= segIndices.get(j) && start <= segIndices.get(j+1)) || 
                     (end >= segIndices.get(j) && end <= segIndices.get(j+1)) ||
                     (start < segIndices.get(j) && end > segIndices.get(j+1)))
                  throw new JSONException("Found an overlap among defined tagged sections!");
               
               if(start < segIndices.get(j))
               {
                  insPos = j;
                  break;
               }
            }
            if(insPos > -1)
            {
               segIndices.add(insPos, end);
               segIndices.add(insPos, start);
            }
            else
            {
               segIndices.add(start);
               segIndices.add(end);
            }
         }

         // validate the list of random variables -- if present (field is optional)
         what = "rvs";
         int numRVs = 0;
         if(trial.has("rvs"))
         {
            JSONArray rvs = trial.getJSONArray("rvs");
            numRVs = rvs.length();
            if(numRVs > 10)
               throw new JSONException("A maximum of 10 RVs may defined in any given trial!");
            for(int i=0; i<numRVs; i++)
            {
               what = "RV " + (i+1);   // 1-based index

               JSONArray rv = rvs.getJSONArray(i);
               String rvType = rv.getString(0);
               switch(rvType)
               {
               case "uniform":
                  // uniform(seed, A, B): seed >= 0; A < B
                  if((rv.getInt(1) < 0) || (rv.getDouble(2) >= rv.getDouble(3)))
                     throw new JSONException("Invalid parameter(s) for a 'uniform' random variable");
                  break;
               case "normal":
                  // normal(seed, M, D, S): seed >= 0, D > 0, S >= 3*D
                  if((rv.getInt(1) < 0) || (rv.getDouble(3) <= 0) ||
                        (rv.getDouble(4) < 3*rv.getDouble(3)))
                     throw new JSONException("Invalid parameter(s) for a 'normal' random variable");
                  break;
               case "exponential":
                  // exponential(seed, L, S): seed >= 0, L > 0, S >= 3/L
                  if((rv.getInt(1) < 0) || (rv.getDouble(2) <= 0) ||
                        (rv.getDouble(3) < 3/rv.getDouble(2)))
                     throw new JSONException("Invalid parameter(s) for an 'exponential' random variable");
                  break;
               case "gamma":
                  // gamma(seed, K, T, S): seed >= 0, K>0, T>0, S >= T*(K + 3*sqrt(K))
                  double paramK = rv.getDouble(2), paramT = rv.getDouble(3);
                  if((rv.getInt(1) < 0) || (paramK <= 0) || (paramT <= 0) ||
                        (rv.getDouble(4 ) <  paramT*(paramK + 3*Math.sqrt(paramK))))
                     throw new JSONException("Invalid parameter(s) for a 'gamma' random variable");
                  break;
               case "function":
                  // function RV defined by a string formula. We only verify that it does not depend on its own
                  // value, and only contains references 'xN' to RVs defined in this list. The RV indices are 0-based
                  // in the formula string!
                  String formula = rv.getString(1);
                  String xRV = "x" + i;
                  if(formula.contains(xRV))
                     throw new JSONException("A 'function' random variable cannot depend on its own value!");
                  for(int j=0; j<10 && i!=j; j++)
                  {
                     xRV = "x" + j;
                     if(formula.contains(xRV) && (j >= numRVs))
                        throw new JSONException("A 'function' random variable depends on an undefined RV!");
                  }
                  break;
               default:
                  throw new JSONException("Invalid random variable type!");
               }
            }
         }

         // validate RV assignments to segment table parameters, if any (field is optional). Ignore the field if no
         // RVs were defined (rather than failing)
         what = "rvuse";
         if((numRVs > 0) && trial.has("rvuse") && (trial.getJSONArray("rvuse").length() > 0))
         {
            JSONArray rvAssigns = trial.getJSONArray("rvuse");
            for(int i=0; i<rvAssigns.length(); i++)
            {
               JSONArray assign = rvAssigns.getJSONArray(i);
               if(assign.length() != 4)
                  throw new JSONException(i + "-th RV assignment is invalid.");

               int rvIdx = assign.getInt(0);
               String paramName = assign.getString(1);
               int segIdx = assign.getInt(2);
               int tgtIdx = assign.getInt(3);

               // all indices are 1-based in keeping with Matlab convention
               if((rvIdx <= 0) || (rvIdx > numRVs))
                  throw new JSONException((i+1) + "-th RV assignment invalid: Bad RV index.");
               if(!RVASSIGNABLE_PARAMS.containsKey(paramName))
                  throw new JSONException((i+1) + "-th RV assignment invalid: Bad param name.");
               if((segIdx <= 0) || (segIdx > nSegs))
                  throw new JSONException((i+1) + "-th RV assignment invalid: Bad segment index.");
               if((!("mindur".equals(paramName) || "maxdur".equals(paramName))) &&
                     ((tgtIdx <= 0) || (tgtIdx > nTgts)))
                  throw new JSONException((i+1) + "-th RV assignment invalid: Bad target trajectory index.");
            }
         }

         // validate the segment table
         what = "segs";
         JSONArray segments = trial.getJSONArray("segs");
         for(int i=0; i<segments.length(); i++)
         {
            what = "segment " + (i+1);
            
            JSONObject segment = segments.getJSONObject(i);
            JSONArray hdr = segment.getJSONArray("hdr");
            JSONArray trajectories = segment.getJSONArray("traj");
            
            // validate any explicit header parameters
            what = "segment " + (i+1) + " hdr";
            boolean ok = (hdr.length() % 2) == 0;
            for(int j=0; ok && j < hdr.length(); j+=2)
            {
               String pname = hdr.getString(j);
               switch(pname)
               {
               case "dur":
                  JSONArray dur = hdr.getJSONArray(j + 1);
                  ok = dur.length() == 2;
                  if(ok)
                  {
                     int min = dur.getInt(0);
                     int max = dur.getInt(1);
                     ok = (0 <= min) && (min <= max);
                  }
                  break;
               case "fix1":
               case "fix2":
                  int iTgt = hdr.getInt(j + 1);
                  ok = (0 <= iTgt) && (iTgt <= nTgts);
                  break;
               case "fixacc":
                  JSONArray fixacc = hdr.getJSONArray(j + 1);
                  ok = fixacc.length() == 2;
                  if(ok) ok = (fixacc.getDouble(0) >= 0.1) && (fixacc.getDouble(1) >= 0.1);
                  break;
               case "grace":
                  ok = (hdr.getInt(j + 1) >= 0);
                  break;
               case "mtrena":
               case "chkrsp":
               case "rmvsync":
                  hdr.getInt(j + 1);
                  break;
               case "marker":
                  int marker = hdr.getInt(j + 1);
                  ok = (0 <= marker) && (marker <= 10);
                  break;
               default:
                  // obsolete param 'xyframe' is simply ignored if present
                  if(!"xyframe".equals(pname))
                     throw new JSONException("Unrecognized header parameter for segment " + (i + 1) + ": " + pname);
               }
            }
            if(!ok) throw new JSONException("Bad header for segment " + (i+1));
            
            // validate all trajectories for the current segment
            what = "segment " + (i+1) + " traj";
            if(trajectories.length() != nTgts)
               throw new JSONException("Missing trajectories for one or more targets in segment " + (i+1));
            for(int iTgt=0; iTgt<nTgts; iTgt++)
            {
               what = "segment " + (i+1) + " traj " + (iTgt + 1);
               JSONArray traj = trajectories.getJSONArray(iTgt);
               ok = (traj.length() % 2) == 0;
               for(int j=0; ok && j<traj.length(); j+=2)
               {
                  String pname = traj.getString(j);
                  switch(pname)
                  {
                  case "on":
                  case "abs":
                  case "snap":
                     traj.getInt(j + 1);  // don't need to check value of any of these flag parameters.
                     break;
                  case "vstab":
                     String vstab = traj.getString(j + 1);
                     ok = vstab.equals("h") || vstab.equals("v") || vstab.equals("hv") || vstab.equals("none");
                     break;
                  case "pos":
                  case "vel":
                  case "acc":
                  case "patvel":
                  case "patacc":
                     JSONArray ar = traj.getJSONArray(j + 1);
                     ok = (ar.length() == 2);
                     if(ok)
                     {
                        ar.getDouble(0);
                        ar.getDouble(1);
                     }
                     break;
                  }
               }
               if(!ok)
                  throw new JSONException("Bad trajectory variables for target " + (iTgt+1) + " in segment " + (i+1));
            }
         }
      }
      catch(JSONException jse)
      {
         throw new JSONException("In trial " + trial.getString("name") + " (" + what + "): " + jse.getMessage());
      }
   }

   /**
    * Append a new empty trial subset to the specified trial set in this JMX document.
    * @param set Name of destination trial set. Must exist in document.
    * @param subName The name of the new trial subset. It cannot duplicate the name of any existing children (trials or
    * other subsets) within the destination set.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTrialSubset(String set, String subName)
   {
      if(isNotValidObjectName(subName))
         return("Object name violates Maestro naming rules");
      
      // find the trial set named
      JSONObject theSet = null;
      try
      {
         for(int i=0; i<trialSets.length(); i++)
         {
            JSONObject obj = trialSets.getJSONObject(i);
            if(set.equals(obj.getString("name")))
            {
               theSet = obj;
               break;
            }
         }
      }
      catch(JSONException jse) { /* should never happen */ }
      
      if(theSet == null) return("Destination trial set does not exist: " + set);
      
      // ensure that proposed subset's name does not match that of an existing trial or subset in destination set. If
      // not, go ahead and append the new subset.
      try
      {
         JSONArray kids = theSet.getJSONArray("trials");
         for(int i=0; i<kids.length(); i++)
         {
            JSONObject kid = kids.getJSONObject(i);
            String kidName = kid.has("subset") ? kid.getString("subset") : kid.getString("name");
            if(kidName.equals(subName))
               return("Subset name duplicates that of an existing object in trial set!");
         }
         
         JSONObject addedSubset = new JSONObject();
         addedSubset.put("subset", subName);
         addedSubset.put("trials", new JSONArray());
         kids.put(addedSubset);
      }
      catch(JSONException jse) { /* should never happen */ }
      
      return("");
   }
   
   /**
    * Append a new trial to the specified trial SUBSET in this JMX document, or replace an existing trial in that 
    * subset.
    * @param set Name of trial set containing the destination subset. Must exist in document.
    * @param subset Name of the trial subset within the set object specified by first argument. Must exist.
    * @param trialObj The trial definition. The required content/format of this <code>JSONObject</code> is described
    * in detail in the class header.
    * @return An empty string if operation is successful; else, a brief message describing why the operation failed. On
    * failure, the JMX document is left unchanged.
    */
   public String addTrialToSubset(String set, String subset, JSONObject trialObj)
   {
      // find the trial subset identified by the first two arguments
      JSONObject theSubset = null;
      try
      {
         JSONObject theSet = null;
         for(int i=0; i<trialSets.length(); i++)
         {
            JSONObject obj = trialSets.getJSONObject(i);
            if(obj.getString("name").equals(set))
            {
               theSet = obj;
               break;
            }
         }
         
         if(theSet != null)
         {
            JSONArray kids = theSet.getJSONArray("trials");
            for(int i=0; i<kids.length(); i++)
            {
               JSONObject kid = kids.getJSONObject(i);
               if(kid.has("subset") && kid.getString("subset").equals(subset))
               {
                  theSubset = kid;
                  break;
               }
            }
         }
      }
      catch(JSONException jse) { /* should never happen */ }
      
      if(theSubset == null) return("Destination trial subset does not exist: " + set + "/" + subset);
      
      // validate the trial object. If successful, replace a trial with the same name under the destination subset,
      // or append the new trial to that subset.
      try
      {
         // check trial name, which is not checked by checkTrial().
         String trName = trialObj.getString("name");
         if(isNotValidObjectName(trName)) throw new JSONException("Invalid trial name: " + trName);

         checkTrial(trialObj);
         
         JSONArray trials = theSubset.getJSONArray("trials");
         boolean found = false;
         for(int i=0; i<trials.length(); i++)
         {
            JSONObject t = trials.getJSONObject(i);
            if(trName.equals(t.getString("name")))
            {
               trials.put(i, trialObj);
               found = true;
            }
         }
         
         if(!found) trials.put(trialObj);
      }
      catch(JSONException jse)
      {
         return(jse.getMessage());
      }
      
      return("");
   }
   

   /** 
    * The JMX document's application settings. A JSON object with fields: 
    * <ul>
    * <li><i>xy</i> : A JSON integer array holding XYScope display properties [w h d del dur fix seed].</li>
    * <li><i>rmv</i> : A JSON integer array holding RMVideo display properties [w h d bkgC sz dur].</li>
    * <li><i>fix</i> : A JSON double array holding Continuous-mode H & V fixation accuracy in deg [hAcc vAcc].</li>
    * <li><i>other</i> : A JSON integer array holding other persisted app settings [d p1 p2 ovride varatio audiorew
    * beep vstabwin].</li>
    * </ul>
    */
   private JSONObject settings = null;
   
   /**
    * All defined channel configurations in the JMX document. A JSON array of JSON objects, each of which is a distinct
    * channel configuration. It may be empty. Each JSON object has two fields:
    * <ul>
    *    <li><i>name</i> : The channel configuration's name. Must be a valid <i>Maestro</i> object name, and no two 
    *    channel configurations can have the same name.</i>
    *    <li><i>channels</i> : JSON array holding descriptions of zero or more data channels in the configuration. Each
    *    such description is a JSON mixed array [ch_name rec? dsp? ofs gain color].</li>
    * </ul>
    */
   private JSONArray chancfgs = null;
   
   /**
    * All defined perturbation waveforms in the JMX document. A JSON array of JSON arrays, each of which describes a 
    * distinct channel configuration. It may be empty. The JSON array defining a perturbation is <i>[name, type, dur, 
    * param1, param2, param3]</i>, where <i>name</i> is the unique name of the perturbation waveform object, <i>type</i>
    * is the perturbation type, <i>dur</i> is its duration in ms, and <i>param1..param3</i> are additional defining
    * parameters that vary by type. Note that <i>param3</i> is ignored and may be omitted when <i>type=="sinusoid"</i>.
    */
   private JSONArray perts = null;

   /**
    * All defined target sets in the JMX document. A JSON array of JSON objects, each of which is a distinct target set.
    * It may be empty (no target sets defined). Each JSON object has two fields:
    * <ul>
    *    <li><i>name</i> : The target set's name. Must be a valid <i>Maestro</i> object name, and no two target sets can
    *    have the same name. Cannot be "Predefined", which is reserved by <i>Maestro</i>.</li>
    *    <li><i>targets</i> : A JSON array of JSON objects, each of which is the definition of a target in this set. The
    *    JSON object has four fields, <i>name, isxy, type, params</i>.</li>
    * </ul>
    */
   private JSONArray targetSets = null;
   
   /**
    * All defined trial sets in the JMX document. A JSON array of JSON objects, each of which is a distinct trial set.
    * It may be empty (no trial sets defined). Each JSON object has two fields:
    * <ul>
    *    <li><i>name</i> : The trial set's name. Must be a valid <i>Maestro</i> object name, and no two trial sets can
    *    have the same name.</li>
    *    <li><i>trials</i> : A JSON array of JSON objects, each of which is the definition of a trial or a trial subset
    *    in this set. A JSON trial object has six required fields, <i>name, params, perts, tgts, tags, segs</i>, and
    *    two optional fields, <i>rvs, rvuse</i>. A trial subset object has two fields, <i>subset</i> is the subset
    *    object's name, while <i>trials</i> is a JSON array of JSON trial objects (it may NOT contain any
    *    subsets!).</li>
    * </ul>
    */
   private JSONArray trialSets = null;
   
   
   /** 
    * The current JMX document version number. 
    * <ul>
    *  <li>1 : Original version number.</li>
    *  <li>2 : Marks the introduction of trial "subsets" in Maestro v3.1.2 (Dec 2014). No migration necessary.</li>
    *  <li>3 : Added support for RMVideo vertical sync flash feature introduced in Maestro 4.0.0, plus the RMVideo
    *  "image" target added in Maestro 3.3.1.</li>
    *  <li>4 : Added VStab sliding-average window length to settings.other. This became a persisted application setting
    *  in Maestro 4.1.1.</li>
    *  <li>4 : Added support for new special op "selectDur", for "selDurByBix" added in Maestro 5.0.1. No change in
    *  structure of JMX doc, so no need for version change.</li>
    * </ul>
    */
   private final static int CURRVERSION = 4;
   
   /**
    * A compiled regular expression that is used to validate <i>Maestro</i> object names: they must have at least one 
    * printable ASCII character that is an alphanumeric character or one of <i>_=.,[]():;#@!$%*-+<>?</i>.
    * ,:;#%*?
    */
   private static final Pattern objNameVerifier =
      Pattern.compile("[a-zA-Z0-9_=.,\\[\\]():;#@!$%*\\-+<>?]+");
   
   /** Maximum length of a <i>Maestro</i> object name. */
   private final static int MAXOBJNAMELEN = 50;
   
   /**
    * A compiled regular expression that is used to validate names of RMVideo media folders and files: they must have at
    * least one printable ASCII character that is an alphanumeric character, the period, or the underscore.
    */
   private static final Pattern mediaNameVerifier = Pattern.compile("[a-zA-Z0-9_.]+");
   
   /** Maximum number of characters in the name of an RMVideo media folder or media file. */
   private final static int RMV_MVF_LEN = 30;
   
   private final static int[] SETTINGS_XY_DEFAULTS = new int[] {300, 300, 800, 10, 1, 0, 0};
   private final static int[] SETTINGS_RMV_DEFAULTS = new int[] {400, 300, 800, 0, 0, 1};
   private final static double[] SETTINGS_FIX_DEFAULTS = new double[] {2.0, 2.0};
   private final static int[] SETTINGS_OTHER_DEFAULTS = new int[] {1500, 25, 25, 0, 1, 0, 0, 1};
   
   private final static HashMap<String, Object> CHANNEL_NAMES;
   // this maps the 16 generic AI channel IDs "aiN" to the corresponding entry in CHANNEL_NAMES
   private final static HashMap<String, String> ALT_CHANNEL_NAMES;
   private final static HashMap<String, Object> CHANNEL_COLORS;
   private final static HashMap<String, Object> PERT_TYPES;
   private final static HashMap<String, Object> RMVTYPES;
   private final static HashMap<String, Object> RMVAPERTURES;
   // maps the aperture names that appear in the Maestro GUI to the actual aperture shape names MAESTRODOC uses.
   private final static HashMap<String, String> RMVAPERTURES_ALT;
   private final static HashMap<String, Object> SPECIALOPS;
   @SuppressWarnings("MismatchedQueryAndUpdateOfCollection")
   private final static HashMap<String, Object> PERT_TRAJCMPTS;
   private final static HashMap<String, Object> RVASSIGNABLE_PARAMS;
   static
   {
      CHANNEL_NAMES = new HashMap<>();
      String[] names = new String[] {"hgpos", "vepos", "hevel", "vevel", "htpos", "vtpos", "hhvel", "hhpos", "hdvel", 
            "htpos2", "vtpos2", "vepos2", "ai12", "ai13", "hgpos2", "spwav", "di0", "di1", "di2", "di3", "di4", "di5", 
            "di6", "di7", "di8", "di9", "di10", "di11", "di12", "di13", "di14", "di15", "fix1_hvel", "fix1_vvel", 
            "fix1_hpos", "fix1_vpos", "fix2_hvel", "fix2_vvel"};
      for(String s : names) CHANNEL_NAMES.put(s, null);
      
      ALT_CHANNEL_NAMES = new HashMap<>();
      for(int i=0; i<16; i++) ALT_CHANNEL_NAMES.put("ai"+ i, names[i]);
      
      CHANNEL_COLORS = new HashMap<>();
      names = new String[] {"white", "red", "green", "blue", "yellow", "magenta", "cyan", "dk green", "orange", 
            "purple", "pink", "med gray"};
      for(String s : names) CHANNEL_COLORS.put(s, null);
      
      PERT_TYPES = new HashMap<>();
      PERT_TYPES.put("sinusoid", null);
      PERT_TYPES.put("pulse train", null);
      PERT_TYPES.put("uniform noise", null);
      PERT_TYPES.put("gaussian noise", null);

      RMVTYPES = new HashMap<>();
      names = new String[] {"point", "dotpatch", "flowfield", "bar", "spot", "grating", "plaid", "movie", "image"};
      for(String s : names) RMVTYPES.put(s, null);
      
      RMVAPERTURES = new HashMap<>();
      RMVAPERTURES.put("rect", null);
      RMVAPERTURES.put("oval", null);
      RMVAPERTURES.put("rectannu", null);
      RMVAPERTURES.put("ovalannu", null);
      
      RMVAPERTURES_ALT = new HashMap<>();
      RMVAPERTURES_ALT.put("rectangular", "rect");
      RMVAPERTURES_ALT.put("elliptical", "oval");
      RMVAPERTURES_ALT.put("rectangular annulus", "rectannu");
      RMVAPERTURES_ALT.put("elliptical annulus", "ovalannu");
      
      SPECIALOPS = new HashMap<>();
      names = new String[] {"none", "skip", "selbyfix", "selbyfix2", "switchfix", "rpdistro", "choosefix1", 
            "choosefix2", "search", "selectDur", "findAndWait"};
      for(String s : names) SPECIALOPS.put(s, null);

      PERT_TRAJCMPTS = new HashMap<>();
      names = new String[] {"winH", "winV", "patH", "patV", "winDir", "patDir", "winSpd", "patSpd", "speed", "direc"};
      for(String s : names) PERT_TRAJCMPTS.put(s, null);

      RVASSIGNABLE_PARAMS = new HashMap<>();
      names = new String[] {"mindur", "maxdur", "hpos", "vpos", "hvel", "vvel", "hacc", "vacc",
            "hpatvel", "vpatvel", "hpatacc", "vpatacc"};
      for(String s : names) RVASSIGNABLE_PARAMS.put(s, null);
   }
   
   
   /**
    * Is the specified string NOT a valid name for a <i>Maestro</i> object? Such names can be up to 50 characters
    * long and can contain only ASCII alphanumeric characters or characters from the set <i>_=.,[]():;#@!$%*-+<>?</i>.
    * @param s Candidate object name.
    * @return True if candidate name is null or does NOT satisfy <i>Maestro</i> object naming rules.
    */
   private static boolean isNotValidObjectName(String s)
   {
      return ((s == null) || (s.length() >= MAXOBJNAMELEN) || !objNameVerifier.matcher(s).matches());
   }
}

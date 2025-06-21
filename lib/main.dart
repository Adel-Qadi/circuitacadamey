import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;


//import 'dart:math';


void main() {
  runApp(CircuitSimulatorApp());
}
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<_CircuitSimulatorScreenState> screenStateKey = GlobalKey();

const String backendHost = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:3000');
Map<int, String> circuitTypes = {};

bool simulationlock = false;
bool netlistpanelvisible = false;
GlobalKey _fileButtonKey = GlobalKey();
GlobalKey _sourceButtonKey  = GlobalKey();
GlobalKey _measurementsButtonKey  = GlobalKey();
Offset globalMousePosition = Offset.zero;

Timer? _longPressTimer;


bool isLoading = false;
int nodecounter =1;
int resistorcounter =1;
int diodecounter =1;
int voltageSourcecounter =1;
int currentsourcecounter =1;
int capacitorcounter =1;
int inductorcounter =1;
int oscilloscopecounter =1;
int transistorcounter =1;

List<html.ImageElement> simulationPlots = [];
List<Component> oscilloscopes=[];
List<OverlayEntry> voltmeterDisplays = [];

void classifyNetlist(String netlist, void Function(String result) onResult) {
  js.context.callMethod('classifyNetlistWithPuter', [
    netlist,
    (String result) {
      onResult(result); // Send result back to Flutter
    }
  ]);
}


Future<String> classifyNetlistOpenAI(String netlist) async {
  final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
  final prompt = '''
tell me what type of circuit this is $netlist, but only say its type with no addittional explanation, dont even include words like this is or what not, dont mention the type of analysis ran by the circuit just mention the circuit itself, also dont be creative treat this as temp0 request, oh and i want actual circuit types, this is for an educational tool so just tell me types that are relevant for an electronic engineer.
''';

  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer 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',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "model": "openai/gpt-4o-mini",  // or "gpt-4" if you want and your key has access
      "messages": [
        {"role": "user", "content": prompt}
      ]
    }),
  );

  if (res.statusCode == 200) {
    final content = jsonDecode(res.body)['choices'][0]['message']['content'];
    return content.trim().split(RegExp(r'[\n.]'))[0];
  } else {
    print('❌ OpenAI error: ${res.body}');
    return 'error';
  }
}

Future<String?> fetchScanResult() async {
  final uri = Uri.parse('http://localhost:3000/runscam');


  try {
    final response = await http.post(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['result'];
    } else {
      print('Failed to fetch result: ${response.body}');
    }
  } catch (e) {
    print('Error during fetch: $e');
  }

  return null;
}

class CircuitSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       debugShowCheckedModeBanner: false,
      title: 'CircuitAcademy',
        navigatorKey: globalNavigatorKey, // Assign global key
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.grey[300],
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: CircuitSimulatorScreen(key: screenStateKey),
    );
  }
}

class CircuitSimulatorScreen extends StatefulWidget {
  CircuitSimulatorScreen({Key? key}) : super(key: key); // ✅ Accepts a Key now

  @override
  _CircuitSimulatorScreenState createState() => _CircuitSimulatorScreenState();
}


class _CircuitSimulatorScreenState extends State<CircuitSimulatorScreen> {
  @override
void initState() {
  super.initState();
  _checkForAutoLoadFile(); // 🔁 Automatically check on launch
}
void _checkForAutoLoadFile() async {
  final uri = Uri.base;
  final fileUrl = uri.queryParameters['textFileURL'];

  if (fileUrl != null && fileUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final fileContent = utf8.decode(response.bodyBytes);
        loadStateFromContent(fileContent); // 👈 Replace with your actual function
      } else {
        print('Failed to fetch file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching file: $e');
    }
  }
}

  List<Component> components = [];
  static const double gridSize = 50.0;
  static const double viewableGridWidth = 1200; // Viewable grid width before scrolling
  static const double totalGridWidth = 5000; // Total grid width with scrolling
  static const double restrictedGridWidth = 1700; // Restrict placement within this width
  static const double gridHeight = 5000;
  List<String> componentPositions = [];
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Offset? lastWirePosition; // ✅ Stores the last placed wire's position
  double _redoButtonOpacity = 0.5;
  double _undoButtonOpacity = 0.5;
  bool isDrawingWires = false; // ✅ Tracks if user is holding left-click to draw wires


Component? getComponentAtAdjustedMousePosition(Offset mousePosition) {
  // ✅ Apply the offset before checking for the component
  Offset adjustedMousePos = mousePosition + Offset(-10, -30);

  for (var comp in components) {
    if ((adjustedMousePos.dx >= comp.position.dx && adjustedMousePos.dx <= comp.position.dx + 50) &&
        (adjustedMousePos.dy >= comp.position.dy && adjustedMousePos.dy <= comp.position.dy + 50)) {
      return comp; // ✅ Return the first component found at the adjusted mouse position
    }
  }
  return null; // ❌ No component found at this position
}



/*
List<Map<String, dynamic>> _saveComponentsToList() {
  List<Map<String, dynamic>> savedComponents = [];

  for (var comp in components) {
    savedComponents.add({
      "type": comp.type.toString().split('.').last, // Convert enum to string
      "x": comp.position.dx, // Store X position
      "y": comp.position.dy, // Store Y position
      "value": comp.value, // Store value (nullable for wires)
      "rotation": comp.rotation, // Store rotation
    });
  }

 // print("✅ Saved Components: $savedComponents"); // Debugging log
  return savedComponents;
}

*/
List<Map<String, dynamic>> _saveComponentsToList() {
  List<Map<String, dynamic>> savedComponents = [];

  for (var comp in components) {
    savedComponents.add({
      "type": comp.type.toString().split('.').last,
      "x": comp.position.dx,
      "y": comp.position.dy,
      "rotation": comp.rotation,
      "value": comp.value,
      "node": comp.node,
      "adjacent": comp.adjacent,
      "v1": comp.v1,
      "v2": comp.v2,
      "td": comp.td,
      "tr": comp.tr,
      "tf": comp.tf,
      "pw": comp.pw,
      "per": comp.per,
      "vo": comp.vo,
      "va": comp.va,
      "freq": comp.freq,
      "theta": comp.theta,
      "phase": comp.phase,
      "componentNumber": comp.componentNumber,
    });
  }

  return savedComponents;
}

List<List<Map<String, dynamic>>> componentHistory = [[] ];

List<List<Map<String, dynamic>>> REDOcomponentHistory = [];

void _saveComponentsState() {
  // Save current component list as a new snapshot
  componentHistory.add(_saveComponentsToList());
  
  print("📌 Saved State! Stack Size: ${componentHistory.length}");

  _undoButtonOpacity =1.0;
}

void _REDOsaveComponentsState() {
  // Save current component list as a new snapshot
  REDOcomponentHistory.add(_saveComponentsToList());
  
  print("📌 Saved State! Stack Size: ${componentHistory.length}");

  _redoButtonOpacity =1.0;
}

void unhighlightAll() {
  setState(() {
    for (var comp in components) {
      if (comp.highlighted) {
        comp.highlighted = false;
        if (comp.rotation == 1000) {
          comp.rotation = 0;
        } else {
          comp.rotation ~/= 10;
        }
      }
    }
  });
_updateWireConnections();
 
}

void TRUEhighlightAll() {
  setState(() {
    for (var comp in components) {
      if (!comp.highlighted) { // ✅ Only highlight non-highlighted components
        comp.highlighted = true;
        if (comp.rotation < 10) {
          comp.rotation = 1000;
        } else {
          comp.rotation *= 10;
        }
      }
    }
  });
_updateWireConnections();
}

void highlightAll() {
  bool allHighlighted = components.isNotEmpty && components.every((comp) => comp.highlighted);

  if (allHighlighted) {
    unhighlightAll(); // ✅ If all are highlighted, unhighlight them
  } else {
    setState(() {
      for (var comp in components) {
        if (!comp.highlighted) { // ✅ Only highlight non-highlighted components
          comp.highlighted = true;
          if (comp.rotation == 0) {
            comp.rotation = 1000;
          } else {
            comp.rotation *= 10;
          }
        }
      }
    });
  }
_updateWireConnections();
}

/*
void _restoreLastState() {
  if (componentHistory.isNotEmpty) {
    // Get the last saved state (list of components)
    _REDOsaveComponentsState();
    _redoButtonOpacity=1;
    _undoButtonOpacity=1;
    List<Map<String, dynamic>> lastState = componentHistory.removeLast();
  

    // ✅ Step 1: Clear all components from the grid
    setState(() {
      components.clear();
    });

    // ✅ Step 2: Re-add all components from the saved state
    for (var compData in lastState) {
      ComponentType? restoredType;
      
      // Convert string back to ComponentType
      switch (compData["type"]) {
        case "resistor":
          restoredType = ComponentType.resistor;
          break;
        case "DCvoltageSource":
          restoredType = ComponentType.DCvoltageSource;
          break;
        case "acvoltagesourcepulse":
          restoredType = ComponentType.acvoltagesourcepulse;
          break;
        case "acvoltagesourcesin":
          restoredType = ComponentType.acvoltagesourcesin;
          break;
        case "diode":
          restoredType = ComponentType.diode;
          break;
        case "wire":
          restoredType = ComponentType.wire;
          break;
          case "ground":
          restoredType = ComponentType.ground;
          break;
          case "transistor":
          restoredType = ComponentType.transistor;
          break;
        default:
          print("⚠ Unknown component type: ${compData["type"]}");
          continue; // Skip unknown components
      }

      _addComponentAtPosition(
        restoredType,
        Offset(compData["x"], compData["y"]),
        value: compData["value"],
        rotation: compData["rotation"],
      );

      print(compData); // Debugging log
    }

    print("🔄 Restored last state. Stack size: ${componentHistory.length}");
  } else {
    print("⚠ No previous states to restore!");

      
        _undoButtonOpacity=0.5;

  }

 
  _updateWireConnections();
}
*/
void _restoreLastState() {
  if(!simulationlock){
  if (componentHistory.isNotEmpty) {
    // Save current state for redo
    _REDOsaveComponentsState();
    _redoButtonOpacity = 1;
    _undoButtonOpacity = 1;

    List<Map<String, dynamic>> lastState = componentHistory.removeLast();

    // ✅ Step 1: Clear current components
    setState(() {
      components.clear();
    });

    // ✅ Step 2: Reconstruct all components from saved data
    for (var compData in lastState) {
      ComponentType? restoredType;

      // Convert saved string back to ComponentType
      switch (compData["type"]) {
        case "resistor":
          restoredType = ComponentType.resistor;
          break;
        case "DCvoltageSource":
          restoredType = ComponentType.DCvoltageSource;
          break;
        case "currentsource":
          restoredType = ComponentType.currentsource;
          break;
        case "acvoltagesourcepulse":
          restoredType = ComponentType.acvoltagesourcepulse;
          break;
        case "acvoltagesourcesin":
          restoredType = ComponentType.acvoltagesourcesin;
          break;
        case "diode":
          restoredType = ComponentType.diode;
          break;
        case "wire":
          restoredType = ComponentType.wire;
          break;
        case "ground":
          restoredType = ComponentType.ground;
          break;
        case "transistor":
          restoredType = ComponentType.transistor;
          break;
        case "capacitor":
          restoredType = ComponentType.capacitor;
          break;
        case "inductor":
          restoredType = ComponentType.inductor;
          break;
        case "oscilloscope":
          restoredType = ComponentType.oscilloscope;
          break;
        case "voltmeter":
          restoredType = ComponentType.voltmeter;
          break;
        case "ammeter":
          restoredType = ComponentType.ammeter;
          break;
        default:
          print("⚠ Unknown component type: ${compData["type"]}");
          continue;
      }

      // ✅ Use all saved values in add function
      _addComponentAtPosition(
        restoredType,
        Offset(compData["x"], compData["y"]),
        value: compData["value"],
        rotation: compData["rotation"] ?? 0,
        componentNumber: compData["componentNumber"] ?? 0,
        node: compData["node"] ?? false,
        adjacent: compData["adjacent"] ?? false,
        v1: compData["v1"] ?? 0,
        v2: compData["v2"] ?? 10,
        td: compData["td"] ?? 0,
        tr: compData["tr"] ?? 1,
        tf: compData["tf"] ?? 1,
        pw: compData["pw"] ?? 10,
        per: compData["per"] ?? 20,
        vo: compData["vo"] ?? 0,
        va: compData["va"] ?? 5,
        freq: compData["freq"] ?? 50000,
        theta: compData["theta"] ?? 0,
        phase: compData["phase"] ?? 0,
      );

      print(compData); // Debugging log
    }

    print("🔄 Restored last state. Stack size: ${componentHistory.length}");
  } else {
    print("⚠ No previous states to restore!");
    _undoButtonOpacity = 0.5;
  }

  _updateWireConnections();
}}

void _clearRedo()
{
  REDOcomponentHistory.clear();
  _redoButtonOpacity=0.5;
  updateUI();

}
/*
void _REDOrestoreLastState() {
  if (REDOcomponentHistory.isNotEmpty) {
    // Get the last saved state (list of components)
    _saveComponentsState();
    List<Map<String, dynamic>> lastState = REDOcomponentHistory.removeLast();

    // ✅ Step 1: Clear all components from the grid
    setState(() {
      components.clear();
    });

    // ✅ Step 2: Re-add all components from the saved state
    for (var compData in lastState) {
      ComponentType? restoredType;
      
      // Convert string back to ComponentType
      switch (compData["type"]) {
        case "resistor":
          restoredType = ComponentType.resistor;
          break;
        case "DCvoltageSource":
          restoredType = ComponentType.DCvoltageSource;
          break;
        case "acvoltagesourcepulse":
          restoredType = ComponentType.acvoltagesourcepulse;
          break;
        case "acvoltagesourcesin":
          restoredType = ComponentType.acvoltagesourcesin;
          break;
        case "diode":
          restoredType = ComponentType.diode;
          break;
        case "wire":
          restoredType = ComponentType.wire;
          break;
           case "transistor":
          restoredType = ComponentType.transistor;
          break;
        default:
          print("⚠ Unknown component type: ${compData["type"]}");
          continue; // Skip unknown components
      }

      _addComponentAtPosition(
        restoredType,
        Offset(compData["x"], compData["y"]),
        value: compData["value"],
        rotation: compData["rotation"],
      );

      print(compData); // Debugging log
    }

    print("🔄 Restored last state. Stack size: ${REDOcomponentHistory.length}");
  } else {
    print("⚠ No previous states to restore!");
    _redoButtonOpacity=0.5;
   
  }

 
  _updateWireConnections();
   updateUI();
}
*/
void _REDOrestoreLastState() {
  if(!simulationlock){
  if (REDOcomponentHistory.isNotEmpty) {
    // Save current state to the undo stack
    _saveComponentsState();

    List<Map<String, dynamic>> lastState = REDOcomponentHistory.removeLast();

    // ✅ Step 1: Clear current components
    setState(() {
      components.clear();
    });

    // ✅ Step 2: Re-add all components using full saved data
    for (var compData in lastState) {
      ComponentType? restoredType;

      // Convert saved string back to ComponentType
      switch (compData["type"]) {
        case "resistor":
          restoredType = ComponentType.resistor;
          break;
        case "DCvoltageSource":
          restoredType = ComponentType.DCvoltageSource;
          break;
        case "currentsource":
          restoredType = ComponentType.currentsource;
          break;
        case "acvoltagesourcepulse":
          restoredType = ComponentType.acvoltagesourcepulse;
          break;
        case "acvoltagesourcesin":
          restoredType = ComponentType.acvoltagesourcesin;
          break;
        case "diode":
          restoredType = ComponentType.diode;
          break;
        case "wire":
          restoredType = ComponentType.wire;
          break;
        case "ground":
          restoredType = ComponentType.ground;
          break;
        case "transistor":
          restoredType = ComponentType.transistor;
          break;
        case "capacitor":
          restoredType = ComponentType.capacitor;
          break;
        case "inductor":
          restoredType = ComponentType.inductor;
          break;
        case "oscilloscope":
          restoredType = ComponentType.oscilloscope;
          break;
        case "voltmeter":
          restoredType = ComponentType.voltmeter;
        case "ammeter":
          restoredType = ComponentType.ammeter;
          break;
        default:
          print("⚠ Unknown component type: ${compData["type"]}");
          continue;
      }

      _addComponentAtPosition(
        restoredType,
        Offset(compData["x"], compData["y"]),
        value: compData["value"],
        rotation: compData["rotation"] ?? 0,
        componentNumber: compData["componentNumber"] ?? 0,
        node: compData["node"] ?? false,
        adjacent: compData["adjacent"] ?? false,
        v1: compData["v1"] ?? 0,
        v2: compData["v2"] ?? 10,
        td: compData["td"] ?? 0,
        tr: compData["tr"] ?? 1,
        tf: compData["tf"] ?? 1,
        pw: compData["pw"] ?? 10,
        per: compData["per"] ?? 20,
        vo: compData["vo"] ?? 0,
        va: compData["va"] ?? 5,
        freq: compData["freq"] ?? 50000,
        theta: compData["theta"] ?? 0,
        phase: compData["phase"] ?? 0,
      );

      print(compData); // Debug log
    }

    print("🔄 Redo restore complete. Stack size: ${REDOcomponentHistory.length}");
  } else {
    print("⚠ No future states to redo!");
    _redoButtonOpacity = 0.5;
  }

  _updateWireConnections();
  updateUI();
}}


void _showNotification(String message) {
  ScaffoldMessenger.of(globalNavigatorKey.currentContext!).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}


void saveStateToFile2() {

    if (components.isEmpty) {
    _showNotification("⚠ No components detected. File not saved.");
    return;
  }
  unhighlightAll();

  List<Map<String, dynamic>> savedData = _saveComponentsToList();
  String jsonString = jsonEncode(savedData); // Convert to JSON format

  // Add a special identifier to avoid loading random text files
  String fileContent = "***CIRCUITACADEMY_SAVEFILE***\n$jsonString";

  final blob = html.Blob([fileContent], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "circuit_save.txt")
    ..click();
  html.Url.revokeObjectUrl(url);
}

void _showSaveFileDialog() {
  TextEditingController fileNameController = TextEditingController();
  FocusNode textFieldFocus = FocusNode();

  showDialog(
    context: globalNavigatorKey.currentContext!,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Focus the text field after a small delay
          Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(textFieldFocus);
          });

          return RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  String fileName = fileNameController.text.trim();
                  if (fileName.isNotEmpty) {
                    saveStateToFile(fileName);
                    Navigator.of(context).pop();
                  }
                   else {
                      saveStateToFile("circuit_save");
                      Navigator.of(context).pop();
                    }
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: AlertDialog(
              title: Text("Save File"),
              content: TextField(
                controller: fileNameController,
                focusNode: textFieldFocus,
                decoration: InputDecoration(
                  labelText: "Enter file name",
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    String fileName = fileNameController.text.trim();
                    if (fileName.isNotEmpty) {
                      saveStateToFile(fileName);
                      Navigator.of(context).pop();
                    }
                    else {
                      saveStateToFile("circuit_save");
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text("Save"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/*
void loadStateFromFile() {

  componentHistory.clear();
 // componentHistory.add([]);
  REDOcomponentHistory.clear();
  _undoButtonOpacity=0.5;
  _redoButtonOpacity=0.5;
  html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.accept = ".txt"; // Only allow text files
  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final file = uploadInput.files!.first;
    final reader = html.FileReader();

    reader.readAsText(file);
    reader.onLoadEnd.listen((event) {
      String fileContent = reader.result as String;

      // ✅ Step 1: Validate the file format
      if (!fileContent.startsWith("***CIRCUITACADEMY_SAVEFILE***\n")) {
        print("⚠ Invalid file! Not a valid CircuitAcademy save file.");
        return;
      }

      // ✅ Step 2: Remove header and decode JSON
      String jsonString = fileContent.replaceFirst("***CIRCUITACADEMY_SAVEFILE***\n", "");
      List<dynamic> loadedData = jsonDecode(jsonString);

      // ✅ Step 3: Clear current components and restore from file
      setState(() {
        components.clear();
        for (var compData in loadedData) {
          ComponentType? restoredType;

          switch (compData["type"]) {
            case "resistor":
              restoredType = ComponentType.resistor;
              break;
            case "DCvoltageSource":
              restoredType = ComponentType.DCvoltageSource;
              break;
            case "acvoltagesourcepulse":
              restoredType = ComponentType.acvoltagesourcepulse;
              break;
            case "acvoltagesourcesin":
              restoredType = ComponentType.acvoltagesourcesin;
              break;
            case "diode":
              restoredType = ComponentType.diode;
              break;
            case "wire":
              restoredType = ComponentType.wire;
              break;
              case "ground":
              restoredType = ComponentType.ground;
              break;
              case "transistor":
              restoredType = ComponentType.transistor;
              break;
            default:
              print("⚠ Unknown component type: ${compData["type"]}");
              continue;
          }

          _addComponentAtPosition(
            restoredType,
            Offset(compData["x"], compData["y"]),
            value: compData["value"],
            rotation: compData["rotation"],
          );
        }
      });

      print("✅ Circuit state loaded successfully!");
    });
  });
}
*/

  void loadStateFromFile() {
    simulationlock=false;
    netlistpanelvisible = simulationlock;
    componentHistory.clear();
    REDOcomponentHistory.clear();
    _undoButtonOpacity = 0.5;
    _redoButtonOpacity = 0.5;

    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = ".txt"; // Only allow text files
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files!.first;
      final reader = html.FileReader();

      reader.readAsText(file);
      reader.onLoadEnd.listen((event) {
        String fileContent = reader.result as String;

        // ✅ Step 1: Validate header
        if (!fileContent.startsWith("***CIRCUITACADEMY_SAVEFILE***\n")) {
          print("⚠ Invalid file! Not a valid CircuitAcademy save file.");
          return;
        }

        // ✅ Step 2: Decode JSON after removing header
        String jsonString = fileContent.replaceFirst("***CIRCUITACADEMY_SAVEFILE***\n", "");
        List<dynamic> loadedData = jsonDecode(jsonString);

        // ✅ Step 3: Clear current components and load all saved ones
        setState(() {
          components.clear();

          for (var compData in loadedData) {
            ComponentType? restoredType;

            switch (compData["type"]) {
              case "resistor":
                restoredType = ComponentType.resistor;
                if(compData["componentNumber"]>resistorcounter)
                resistorcounter=compData["componentNumber"]+ 1;
                break;
              case "DCvoltageSource":
                restoredType = ComponentType.DCvoltageSource;
                if(compData["componentNumber"]>voltageSourcecounter)
                voltageSourcecounter=compData["componentNumber"]+ 1;
                break;
              case "currentsource":
                restoredType = ComponentType.currentsource;
                if(compData["componentNumber"]>currentsourcecounter)
                currentsourcecounter=compData["componentNumber"]+ 1;
                break;
              case "acvoltagesourcepulse":
                restoredType = ComponentType.acvoltagesourcepulse;
                if(compData["componentNumber"]>voltageSourcecounter)
                voltageSourcecounter=compData["componentNumber"]+ 1;
                break;
              case "acvoltagesourcesin":
                restoredType = ComponentType.acvoltagesourcesin;
                if(compData["componentNumber"]>voltageSourcecounter)
                voltageSourcecounter=compData["componentNumber"]+ 1;
                break;
              case "diode":
                restoredType = ComponentType.diode;
                if(compData["componentNumber"]>diodecounter)
                diodecounter=compData["componentNumber"]+ 1;
                break;
              case "wire":
                restoredType = ComponentType.wire;
                break;
              case "ground":
                restoredType = ComponentType.ground;
                break;
              case "transistor":
                restoredType = ComponentType.transistor;
                if(compData["componentNumber"]>transistorcounter)
                transistorcounter=compData["componentNumber"]+ 1;
                break;
              case "capacitor":
                restoredType = ComponentType.capacitor;
                if(compData["componentNumber"]>capacitorcounter)
                capacitorcounter=compData["componentNumber"]+ 1;
                break;
              case "inductor":
                restoredType = ComponentType.inductor;
                if(compData["componentNumber"]>inductorcounter)
                inductorcounter=compData["componentNumber"]+ 1;
                break;
              case "oscilloscope":
                restoredType = ComponentType.oscilloscope;
                if(compData["componentNumber"]>oscilloscopecounter)
                oscilloscopecounter=compData["componentNumber"]+ 1;
                break;
              case "voltmeter":
                restoredType = ComponentType.voltmeter;
              case "ammeter":
                restoredType = ComponentType.ammeter;
                break;
              default:
                print("⚠ Unknown component type: ${compData["type"]}");
                continue;
            }

            _addComponentAtPosition(
              restoredType,
              Offset(compData["x"], compData["y"]),
              value: compData["value"],
              rotation: compData["rotation"] ?? 0,
              componentNumber: compData["componentNumber"] ?? 0,
              node: compData["node"] ?? false,
              adjacent: compData["adjacent"] ?? false,
              v1: compData["v1"] ?? 0,
              v2: compData["v2"] ?? 10,
              td: compData["td"] ?? 0,
              tr: compData["tr"] ?? 1,
              tf: compData["tf"] ?? 1,
              pw: compData["pw"] ?? 10,
              per: compData["per"] ?? 20,
              vo: compData["vo"] ?? 0,
              va: compData["va"] ?? 5,
              freq: compData["freq"] ?? 50000,
              theta: compData["theta"] ?? 0,
              phase: compData["phase"] ?? 0,
            );
          }
        });

        print("✅ Circuit state loaded successfully!");
      });
    });
  }

void loadStateFromContent(String fileContent) {
  simulationlock = false;
  netlistpanelvisible = simulationlock;
  componentHistory.clear();
  REDOcomponentHistory.clear();
  _undoButtonOpacity = 0.5;
  _redoButtonOpacity = 0.5;

  // ✅ Step 1: Validate header
  if (!fileContent.startsWith("***CIRCUITACADEMY_SAVEFILE***\n")) {
    print("⚠ Invalid file! Not a valid CircuitAcademy save file.");
    return;
  }

  // ✅ Step 2: Decode JSON after removing header
  String jsonString = fileContent.replaceFirst("***CIRCUITACADEMY_SAVEFILE***\n", "");
  List<dynamic> loadedData = jsonDecode(jsonString);

  // ✅ Step 3: Clear current components and load all saved ones
  setState(() {
    components.clear();

    for (var compData in loadedData) {
      ComponentType? restoredType;

      switch (compData["type"]) {
        case "resistor":
          restoredType = ComponentType.resistor;
          if (compData["componentNumber"] > resistorcounter)
            resistorcounter = compData["componentNumber"] + 1;
          break;
        case "DCvoltageSource":
          restoredType = ComponentType.DCvoltageSource;
          if (compData["componentNumber"] > voltageSourcecounter)
            voltageSourcecounter = compData["componentNumber"] + 1;
          break;
        case "currentsource":
          restoredType = ComponentType.currentsource;
          if (compData["componentNumber"] > currentsourcecounter)
            currentsourcecounter = compData["componentNumber"] + 1;
          break;
        case "acvoltagesourcepulse":
          restoredType = ComponentType.acvoltagesourcepulse;
          if (compData["componentNumber"] > voltageSourcecounter)
            voltageSourcecounter = compData["componentNumber"] + 1;
          break;
        case "acvoltagesourcesin":
          restoredType = ComponentType.acvoltagesourcesin;
          if (compData["componentNumber"] > voltageSourcecounter)
            voltageSourcecounter = compData["componentNumber"] + 1;
          break;
        case "diode":
          restoredType = ComponentType.diode;
          if (compData["componentNumber"] > diodecounter)
            diodecounter = compData["componentNumber"] + 1;
          break;
        case "wire":
          restoredType = ComponentType.wire;
          break;
        case "ground":
          restoredType = ComponentType.ground;
          break;
        case "transistor":
          restoredType = ComponentType.transistor;
          if (compData["componentNumber"] > transistorcounter)
            transistorcounter = compData["componentNumber"] + 1;
          break;
        case "capacitor":
          restoredType = ComponentType.capacitor;
          if (compData["componentNumber"] > capacitorcounter)
            capacitorcounter = compData["componentNumber"] + 1;
          break;
        case "inductor":
          restoredType = ComponentType.inductor;
          if (compData["componentNumber"] > inductorcounter)
            inductorcounter = compData["componentNumber"] + 1;
          break;
        case "oscilloscope":
          restoredType = ComponentType.oscilloscope;
          if (compData["componentNumber"] > oscilloscopecounter)
            oscilloscopecounter = compData["componentNumber"] + 1;
          break;
        case "voltmeter":
          restoredType = ComponentType.voltmeter;
          break;
        case "ammeter":
          restoredType = ComponentType.ammeter;
          break;
        default:
          print("⚠ Unknown component type: ${compData["type"]}");
          continue;
      }

      _addComponentAtPosition(
        restoredType,
        Offset(compData["x"], compData["y"]),
        value: compData["value"],
        rotation: compData["rotation"] ?? 0,
        componentNumber: compData["componentNumber"] ?? 0,
        node: compData["node"] ?? false,
        adjacent: compData["adjacent"] ?? false,
        v1: compData["v1"] ?? 0,
        v2: compData["v2"] ?? 10,
        td: compData["td"] ?? 0,
        tr: compData["tr"] ?? 1,
        tf: compData["tf"] ?? 1,
        pw: compData["pw"] ?? 10,
        per: compData["per"] ?? 20,
        vo: compData["vo"] ?? 0,
        va: compData["va"] ?? 5,
        freq: compData["freq"] ?? 50000,
        theta: compData["theta"] ?? 0,
        phase: compData["phase"] ?? 0,
      );
    }
  });

  print("✅ Circuit state loaded successfully (from content)!");
}

void saveStateToFile(String fileName) {
  if (components.isEmpty) {
    // Show a notification if the grid is empty
    ScaffoldMessenger.of(globalNavigatorKey.currentContext!).showSnackBar(
      SnackBar(content: Text("⚠ No components detected! Nothing to save.")),
    );
    return;
  }
  unhighlightAll();

  List<Map<String, dynamic>> savedData = _saveComponentsToList();
  String jsonData = jsonEncode(savedData);

  // ✅ Add a special identifier to prevent loading random files
  String fileContent = "***CIRCUITACADEMY_SAVEFILE***\n$jsonData";

  // Create a Blob for file download
  final blob = html.Blob([fileContent], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create a hidden anchor tag to trigger download
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.txt")
    ..click();

  html.Url.revokeObjectUrl(url); // ✅ Free up memory

  print("✅ Saved file: $fileName.txt");
}



void _showLoadFileDialog() {
  if (components.isEmpty){ loadStateFromFile();}
  else{
  showDialog(
    context: globalNavigatorKey.currentContext!,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Load File"),
        content: Text("Warning: Loading a new file will erase the current grid. Do you want to continue?"),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text("Cancel"),
          ),
          // Save & Load Button
          TextButton(
            onPressed: () {
              saveStateToFile2();  // ✅ Save current state
              Navigator.of(context).pop(); // Close the dialog
              Future.delayed(Duration(milliseconds: 300), () {
                loadStateFromFile();  // ✅ Then load the new file
              });
            },
            child: Text("Save & Load"),
          ),
          // Load Anyway Button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              loadStateFromFile();  // ✅ Load new file without saving
            },
            child: Text("Load Anyway"),
          ),
        ],
      );
    },
  );
  }
  
}
/*
void _loadComponentsFromList(List<Map<String, dynamic>> savedComponents) {
  setState(() {
    components.clear(); // Remove current components before loading
    for (var comp in savedComponents) {
      components.add(Component(
        type: _getComponentTypeFromString(comp["type"]),
        position: Offset(comp["x"], comp["y"]),
        value: comp["value"],
        rotation: comp["rotation"],
      ));
    }
  });

  print("✅ Loaded Components from List!");
}
*/
void _loadComponentsFromList(List<Map<String, dynamic>> savedComponents) {
  setState(() {
    components.clear(); // Clear existing components

    for (var comp in savedComponents) {
      components.add(Component(
        type: _getComponentTypeFromString(comp["type"]),
        position: Offset(comp["x"], comp["y"]),
        rotation: comp["rotation"],
        value: comp["value"],
        node: comp["node"] ?? false,
        adjacent: comp["adjacent"] ?? false,
        v1: comp["v1"] ?? 0,
        v2: comp["v2"] ?? 10,
        td: comp["td"] ?? 0,
        tr: comp["tr"] ?? 1,
        tf: comp["tf"] ?? 1,
        pw: comp["pw"] ?? 10,
        per: comp["per"] ?? 20,
        vo: comp["vo"] ?? 0,
        va: comp["va"] ?? 5,
        freq: comp["freq"] ?? 50000,
        theta: comp["theta"] ?? 0,
        phase: comp["phase"] ?? 0,
        componentNumber: comp["componentNumber"] ?? 0,
      ));
    }
  });

  print("✅ Loaded Components from List!");
}

ComponentType _getComponentTypeFromString(String type) {
  switch (type) {
    case "resistor":
      return ComponentType.resistor;
    case "DCvoltageSource":
      return ComponentType.DCvoltageSource;
    case "currentsource":
      return ComponentType.currentsource;
    case "acvoltagesourcepulse":
      return ComponentType.acvoltagesourcepulse;
    case "acvoltagesourcesin":
      return ComponentType.acvoltagesourcesin;
    case "diode":
      return ComponentType.diode;
    case "wire":
      return ComponentType.wire;
      case "ground":
      return ComponentType.ground;
    default:
      throw Exception("Unknown component type: $type");
  }
}

/*
void _addComponentAtPosition(ComponentType type, Offset position, {double? value, int rotation = 0}) {
  setState(() {
    components.add(Component(
      type: type,
      position: _snapToGrid(position), // ✅ Snap position to the grid
      value: value, // ✅ Assign value if applicable
      rotation: rotation, // ✅ Assign rotation
    ));
  });

}
*/
void _addComponentAtPosition(
  ComponentType type,
  Offset position, {
  double? value,
  int rotation = 0,
  int componentNumber = 0,
  bool node = false,
  bool adjacent = false,
  double v1 = 0,
  double v2 = 10,
  double td = 0,
  double tr = 1,
  double tf = 1,
  double pw = 10,
  double per = 20,
  double vo = 0,
  double va = 5,
  double freq = 50000,
  double theta = 0,
  double phase = 0,
}) {
  setState(() {
    components.add(Component(
      type: type,
      position: _snapToGrid(position),
      value: value,
      rotation: rotation,
      componentNumber: componentNumber,
      node: node,
      adjacent: adjacent,
      v1: v1,
      v2: v2,
      td: td,
      tr: tr,
      tf: tf,
      pw: pw,
      per: per,
      vo: vo,
      va: va,
      freq: freq,
      theta: theta,
      phase: phase,
    ));
  });
}

List<Component> selectedWires = []; // Store connected wires
List<Component> selectedCircuit = [];

void _findConnectedWires(Component wire) {
  selectedWires.clear(); // Reset selection
  _collectConnectedWires(wire, selectedWires);
}



/// Recursively finds all connected wires with the same rotation
void _collectConnectedWires(Component wire, List<Component> collected) {
  if (!collected.contains(wire)) {
    collected.add(wire);
    for (var other in components.where((c) => c.type == ComponentType.wire)) {
      if (wire.position == other.position) continue; // Skip itself
      if (wire.rotation != other.rotation) continue; // ✅ Must have the same rotation

      // Check if the wire is adjacent (connected)
      if (_isConnected(wire, other)) {
        _collectConnectedWires(other, collected); // Recursively find all connected
      }
    }
  }
}

void _findConnectedWireNodes(Component wire) {
  selectedWires.clear(); // Reset selection
  _collectConnectedWireNodes(wire, selectedWires);
}



/// Recursively finds all connected wires with the same rotation
void _collectConnectedWireNodes(Component wire, List<Component> collected) {
  unhighlightAll();
  if (!collected.contains(wire)) {
    collected.add(wire);
    for (var other in components.where((c) => c.type == ComponentType.wire)) {
      if (wire.position == other.position) continue; // Skip itself
      if ((other.rotation == 2) ||   (other.rotation == 3) || (other.rotation == 4) || (other.rotation == 5) || (other.rotation == 6) ) continue; // ✅ Must have the same rotation

      // Check if the wire is adjacent (connected)
      if (_isConnected(wire, other)) {
        _collectConnectedWireNodes(other, collected); // Recursively find all connected
      }
    }
  }
}

void _highlightConnectedComponents(Component start) {
  Set<Component> visited = {};

  void visit(Component current) {
    visited.add(current);

    for (var neighbor in components) {
      if (!visited.contains(neighbor)) {
        bool sameX = current.position.dx == neighbor.position.dx;
        bool sameY = current.position.dy == neighbor.position.dy;
        double deltaX = (current.position.dx - neighbor.position.dx).abs();
        double deltaY = (current.position.dy - neighbor.position.dy).abs();

        if ((sameX && deltaY == gridSize) || (sameY && deltaX == gridSize)) {
          visit(neighbor);
        }
      }
    }
  }

  visit(start);

  // 🔄 Check if all are already highlighted
  bool allHighlighted = visited.every((comp) => comp.highlighted);

  setState(() {
    for (var comp in visited) {
      if (allHighlighted) {
        // 🔻 Unhighlight
        comp.highlighted = false;
        comp.rotation = (comp.rotation == 1000) ? 0 : comp.rotation ~/ 10;
      } else {
        // 🔺 Highlight
        if (comp.highlighted==false){
        comp.highlighted = true;
        comp.rotation = (comp.rotation == 0) ? 1000 : comp.rotation * 10;
        }
      }
    }
  });
}


List<List<Component>> getConnectedCircuits(List<Component> allComponents) {
  Set<Component> visited = {};
  List<List<Component>> circuits = [];

  bool areConnected(Component a, Component b) {
    double dx = (a.position.dx - b.position.dx).abs();
    double dy = (a.position.dy - b.position.dy).abs();
    return (a.position.dx == b.position.dx && dy == gridSize) ||
           (a.position.dy == b.position.dy && dx == gridSize);
  }

  void dfs(Component current, List<Component> circuit) {
    visited.add(current);
    circuit.add(current);

    for (Component neighbor in allComponents) {
      if (!visited.contains(neighbor) && areConnected(current, neighbor)) {
        dfs(neighbor, circuit);
      }
    }
  }

  for (Component comp in allComponents) {
    if (!visited.contains(comp)) {
      List<Component> newCircuit = [];
      dfs(comp, newCircuit);
      if (newCircuit.isNotEmpty) {
        circuits.add(newCircuit);
      }
    }
  }

  return circuits;
}
List<String> getnetlistop(List<Component> circuit, int circuitnumber) {
  unhighlightAll();
  const double gridSize = 50.0;
  List<String> outputLines = [""];
  bool hadDiode = false;
  bool hadTransistor = false;

  for (var comp in circuit) {
    if (comp.type != ComponentType.wire &&comp.type!=ComponentType.ammeter && comp.type != ComponentType.ground) {
      Offset positiveDir;
      Offset negativeDir;

      // Determine direction of terminals based on rotation
      switch (comp.rotation) {
        case 0: // Right-facing → Positive is Left
          positiveDir = Offset(-gridSize, 0);
          negativeDir = Offset(gridSize, 0);
          break;
        case 1: // Down-facing → Positive is Up
          positiveDir = Offset(0, -gridSize);
          negativeDir = Offset(0, gridSize);
          break;
        case 2: // Left-facing → Positive is Right
          positiveDir = Offset(gridSize, 0);
          negativeDir = Offset(-gridSize, 0);
          break;
        case 3: // Up-facing → Positive is Down
          positiveDir = Offset(0, gridSize);
          negativeDir = Offset(0, -gridSize);
          break;
        default:
          positiveDir = Offset.zero;
          negativeDir = Offset.zero;
      }

      // Find connected wires at each terminal
      int? posNode;
      int? negNode;

      Offset posPos = comp.position + positiveDir;
      Offset negPos = comp.position + negativeDir;

      for (var neighbor in circuit) {
        if ((neighbor.type == ComponentType.wire ||neighbor.type == ComponentType.ammeter )) {
          if (neighbor.position == posPos) {
            posNode = neighbor.componentNumber;
            if(comp.type!=ComponentType.ground )
            {
            neighbor.currentSourceReference=comp;//to get the current from the currentSourceReference
            neighbor.adjacent =true;
           // _highlightFullWirechill(neighbor);
            }
          } else if (neighbor.position == negPos) {
            negNode = neighbor.componentNumber;
            if(comp.type!=ComponentType.ground )
            {
            neighbor.currentSourceReference=comp;//to get the current from the currentSourceReference
            neighbor.adjacent =true;
         //   _highlightFullWirechill(neighbor);
            }
          }
        }
      }

      // Construct component label
      String typeName = "";
      
      switch (comp.type) {
        case ComponentType.resistor:
          typeName = "R${comp.componentNumber}";
          break;
        case ComponentType.diode:
          typeName = "D${comp.componentNumber}";
          hadDiode = true;
          break;
        case ComponentType.DCvoltageSource:
          typeName = "V${comp.componentNumber}";
          break;
        case ComponentType.currentsource:
          typeName = "I${comp.componentNumber}";
          break;
        case ComponentType.acvoltagesourcepulse:
          typeName = "V${comp.componentNumber}";
          break;
        case ComponentType.acvoltagesourcesin:
          typeName = "V${comp.componentNumber}";
          break;
        case ComponentType.capacitor:
          typeName = "C${comp.componentNumber}";
          break;
        case ComponentType.inductor:
          typeName = "L${comp.componentNumber}";
          break;
        case ComponentType.transistor:
          typeName = "Q${comp.componentNumber}";
          hadTransistor = true;
          break;
        default:
          continue;
      }

      // Use fallback if node wasn't found
      String n1 = posNode?.toString() ?? "0";
      String n2 = negNode?.toString() ?? "0";

      // Construct netlist line
      if (comp.type == ComponentType.transistor)
      {

          outputLines.add(_findTransistorNodes(comp,circuit,typeName));

      }
      else if (comp.type == ComponentType.diode) {
        outputLines.add("$typeName $n1 $n2 Dmod");
      } else {
        outputLines.add("$typeName $n1 $n2 ${comp.value}");
      }
    }
  }

  if (hadDiode) {
    outputLines.add(".model Dmod D");
  }

  if (hadTransistor) {
    outputLines.add(".model Q2N2222 NPN");
  }

  outputLines.add(".OP\n.END");
  
  return outputLines;
}

List<String> getnetlistTran(List<Component> circuit, int circuitnumber) {
  unhighlightAll();
  oscilloscopes.clear();
  simulationPlots.clear();
  const double gridSize = 50.0;
  List<String> outputLines = [""];
  //List<int> nodes =[0];
  bool hadDiode = false;
  bool hadTransistor = false;
  List<String> compsi=[];
  List<String> compsv=[];


    for (var comp in circuit) {
    if (comp.type != ComponentType.wire && comp.type!=ComponentType.ammeter && comp.type != ComponentType.ground) {
      Offset positiveDir;
      Offset negativeDir;
      // Determine direction of terminals based on rotation
      switch (comp.rotation) {
        case 0: // Right-facing → Positive is Left
          positiveDir = Offset(-gridSize, 0);
          negativeDir = Offset(gridSize, 0);
          break;
        case 1: // Down-facing → Positive is Up
          positiveDir = Offset(0, -gridSize);
          negativeDir = Offset(0, gridSize);
          break;
        case 2: // Left-facing → Positive is Right
          positiveDir = Offset(gridSize, 0);
          negativeDir = Offset(-gridSize, 0);
          break;
        case 3: // Up-facing → Positive is Down
          positiveDir = Offset(0, gridSize);
          negativeDir = Offset(0, -gridSize);
          break;
        default:
          positiveDir = Offset.zero;
          negativeDir = Offset.zero;
      }

      // Find connected wires at each terminal
      int? posNode;
      int? negNode;

      Offset posPos = comp.position + positiveDir;
      Offset negPos = comp.position + negativeDir;

      for (var neighbor in circuit) {
        if ((neighbor.type == ComponentType.wire ||neighbor.type == ComponentType.ammeter )) {
          if (neighbor.position == posPos) {
            posNode = neighbor.componentNumber;
            if(comp.type!=ComponentType.ground )
            neighbor.currentSourceReference=comp;//to get the current from the currentSourceReference
          } else if (neighbor.position == negPos) {
            negNode = neighbor.componentNumber;
            if(comp.type!=ComponentType.ground )
            neighbor.currentSourceReference=comp;//to get the current from the currentSourceReference
          }
        }
      }

      // Construct component label
      String typeName = "";
      
      switch (comp.type) {
        case ComponentType.resistor:
          typeName = "R${comp.componentNumber}";
          
          break;
        case ComponentType.diode:
          typeName = "D${comp.componentNumber}";
          
          hadDiode = true;
          break;
        case ComponentType.DCvoltageSource:
          typeName = "V${comp.componentNumber}";
          
          break;
        case ComponentType.currentsource:
          typeName = "I${comp.componentNumber}";
          
          break;
          case ComponentType.acvoltagesourcepulse:
          typeName = "V${comp.componentNumber}";
          
          break;
          case ComponentType.acvoltagesourcesin:
          typeName = "V${comp.componentNumber}";
          
          break;
        case ComponentType.capacitor:
          typeName = "C${comp.componentNumber}";
          
          break;
        case ComponentType.inductor:
          typeName = "L${comp.componentNumber}";
          
          break;
        case ComponentType.transistor:
          typeName = "Q${comp.componentNumber}";
          compsi.add(typeName+":C");
          compsi.add(typeName+":B");
          compsi.add(typeName+":E");
          hadTransistor = true;
          break;
        case ComponentType.oscilloscope:
        break;
        default:
          continue;
      }

      // Use fallback if node wasn't found
      String n1 = posNode?.toString() ?? "0";
      String n2 = negNode?.toString() ?? "0";

      // Construct netlist line
      if (comp.type == ComponentType.oscilloscope){
        if(n1!="0"&&n2!="0")
        compsv.add(n1+","+n2);
        else if(n1=="0")
        compsv.add(n2);
        else if(n2=="0")
        compsv.add(n1);


        oscilloscopes.add(comp);
      }
      else if (comp.type == ComponentType.transistor)
      {

          outputLines.add(_findTransistorNodes(comp,circuit,typeName));

          // compsv=_findTransistorNodesVolt(comp, circuit,compsv);

      }
      else if (comp.type == ComponentType.diode) {
        outputLines.add("$typeName $n1 $n2 Dmod");
       // nodes.add(int.parse(n1));
       // nodes.add(int.parse(n2));
      }
      else if (comp.type == ComponentType.acvoltagesourcepulse) {
        String v1= comp.v2.toString();
        String v2= comp.v1.toString();
        String td= comp.td.toString()+"n";
        String tr= comp.tr.toString()+"n";
        String tf= comp.tf.toString()+"n";
        String pw= comp.pw.toString()+"n";
        String per= comp.per.toString()+"n";
        outputLines.add("$typeName $n1 $n2 PULSE( $v2 $v1 $td $tr $tf $pw $per)");

      }

      else if (comp.type == ComponentType.acvoltagesourcesin) {
        String VO= comp.vo.toString();
        String VA = comp.va.toString();
        String FREQ= comp.freq.toString();
        String TD= comp.td.toString()+"n";
        String THETA= comp.theta.toString()+"n";
        String PHASE= comp.phase.toString()+"n";
        outputLines.add("$typeName $n1 $n2 SIN( $VO $VA $FREQ $TD $THETA $PHASE)");

      }
       else {
        outputLines.add("$typeName $n1 $n2 ${comp.value}");
       // nodes.add(int.parse(n1));
       // nodes.add(int.parse(n2));
       /*
       if(int.parse(n1)!=0 && int.parse(n2)!=0)
       {
         compsv.add(n1+","+n2);
       }
       else if(int.parse(n1)==0)
       {
          compsv.add(n2);
       }
       else if(int.parse(n2)==0)
       {
          compsv.add(n1);
       }
        */
      }
    }
  }
  /*
 nodes.toSet().toList();
 List<int> uniqueList = [];

  for (var number in nodes) {
    if (!uniqueList.contains(number)) {
      uniqueList.add(number);
    }
  }
  uniqueList.remove(0);
  */
  if (hadDiode) {
    outputLines.add(".model Dmod D");
  }

  if (hadTransistor) {
    outputLines.add(".model Q2N2222 NPN");
  }

  outputLines.add(".tran 0.1u 50u \n.probeall \n.control \nrun");
  String wrdata="";
  for (var comp in compsv) {
      wrdata+=" v($comp)";
  }

   for (var comp in compsi) {
      wrdata+=" i($comp)";
  }
  

  String oscilloscopecomment ="* ";
  oscilloscopes =oscilloscopes.toSet().toList();
  for(var comp in oscilloscopes)
  {
    oscilloscopecomment= oscilloscopecomment + comp.componentNumber.toString()+" ";
  }
  
  wrdata+=oscilloscopecomment;

  outputLines.add("wrdata rc_data.txt"+wrdata);
  outputLines.add("\n.endc \n.END");


print(outputLines);


  return outputLines;
}





void attachSimulationPlotsByNumber( List<Component> components, List<html.ImageElement> images) {
for (var comp in components)
{
  comp.transientimage=html.ImageElement();
}




  for (var comp in components) {
    final match = images.firstWhere(
      (img) {
        final src = img.src ?? '';
        final uri = Uri.parse(src);
        final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        return name == 'v_${comp.componentNumber}.png';
      },
      orElse: () => html.ImageElement(), // fallback: dummy element
    );

    if (match.src != null && match.src!.contains('v_${comp.componentNumber}.png')) {
      comp.transientimage = match;
    //  _showNotification('v_${comp.componentNumber}.png');
    }
  }



}


String _findTransistorNodes(Component tran,List<Component> circuit, typeName )
{
  int Cnode=0;
  int Bnode=0;
  int Enode=0;
  Offset upPos = Offset(tran.position.dx, tran.position.dy - 50);
  Offset downPos = Offset(tran.position.dx, tran.position.dy + 50);
  Offset leftPos = Offset(tran.position.dx - 50, tran.position.dy);
  Offset rightPos = Offset(tran.position.dx + 50, tran.position.dy);
  for (var comp in circuit)
  { 
    switch(tran.rotation)
    { 
      case 0:
        if (comp.position == upPos)
        {
          Bnode = comp.componentNumber;
        }
        else if (comp.position == leftPos)
        {
          Enode = comp.componentNumber;
        }
        else if (comp.position == rightPos)
        {
          Cnode = comp.componentNumber;
        }
      break;
      case 1:
        if (comp.position == upPos)
        {
          Enode = comp.componentNumber;
        }
        else if (comp.position == downPos)
        {
          Cnode = comp.componentNumber;
        }
        else if (comp.position == rightPos)
        {
          Bnode = comp.componentNumber;
        }
      break;
      case 2:
        if (comp.position == leftPos)
        {
          Cnode = comp.componentNumber;
        }
        else if (comp.position == downPos)
        {
          Bnode = comp.componentNumber;
        }
        else if (comp.position == rightPos)
        {
          Enode = comp.componentNumber;
        }
      break;
      case 3:
        if (comp.position == leftPos)
        {
          Bnode = comp.componentNumber;
        }
        else if (comp.position == downPos)
        {
          Enode = comp.componentNumber;
        }
        else if (comp.position == upPos)
        {
          Cnode = comp.componentNumber;
        }
      break;
    }
  } 

  String list ="$typeName $Cnode $Bnode $Enode Q2N2222";
  return list;
}

List<String> _findTransistorNodesVolt(Component tran,List<Component> circuit,List<String> volts)
{
  Offset upPos = Offset(tran.position.dx, tran.position.dy - 50);
  Offset downPos = Offset(tran.position.dx, tran.position.dy + 50);
  Offset leftPos = Offset(tran.position.dx - 50, tran.position.dy);
  Offset rightPos = Offset(tran.position.dx + 50, tran.position.dy);
  List<int> nodes=[];
  int c=0;
  for (var comp in circuit)
  { 
    switch(tran.rotation)
    { 
      case 0:
        if (comp.position == upPos && comp.componentNumber!=0)
        {
     
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == leftPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == rightPos && comp.componentNumber!=0) 
        {
          nodes.add(comp.componentNumber);
          c++;
        }
      break;
      case 1:
        if (comp.position == upPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == downPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == rightPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
      break;
      case 2:
        if (comp.position == leftPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == downPos && comp.componentNumber!=0) 
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == rightPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
      break;
      case 3:
        if (comp.position == leftPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == downPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
        else if (comp.position == upPos && comp.componentNumber!=0)
        {
          nodes.add(comp.componentNumber);
          c++;
        }
      break;
    }
  } 

  if(c==3)
  {
  volts.add(nodes[0].toString()+","+nodes[1].toString());
  volts.add(nodes[1].toString()+","+nodes[2].toString());
  volts.add(nodes[0].toString()+","+nodes[2].toString());
  }
  else if(c==2)
  {
    volts.add(nodes[0].toString()+","+nodes[1].toString());
    volts.add(nodes[1].toString());
    volts.add(nodes[0].toString());
  }
  else if(c==1)
  {
    volts.add(nodes[0].toString());
  }

  return volts;
}


void assignVoltageToVoltmeter(List<Component> circuit)
{
  double lv=0;
  double rv =0;
  for(var volt in circuit)
  {
    if (volt.type == ComponentType.voltmeter)
    {
  Offset upPos    = Offset(volt.position.dx, volt.position.dy - 50);
  Offset downPos  = Offset(volt.position.dx, volt.position.dy + 50);
  Offset leftPos  = Offset(volt.position.dx - 50, volt.position.dy);
  Offset rightPos = Offset(volt.position.dx + 50, volt.position.dy);
//_showNotification("found");
     for (var comp in circuit)
      {
        
        switch (volt.rotation){
        case 0:
          if(comp.position == rightPos)
          {
            if(comp.simulatedVoltage!=null)
            {
          //    _showNotification(comp.position.toString());
            rv = comp.simulatedVoltage!;
         //   _showNotification(comp.simulatedVoltage.toString());
            }
           // else {_showNotification("idk dude");}
          }
          if(comp.position == leftPos)
          {
            //_showNotification(comp.position.toString());
            lv = comp.simulatedVoltage!;
          }
        break;
        case 2:
          if(comp.position == rightPos)
          {
            lv = comp.simulatedVoltage!;
          }
          if(comp.position == leftPos)
          {
            rv = comp.simulatedVoltage!;
          }
        break;
        case 1:
          if(comp.position == upPos)
          {
            rv = comp.simulatedVoltage!;
          }
          if(comp.position == downPos)
          {
            lv = comp.simulatedVoltage!;
          }
        break;
        case 3:
          if(comp.position == upPos)
          {
            lv = comp.simulatedVoltage!;
          }
          if(comp.position == downPos)
          {
            rv = comp.simulatedVoltage!;
          }
        break;
        }
      }

      
      volt.simulatedVoltage = (rv - lv)*-1;  
     
//      _showNotification((rv-lv).toString());
    }
  }
//buildVoltmeterValueLabels(circuit);
showVoltmeterDisplays(context, components);
}

List<Widget> buildVoltmeterValueLabels(List<Component> components) {
  return components.where((comp) => comp.type == ComponentType.voltmeter).map((comp) {
    final Offset pos = comp.position;

    return Positioned(
      left: pos.dx + 50,
      top: pos.dy - 50,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.yellow[100],
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 2),
          ],
        ),
        child: Text(
          comp.vo.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }).toList();
}


void generateNodes(List<Component> circuitComponents) {
  const double gridSize = 50.0;

  for (var comp in circuitComponents) {
    if (comp.type != ComponentType.wire && comp.type!=ComponentType.oscilloscope && comp.type !=ComponentType.voltmeter && comp.type !=ComponentType.ammeter) {
      // Define the 4 directions and their required wire rotations
      Map<Offset, Set<int>> directionToValidRotations = {
        Offset(0, -gridSize): {1,10,2,20,3,30,4,40,6,60,9,90,11,110},  // Up → wire must be vertical up
        Offset(0, gridSize):  {1,10,2,20,3,30,4,40,5,50,7,70,8,80},   // Down → wire must be vertical down
        Offset(-gridSize, 0): {2,20,4,40,5,50,6,60,8,80,9,90,0,1000},  // Left → wire must be horizontal left
        Offset(gridSize, 0): {2,20,3,30,5,50,6,60,7,70,11,110,0,1000},   // Right → wire must be horizontal right
      };

      for (var entry in directionToValidRotations.entries) {
        Offset dir = entry.key;
        Set<int> validRotations = entry.value;
        Offset adjacentPos = comp.position + dir;
        
        for (var other in circuitComponents) {


           
          // code related to nodes in manual computation
          if(other.type == ComponentType.wire || other.type == ComponentType.ammeter)
          {
             
            if (other.rotation == 2 || other.rotation == 20 || other.rotation == 3 || other.rotation == 30 || other.rotation == 4 || other.rotation == 40 || other.rotation == 5 || other.rotation == 50 || other.rotation ==  6 || other.rotation == 60)
            {
              other.truenode = true;
              
            }
          }
          if(other.type == ComponentType.ground)
          {
            other.truenode = true;
          }


          //code related to nodes in netlist
          if ((other.type == ComponentType.wire || other.type == ComponentType.ammeter) &&
              other.position == adjacentPos &&
              validRotations.contains(other.rotation)) {
            assignNode(other); // ✅ Mark only if rotation matches expected direction
            other.adjacent=true;
          }
        }
      }
    }
  }
}

void assignCurrentToWires(List<Component> circuit2) {
  List<Component> circuit = circuit2;



  for (var sourceWire in circuit) {
    if((sourceWire.type == ComponentType.wire ||sourceWire.type == ComponentType.ammeter )&& sourceWire.componentNumber ==0)
    {
      sourceWire.simulatedVoltage =0;
    }

    if ((sourceWire.type == ComponentType.wire ||sourceWire.type == ComponentType.ammeter ) && sourceWire.adjacent) {
     _highlightFullWirecur(sourceWire);
      
    }
  
  }
for (var tran in circuit){

if(tran.type == ComponentType.transistor)
{

  Offset upPos = Offset(tran.position.dx, tran.position.dy - 50);
  Offset downPos = Offset(tran.position.dx, tran.position.dy + 50);
  Offset leftPos = Offset(tran.position.dx - 50, tran.position.dy);
  Offset rightPos = Offset(tran.position.dx + 50, tran.position.dy);
  for (var comp in circuit)
  { 
    switch(tran.rotation)
    { 
      case 0:
        if (comp.position == upPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedBaseCurrent;
        }
        else if (comp.position == leftPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedEmitterCurrent;
        }
        else if (comp.position == rightPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedCollectorCurrent;
        }
      break;
      case 1:
        if (comp.position == upPos)
        {
         comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedEmitterCurrent;
        }
        else if (comp.position == downPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedCollectorCurrent;
        }
        else if (comp.position == rightPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedBaseCurrent;
        }
      break;
      case 2:
        if (comp.position == leftPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedCollectorCurrent;
        }
        else if (comp.position == downPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedBaseCurrent;
        }
        else if (comp.position == rightPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedEmitterCurrent;
        }
      break;
      case 3:
        if (comp.position == leftPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedBaseCurrent;
        }
        else if (comp.position == downPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedEmitterCurrent;
        }
        else if (comp.position == upPos)
        {
          comp.currentSourceReference= tran;
          comp.simulatedCurrent = tran.simulatedCollectorCurrent;
        }
      break;
    }
  } 

}
}

}



/*
void correctNodes(List<Component> circuit) {
  
  // Create a copy of the list to safely iterate while allowing removal
  List<Component> wires = List.from(circuit.where((c) => (c.type == ComponentType.wire||c.type==ComponentType.ammeter)));
  List<Component> wires2;
  Component node =circuit[0];
  

  for (var comp in circuit){
    if(ComponentType.ground == comp.type)
    {
       switch (comp.rotation)
      {
        case 0:
        {
          Offset position =  comp.position + Offset(-gridSize, 0);
           for (var left in components) {
             if (left.position == position) {
                  left.componentNumber=0;
                  node=left;
              }
           }
        }
        case 1:
        {
          Offset position =  comp.position + Offset(0, -gridSize);
           for (var up in components) {
             if (up.position == position) {
                  up.componentNumber=0;
                  node=up;
              }
           }

        }
        case 2:
        {
          Offset position =  comp.position + Offset(gridSize, 0);
           for (var right in components) {
             if (right.position == position) {
                  right.componentNumber=0;
                  node=right;
              }
           }
        }
        case 3:
        {
          Offset position =  comp.position + Offset( 0,gridSize);
           for (var right in components) {
             if (right.position == position) {
                  right.componentNumber=0;
                  node=right;
              }
           }
        }
      }
         wires2= getFullConnectedWire(node);
         for (var nodes in wires2)
  {
    nodes.componentNumber= node.componentNumber;
    nodes.node=false;
    wires.remove(nodes);
     node.node=true;
  }
      

    }
  }
nodecounter=1;
  for (var wire in wires) {   
  wires2= getFullConnectedWire(wire);
  for (var isnode in wires2)
  {
    if(isnode.node)
    {
      node=isnode;
      node.componentNumber=nodecounter;
      print(nodecounter);
      nodecounter++;
      break;
    }
  }

  for (var nodes in wires2)
  {
    nodes.componentNumber= node.componentNumber;
    nodes.node=false;
    wires.remove(nodes);
     node.node=true;
  }
  }
}
*/

void correctNodes(List<Component> circuit) {
  List<Component> wires = List.from(circuit.where((c) => c.type == ComponentType.wire || c.type == ComponentType.ammeter));
  List<Component> wires2;
  Component node = circuit[0];

  for (var comp in circuit) {
    if (ComponentType.ground == comp.type) {
      switch (comp.rotation) {
        case 0:
          {
            Offset position = comp.position + Offset(-gridSize, 0);
            for (var left in components) {
              if (left.position == position) {
                left.componentNumber = 0;
                node = left;
              }
            }
            break;
          }
        case 1:
          {
            Offset position = comp.position + Offset(0, -gridSize);
            for (var up in components) {
              if (up.position == position) {
                up.componentNumber = 0;
                node = up;
              }
            }
            break;
          }
        case 2:
          {
            Offset position = comp.position + Offset(gridSize, 0);
            for (var right in components) {
              if (right.position == position) {
                right.componentNumber = 0;
                node = right;
              }
            }
            break;
          }
        case 3:
          {
            Offset position = comp.position + Offset(0, gridSize);
            for (var down in components) {
              if (down.position == position) {
                down.componentNumber = 0;
                node = down;
              }
            }
            break;
          }
      }

      wires2 = getFullConnectedWire(node);
      List<Component> toRemove = [];
      for (var nodes in wires2) {
        nodes.componentNumber = node.componentNumber;
        nodes.node = false;
        toRemove.add(nodes);
        node.node = true;
      }
      wires.removeWhere((w) => toRemove.contains(w));
    }
  }

  nodecounter = 1;
  while (wires.isNotEmpty) {
    Component wire = wires.first;
    wires2 = getFullConnectedWire(wire);

    Component? nodeCandidate;
    for (var isnode in wires2) {
      if (isnode.node) {
        nodeCandidate = isnode;
        nodeCandidate.componentNumber = nodecounter;
        print(nodecounter);
        nodecounter++;
        break;
      }
    }

    if (nodeCandidate != null) {
      node = nodeCandidate;
    }

    List<Component> toRemove = [];
    for (var nodes in wires2) {
      nodes.componentNumber = node.componentNumber;
      nodes.node = false;
      toRemove.add(nodes);
      node.node = true;
    }
    wires.removeWhere((w) => toRemove.contains(w));
  }
}


void refreshCircuit(List<Component> circuit)
{
  for (var comp in circuit)
  {
    comp.simulatedCurrent =null;
    comp.simulatedVoltage =null;
    if(comp.type==ComponentType.wire)
    {
    comp.node=false;
   // comp.componentNumber=1110;
    }
  }
}
void correctTruenodes(List<Component> circuit) {
  const double gridSize = 50.0;

  // Group all components with trueNode = true by componentNumber
  Map<int, List<Component>> grouped = {};

  for (var comp in circuit) {
    if (comp.truenode) {
      grouped.putIfAbsent(comp.componentNumber, () => []).add(comp);
    }
  }

  for (var entry in grouped.entries) {
    List<Component> group = entry.value;

    // Step 1: Try to find a trueNode connected to a component with a different componentNumber
    Component? preferred;

    for (var nodeCandidate in group) {
      List<Offset> directions = [
        Offset(0, -gridSize), // up
        Offset(0, gridSize),  // down
        Offset(-gridSize, 0), // left
        Offset(gridSize, 0),  // right
      ];

      for (var dir in directions) {
        Offset adjacent = nodeCandidate.position + dir;

        for (var other in circuit) {
          if (other.position == adjacent &&
              other.componentNumber != nodeCandidate.componentNumber) {
            preferred = nodeCandidate;
            break;
          }
        }

        if (preferred != null) break;
      }

      if (preferred != null) break;
    }

    // Step 2: If found, keep only that one as trueNode
    for (var comp in group) {
      comp.truenode = (comp == preferred);
    }

    // Step 3: If no preferred found, just keep the first as fallback
    if (preferred == null && group.isNotEmpty) {
      group.first.truenode = true;
      for (int i = 1; i < group.length; i++) {
        group[i].truenode = false;
      }
    }
  }
}

String getSpicePrefix(ComponentType type) {
  switch (type) {
    case ComponentType.resistor:
      return 'R';
    case ComponentType.diode:
      return 'D';
    case ComponentType.DCvoltageSource:
      return 'V';
    case ComponentType.currentsource:
      return 'I';
    case ComponentType.acvoltagesourcepulse:
      return 'V';
    case ComponentType.acvoltagesourcesin:
      return 'V';
    case ComponentType.transistor:
      return 'Q'; // ✅ THIS FIXES YOUR PROBLEM
    case ComponentType.wire:
      return 'W'; // optional, depends if needed
    // Add other cases if needed
    default:
      return '?'; // fallback
  }
}


void sendNetlistToBackendop(String netlistContent, List<Component> circuit, int circuitnumber) {
 final uri = Uri.parse('$backendHost/simulateop');

  final request = html.HttpRequest();
  request
    ..open('POST', uri.toString())
    ..setRequestHeader('Content-Type', 'application/json')
    ..onLoadEnd.listen((event) {
      if (request.status == 200) {
        final json = jsonDecode(request.responseText!);
        Map<String, dynamic> voltages = json['voltages'] ?? {};
        Map<String, dynamic> currents = json['currents'] ?? {};
        List<String> resultOutput = List<String>.from(json['result'] ?? []);

        // 🔋 Assign node voltages to wires
        voltages.forEach((key, value) {
          int? nodeNumber = int.tryParse(key.replaceAll('node_', ''));
          if (nodeNumber != null) {
            for (var comp in circuit) {
              if (comp.componentNumber == nodeNumber && (comp.type == ComponentType.wire ||comp.type == ComponentType.ammeter )) {
                comp.simulatedVoltage = value.toDouble();
              }
            }
          }
        });

        // ⚡ Assign currents to components (any type)
       currents.forEach((label, value) {
  for (var comp in circuit) {
    final prefix = getSpicePrefix(comp.type); // e.g., "R", "D", "V", "Q"
    final compLabel = "$prefix${comp.componentNumber}"; // e.g., Q1
    
    // ✅ Special case: transistor pin currents (like Q1:C)
    if (label.toUpperCase().startsWith("$compLabel:") && comp.type == ComponentType.transistor) {
      final parts = label.toUpperCase().split(':');
      if (parts.length == 2) {
        final pin = parts[1]; // C, B, or E
        final currentValue = value.toDouble();
        
        if (pin == 'C') {
          comp.simulatedCollectorCurrent = currentValue;
        } else if (pin == 'B') {
          comp.simulatedBaseCurrent = currentValue;
        } else if (pin == 'E') {
          comp.simulatedEmitterCurrent = currentValue;
        }
      }
    }
    // ✅ Regular components (resistor, diode, etc.)
    else if (label.toUpperCase() == compLabel && comp.type != ComponentType.DCvoltageSource) {
      comp.simulatedCurrent = value.toDouble();
    }
    // ✅ Voltage sources (negate current)
    else if (label.toUpperCase() == compLabel && comp.type == ComponentType.DCvoltageSource) {
      comp.simulatedCurrent = -value.toDouble();
    }
  }
});



        // 🪄 Also update panel text as usual
      screenStateKey.currentState?.setState(() {
  componentPositions.addAll([
    'circuit $circuitnumber:',
    ...netlistContent
        .split('\n'),
     //   .where((line) => !line.trim().startsWith('circuit')), // avoid duplicates
    '',
    '--- Simulation Output ---',
    ...resultOutput,
    '-------------------------',
  ]);
});


      } else {
        print("❌ Failed to send netlist. Status code: ${request.status}");
        print("❗ Response: ${request.responseText}");
      }
    });

  final payload = jsonEncode({
    "content": netlistContent,
  });

  request.send(payload);
 // buildVoltmeterValueLabels(circuit);
 // assignVoltageToVoltmeter(circuit);
}


void sendNetlistToBackendtran(String netlistContent, List<Component> circuit, int circuitnumber) {
 final uri = Uri.parse('$backendHost/simulatetran');

  final request = html.HttpRequest();
  request
    ..open('POST', uri.toString())
    ..setRequestHeader('Content-Type', 'application/json')
    ..onLoadEnd.listen((event) {
      if (request.status == 200) {
        final json = jsonDecode(request.responseText!);
        Map<String, dynamic> voltages = json['voltages'] ?? {};
        Map<String, dynamic> currents = json['currents'] ?? {};
        List<String> resultOutput = List<String>.from(json['result'] ?? []);

        List<String> plotUrls = List<String>.from(json['plots'] ?? []);
      simulationPlots.clear();

      for (String relativeUrl in plotUrls) {
        final fullUrl = '$backendHost$relativeUrl';
        simulationPlots.add(html.ImageElement(src: fullUrl));
      }
   
      attachSimulationPlotsByNumber(oscilloscopes,simulationPlots);


        // 🔋 Assign node voltages to wires
        voltages.forEach((key, value) {
          int? nodeNumber = int.tryParse(key.replaceAll('node_', ''));
          if (nodeNumber != null) {
            for (var comp in circuit) {
              if (comp.componentNumber == nodeNumber && (comp.type == ComponentType.wire ||comp.type == ComponentType.ammeter )) {
                comp.simulatedVoltage = value.toDouble();
              }
            }
          }
        });

        // ⚡ Assign currents to components (any type)
        currents.forEach((label, value) {
          for (var comp in circuit) {
            final prefix = comp.type.toString().split('.').last[0].toUpperCase(); // e.g., "R", "D", "V"
            final compLabel = "$prefix${comp.componentNumber}";
            if (label.toUpperCase() == compLabel && comp.type != ComponentType.DCvoltageSource) {
              comp.simulatedCurrent = value.toDouble();
            }
            else if (label.toUpperCase() == compLabel && comp.type == ComponentType.DCvoltageSource) {
              comp.simulatedCurrent = -value.toDouble();
            }
          }
        });

        // 🪄 Also update panel text as usual
      screenStateKey.currentState?.setState(() {
  componentPositions.addAll([
    'circuit $circuitnumber:',
    ...netlistContent
        .split('\n'),
     //   .where((line) => !line.trim().startsWith('circuit')), // avoid duplicates
    '',
    '--- Simulation Output ---',
    ...resultOutput,
    '-------------------------',
  ]);
});


      } else {
        print("❌ Failed to send netlist. Status code: ${request.status}");
        print("❗ Response: ${request.responseText}");
      }
    });

  final payload = jsonEncode({
    "content": netlistContent,
  });

  request.send(payload);
  
}

/// Checks if two wires are adjacent (directly connected)
bool _isConnected(Component a, Component b) {
  double dx = (a.position.dx - b.position.dx).abs();
  double dy = (a.position.dy - b.position.dy).abs();
  return (dx == gridSize && dy == 0) || (dy == gridSize && dx == 0);
}





  void _deleteFullWire(Component wire) {
  Set<Component> wiresToDelete = {};

bool _areWiresConnected(Component wire1, Component wire2) {
  return (wire1.position.dx == wire2.position.dx && (wire1.position.dy - wire2.position.dy).abs() == gridSize) ||
         (wire1.position.dy == wire2.position.dy && (wire1.position.dx - wire2.position.dx).abs() == gridSize);
}

  // Helper function to find all connected wires recursively
  void findConnectedWires(Component currentWire) {
    wiresToDelete.add(currentWire);
    for (var neighbor in components.where((c) =>
       (c.type == ComponentType.wire ||c.type == ComponentType.ammeter ) &&
        !wiresToDelete.contains(c) &&
        _areWiresConnected(currentWire, c))) {
      findConnectedWires(neighbor);
    }
  }


    
  // Start finding connected wires
  findConnectedWires(wire);

  // Remove all found wires
  setState(() {
    components.removeWhere((c) => wiresToDelete.contains(c));
  });
}
void _highlightFullWirechill(Component wire) {
  Set<Component> wiresToHighlight = {};

  bool _areWiresConnected(Component wire1, Component wire2) {
    return (wire1.position.dx == wire2.position.dx && (wire1.position.dy - wire2.position.dy).abs() == gridSize) ||
           (wire1.position.dy == wire2.position.dy && (wire1.position.dx - wire2.position.dx).abs() == gridSize);
  }

  final Set<int> disallowedRotations = {2, 3, 4, 5, 6, 20, 30, 40, 50, 60};

  void findConnectedWires(Component currentWire) {
    wiresToHighlight.add(currentWire);

    // If this wire has a disallowed rotation, stop here — don't recurse further
    if (disallowedRotations.contains(currentWire.rotation)) {
      return;
    }

    for (var neighbor in components.where((c) =>
        (c.type == ComponentType.wire ||c.type == ComponentType.ammeter ) &&
        !wiresToHighlight.contains(c) &&
        _areWiresConnected(currentWire, c))) {
      findConnectedWires(neighbor);
    }
  }

  // Start finding connected wires
  findConnectedWires(wire);

  setState(() {
    for (var wires in wiresToHighlight) {
      wires.chill=true;
    }
  });

  print("✅ Applied currentSourceReference to ${wiresToHighlight.length} wires.");
}

void _highlightFullWirecur(Component wire) {
  //_showNotification("ye");
  Set<Component> wiresToHighlight = {};

  bool _areWiresConnected(Component wire1, Component wire2) {
    return (wire1.position.dx == wire2.position.dx && (wire1.position.dy - wire2.position.dy).abs() == gridSize) ||
           (wire1.position.dy == wire2.position.dy && (wire1.position.dx - wire2.position.dx).abs() == gridSize);
  }

  // List of disallowed rotation values
  final Set<int> disallowedRotations = {2, 3, 4, 5, 6, 20, 30, 40, 50, 60};

  // Recursive function to find connected wires
  void findConnectedWires(Component currentWire) {
    if (disallowedRotations.contains(currentWire.rotation) && currentWire.chill==false) {
      return; // ❌ Stop if this wire shouldn't be highlighted
    }

    wiresToHighlight.add(currentWire);

    for (var neighbor in components.where((c) =>
        (c.type == ComponentType.wire ||c.type == ComponentType.ammeter) &&
        !wiresToHighlight.contains(c) &&
        _areWiresConnected(currentWire, c))) {
      findConnectedWires(neighbor);
    }
  }

  // Start finding connected wires
  findConnectedWires(wire);

  // Highlight or unhighlight the wires
  
    setState(() {
      for (var wires in wiresToHighlight) {
        wires.currentSourceReference = wire.currentSourceReference;
      }
    });
  

  print("✅ Highlighted ${wiresToHighlight.length} connected wires.");
}

void _highlightFullWire(Component wire) {
  Set<Component> wiresToHighlight = {};

bool _areWiresConnected(Component wire1, Component wire2) {
  return (wire1.position.dx == wire2.position.dx && (wire1.position.dy - wire2.position.dy).abs() == gridSize) ||
         (wire1.position.dy == wire2.position.dy && (wire1.position.dx - wire2.position.dx).abs() == gridSize);
}

  // Helper function to find all connected wires recursively
  void findConnectedWires(Component currentWire) {
    wiresToHighlight.add(currentWire);
    for (var neighbor in components.where((c) =>
        (c.type == ComponentType.wire ||c.type == ComponentType.ammeter ) &&
        !wiresToHighlight.contains(c) &&
        _areWiresConnected(currentWire, c))) {
      findConnectedWires(neighbor);
    }
  }


    
  // Start finding connected wires
  findConnectedWires(wire);

  // higlight all found wires
    if(!(wire.highlighted))
    {
    setState(() {
    for (var wire in wiresToHighlight) {
      if (!wire.highlighted) {
        wire.highlighted = true;
        wire.rotation = (wire.rotation == 0) ? 1000 : wire.rotation * 10; // Apply highlighting rule
      }
    }
  });
    }
    else
    {
      setState(() {
  for (var wire in wiresToHighlight) {
    if (wire.highlighted) {
      wire.highlighted = false;
      wire.rotation = (wire.rotation == 1000) ? 0 : wire.rotation ~/ 10; // Reverse highlight effect
    }
  }
});

    }

  print("✅ Highlighted ${wiresToHighlight.length} connected wires.");
  
}

List<Component> getFullConnectedWire(Component wire) {
  Set<Component> wiresToReturn = {};

  bool _areWiresConnected(Component wire1, Component wire2) {
    return (wire1.position.dx == wire2.position.dx &&
            (wire1.position.dy - wire2.position.dy).abs() == gridSize) ||
           (wire1.position.dy == wire2.position.dy &&
            (wire1.position.dx - wire2.position.dx).abs() == gridSize);
  }

  // Recursive search
  void findConnectedWires(Component currentWire) {
    wiresToReturn.add(currentWire);
    for (var neighbor in components.where((c) =>
        (c.type == ComponentType.wire ||c.type == ComponentType.ammeter ) &&
        !wiresToReturn.contains(c) &&
        _areWiresConnected(currentWire, c))) {
      findConnectedWires(neighbor);
    }
  }

  findConnectedWires(wire);
  print("✅ Found ${wiresToReturn.length} connected wires.");
  return wiresToReturn.toList();
}

List<Component> getConnectedWireNoNodes(Component wire) {
  Set<Component> wiresToReturn = {};


  getConnectedWireNoNodes(wire);
  print("✅ Found ${wiresToReturn.length} connected wires.");
  return wiresToReturn.toList();
}



void _deleteAllComponents() {
  setState(() {
    components.clear(); // ✅ Remove all components
  });
}
void moveHighlightedComponents(String direction) {
  const double moveDistance = 50.0; // Adjust grid movement step if needed

  setState(() {
    for (var comp in components) {
      if (comp.highlighted) {
        switch (direction) {
          case "left":
            comp.position = Offset(comp.position.dx - moveDistance, comp.position.dy);
            break;
          case "right":
            comp.position = Offset(comp.position.dx + moveDistance, comp.position.dy);
            break;
          case "up":
            comp.position = Offset(comp.position.dx, comp.position.dy - moveDistance);
            break;
          case "down":
            comp.position = Offset(comp.position.dx, comp.position.dy + moveDistance);
            break;
          default:
            print("⚠ Invalid direction: $direction");
        }
      }
    }
  });

  _updateWireConnections();
  _saveComponentsState();
  _clearRedo();
}


void updateUI() {
  setState(() {}); // ✅ Triggers a UI refresh
 
}

String _getUnit(Component comp) {
  double? value;
  if(comp.value != null)
  {
    value = comp.value;
    
  }
  int compnum = comp.componentNumber;
  switch (comp.type) {
    case ComponentType.DCvoltageSource:
      return "V$compnum\n$value V"; // ✅ Voltage source shows "V"
    case ComponentType.currentsource:
      return "I$compnum $value"+"A"; 
    case ComponentType.acvoltagesourcepulse:
      return "pulse V$compnum\n";
    case ComponentType.acvoltagesourcesin:
      return "sin V$compnum\n";
    case ComponentType.resistor:
      return "R$compnum\n$value Ω"; // ✅ Resistor shows "Ohm" symbol
    case ComponentType.diode:
      return "D$compnum\n$value V"; // ✅ Diode shows "V"
    case ComponentType.capacitor:
      return "C$compnum\n$value F";
    case ComponentType.inductor:
      return "C$compnum\n$value H";
    case ComponentType.transistor:
      return "Q$compnum\n";
    case ComponentType.oscilloscope:
      return "oscilloscope $compnum\n";
    case ComponentType.voltmeter:
      return "voltmeter \n ";
    case ComponentType.ammeter:
      return "Ammeter \n ";
    case ComponentType.wire:
    {
      if(comp.node)
      {
       
        return "Node $compnum";
      }
      else
      return "";
    }
    default:
      return "";  // ✅ No unit for wires or unknown components
  }
}


 void _updateWireConnections() {
  for (var wire in components.where((c) => c.type == ComponentType.wire)) {
    bool hasUp = components.any((c) => c.position == wire.position + Offset(0, -gridSize)&& (c.type == ComponentType.wire || ((c.type== ComponentType.transistor)&&(c.rotation==2 || c.rotation==20))|| ((c.type== ComponentType.ground)&&(c.rotation==3 || c.rotation==30))||(c.type!= ComponentType.ground)&&(c.rotation==1 || c.rotation==3 ||c.rotation==10 || c.rotation==30)));
    bool hasDown = components.any((c) => c.position == wire.position + Offset(0, gridSize)&& (c.type == ComponentType.wire || ((c.type== ComponentType.transistor)&&(c.rotation==0 || c.rotation==1000))|| ((c.type== ComponentType.ground)&&(c.rotation==1 || c.rotation==10))||(c.type!= ComponentType.ground)&&(c.rotation==1 || c.rotation==3 || c.rotation==10 || c.rotation==30)));
    bool hasLeft = components.any((c) => c.position == wire.position + Offset(-gridSize, 0)&& (c.type == ComponentType.wire || ((c.type== ComponentType.transistor)&&(c.rotation==1 || c.rotation==10))|| ((c.type== ComponentType.ground)&&(c.rotation==2 || c.rotation==20))||(c.type!= ComponentType.ground)&&(c.rotation==0 || c.rotation==2 || c.rotation==1000 || c.rotation==20)));
    bool hasRight = components.any((c) => c.position == wire.position + Offset(gridSize, 0)&& (c.type == ComponentType.wire || ((c.type== ComponentType.transistor)&&(c.rotation==3 || c.rotation==30))|| ((c.type== ComponentType.ground)&&(c.rotation==0 || c.rotation==1000))||(c.type!= ComponentType.ground)&&(c.rotation==0 || c.rotation==2 || c.rotation==1000 || c.rotation==20)));

    // ✅ Determine new image based on connections
    String newImage = "wire";
    if (hasUp) newImage += "_UP";
    if (hasDown) newImage += "_DOWN";
    if (hasLeft) newImage += "_LEFT";
    if (hasRight) newImage += "_RIGHT";

    // ✅ Update wire image path
    //wire.imagePath = "assets/$newImage.png";
    
    switch(newImage){
      case "wire_UP_DOWN_LEFT_RIGHT":
      wire.rotation =2;
       case "wire_UP_DOWN_LEFT":
      wire.rotation =3;
       case "wire_UP_DOWN_RIGHT":
      wire.rotation =4;
       case "wire_UP_LEFT_RIGHT":
      wire.rotation =5;
       case "wire_DOWN_LEFT_RIGHT":
      wire.rotation =6;
      case "wire_UP_LEFT":
      wire.rotation =7;
      case "wire_UP_RIGHT":
      wire.rotation =8;
      case "wire_DOWN_RIGHT":
      wire.rotation =9;
      case "wire_DOWN_LEFT":
      wire.rotation =11;
       case "wire_UP_DOWN":
      wire.rotation =1;
      case "wire_UP":
      wire.rotation =1;
      case "wire_DOWN":
      wire.rotation =1;
       case "wire_LEFT_RIGHT":
      wire.rotation =0;
      case "wire_LEFT":
      wire.rotation =0;
      case "wire_RIGHT":
      wire.rotation =0;
       default:
      wire.rotation =0;

    }
    if(wire.highlighted)
    {
      if(wire.rotation==0)
      {
        wire.rotation = 1000;
      }
      else{
        wire.rotation*=10;
      }
    }
    
  }
  _correctHighlights();
  updateUI();
 
}



void autorotatenonwire(Component comp) {
 
    bool hasUp = components.any((c) => c.position == comp.position + Offset(0, -gridSize)&& (c.type == ComponentType.wire ||(c.rotation==1 || c.rotation==3 ||c.rotation==10 || c.rotation==30)));
    bool hasDown = components.any((c) => c.position == comp.position + Offset(0, gridSize)&& (c.type == ComponentType.wire ||(c.rotation==1 || c.rotation==3 || c.rotation==10 || c.rotation==30)));
    bool hasLeft = components.any((c) => c.position == comp.position + Offset(-gridSize, 0)&& (c.type == ComponentType.wire ||(c.rotation==0 || c.rotation==2 || c.rotation==1000 || c.rotation==20)));
    bool hasRight = components.any((c) => c.position == comp.position + Offset(gridSize, 0)&& (c.type == ComponentType.wire ||(c.rotation==0 || c.rotation==2 || c.rotation==1000 || c.rotation==20)));

    // ✅ Determine new image based on connections
    String newImage = "wire";
    if (hasUp) newImage += "_UP";
    if (hasDown) newImage += "_DOWN";
    if (hasLeft) newImage += "_LEFT";
    if (hasRight) newImage += "_RIGHT";

    // ✅ Update wire image path
    //wire.imagePath = "assets/$newImage.png";
    
    switch(newImage){
       case "wire_UP_DOWN_LEFT":
      comp.rotation =1;
       case "wire_UP_DOWN_RIGHT":
      comp.rotation =1;
       case "wire_UP_DOWN":
      comp.rotation =1;
      case "wire_UP":
      comp.rotation =1;
      case "wire_DOWN":
      comp.rotation =3;
      case "wire_RIGHT":
      comp.rotation =2;
       default:
      comp.rotation =0;
    }
  
    
  
  _correctHighlights();
  updateUI();
 
}

String _defaultImagePath(ComponentType type) {
  switch (type) {
    case ComponentType.resistor:
      return "assets/resistor.png";
    case ComponentType.DCvoltageSource:
      return "assets/voltage_source.png";
    case ComponentType.currentsource:
      return "assets/voltage_source.png";
    case ComponentType.diode:
      return "assets/diode.png";
    case ComponentType.wire:
      return "assets/wire.png";
    case ComponentType.ground:
      return "assets/ground.png";
    case ComponentType.capacitor:
      return "assets/capacitor.png";
    case ComponentType.inductor:
      return "assets/inductor.png";
    case ComponentType.transistor:
      return "assets/transistor.png";
    case ComponentType.oscilloscope:
      return "assets/oscilloscope.png";
    case ComponentType.voltmeter:
      return "assets/voltmeter.png";
    default:
      return "";
  }
}

void _correctHighlights() {
  
  setState(() {
    for (var comp in components) {
      // ✅ If the component is NOT a wire
      if (comp.type != ComponentType.wire) {
        
        // ✅ If NOT highlighted, ensure rotation is reset properly
        if (!comp.highlighted) {
          if (comp.rotation >= 10) {
            comp.rotation = (comp.rotation == 1000) ? 0 : comp.rotation ~/ 10;
          }
        } 
        
        // ✅ If highlighted, ensure rotation is properly multiplied
        else {
          if (comp.rotation < 10) {
            comp.rotation = (comp.rotation == 0) ? 1000 : comp.rotation * 10;
          }
        }
      }
    }
  });
  
}

void deleteHighlightedComponents() {
  setState(() {
    components.removeWhere((comp) => comp.highlighted);
  });
  print("🗑 Deleted all highlighted components.");
}


  void _addComponent(ComponentType type) {

      int number =0;
      switch(type)
      {
        case ComponentType.diode:
        {
          number=diodecounter;
          diodecounter++;
        }
        case ComponentType.resistor:
        {
          number=resistorcounter;
          resistorcounter++;
        }
        case ComponentType.DCvoltageSource:
        {
          number=voltageSourcecounter;
          voltageSourcecounter++;
        }
        case ComponentType.currentsource:
        {
          number=currentsourcecounter;
          currentsourcecounter++;
        }
        case ComponentType.acvoltagesourcepulse:
        {
          number=voltageSourcecounter;
          voltageSourcecounter++;
        }
        case ComponentType.acvoltagesourcesin:
        {
          number=voltageSourcecounter;
          voltageSourcecounter++;
        }
        case ComponentType.capacitor:
        {
          number=capacitorcounter;
          capacitorcounter++;
        }
        case ComponentType.inductor:
        {
          number=inductorcounter;
          inductorcounter++;
        }
        case ComponentType.transistor:
        {
          number=transistorcounter;
          transistorcounter++;
        }
        case ComponentType.oscilloscope:
        {
          number=oscilloscopecounter;
          oscilloscopecounter++;
        }
        default:
      }


  Offset initialPosition = _snapToGrid(Offset(200, 200));

  // ✅ Check if a wire exists at the position
  setState(() {
    components.removeWhere(
        (c) => c.position == initialPosition && c.type == ComponentType.wire);

    // ✅ Now add the new component
    components.add(Component(
      type: type,
      position: initialPosition,
      componentNumber: number,
      value: (type == ComponentType.wire || type==ComponentType.ground) ? null : (type == ComponentType.diode ? 0.7 : 1.0),
    ));
  });
  screenStateKey.currentState?._saveComponentsState();
  screenStateKey.currentState?._clearRedo();
}


void startCopyingComponent(Component original) {
  setState(() {
    components.add(Component(
      type: original.type,
      position: _snapToGrid(original.position + Offset(50, 50)), // ✅ Slightly offset from original
      value: original.value, // ✅ Copy the exact value
      rotation: original.rotation
   //   componentNumber: original.componentNumber // ✅ Copy the exact rotation
    ));
  });
}

void copyHighlightedComponents() {
  // ✅ Find all highlighted components
  List<Component> highlightedComponents = components.where((c) => c.highlighted).toList();

  if (highlightedComponents.isEmpty) return; // ✅ No components to copy

  // ✅ Find the highest and lowest Y positions
  double minY = highlightedComponents.map((c) => c.position.dy).reduce((a, b) => a < b ? a : b);
  double maxY = highlightedComponents.map((c) => c.position.dy).reduce((a, b) => a > b ? a : b);

  double verticalOffset = maxY - minY + gridSize +50; // ✅ Offset to place copies below

  setState(() {
    for (var original in highlightedComponents) {
      components.add(Component(
        type: original.type,
        position: _snapToGrid(original.position + Offset(0, verticalOffset)), // ✅ Paste below original
        value: original.value, // ✅ Copy the exact value
        rotation: (original.rotation == 1000) ? 0 : original.rotation ~/ 10, // ✅ Remove highlighting effect
         // ✅ Ensure copied components are unhighlighted
      ));
    }
  });

  print("✅ Copied ${highlightedComponents.length} components and pasted below.");
}



  Offset _snapToGrid(Offset position) {
  double x = (position.dx / gridSize).round() * gridSize;
  double y = (position.dy / gridSize).round() * gridSize;
  
  // ✅ Ensure components stay within the restricted placement area
  x = x.clamp(0, restrictedGridWidth - gridSize);
  y = y.clamp(0, gridHeight - gridSize);

  Offset newPos = Offset(x, y);

  // ✅ Check for wire connections after placing
 // _updateWireConnections();
 
//_saveComponentsState();
  return newPos;
}


  void _showPositions() {
    setState(() {
      componentPositions = components.map((comp) {
        double x = comp.position.dx == 0 ? 0 : comp.position.dx / gridSize;
        double y = comp.position.dy == 0 ? 0 : comp.position.dy / gridSize;
        int z= comp.rotation;
        int b= comp.componentNumber;
        bool a = comp.highlighted;
        bool n = comp.truenode;
        return "${comp.type.toString().split('.').last} at ($x, $y), higlighted: $a, rotation:$z, number:$b, truenode:$n\n";
      }).toList();
    });

    
  }



void _showContextMenu(BuildContext context, Offset position, Component component) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
    items: component.getContextMenuItems(context, () { // Pass context here
      setState(() {
        components.remove(component);
      });
    },// () => setState(() {})), // ✅ Pass setState() for UI updates
  ));
}
/*
void showVoltmeterDisplays(BuildContext context, List<Component> components) {
  removeVoltmeterDisplays(); // Clean old displays

  final overlay = Overlay.of(context);

  for (var comp in components) {
    if (comp.type == ComponentType.voltmeter) {
      final position = comp.position;

      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx + 80,
          top: position.dy +40,
          child: Material(
            
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 2),
                ],
              ),
              child: Text(
                comp.simulatedVoltage.toString()+" V",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      voltmeterDisplays.add(overlayEntry);
    }
  }
}
*/
void showVoltmeterDisplays(BuildContext context, List<Component> components) {
  removeVoltmeterDisplays(); // Clean old displays

  final overlay = Overlay.of(context);

  for (var comp in components) {
    if (comp.type == ComponentType.voltmeter || comp.type == ComponentType.ammeter) {
      final position = comp.position;

      // Determine the display text and units
      String displayText;
      if (comp.type == ComponentType.voltmeter) {
        displayText = "${comp.simulatedVoltage} V";
      } else {
        displayText = "${comp.currentSourceReference!.simulatedCurrent} A";
      }

      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx + 80,
          top: position.dy + 40,
          child: Material(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 2),
                ],
              ),
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      voltmeterDisplays.add(overlayEntry);
    }
  }
}

void removeVoltmeterDisplays() {
  for (final display in voltmeterDisplays) {
    display.remove();
  }
  voltmeterDisplays.clear();
}


  @override
  Widget build(BuildContext context) {
    
    return RawKeyboardListener(
    focusNode: FocusNode(), // Allows keyboard detection
    autofocus: true, // Auto-focus on this widget
    onKey: (RawKeyEvent event) {
      if (event is RawKeyDownEvent) { // Detect key press (not release)
        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ && !simulationlock) {
          _restoreLastState(); // Call  undo function
          
          print("🔄 Undo Triggered (Ctrl + Z)");
        }
        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyY && !simulationlock) {
          _REDOrestoreLastState(); // Call  redo function
          
          print("🔄 Redo Triggered (Ctrl + Y)");
        }

         if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {


          _showSaveFileDialog(); // Call save function
          
          print("file save Triggered (Ctrl + S)");
        }

        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyO) {


          _showLoadFileDialog(); // Call load function
          
          print("load save Triggered (Ctrl + O)");
        }
        if ( event.logicalKey == LogicalKeyboardKey.keyA && ( event.isControlPressed || RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight)) && !simulationlock ) {

          highlightAll(); // Call load function
          _correctHighlights();
          
          print("highlight all Triggered (Ctrl + A)");
        }
        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC && !simulationlock)  {
 
          copyHighlightedComponents(); // Call load function
          
          print("load save Triggered (Ctrl + C)");
        }

        if (event.logicalKey == LogicalKeyboardKey.delete && !simulationlock) {

        
          deleteHighlightedComponents();
       
          
          print("Delete Triggered (Delete");
          _updateWireConnections();
        }

        if ( event.logicalKey == LogicalKeyboardKey.arrowUp && !simulationlock) {
 
          moveHighlightedComponents("up"); // Call load function
          
          print("move up Triggered (ArrowUP)");
          _updateWireConnections();
        }
        if ( event.logicalKey == LogicalKeyboardKey.arrowDown && !simulationlock) {
 
          moveHighlightedComponents("down"); // Call load function
          
          print("move down Triggered (ArrowDOWN)");
          _updateWireConnections();
        }
        if ( event.logicalKey == LogicalKeyboardKey.arrowRight && !simulationlock) {
 
          moveHighlightedComponents("right"); // Call load function
          
          print("move right Triggered (ArrowRIGHT)");
          _updateWireConnections();
        }
        if ( event.logicalKey == LogicalKeyboardKey.arrowLeft && !simulationlock) {
 
          moveHighlightedComponents("left"); // Call load function
          
          print("move left Triggered (ArrowLEFT)");
          _updateWireConnections();
        }
      }
    },
    child: Scaffold(
    appBar: AppBar(
  title: Text("CircuitAcademy"),
  backgroundColor: Colors.grey[300],
  actions: [
    Row(
      mainAxisSize: MainAxisSize.min, // ✅ Prevents row from stretching
      children: [
        Row(
  children: [


TextButton.icon(
  key: _fileButtonKey, // Assign key to button
  onPressed: () async {
    final RenderBox button = _fileButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx , 
        buttonPosition.dy + button.size.height + 10, // ⬇ Places below button
        buttonPosition.dx + button.size.width, 
        buttonPosition.dy + button.size.height + 50, // Adjust dropdown height
      ),
      items: [
        PopupMenuItem<String>(
          value: 'Save File',
          child: Row(
            children: [
              Icon(Icons.save, color: Colors.blue), // 🟦 Save icon
              SizedBox(width: 8),
              Text('Save File'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'Load File',
          child: Row(
            children: [
              Icon(Icons.folder_open, color: Colors.green), // 🟩 Load icon
              SizedBox(width: 8),
              Text('Load File'),
            ],
          ),
        ),
      ],
    );

    if (selected == 'Save File') {
      _showSaveFileDialog(); // Call save function
    } else if (selected == 'Load File') {
      _showLoadFileDialog(); // Call load function
    }
  },
  icon: Icon(Icons.folder, color: Colors.deepPurpleAccent), // 📁 File icon
  label: Text("File", style: TextStyle(color: Colors.black)),
),



  ],
),
SizedBox(width: 20),

      Tooltip(
  message: "click to undo the last change",
  textStyle: TextStyle(color: Colors.white, fontSize: 14),
  decoration: BoxDecoration(
    color: Colors.grey,
    borderRadius: BorderRadius.circular(15),
  ),
  child:
        Opacity(
  opacity: _undoButtonOpacity,
  child:
       GestureDetector(
 onLongPress: () {
    _longPressTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      _restoreLastState(); // Keep triggering while holding

    });
  },
  onLongPressEnd: (_) {
    _longPressTimer?.cancel(); // Stop when user releases the button

  },
  child: ElevatedButton(
    onPressed: _restoreLastState, // Single tap triggers once
    child: Icon(Icons.undo, size: 24),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurpleAccent,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  ),
)

        
        ),
        ),

        SizedBox(width: 10),
         Tooltip(
  message: "click to redo the last change",
  textStyle: TextStyle(color: Colors.white, fontSize: 14),
  decoration: BoxDecoration(
    color: Colors.grey,
    borderRadius: BorderRadius.circular(15),
  ),
  child:

Opacity(
  opacity: _redoButtonOpacity,
  child:
        ElevatedButton(
        onPressed: _REDOrestoreLastState, // ✅ Call _restoreLastState when pressed
        child: Icon(Icons.redo, size: 24),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurpleAccent, // Change color if needed
          foregroundColor: Colors.white, // Text color
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),

        
        ),
),


         ),
  SizedBox(width: 30),
  Tooltip(
  message: simulationlock ? 'Pause simulation' : 'Start simulation',
  child: IconButton(
  icon: isLoading
      ? SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              simulationlock
                  ? Color.fromARGB(255, 224, 47, 35)
                  : Color.fromARGB(255, 79, 214, 84),
            ),
          ),
        )
      : Icon(
          simulationlock ? Icons.pause_circle_filled : Icons.play_circle_fill,
          size: 36,
          color: simulationlock
              ? Color.fromARGB(255, 224, 47, 35)
              : Color.fromARGB(255, 79, 214, 84),
        ),
  onPressed: () async {
    if (!simulationlock) {
      HapticFeedback.mediumImpact();

      setState(() {
        isLoading = true;
        simulationlock = true;
        netlistpanelvisible = simulationlock;
        componentPositions.clear();
      });

      List<List<Component>> circuits = getConnectedCircuits(components);
      List<String> allOutputs = [];
      circuitTypes = {};
      String fileContent;
      int circuitnumber = 1;

      for (var circuit in circuits) {
        bool transient = circuit.any((comp) =>
            comp.type == ComponentType.acvoltagesourcepulse ||
            comp.type == ComponentType.acvoltagesourcesin);

        refreshCircuit(circuit);
        generateNodes(circuit);
        correctNodes(circuit);
        correctTruenodes(circuit);

        if (!transient) {
          fileContent = getnetlistop(circuit, circuitnumber).join('\n');
          sendNetlistToBackendop(fileContent, circuit, circuitnumber);
          allOutputs.addAll(getnetlistop(circuit, circuitnumber));

          String result = await classifyNetlistOpenAI(fileContent);
          String? scamResult = await fetchScanResult();

          setState(() {
            componentPositions.clear();
            componentPositions.add("circuit seems to be : \n");
            componentPositions.add(result);
            componentPositions.add("----------------------------------------------------------------------------------------------------\nCircuit Solution Breakdown:\n");
            componentPositions.add(scamResult ?? 'circuit seems to contain advanced elements such as transistors or diodes which cant be analyzed using simple nodal analysis');
            componentPositions.add("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
          });
        } else {
          fileContent = getnetlistTran(circuit, circuitnumber).join('\n');
          sendNetlistToBackendtran(fileContent, circuit, circuitnumber);
          allOutputs.add("circuit $circuitnumber:\n");
          allOutputs.addAll(getnetlistTran(circuit, circuitnumber));

          String result = await classifyNetlistOpenAI(fileContent);

          String? scamResult = await fetchScanResult();

          setState(() {
            componentPositions.clear();
            componentPositions.add("circuit seems to be : \n");
            componentPositions.add(result);
            componentPositions.add("----------------------------------------------------------------------------------------------------\nCircuit Solution Breakdown:\n");
            componentPositions.add(scamResult ?? 'circuit seems to contain advanced elements such as transistors or diodes which cant be analyzed using simple nodal analysis');
            componentPositions.add("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
          });


        }

        circuitnumber++;
        assignCurrentToWires(circuit);
        Future.delayed(Duration(milliseconds: 100), () {
          assignVoltageToVoltmeter(circuit);
        });
      }

      setState(() {
        isLoading = false;
      });

      updateUI();
    } else {
      setState(() {
        simulationlock = false;
        netlistpanelvisible =simulationlock;
        removeVoltmeterDisplays();
      });
    }
  },
),

)

,
        SizedBox(width: 340),
TextButton(
  onPressed: () async {
    final RenderBox button = _sourceButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height + 10,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy + button.size.height + 50,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'DC Voltage Source',
          child: Text('DC Voltage Source'),
        ),
        PopupMenuItem<String>(
          value: 'AC Sinusoidal Source',
          child: Text('AC Sinusoidalvoltage Source'),
        ),
        PopupMenuItem<String>(
          value: 'AC Pulse Source',
          child: Text('AC Pulse voltage Source'),
        ),
        PopupMenuItem<String>(
          value: 'current Source',
          child: Text('Current Source'),
        ),
      ],
    );

    if (selected != null) {
      switch (selected) {
        case 'DC Voltage Source':
          _addComponent(ComponentType.DCvoltageSource);
          break;
        case 'AC Sinusoidal Source':
          _addComponent(ComponentType.acvoltagesourcesin);
          break;
        case 'AC Pulse Source':
          _addComponent(ComponentType.acvoltagesourcepulse);
          break;
        case 'current Source':
          _addComponent(ComponentType.currentsource);
          break;
      }
    }
  },
  key: _sourceButtonKey,
  child: Text("Sources", style: TextStyle(color: Colors.black)),
)



,
        _buildComponentButton(ComponentType.resistor, "Resistor"),
        _buildComponentButton(ComponentType.diode, "Diode"),
        _buildComponentButton(ComponentType.ground, "Ground"),
        _buildComponentButton(ComponentType.capacitor, "Capacitor"),
        _buildComponentButton(ComponentType.inductor, "Inductor"),
        _buildComponentButton(ComponentType.transistor, "Transistor"),
       // _buildComponentButton(ComponentType.oscilloscope, "oscilloscope"),
      //  _buildComponentButton(ComponentType.voltmeter, "voltmeter"),
      //  _buildComponentButton(ComponentType.ammeter, "Ammeter"),
        TextButton(
  onPressed: () async {
    final RenderBox button = _measurementsButtonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height + 10,
        buttonPosition.dx + button.size.width,
        buttonPosition.dy + button.size.height + 50,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'oscilloscope',
          child: Text('oscilloscope'),
        ),
        PopupMenuItem<String>(
          value: 'voltmeter',
          child: Text('Voltmeter'),
        ),
        PopupMenuItem<String>(
          value: 'Ammeter',
          child: Text('Ammeter'),
        ),
      ],
    );

    if (selected != null) {
      switch (selected) {
        case 'oscilloscope':
          _addComponent(ComponentType.oscilloscope);
          break;
        case 'voltmeter':
          _addComponent(ComponentType.voltmeter);
          break;
        case 'Ammeter':
          _addComponent(ComponentType.ammeter);
          break;

      }
    }
  },
  key: _measurementsButtonKey,
  child: Text("measurement tools", style: TextStyle(color: Colors.black)),
),
       
        SizedBox(width: 350), // ✅ Pushes buttons to the left
      ],
    ),
  ],
),

      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[200],
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.white,
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      thickness: 8,
                      radius: Radius.circular(10),
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        thickness: 8,
                        radius: Radius.circular(10),
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              width: totalGridWidth,
                              height: gridHeight,
                              child: Stack(
                                children: [
                                  
                                  _buildGrid(),
                                  ...components.map((comp) => Positioned(
  left: comp.position.dx,
  top: comp.position.dy,
  child: Stack(
    clipBehavior: Clip.none, // Allows text to be positioned outside the Stack
    alignment: Alignment.center,
    children: [ 
      if (comp.value != null || comp.node)
  Positioned(
    top: -20, // Moves text 20 pixels above the component
    child: Text(
      "${_getUnit(comp)}", // ✅ Append the correct unit
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color.fromARGB(255, 33, 19, 236),
       
        
      
      
      ),

    ),
    
  ),

      GestureDetector(
  onTap: () {
    if(!simulationlock){
    if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
      // ✅ Shift + Click toggles highlighting
      setState(() {

        if(comp.type == ComponentType.wire)
        {
          _highlightFullWire(comp);
        }
        else{
        if (comp.highlighted) {
          comp.highlighted = false;
          if (comp.rotation == 1000) {
            comp.rotation = 0;
          } else {
            comp.rotation ~/= 10; // Divide by 10
          }
        } else {
          comp.highlighted = true;
          if (comp.rotation == 0) {
            comp.rotation = 1000;
          } else {
            comp.rotation *= 10; // Multiply by 10
          }
        }
      }
      });
    }}
  },
  onSecondaryTapDown: (details) {
    if(!simulationlock)
    _showContextMenu(context, details.globalPosition, comp);
  },
  

  onDoubleTap: ()
  {
    String valtype= "";
    switch (comp.type) {
    case ComponentType.resistor:
    valtype ="Resitsance";
    case ComponentType.currentsource:
    valtype ="Ampere";
    case ComponentType.DCvoltageSource:
    valtype ="Voltage";
    case ComponentType.acvoltagesourcepulse:
    valtype ="Voltage";
    case ComponentType.acvoltagesourcesin:
    valtype ="Voltage";
    case ComponentType.diode:
    valtype ="forward Voltage";
    case ComponentType.capacitor:
    valtype ="Farad";
    case ComponentType.inductor:
    valtype ="Henry";
    default:
      valtype ="value";
  }
    if ((HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight) )&& !simulationlock) {
      screenStateKey.currentState?._highlightConnectedComponents(comp);
    }
    
    else if (comp.type == ComponentType.acvoltagesourcepulse && !simulationlock) {
  _showSevenValueDialog(
      context,
      "Edit Pulse Parameters",
      (v1, v2, td, tr, tf, pw, per) {
        // 👇 This is where you get the 7 values after the user presses OK
        print("V1: $v1");
        print("V2: $v2");
        print("TD: $td");
        print("TR: $tr");
        print("TF: $tf");
        print("PW: $pw");
        print("PER: $per");

        // Example: update your component's parameters
        setState(() {
          comp.v1 = v1;
          comp.v2 = v2;
          comp.td = td;
          comp.tr = tr;
          comp.tf = tf;
          comp.pw = pw;
          comp.per = per;
        });
      },
      initialValues: [
        comp.v1,
        comp.v2,
        comp.td,
        comp.tr,
        comp.tf,
        comp.pw,
        comp.per,
      ],
    );
  
  
}

else if (comp.type == ComponentType.acvoltagesourcesin && !simulationlock) {
  _showSixValueDialog(
  context,
  "Edit AC Source Parameters",
  (vo, va, freq, td, theta, phase) {
    comp.vo = vo;
    comp.va = va;
    comp.freq = freq;
    comp.td = td;
    comp.theta = theta;
    comp.phase = phase;

    screenStateKey.currentState?.updateUI();
    screenStateKey.currentState?._saveComponentsState();
    screenStateKey.currentState?._clearRedo();
  },
  initialValues: [
    comp.vo,
    comp.va,
    comp.freq,
    comp.td,
    comp.theta,
    comp.phase,
  ],
);
  
  
}

    else if(comp.type==ComponentType.oscilloscope)
    {
 comp._showHtmlImageDialog(context, comp.transientimage );

  //  _showNotification(comp.transientimage.src!);
    }
    else if(comp.type==ComponentType.oscilloscope)
    {
 //cunt
    }

    else if(comp.type != ComponentType.wire && comp.type != ComponentType.ammeter&& comp.type != ComponentType.voltmeter && comp.type != ComponentType.oscilloscope && comp.type != ComponentType.ground && comp.type != ComponentType.diode && comp.type != ComponentType.transistor && !simulationlock){
    comp._showValueDialog(context, "Change $valtype", (newValue) {
            comp.value = newValue; // Update value
            screenStateKey.currentState?.updateUI();
            screenStateKey.currentState?._saveComponentsState();
            screenStateKey.currentState?._clearRedo();
    }

    );
    }
    
  },
  
 child: Draggable<Component>(
    data: comp,
    feedback: _buildComponent(comp.type, comp.rotation),
    childWhenDragging: Opacity(opacity: 0.5, child: _buildComponent(comp.type, comp.rotation)),
    child: _buildComponent(comp.type, comp.rotation),
    
    onDragStarted: () {
      if (comp.type == ComponentType.wire && !simulationlock ) {
        _findConnectedWires(comp);
      }
    },
    
    onDraggableCanceled: (_, Offset position) {
      if( !simulationlock)
      {
      setState(() {
        Offset snappedPos = _snapToGrid(position - Offset(0, kToolbarHeight- _verticalController.offset));
        Offset delta = snappedPos - comp.position;

        // ✅ Remove any wire at this position before placing the component
        components.removeWhere((c) => c.position == snappedPos && c.type == ComponentType.wire);

        // ✅ Move the dragged component
        comp.position = snappedPos;
        if (ComponentType.wire !=comp.type )
        {
          autorotatenonwire(comp);
        }

        // ✅ Only move highlighted components if the dragged component is highlighted
        if (comp.highlighted) {
          for (var component in components.where((c) => c.highlighted)) {
            if (component != comp) { // Avoid redundant movement
              component.position += delta;
            }
          }
        }
        else if(comp.type == ComponentType.wire) {
          for (var wire in selectedWires) {
                if(!(wire.position == snappedPos))
                {
      wire.position += delta;
                }

                   }

        }

        _updateWireConnections();
        _saveComponentsState();
        _clearRedo();
      });
      }
    },
  ),

),

    ],
  ),
))
                              ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Visibility(
  visible: netlistpanelvisible,
  child:
          Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: EdgeInsets.all(15),
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Space buttons evenly

children: [
  ElevatedButton(
  onPressed: () {
    setState(() {
      netlistpanelvisible = false;
    });
  },
  child: Text("Hide explantion panel"),
)

  ],
),

                SizedBox(height: 10),
              Expanded(
  child: SingleChildScrollView(
    padding: EdgeInsets.all(8),
    child: isLoading
        ? Center(child: CircularProgressIndicator())
        : SelectableText(
            componentPositions.join('\n'),
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
  ),
),
 

              ],
            ),
          ),
          ),
          
if (!netlistpanelvisible && simulationlock)
  Align(
    alignment: Alignment.topLeft, // Top left corner
    child: Padding(
      padding: EdgeInsets.only(top: 20), // Adjust for spacing
      child: SizedBox(
        width: 100,
        height: 36,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              netlistpanelvisible = true;
            });
          },
          child: Text("Show panel", style: TextStyle(fontSize: 13)),
        ),
      ),
   ),
  )



        ],
      ),
    ),
    );
  }

  Widget _buildGrid() {
   // componentHistory.add(_saveComponentsToList());
  return GestureDetector(
    onPanStart: (details) {
      if(!simulationlock)
      {
      isDrawingWires = true; // ✅ Start drawing wires
      _placeWireAt(details.localPosition);
      }
    },
    onPanUpdate: (details) {
      if(!simulationlock)
      {
      if (isDrawingWires) {
        _placeWireAt(details.localPosition);
      }
      }
    },
    onPanEnd: (_) {
      if(!simulationlock)
      isDrawingWires = false; // ✅ Stop drawing wires
      
    },
    child: MouseRegion(
      onEnter: (_) {
        html.document.onContextMenu.listen((event) {
          event.preventDefault(); // ✅ Disable right-click on grid
        });
      },
      onHover: (event) {
    globalMousePosition = event.localPosition;
  },
      child: CustomPaint(
        painter: GridPainter(),
        size: Size(totalGridWidth, gridHeight),
      ),
    ),
    
  );
}


void _placeWireAt(Offset position) {
  // ✅ Offset position slightly up and left before snapping to grid
  const double offsetX = -10; // Move left by 10 pixels
  const double offsetY = -30; // Move up by 10 pixels

  Offset adjustedPosition = position + Offset(offsetX, offsetY);
  Offset snappedPos = _snapToGrid(adjustedPosition);

  // ✅ Prevent duplicate wire placement
  if (lastWirePosition == snappedPos) return;
  lastWirePosition = snappedPos;

  // ✅ Check if any component (not just wires) is already at this position
  bool positionOccupied = components.any((c) => c.position == snappedPos);

  if (!positionOccupied) {
    setState(() {
      components.add(Component(
        type: ComponentType.wire,
        position: snappedPos,
      ));
    });
    screenStateKey.currentState?._saveComponentsState();
    screenStateKey.currentState?._clearRedo();
    _updateWireConnections();
  }
}


 void assignNode(Component wire)
 {
  if(!wire.node){
        wire.node =true;
        //wire.componentNumber = nodecounter;
       // nodecounter++;
        screenStateKey.currentState?.updateUI();  
        }

 }


  Widget _buildComponentButton(ComponentType type, String label) {
    return TextButton(
      onPressed: () {
        if(!simulationlock)
        _addComponent(type);
      },
      child: Text(label, style: TextStyle(color: Colors.black)),
    );
  }

  Widget _buildComponent(ComponentType type, int rotation) {
  String imagePath = _getImagePath(type, rotation);
  return Image.asset(
    imagePath,
    width: 50,
    height: 50,
  );
  
}

 String _getImagePath(ComponentType type, int rotation) {
  String basePath = "assets/";

  switch (type) {
    case ComponentType.resistor:
      return basePath + "resistor_$rotation.png"; // Example: resistor_0.png, resistor_1.png, etc.
    case ComponentType.currentsource:
      return basePath + "current_source_$rotation.png";
    case ComponentType.DCvoltageSource:
      return basePath + "voltage_source_$rotation.png";
    case ComponentType.acvoltagesourcepulse:
      return basePath + "Pulse_source_$rotation.png";
    case ComponentType.acvoltagesourcesin:
      return basePath + "AC_source_$rotation.png";
    case ComponentType.diode:
      return basePath + "diode_$rotation.png";
    case ComponentType.wire:
      return basePath + "wire_$rotation.png";
    case ComponentType.ground:
      return basePath + "ground_$rotation.png";
    case ComponentType.capacitor:
      return basePath + "capacitor_$rotation.png";
    case ComponentType.inductor:
      return basePath + "inductor_$rotation.png";
    case ComponentType.transistor:
      return basePath + "transistor_$rotation.png";
    case ComponentType.oscilloscope:
      return basePath + "oscilloscope_$rotation.png";
    case ComponentType.voltmeter:
      return basePath + "voltmeter_$rotation.png";
    case ComponentType.ammeter:
      return basePath + "voltmeter_$rotation.png";
    default:
      return "";
  }
}


}


class Component {
  final ComponentType type;
  Offset position;
  int rotation;
  double? value;
  bool highlighted = false;
  bool node = false;
  bool truenode = false;
  bool adjacent =false;
  bool chill = false;
  double? simulatedVoltage;
  double? simulatedCurrent;
  double? simulatedCollectorCurrent;
  double? simulatedBaseCurrent;
  double? simulatedEmitterCurrent;
  double v1 =0, v2=10, td=0, tr=1, tf=1, pw=10, per=20;
  double vo = 0 ,va =5, freq =50000,theta =0, phase =0;
  int componentNumber;
  html.ImageElement? transientimage;


 Component? currentSourceReference;



    Component({
    required this.type,
    required this.position,
    this.componentNumber = 0,
    this.value,
    this.rotation = 0,
    this.node = false,
    this.adjacent = false,
    this.v1 = 0,
    this.v2 = 10,
    this.td = 0,
    this.tr = 1,
    this.tf = 1,
    this.pw = 10,
    this.per = 20,
    this.vo = 0,
    this.va = 5,
    this.freq = 50000,
    this.theta = 0,
    this.phase = 0,
  });
 //  : imagePath = screenStateKey.currentState?._defaultImagePath(type);
   
   

List<PopupMenuEntry> getContextMenuItems(BuildContext context, VoidCallback onDelete) {
  List<PopupMenuEntry> menuItems = [];

  // ✅ 1. "Change Value" should be first
  if (value != null) {
    if (type != ComponentType.wire && type != ComponentType.ground && type != ComponentType.diode && type != ComponentType.transistor) {
      menuItems.add(PopupMenuItem(
        child: Text("Change Value"),
        onTap: () {
           String valtype= "";
    switch (type) {
    case ComponentType.resistor:
    valtype ="Resitsance";
    case ComponentType.currentsource:
    valtype ="Ampere";
    case ComponentType.DCvoltageSource:
    valtype ="Voltage";
    case ComponentType.acvoltagesourcepulse:
    valtype ="Voltage";
    case ComponentType.acvoltagesourcesin:
    valtype ="Voltage";
  //  case ComponentType.diode:
   // valtype ="forward Voltage";
    case ComponentType.capacitor:
    valtype ="Farad";
    case ComponentType.inductor:
    valtype ="Henry";
    default:
      valtype ="value";
  }
   if (type == ComponentType.acvoltagesourcepulse) {
  _showSevenValueDialog(
      context,
      "Edit Pulse Parameters",
      (v11, v21, td1, tr1, tf1, pw1, per1) {
        // 👇 This is where you get the 7 values after the user presses OK
        print("V1: $v11");
        print("V2: $v21");
        print("TD: $td1");
        print("TR: $tr1");
        print("TF: $tf1");
        print("PW: $pw1");
        print("PER: $per1");

        // Example: update your component's parameters
        screenStateKey.currentState?.setState(() {
          v1 = v11;
          v2 = v21;
          td = td1;
          tr = tr1;
          tf = tf1;
          pw = pw1;
          per = per1;
        });
      },
      initialValues: [
        v1,
        v2,
        td,
        tr,
        tf,
        pw,
        per,
      ],
    );
  
  
}
    else if (type == ComponentType.acvoltagesourcesin) {
  _showSixValueDialog(
  context,
  "Edit AC Source Parameters",
  (vo, va, freq, td, theta, phase) {
    vo = vo;
    va = va;
    freq = freq;
    td = td;
    theta = theta;
    phase = phase;

    screenStateKey.currentState?.updateUI();
    screenStateKey.currentState?._saveComponentsState();
    screenStateKey.currentState?._clearRedo();
  },
  initialValues: [
   vo,
   va,
   freq,
   td,
   theta,
   phase,
  ],
);

  
  
}

 else
          _showValueDialog(context, "Change $valtype", (newValue) {
            value = newValue; // Update value
            screenStateKey.currentState?.updateUI();
            screenStateKey.currentState?._saveComponentsState();
            screenStateKey.currentState?._clearRedo();
          });
        },
      ));
    } 
  }

  // ✅ 2. "Copy" should be second
  if (type != ComponentType.wire && !highlighted) {
    menuItems.add(PopupMenuItem(
      child: Text("Copy"),
      onTap: () {
        screenStateKey.currentState?.startCopyingComponent(this);
        screenStateKey.currentState?._saveComponentsState();
        screenStateKey.currentState?._clearRedo();
      },
    ));
  }
  if (highlighted) {
    menuItems.add(PopupMenuItem(
      child: Text("Copy"),
      onTap: () {
        screenStateKey.currentState?.copyHighlightedComponents();
        screenStateKey.currentState?._saveComponentsState();
        screenStateKey.currentState?._clearRedo();
      },
    ));
  }
  /*
if (currentSourceReference!= null) {
  /*
  String? b =currentSourceReference?.componentNumber.toString();
 menuItems.add(PopupMenuItem(
      child: Text("$b"),
    ));
    */
 if(currentSourceReference?.simulatedCurrent!=null)
 {
  double? simcur = currentSourceReference!.simulatedCurrent;
    menuItems.add(PopupMenuItem(
      child: Text("$simcur A"),
      onTap: (){
        screenStateKey.currentState?._highlightFullWirecur(this);
      },
    ));

  }
}*/



  // ✅ 3. "Delete" should be third
   if (!highlighted) {
  menuItems.add(PopupMenuItem(
    child: Text("Delete"),
    onTap: () {
      onDelete(); // ✅ Delete the component
      Future.delayed(Duration(milliseconds: 10), () { 
        screenStateKey.currentState?._updateWireConnections(); // ✅ Update wire connections
        screenStateKey.currentState?._saveComponentsState();
        screenStateKey.currentState?._clearRedo();
      });
    },
  ));
}

if (type==ComponentType.transistor) {

 
 {
  double? simcurb = simulatedBaseCurrent;
  double? simcurc = simulatedCollectorCurrent;
  double? simcure = simulatedEmitterCurrent;
    menuItems.add(PopupMenuItem(
      child: Text("base $simcurb A"),
    ));
    menuItems.add(PopupMenuItem(
      child: Text("collector $simcurc A"),
    ));
    menuItems.add(PopupMenuItem(
      child: Text("emitter $simcure A"),
    ));

  }
}
  // ✅ 4. "Delete all highlighted components" if applicable
  if (highlighted) {
    menuItems.add(PopupMenuItem(
      child: Text("Delete"),
      onTap: () {
        Future.delayed(Duration(milliseconds: 10), () {
          screenStateKey.currentState?.deleteHighlightedComponents();
        });
      },
    ));
  }

  // ✅ 5. "Delete Full Wire" (if applicable)
  if (type == ComponentType.wire && !highlighted) {
    menuItems.add(PopupMenuItem(
      child: Text("Delete Full Wire"),
      onTap: () {
        Future.delayed(Duration(milliseconds: 10), () {
          screenStateKey.currentState?._deleteFullWire(this);
        });
      },
    ));
  
  }
/*
     if(simulatedCurrent != null){
      
     
    menuItems.add(PopupMenuItem(
      child: Text("$simulatedCurrent A"),
    ));
   }
    if(simulatedVoltage != null){
    menuItems.add(PopupMenuItem(
      child: Text("$simulatedVoltage V"),
    ));
   }*/

/*
  if (type == ComponentType.wire ) {
    menuItems.add(PopupMenuItem(
      child: Text("Assign node"),
      onTap: () {
         screenStateKey.currentState?.assignNode(this);
        screenStateKey.currentState?.updateUI();
        
      },
    ));
  }
*/
  // ✅ 6. "Rotate Right" & "Rotate Left" (if applicable)
  if (type != ComponentType.wire) {
    menuItems.add(PopupMenuItem(
      child: Text("Rotate Right"),
      onTap: () {
         if (highlighted) {
          // Highlighted rotation cycle: 1000 → 10 → 20 → 30 → 1000
          if (rotation == 1000) {
            rotation = 10;
          } else if (rotation == 10) {
            rotation = 20;
          } else if (rotation == 20) {
            rotation = 30;
          } else if (rotation == 30) {
            rotation = 1000;
          }
        } else
        {
        rotation = (rotation + 1) % 4; // ✅ Cycles 0 → 1 → 2 → 3 → 0
        }
  
        screenStateKey.currentState?.updateUI(); // ✅ Refresh UI
        Future.delayed(Duration(milliseconds: 10), () { 
          screenStateKey.currentState?._updateWireConnections();
        });
      },
    ));

    menuItems.add(PopupMenuItem(
      child: Text("Rotate Left"),
      onTap: () {
     if (highlighted) {
          // Highlighted rotation cycle: 1000 → 30 → 20 → 10 → 1000
          if (rotation == 1000) {
            rotation = 30;
          } else if (rotation == 30) {
            rotation = 20;
          } else if (rotation == 20) {
            rotation = 10;
          } else if (rotation == 10) {
            rotation = 1000;
          }
        } else
        {
        rotation = (rotation - 1) % 4; // ✅ Cycles 0 → 3 → 2 → 1 → 0
        if (rotation < 0) rotation = 3; // ✅ Handle negative values
        }
    
        screenStateKey.currentState?.updateUI(); // ✅ Refresh UI
        Future.delayed(Duration(milliseconds: 10), () { 
          screenStateKey.currentState?._updateWireConnections();
        });
      },
    ));
  }

  screenStateKey.currentState?._updateWireConnections();
  return menuItems;
}
/*
  void _showHtmlImageDialog(BuildContext context, html.ImageElement imageElement) {
  final viewType = 'html-img-${DateTime.now().microsecondsSinceEpoch}';

  // ✅ Set size using CSS on the image itself
  imageElement
    ..style.width = '100%'      // Fill container width
    ..style.height = '100%'     // Fill container height
    ..style.objectFit = 'contain'
    ..style.display = 'block'
    ..style.margin = '0 auto';

  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int _) => imageElement);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            // ✅ Set size of the dialog panel here
            Container(
              width: 700, // Adjust width of the panel
              height: 500, // Adjust height of the panel
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: HtmlElementView(viewType: viewType),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: Icon(Icons.close),
                splashRadius: 20,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

*/
void _showHtmlImageDialog(BuildContext context, html.ImageElement? imageElement) {
  if (imageElement != null) {
    final viewType = 'html-img-${DateTime.now().microsecondsSinceEpoch}';

    // ✅ Set size using CSS on the image itself
    imageElement
      ..style.width = '100%'      // Fill container width
      ..style.height = '100%'     // Fill container height
      ..style.objectFit = 'contain'
      ..style.display = 'block'
      ..style.margin = '0 auto';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) => imageElement);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                width: 700,
                height: 500,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HtmlElementView(viewType: viewType),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: Icon(Icons.close),
                  splashRadius: 20,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  } else {
    // If imageElement is null — show the fallback message instead
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                width: 700,
                height: 500,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Graph unavailable as simulation isn’t running in linear time',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: Icon(Icons.close),
                  splashRadius: 20,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



  void _showValueDialog(BuildContext context, String title, Function(double) onValueChanged) {
  TextEditingController controller = TextEditingController(text: value?.toString() ?? "");
  FocusNode focusNode = FocusNode();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(focusNode);
          });

          return RawKeyboardListener(
            focusNode: FocusNode(), // Listener node
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  double? newValue = double.tryParse(controller.text);
                  if (newValue == null || newValue == 0) {
                    setDialogState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("⚠ Please enter a valid non-zero number")),
                    );
                  } else {
                    onValueChanged(newValue);
                    Navigator.of(context).pop();
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: "Enter new value",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    double? newValue = double.tryParse(controller.text);
                    if (newValue == null || newValue == 0) {
                      setDialogState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("⚠ Please enter a valid non-zero number")),
                      );
                    } else {
                      onValueChanged(newValue);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text("OK"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


}


  void _showSevenValueDialog(
  BuildContext context,
  String title,
  Function(double, double, double, double, double, double, double) onValuesChanged, {
  List<double?>? initialValues, // Optional list of 7 initial values
}) {
  final controllers = List.generate(
    7,
    (index) => TextEditingController(
      text: (initialValues != null && initialValues.length > index)
          ? initialValues[index]?.toString() ?? ''
          : '',
    ),
  );

  final focusNodes = List.generate(7, (_) => FocusNode());
  final labels = ["Voltage low", "Voltage high", "Delay time(ns)", "Rise time(ns)", "Fall time(ns)", "pulse width(ns)", "Period(ns)"];
  final errorTexts = List<String?>.filled(7, null);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(focusNodes[0]);
          });

          void handleSubmit() {
            final values = List<double?>.generate(
              7,
              (i) => double.tryParse(controllers[i].text),
            );

            bool hasError = false;

            for (int i = 0; i < values.length; i++) {
              if (values[i] == null) {
                hasError = true;
                errorTexts[i] = "⚠ Invalid number";
              } else {
                errorTexts[i] = null;
              }
            }

            if (hasError) {
              setDialogState(() {});
            } else {
              onValuesChanged(
                values[0]!,
                values[1]!,
                values[2]!,
                values[3]!,
                values[4]!,
                values[5]!,
                values[6]!,
              );
              Navigator.of(context).pop();
            }
          }

          return RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  handleSubmit();
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[index]),
                          TextField(
                            controller: controllers[index],
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            focusNode: focusNodes[index],
                            decoration: InputDecoration(
                              hintText: "Enter ${labels[index]}",
                              errorText: errorTexts[index],
                            ),
                            onSubmitted: (_) {
                              if (index < 6) {
                                FocusScope.of(context)
                                    .requestFocus(focusNodes[index + 1]);
                              } else {
                                handleSubmit();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: handleSubmit,
                  child: Text("OK"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


void _showSixValueDialog(
  BuildContext context,
  String title,
  Function(double, double, double, double, double, double) onValuesChanged, {
  List<double?>? initialValues,
}) {
  final controllers = List.generate(
    6,
    (index) => TextEditingController(
      text: (initialValues != null && initialValues.length > index)
          ? initialValues[index]?.toString() ?? ''
          : '',
    ),
  );

  final focusNodes = List.generate(6, (_) => FocusNode());
  final labels = ["DC offset", "Voltage amplitude	", "Frequency", "time delay(ns)", "Theta", "Phase"];
  final errorTexts = List<String?>.filled(6, null);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future.delayed(Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(focusNodes[0]);
          });

          void handleSubmit() {
            final values = List<double?>.generate(
              6,
              (i) => double.tryParse(controllers[i].text),
            );

            bool hasError = false;

            for (int i = 0; i < values.length; i++) {
              if (values[i] == null) {
                hasError = true;
                errorTexts[i] = "⚠ Invalid number";
              } else {
                errorTexts[i] = null;
              }
            }

            if (hasError) {
              setDialogState(() {});
            } else {
              onValuesChanged(
                values[0]!,
                values[1]!,
                values[2]!,
                values[3]!,
                values[4]!,
                values[5]!,
              );
              Navigator.of(context).pop();
            }
          }

          return RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  handleSubmit();
                } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(6, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[index]),
                          TextField(
                            controller: controllers[index],
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            focusNode: focusNodes[index],
                            decoration: InputDecoration(
                              hintText: "Enter ${labels[index]}",
                              errorText: errorTexts[index],
                            ),
                            onSubmitted: (_) {
                              if (index < 5) {
                                FocusScope.of(context)
                                    .requestFocus(focusNodes[index + 1]);
                              } else {
                                handleSubmit();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: handleSubmit,
                  child: Text("OK"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}



enum ComponentType { resistor,currentsource, DCvoltageSource,acvoltagesourcepulse,acvoltagesourcesin, diode, wire, ground, capacitor, inductor, transistor, oscilloscope , voltmeter ,ammeter }

class GridPainter extends CustomPainter {
  static const double gridSize = 50.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;
    
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

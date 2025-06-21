CircuitAcademy – Circuit Simulation Platform
CircuitAcademy includes a fully integrated simulation engine designed to help students understand and analyze electronic circuits in both theoretical and practical ways. The platform focuses on simplifying circuit analysis by combining a drag-and-drop interface with real-time simulation and symbolic explanation.

Features
  Real-time circuit simulation using NGSpice

  Symbolic analysis engine using the Modified Nodal Analysis (MNA) method via SymPy

  AC analysis support with transient waveform plotting using Gnuplot

  Automatic netlist generation from user-drawn circuits
  
  Detailed mathematical breakdown of circuit behavior, including:

   Matrix formulation (A·x = z)

   Node voltages

   Branch currents using Ohm’s Law and impedance

  Ability to save and load circuits as .txt files

  Integrated oscilloscope for AC signal visualization
  
  Integrated multimers component for dc outputs

  Keyboard shortcuts for circuit editing (undo, redo, copy, highlight, save, load)

  Circuit classification using a Python-based AI API

Technologies Used
  NGSpice – For executing DC and AC simulations

  SymPy (Python) – For symbolic matrix-based analysis

  Gnuplot – For voltage/time graph rendering in AC simulations

  Flutter – For building the cross-platform circuit editor interface

  Node.js – For backend simulation management and API routing

Current Limitations
The symbolic explanation system doesnt support components like diodes and transistors are not yet supported



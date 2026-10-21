# Zybo (Vivado)

⚠️ **Not yet a board project.** This folder holds only `hits_vivado.tcl`, which
synthesizes, places and routes the HITS core in Vivado out of context: no board,
no pins, a 25 ns clock, for any part (default `xc7z010clg400-1`, the Zynq-7010 of
the Zybo). It reports the resources and the worst-case Fmax. A project that puts
HITS on the Zybo, with its clock, reset and outputs, is still to be written.

Run it from an empty folder:

```sh
vivado -mode batch -source <hits>/projects/zybo/hits_vivado.tcl -tclargs [part] [D:<MACRO>[:value] ...] [G:<PARAMETER>:<value> ...]
```

The header of the script explains the arguments.

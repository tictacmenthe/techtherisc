# TechTheRISC
Simple RISCV-32-I/E implementation in VHDL

## Dependencies
- GHDL v0.37+ (any framework:llvm/gcc/mcode). Could work with others (vsim...), not tested.
- Python3 (works on 3.9.0, doesn't really require much)
- vunit-hdl v4.4.0+ (from Python pip)
- GTKWave v3.3.100+ (for GUI wave visualization)

## Running
HDL Compilation is automatic with VUnit, it automatically detects what entities are needed and compiles them.
All that is required is that the libraries are created in the root ```run.py``` script, and the corresponding source files are added to them.

To run a testbench named ```test_lib.<the_tb_entity>``` located in a file ```./test_lib/the_tb_entity.vhd```, you can:
- Run the script ```run.py``` and give it any wildcard based argument that matches the .vhd file of the TB.
- Run the script ```run.py``` and give it any wildcard based argument that matches the name of the entity (```<the_library>.<the_tb_entity>.<the_test_case>```).

If nothing matches, VUnit automatically runs every testbench found.
A testbench is a module that includes ```_tb``` or ```tb_``` in its name and the generic parameter ```runner_cfg```.

Some options:
- If using the first method, giving -g or --gui checks if there are any .gtkw savefiles for GTKWave (easily created using its GUI)
  If there are no savefiles, just opens GTKWave without any save data
- Every other VUnit CLI arguments are available (-v for verbose mode, etc).

## Modifying

- Sources files and libraries are specified in the sources.conf file at the root of the project. The syntax is inside and fairly simple for now.
- That's about it.

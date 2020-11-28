#!python
import subprocess
import glob
import sys
import os
from vunit import VUnit

copy_argv = sys.argv[1:]

final_argv = []

waves = []

gui_request = any(x in copy_argv for x in ['-g', '--gui'])


# Construct the new argv from input argv by finding the files to use in test (with wildcards pattern matching)
for i, arg in enumerate(copy_argv):
  found = glob.glob('test_lib/*'+arg+'*.vhd')
  if found: # If the pattern matches a .vhd file in test_lib
     # TB pattern for VUnit, with wildcards to run all test cases for this TB
    final_argv.append('*'+arg+'*')
  else: # else, add it raw if not -g
    if arg not in ['-g', '--gui']:
      final_argv.append(arg)

  # Records which tests in the list can be opened with gtkwave (already have an .gtkw file)
  if gui_request:
    found = glob.glob('test_lib/*'+arg+'*.gtkw')
    if found:
      for f in found:
        waves.append(f)

# Log it, and add -g
if gui_request:
  if not waves:
    final_argv.append('-g')
    print("Running with GUI without any save file.")
  else:
    print("Running with GUI and there are save files.")
else:
  print("Running with no GUI.")


exit()
# force gtkwave files to be generated, even if not openned with GUI
final_argv+=['--gtkwave-fmt', 'ghw']

def show_waves(results):
  for wave in waves:
    print(f"Running 'gtkwave {wave}'.")
    res = subprocess.call(['gtkwave', wave], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    print("GTKWave subprocess returned", res)

vu = VUnit.from_argv(argv=final_argv)

vu.enable_location_preprocessing()

src_lib = vu.add_library("src_lib")
tool_lib = vu.add_library("tool_lib")
test_lib = vu.add_library("test_lib")

src_lib.add_source_files(src_lib.name+"/utility_pkg.vhd")
src_lib.add_source_files(src_lib.name+"/ttr_pkg.vhd")
src_lib.add_source_files(src_lib.name+"/registers.vhd")
src_lib.add_source_files(src_lib.name+"/instr_decoder.vhd")
test_lib.add_source_files(test_lib.name+"/reg_tb.vhd")
test_lib.add_source_files(test_lib.name+"/instr_tb.vhd")

vu.main(show_waves)

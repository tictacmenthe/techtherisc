#!/usr/bin/python
import subprocess
import glob
import sys
import os
from vunit import VUnit

class bcolors:
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

SOURCES_FILE = "./sources.conf"


# Construct the new argv from input argv by finding the files to use in test (with wildcards pattern matching)
print("\n==== "+ bcolors.BOLD +"Setting up arguments for Vunit"+ bcolors.ENDC +" ==========")
copy_argv = sys.argv[1:] # copy of argv without the current filename
final_argv = [] # The argv list that will be used with VUnit
waves = []  # List of files for which to show a wave with specific a gtkwave savefile
gui_request = any(x in copy_argv for x in ['-g', '--gui']) # if a graph was asked or not

# filter arguments a bit, format source files/tb.
for arg in copy_argv:
  found = glob.glob('test_lib/*'+arg+'*.vhd')
  if found: # If the pattern matches a .vhd file in test_lib
     # TB pattern for VUnit, with wildcards to run all test cases for this TB
    final_argv.append('*'+arg+'*')
  else: # else, add it raw if not a custom parameter
    if arg not in ['-g', '--gui', '--dt']:
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


# force gtkwave files to be generated, even if not openned with GUI
final_argv+=['--gtkwave-fmt', 'ghw']


# Callback called to show graphs if possible. Used because vu.main() doesn't return for some reason.
def show_waves(results):
  if waves:
    print("\n==== "+ bcolors.WARNING +"Running GTKWave when possible"+ bcolors.ENDC +" ===========")
  for wave in waves:
    print(f'\nRunning "gtkwave {wave}".')
    res = subprocess.call(['gtkwave', wave], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    print("GTKWave subprocess returned:", res)


# Init VUnit with the arguments.
vu = VUnit.from_argv(argv=final_argv)

# Enables some preprocessing (to print lines for logs, allow delta-cycle logs etc).
vu.enable_location_preprocessing()


# Read source files from sources configuration file
print("\n==== "+ bcolors.BOLD +"Setting up VUnit project structure "+ bcolors.ENDC +"======")
libraries_dict = {}
with open(SOURCES_FILE) as sources_file:
  for line in sources_file:
    line = line.split("#")[0].strip()
    if line:
      tokens = line.split()
      if len(tokens) > 1:
        libname, filename = tokens[0], os.path.join(tokens[0], tokens[1])
        if libname in libraries_dict.keys():
          if filename not in libraries_dict[libname]:
            libraries_dict[libname].append(filename)
        else:
          libraries_dict[libname] = [filename]

# Setup file structure for VUnit.
vu_libraries = []
for n, k in enumerate(libraries_dict.keys()):
  # Create VUnit vu_libraries
  vu_libraries.append(vu.add_library(k))
  print(f'\n== Library "{k}"\n== Files:')
  # Add source files to each library
  for f in libraries_dict[k]:
    print(f'==== "{f}"')
    vu_libraries[n].add_source_file(f)

# Display delta cycles too in logs. Requires preprocessing enabled AND GHDL.
if "--dt" in copy_argv:
  vu.set_sim_option("ghdl.sim_flags", ["--disp-time"])

# Run the VUnit framework. Doesn't return, ever.
#    show_waves is a callback called after the tests (for graphs, coverage, logs).
print("\n==== "+ bcolors.BOLD + bcolors.OKCYAN +"Running VUnit"+ bcolors.ENDC +" ===========================")
vu.main(show_waves)

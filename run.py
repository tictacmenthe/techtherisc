from vunit import VUnit

vu = VUnit.from_argv()

src_lib = vu.add_library("src_lib")
tool_lib = vu.add_library("tool_lib")
test_lib = vu.add_library("test_lib")

src_lib.add_source_files(src_lib.name+"/utility_pkg.vhd")
src_lib.add_source_files(src_lib.name+"/ttr_pkg.vhd")
src_lib.add_source_files(src_lib.name+"/registers.vhd")
src_lib.add_source_files(src_lib.name+"/instr_decoder.vhd")
test_lib.add_source_files(test_lib.name+"/reg_tb.vhd")
test_lib.add_source_files(test_lib.name+"/instr_tb.vhd")

vu.main()
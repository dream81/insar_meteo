from os.path import join as pjoin, isfile
from distutils.ccompiler import new_compiler
from sys import argv

c_file = [argv[1]]
libs = ["m", "gsl", "gslcblas"]
flags = ["-std=c99"]
macros = [("HAVE_INLINE", None), ("GSL_RANGE_CHECK_OFF", None)]
inc_dirs = ["/home/istvan/miniconda3/include"]
lib_dirs = ["/home/istvan/miniconda3/lib"]

#libs = ["m", "stdc++"]
#flags = ["-std=c++11"]
#macros = None

def main():
    c_basename = c_file[0].split(".")[0]
    
    ccomp = new_compiler()
    ccomp.compile(c_file, extra_postargs=flags)
    #ccomp.compile(["matrix.c"], extra_postargs=flags, macros=macros)
    ccomp.compile(["main_functions.c"], extra_postargs=flags,
                  include_dirs=inc_dirs, macros=macros)
    
    ccomp.link_executable([c_basename + ".o", "main_functions.o"],
                          pjoin("..", "bin", c_basename),
                          libraries=libs, library_dirs=lib_dirs,
                          extra_postargs=flags)
    
if __name__ == "__main__":
    main()

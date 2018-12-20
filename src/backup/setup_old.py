from os.path import join
from numpy.distutils.core import Extension, setup


def main():
    #flags = ["-std=c++03", "-O3", "-march=native", "-ffast-math", "-funroll-loops"]
    #flags = ["-std=c++03", "-O0", "-save-temps"]
    flags = ["-std=c++11", "-O3"]
    macros = [("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")]
    inc_dirs = ["include"]
    
    nparray  = join("aux", "nparray.cc")
    utils    = join("aux", "utils.cc")
    satorbit = join("aux", "satorbit.cc")
    sources  = ["inmet_auxmodule.cc", nparray, utils, satorbit]
    
    ext_modules = [
        Extension(name="inmet_aux", sources=sources,
                  define_macros=macros,
                  extra_compile_args=flags,
                  include_dirs=inc_dirs,
                  libraries=["m"])
    ]
    
    setup(ext_modules=ext_modules)


if __name__ == "__main__":
    main()
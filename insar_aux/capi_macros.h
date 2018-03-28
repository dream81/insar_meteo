#ifndef CAPI_MACROS_H
#define CAPI_MACROS_H

//----------------------------------------------------------------------
// WGS-84 ELLIPSOID PARAMETERS
//----------------------------------------------------------------------

// RADIUS OF EARTH
#define R_earth 6372000

#define WA  6378137.0
#define WB  6356752.3142

// (WA*WA-WB*WB)/WA/WA
#define E2  6.694380e-03


//----------------------------------------------------------------------
// DEGREES, RADIANS, PI
//----------------------------------------------------------------------

#ifndef M_PI
#define M_PI 3.14159265358979
#endif

#define DEG2RAD 1.745329e-02
#define RAD2DEG 5.729578e+01


#define distance(x, y, z) sqrt((y)*(y)+(x)*(x)+(z)*(z))

#define OR ||
#define AND &&

//----------------------------------------------------------------------
// FOR MACROS
// REQUIRES C99 standard!
//----------------------------------------------------------------------

#define FOR(ii, min, max) for(uint (ii) = (min); (ii) < (max); (ii)++)
#define FORS(ii, min, max, step) for(uint (ii) = (min); (ii) < (max); (ii) += (step))

//----------------------------------------------------------------------
// IO MACROS
//----------------------------------------------------------------------

#define error(text) PySys_WriteStderr(text"\n")
#define errora(text, ...) PySys_WriteStderr(text"\n", __VA_ARGS__)

#define println(format, ...) PySys_WriteStdout(format"\n", __VA_ARGS__)
#define print(format, ...) PySys_WriteStdout(format, __VA_ARGS__)

#define _log print("%s\t%d\n", __FILE__, __LINE__)

//----------------------------------------------------------------------
// FUNCTION DEFINITION MACROS
//----------------------------------------------------------------------

#define FUNCTION_NOARGS(fun_name, module_name_ext) \
static PyObject * fun_name (PyObject * self)

#define FUNCTION_VARARGS(fun_name) \
static PyObject * fun_name (PyObject * self, PyObject * args)

#define FUNCTION_KEYWORDS(fun_name) \
static PyObject * fun_name (PyObject * self, PyObject * args, PyObject * kwargs)

//----------------------------------------------------------------------

#define METHOD_NOARGS(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_NOARGS, fun_name ## __doc__}

#define METHOD_VARARGS(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_VARARGS, fun_name ## __doc__}

#define METHOD_KEYWORDS(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_VARARGS | METH_KEYWORDS, \
 fun_name ## __doc__}

#define DOC(fun_name, doc) PyDoc_VAR(fun_name ## __doc__) = PyDoc_STR(doc)

#define PARSE_KEYWORDS(keys, format, ...) \
({ \
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, format, keywords, \
                                     __VA_ARGS__))\
        return NULL; \
})

//----------------------------------------------------------------------
// NUMPY CONVENIENCE MACROS
//----------------------------------------------------------------------

#define NPY_AO PyArrayObject 
#define NPY_PTR(obj, i, j) PyArray_GETPTR2(obj, i, j)
#define NPY_DIM(obj, idx) PyArray_DIM(obj, idx)
#define NPY_DELEM(obj, i, j) *((double *) PyArray_GETPTR2(obj, i, j))
#define NPY_IELEM(obj, i, j) *((int *) PyArray_GETPTR2(obj, i, j))

//----------------------------------------------------------------------
// ERROR CODES
//----------------------------------------------------------------------

#define IO_ERR    -1
#define ALLOC_ERR -2
#define NUM_ERR   -3

#endif

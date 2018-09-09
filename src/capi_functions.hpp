#ifndef CAPI_FUNCTIONS_HPP
#define CAPI_FUNCTIONS_HPP

#include "Python.h"
#include "numpy/arrayobject.h"

// turn s into string "s"
#define QUOTE(s) # s

#define CONCAT(a,b) a ## b

#define pyexc(exc_type, format, ...)\
        PyErr_Format((exc_type), (format), __VA_ARGS__)\

#define pyexcs(exc_type, string)\
        PyErr_Format((exc_type), (string))\

/*************
 * IO macros *
 *************/

#define error(text, ...) PySys_WriteStderr(text, __VA_ARGS__)
#define errors(text) PySys_WriteStderr(text)
#define errorln(text, ...) PySys_WriteStderr(text"\n", __VA_ARGS__)

#define prints(string) PySys_WriteStdout(string)
#define print(string, ...) PySys_WriteStdout(string, __VA_ARGS__)
#define println(format, ...) PySys_WriteStdout(format"\n", __VA_ARGS__)

#define _log println("File: %s line: %d", __FILE__, __LINE__)

template<typename T> struct dtype { const int typenum; };

template<> struct dtype<npy_double> { static const int typenum = NPY_DOUBLE; };
template<> struct dtype<npy_bool> { static const int typenum = NPY_BOOL; };

template<typename T, unsigned int ndim>
struct array {
    unsigned int shape[ndim], strides[ndim];
    PyArrayObject *_array;
    PyObject *_obj;
    T * data;
    
    array()
    {
        data = NULL;
        _array = NULL;
        _obj = NULL;
    };
    
    ~array()
    {
        Py_XDECREF(_array);
    }
    
    array(T * _data, ...) {
        va_list vl;
        unsigned int shape_sum = 0;
        
        va_start(vl, _data);
        
        for(unsigned int ii = 0; ii < ndim; ++ii)
            shape[ii] = static_cast<unsigned int>(va_arg(vl, int));
        
        va_end(vl);
        
        for(unsigned int ii = 0; ii < ndim; ++ii) {
            shape_sum = 1;
            
            for(unsigned int jj = ii + 1; jj < ndim; ++jj)
                 shape_sum *= shape[jj];
            
            strides[ii] = shape_sum;
        }
        data = _data;
    }

    const PyArrayObject * get_array()
    {
        return _array;
    }

    const PyObject * get_obj()
    {
        return _obj;
    }
    
    const unsigned int get_shape(unsigned int ii)
    {
        return shape[ii];
    }

    const unsigned int rows()
    {
        return shape[0];
    }
    
    const unsigned int cols()
    {
        return shape[1];
    }
    
    T* get_data()
    {
        return data;
    }
    
    T& operator()(unsigned int ii)
    {
        return data[ii * strides[0]];
    }

    T& operator()(unsigned int ii, unsigned int jj)
    {
        return data[ii * strides[0] + jj * strides[1]];
    }
    
    T& operator()(unsigned int ii, unsigned int jj, unsigned int kk)
    {
        return data[ii * strides[0] + jj * strides[1] + kk * strides[2]];
    }

    T& operator()(unsigned int ii, unsigned int jj, unsigned int kk,
                  unsigned int ll)
    {
        return data[  ii * strides[0] + jj * strides[1] + kk * strides[2]
                    + ll * strides[3]];
    }
};

template<typename T, unsigned int ndim>
static int setup_array(array<T,ndim>& arr, PyArrayObject *_array)
{
    int _ndim = static_cast<unsigned int>(PyArray_NDIM(_array));
    
    if (ndim != _ndim) {
        pyexc(PyExc_TypeError, "numpy array expected to be %u "
                               "dimensional but we got %u dimensional "
                               "array!", ndim, _ndim);
        return 1;
        
    }
    
    npy_intp * _shape = PyArray_DIMS(_array);

    for(unsigned int ii = 0; ii < ndim; ++ii)
        arr.shape[ii] = static_cast<unsigned int>(_shape[ii]);

    int elemsize = int(PyArray_ITEMSIZE(_array));
    
    npy_intp * _strides = PyArray_STRIDES(_array);
    
    for(unsigned int ii = 0; ii < ndim; ++ii)
        arr.strides[ii] = static_cast<unsigned int>(double(_strides[ii])
                                                    / elemsize);
    
    arr.data = (T*) PyArray_DATA(_array);
    arr._array = _array;
    
    return 0;
}

template<typename T, unsigned int ndim>
static int import(array<T,ndim>& arr, PyObject *_obj = NULL)
{
    PyObject * tmp_obj = NULL;
    PyArrayObject * tmp_array = NULL;
    
    if (_obj == NULL)
        tmp_obj = arr._obj;
    else
        arr._obj = tmp_obj = _obj;
    
    if ((tmp_array =
         (PyArrayObject*) PyArray_FROM_OTF(tmp_obj, dtype<T>::typenum,
                                           NPY_ARRAY_IN_ARRAY)) == NULL) {
        pyexcs(PyExc_TypeError, "Failed to convert numpy array!");
        return 1;
    }
    
    return setup_array(arr, tmp_array);
}

template<typename T, unsigned int ndim>
static int empty(array<T,ndim>& arr, npy_intp *dims, int fortran = 0)
{
    PyArrayObject * tmp_array = NULL;
    
    if ((tmp_array = (PyArrayObject*) PyArray_EMPTY(ndim, dims,
                      dtype<T>::typenum, fortran)) == NULL) {
        pyexcs(PyExc_TypeError, "Failed to create empty numpy array!");
        return 1;
    }
    
    return setup_array(arr, tmp_array);
}

template<typename T>
struct arraynd {
    unsigned int *strides;
    npy_intp *shape;
    PyArrayObject *_array;
    T * data;
    
    arraynd()
    {
        strides = NULL;
        shape = NULL;
        data = NULL;
        _array = NULL;
    };
    
    ~arraynd()
    {
        if (strides != NULL) {
            PyMem_Del(strides);
            strides = NULL;
        }
    }

    const PyArrayObject * get_array()
    {
        return _array;
    }
    
    const unsigned int get_shape(unsigned int ii)
    {
        return static_cast<unsigned int>(shape[ii]);
    }

    const unsigned int rows()
    {
        return static_cast<unsigned int>(shape[0]);
    }
    
    const unsigned int cols()
    {
        return static_cast<unsigned int>(shape[1]);
    }
    
    T* get_data()
    {
        return data;
    }
    
    T& operator()(unsigned int ii)
    {
        return data[ii * strides[0]];
    }

    T& operator()(unsigned int ii, unsigned int jj)
    {
        return data[ii * strides[0] + jj * strides[1]];
    }
    
    T& operator()(unsigned int ii, unsigned int jj, unsigned int kk)
    {
        return data[ii * strides[0] + jj * strides[1] + kk * strides[2]];
    }

    T& operator()(unsigned int ii, unsigned int jj, unsigned int kk,
                  unsigned int ll)
    {
        return data[  ii * strides[0] + jj * strides[1] + kk * strides[2]
                    + ll * strides[3]];
    }
};

template<typename T>
static int import(arraynd<T>& arr, PyArrayObject * _array = NULL) {

    PyArrayObject * tmp_array = NULL;
    
    if (_array == NULL)
        tmp_array = arr._array;
    else
        arr._array = tmp_array = _array;
    
    unsigned int ndim = static_cast<unsigned int>(PyArray_NDIM(tmp_array));
    arr.shape = PyArray_DIMS(tmp_array);
    
    int elemsize = int(PyArray_ITEMSIZE(tmp_array));
    
    if ((arr.strides = PyMem_New(unsigned int, ndim)) == NULL) {
        pyexcs(PyExc_MemoryError, "Failed to allocate memory for array "
                                  "strides!");
        return 1;
    }
    
    npy_intp * _strides = PyArray_STRIDES(tmp_array);
    
    for(unsigned int ii = 0; ii < ndim; ++ii)
        arr.strides[ii] = static_cast<unsigned int>(double(_strides[ii])
                                                    / elemsize);
    
    arr.data = static_cast<T*>(PyArray_DATA(tmp_array));
    
    return 0;
}


/******************************
 * Function definition macros *
 ******************************/

#define array_type(ar_struct) &((ar_struct)._obj)

#define py_noargs PyObject *self
#define py_varargs PyObject *self, PyObject *args
#define py_keywords PyObject *self, PyObject *args, PyObject *kwargs

#define pymeth_noargs(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_NOARGS, fun_name ## __doc__}

#define pymeth_varargs(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_VARARGS, fun_name ## __doc__}

#define pymeth_keywords(fun_name) \
{#fun_name, (PyCFunction) fun_name, METH_VARARGS | METH_KEYWORDS, \
 fun_name ## __doc__}

#define pydoc(fun_name, doc) PyDoc_VAR(fun_name ## __doc__) = PyDoc_STR(doc)

#define keywords(...) static char * keywords[] = {__VA_ARGS__, NULL}

#define parse_varargs(format, ...) \
do {\
    if (!PyArg_ParseTuple(args, format, __VA_ARGS__))\
        return NULL;\
} while(0)

#define parse_keywords(format, ...) \
do {\
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, format, keywords,\
                                     __VA_ARGS__))\
        return NULL;\
} while(0)

/********************************
 * Module initialization macros *
 ********************************/

// Python 3
#if PY_VERSION_HEX >= 0x03000000

#define PyString_Check PyBytes_Check
#define PyString_GET_SIZE PyBytes_GET_SIZE
#define PyString_AS_STRING PyBytes_AS_STRING
#define PyString_FromString PyBytes_FromString
#define PyUString_FromStringAndSize PyUnicode_FromStringAndSize
#define PyString_ConcatAndDel PyBytes_ConcatAndDel
#define PyString_AsString PyBytes_AsString

#define PyInt_Check PyLong_Check
#define PyInt_FromLong PyLong_FromLong
#define PyInt_AS_LONG PyLong_AsLong
#define PyInt_AsLong PyLong_AsLong

#define PyNumber_Int PyNumber_Long

// Python 2
#else 

#define PyUString_FromStringAndSize PyString_FromStringAndSize

// Python 2/3
#endif 

/*
Copy this into your sourcefile. Replace version, module_name, module_doc
with anything you see fit.

Replace inmet_aux with your module name below in the PyMODINIT_FUNC
function definitions. 

Put your own functions in the function definition part
( static PyMethodDef module_methods[] = {... ).

COPY FROM HERE:

#define version "0.0.1"
#define module_name "inmet_aux"
static const char* module_doc = "inmet_aux";


static PyObject * module_error;
static PyObject * module;

static PyMethodDef module_methods[] = {
    pymeth_varargs(test),
    pymeth_varargs(azi_inc),
    pymeth_keywords(asc_dsc_select),
    {NULL, NULL, 0, NULL}
};

#if PY_VERSION_HEX >= 0x03000000
static struct PyModuleDef module_def = {
    PyModuleDef_HEAD_INIT,
    module_name,
    NULL,
    -1,
    module_methods,
    NULL,
    NULL,
    NULL,
    NULL
};
#endif

#if PY_VERSION_HEX >= 0x03000000
#define RETVAL m
PyMODINIT_FUNC CONCAT(PyInit_, inmet_aux)(void) {
#else
#define RETVAL
PyMODINIT_FUNC CONCAT(init, inmet_aux)(void) {
#endif
    PyObject *m, *d, *s;
#if PY_VERSION_HEX >= 0x03000000
    m = module = PyModule_Create(&module_def);
#else
    m = module = Py_InitModule(module_name, module_methods);
#endif
    import_array();
    
    if (PyErr_Occurred()) {
        PyErr_SetString(PyExc_ImportError, "can't initialize module"
                        module_name "(failed to import numpy)");
        return RETVAL;
    }
    d = PyModule_GetDict(m);
    s = PyString_FromString("$Revision: $");
    
    PyDict_SetItemString(d, "__version__", s);

#if PY_VERSION_HEX >= 0x03000000
    s = PyUnicode_FromString(
#else
    s = PyString_FromString(
#endif
    module_doc);
  
    PyDict_SetItemString(d, "__doc__", s);

    module_error = PyErr_NewException(module_name ".error", NULL, NULL);

    Py_DECREF(s);

    return RETVAL;
}
*/

#endif // end CAPI_FUNCTIONS_HPP

# Copyright (C) 2018  István Bozsó
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import os
import subprocess as sub
from shlex import split
import os.path as pth
from argparse import ArgumentParser

from inmet.gnuplot import Gnuplot


def parse_config_file(filepath, comment="#", sep=":"):

    with open(filepath, "r") as f:
        params = {get_key(line, sep): get_value(line, comment, sep)
                  for line in f
                  if sep in line and not line.startswith(comment)}

    return params


def get_par(parameter, search, sep=":"):

    if isinstance(search, list):
        searchfile = search
    elif pth.isfile(search):
        with open(search, "r") as f:
            searchfile = f.readlines()
    else:
        raise ValueError("search should be either a list or a string that "
                         "describes a path to the parameter file.")
    
    parameter_value = None
    
    for line in searchfile:
        if parameter in line:
            parameter_value = " ".join(line.split(sep)[1:]).strip()
            break

    return parameter_value



# *****************
# * DAISY Modules *
# *****************


def data_select(in_asc, in_dsc, ps_sep=100.0):
    
    cmd("daisy data_select", in_asc, in_dsc, ps_sep)


def dominant(in_asc="asc_data.xys", in_dsc="dsc_data.xys", ps_sep=100.0):
    
    cmd("daisy dominant", in_asc, in_dsc, ps_sep)


def poly_orbit(asc_orbit="asc_master.res", dsc_orbit="dsc_master.res", deg=4):
    
    cmd("daisy poly_orbit", asc_orbit, deg)
    cmd("daisy poly_orbit", dsc_orbit, deg)


def integrate(dominant="dominant.xyd", asc_fit_orbit="asc_master.porb",
              dsc_fit_orbit="dsc_master.porb"):
    cmd("daisy integrate", dominant, asc_fit_orbit, dsc_fit_orbit)

# *****************
# * INMET Modules *
# *****************


def azi_inc(fit_file, coords, mode, outfile, max_iter=1000):

    cmd("inmet azi_inc", fit_file, coords, mode, max_iter, outfile)


def fit_orbit(coords, fit_file, deg=3, centered=True):

    if centered:
        cmd("inmet fit_orbit", coords, deg, 1, fit_file)
    else:
        cmd("inmet fit_orbit", coords, deg, 0, fit_file)


def eval_orbit(fit_file, outfile, nstep=100, multiply=1):

    cmd("inmet eval_orbit", fit_file, nstep, multiply, outfile)


def orbit_fit(path, preproc, fit_file, centered=True, deg=3):
    
    extract_coords(path, preproc, "coords.txyz")
    
    if centered:
        cmd("inmet fit_orbit", "coords.txyz", deg, 1, fit_file, prt=True)
    else:
        cmd("inmet fit_orbit", "coords.txyz", deg, 0, fit_file, prt=True)

    #os.remove("coords.txyz")


def plot_orbit(path, preproc, fit_file, fit_plot, nstep=100, **kwargs):

    extract_coords(path, preproc, "coords.txyz")

    cmd("inmet eval_orbit", fit_file, nstep, 1, "fit.txyz")
    
    gpt = Gnuplot(out=fit_plot, term="pngcairo")
    gpt.multiplot(3, title="3D orbit coordinates and fitted polynoms",
                  portrait=True)
    
    titles = ("X", "Y", "Z")
    
    for ii in range(2, 5):
        # convert meters to kilometers
        incols = "1:(${} / 1e3)".format(ii)
        
        gpt.ylabel("{} [km]".format(titles[ii - 2]))
        gpt.xlabel("Time [s]")
        
        gpt.plot("coords.txyz", using=incols, pt_type="empty_circle",
                 title="Coordinates"),
        gpt.plot("fit.txyz", using=incols, line_type="black",
                 title="Fitted polynom")
        
        gpt.end_plot()
        
    del gpt
    
    os.remove("coords.txyz")
    os.remove("fit.txyz")


def extract_coords(path, preproc, coordsfile):

    if not pth.isfile(path):
        raise IOError("{} is not a file.".format(path))

    with open(path, "r") as f:
        lines = f.readlines()
    
    if preproc == "doris":
        data_num = [(ii, line) for ii, line in enumerate(lines)
                    if line.startswith("NUMBER_OF_DATAPOINTS:")]
    
        if len(data_num) != 1:
            raise ValueError("More than one or none of the lines contain the "
                             "number of datapoints.")
    
        idx = data_num[0][0]
        data_num = int(data_num[0][1].split(":")[1])
        
        with open("coords.txyz", "w") as f:
            f.write("".join(lines[idx + 1:idx + data_num + 1]))
    
    elif preproc == "gamma":
        data_num = [(ii, line) for ii, line in enumerate(lines)
                    if line.startswith("number_of_state_vectors:")]

        if len(data_num) != 1:
            raise ValueError("More than one or none of the lines contains the "
                             "number of datapoints.")
        
        idx = data_num[0][0]
        data_num = int(data_num[0][1].split(":")[1])
        
        t_first = float(lines[idx + 1].split(":")[1].split()[0])
        t_step  = float(lines[idx + 2].split(":")[1].split()[0])
        
        with open(coordsfile, "w") as f:
            for ii in range(data_num):
                coords = get_par("state_vector_position_{}".format(ii + 1), lines)
                f.write("{} {}\n".format(t_first + ii * t_step,
                                         coords.split("m")[0]))
    else:
        raise ValueError("preproc should be either \"doris\" or \"gamma\" "
                         "not {}".format(preproc))
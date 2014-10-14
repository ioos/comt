#!/bin/bash
# Usage: uvrhotate.sh roms_netcdf_file [newromsfile]
# Rotates the grid direction velocity in a ROMS output file to geographic east/north
# coordinates and reports this on a reduced rho-points centered grid (reduced because the
# first/last row/column of data is lost in the interpolation to the rho points).
# Reduced grid coordinates are named lon_red,lat_red
#
# Uses NCO tools http://http://nco.sourceforge.net
#
# John Wilkin and Rich Signell 
# October 4, 2014

# handy functions from http://nco.sourceforge.net/nco.html#Filters-for-ncks
function ncdmnsz { ncks -m -M ${2} | grep -E -i ": ${1}, size =" | cut -f 7 -d ' ' | uniq ; }
function ncattget { ncks -M -m ${3} | grep -E -i "^${2} attribute [0-9]+: ${1}" | cut -f 11- -d ' ' | sort ; }

if [ "$#" -eq "0" ]
  then
    echo "No argument supplied"
    echo "Usage: uvrhotate.sh romsfile.nc [new_romsfile.nc]"
    exit
fi

# set the file to process
roms=$1

if [ "$#" -eq "1" ]
  then
    # set the output file name
    romsout=new_$roms
    echo "Output file will be $romsout"
  else
    romsout=$2
fi

# name of time coordinate variable (it might be "time" in FMRC instead of "ocean_time")
# time=ocean_time
time=`ncattget time u $roms`

# get dimensions
xi_rho=`ncdmnsz eta_rho $roms` 
xi_rho=${xi_rho/,/}
eta_rho=`ncdmnsz eta_rho $roms` 
eta_rho=${eta_rho/,/}
let "xm3 = $xi_rho-3"
let "xm2 = $xi_rho-2"
let "em3 = $eta_rho-3"
let "em2 = $eta_rho-2"

# extract just u, v, angle and their coordinates
ncks --overwrite -v u,v $roms test.nc

# u velocity
# eta_rho and eta_u match, but xi_rho and xi_u do not
# extract two files shifted in xi, and clip the first and last eta
# don't get the coordinates because they will be specified later from the reduced subset
# of rho points lon/lat
ncks --overwrite -C -v u,$time -d xi_u,0,$xm3 -d eta_u,1,$em2 test.nc testuL.nc  # lower bound
ncks --overwrite -C -v u,$time -d xi_u,1,$xm2 -d eta_u,1,$em2 test.nc testuU.nc  # upper

# average these two to get u on the rho points 
ncra --overwrite testuL.nc testuU.nc u.nc 
ncrename --dimension xi_u,xi_red u.nc 
ncrename --dimension eta_u,eta_red u.nc 

# v velocity
# xi_rho and xi_v match, but eta_rho and eta_v do not
# extract two files shifted in eta, and clip the first and last xi
ncks --overwrite -C -v v,$time -d xi_v,1,$xm2 -d eta_v,0,$em3 test.nc testvL.nc # lower
ncks --overwrite -C -v v,$time -d xi_v,1,$xm2 -d eta_v,1,$em2 test.nc testvU.nc # upper

# average these two to get v on the rho points 
ncra --overwrite testvL.nc testvU.nc v.nc
ncrename --dimension xi_v,xi_red v.nc 
ncrename --dimension eta_v,eta_red v.nc 

# get angle for this subset of rho points
ncks --overwrite -v angle,lon_rho,lat_rho -d xi_rho,1,$xm2 -d eta_rho,1,$em2 $roms uvangle.nc
ncrename --dimension xi_rho,xi_red uvangle.nc 
ncrename --dimension eta_rho,eta_red uvangle.nc 

# combine all into one file
ncks -A u.nc v.nc 
ncks -A v.nc uvangle.nc

# Now the file uvangle.nc has the u and v components averaged to the same rho points, and 
# the angle centered at those same rho points.
#
# Next apply rotation with ncap2 ... 
#
# I believe the appropriate equation is
# ueast=Real((Uroms+i*Vroms)*exp(i*angle))   ue  =u*cos(angle)-v*sin(angle)       
# vnorth=Imag((Uroms+i*Vroms)*exp(i*angle))  vn = u*sin(angle)+v*cos(angle)
ncap2 -O -s 'ue=u*cos(angle)-v*sin(angle)' -s 'vn=u*sin(angle)+v*cos(angle)' uvangle.nc final.nc

# make the coordinate names and attributes consistent 
ncrename -v lon_rho,lon_red final.nc
ncrename -v lat_rho,lat_red final.nc
ncatted -a coordinates,ue,m,c,"lon_red lat_red s_rho $time" final.nc
ncatted -a coordinates,vn,m,c,"lon_red lat_red s_rho $time" final.nc

# add standard name to new variables
ncatted -a standard_name,ue,a,c,"eastward_sea_water_velocity" final.nc
ncatted -a standard_name,vn,a,c,"northward_sea_water_velocity" final.nc

# append new data to copy of input file
cp $roms $romsout
ncks -A final.nc $romsout

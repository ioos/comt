#!/bin/bash
# Usage: uvrhotate.sh roms_netcdf_file [newromsfile]
# Rotates the grid direction velocity in a ROMS output file to geographic east/north
# coordinates and reports this on a reduced rho-points centered grid (reduced because the
# first/last row/column of data is lost in the interpolation to the rho points).
#
# Uses NCO tools http://http://nco.sourceforge.net
#
# John Wilkin, Rich Signell, and Kyle Wilcox
# October 14, 2014

# handy functions from http://nco.sourceforge.net/nco.html#Filters-for-ncks
function ncdmnsz { ncks -m -M ${2} | grep -E -i ": ${1}, size =" | cut -f 7 -d ' ' | uniq ; }
function ncattget { ncks -M -m ${3} | grep -E -i "^${2} attribute [0-9]+: ${1}" | cut -f 11- -d ' ' | sort ; }

if [ "$#" -eq "0" ]
  then
    echo "No argument supplied"
    echo "Usage: uvrhotate.sh romsfile.nc [new_romsfile.nc]"
    exit
fi


RAND=$RANDOM
#echo "Run number: $RAND"

# set the file to process
echo "Setting temporary file locations..."
INPUT=$1
TMPNC=/tmp/$RAND.nc
TMPULB=/tmp/tmpulb_$RAND.nc
TMPUUB=/tmp/tmpuub_$RAND.nc
TMPU=/tmp/tmpu_$RAND.nc
TMPVLB=/tmp/tmpvlb_$RAND.nc
TMPVUB=/tmp/tmpvub_$RAND.nc
TMPV=/tmp/tmpv_$RAND.nc
TMPUV_ANGLE=/tmp/tmpuvangle_$RAND.nc
NEWDATA=/tmp/tmpnewdata_$RAND.nc
REGRIDDED=/tmp/tmpregridded_$RAND.nc
NCOSCRIPT=/tmp/tmpncoscript_$RAND.nco

if [ "$#" -eq "1" ]; then
  echo "Please supply an output file as the second argument"
  exit 1
fi
OUTPUT=$2
echo "Output file will be $OUTPUT"

# name of time coordinate variable (it might be "time" in FMRC instead of "ocean_time")
# time=ocean_time
echo "Getting time..."
time=`ncattget time u $INPUT`

# get dimensions
echo "Getting dimensions..."
xi_rho=`ncdmnsz xi_rho $INPUT`
xi_rho=${xi_rho/,/}
eta_rho=`ncdmnsz eta_rho $INPUT`
eta_rho=${eta_rho/,/}
let "xm3 = $xi_rho-3"
let "xm2 = $xi_rho-2"
let "em3 = $eta_rho-3"
let "em2 = $eta_rho-2"

# extract just u, v, angle and their coordinates
echo "Extracting U and V from original file..."
ncks --overwrite -v u,v $INPUT $TMPNC


# u velocity
# eta_rho and eta_u match, but xi_rho and xi_u do not
# extract two files shifted in xi, and clip the first and last eta
# don't get the coordinates because they will be specified later from the reduced subset
# of rho points lon/lat
echo "Extracting subsets of U..."
ncks --overwrite -q -C -v u,$time -d xi_u,0,$xm3 -d eta_u,1,$em2 $TMPNC $TMPULB  # u lower
ncks --overwrite -q -C -v u,$time -d xi_u,1,$xm2 -d eta_u,1,$em2 $TMPNC $TMPUUB  # u upper

# average these two to get u on the rho points
echo "Averaging U onto rho points..."
nces --overwrite $TMPULB $TMPUUB $TMPU
ncrename --dimension xi_u,xi_red $TMPU
ncrename --dimension eta_u,eta_red $TMPU

# v velocity
# xi_rho and xi_v match, but eta_rho and eta_v do not
# extract two files shifted in eta, and clip the first and last xi
echo "Extracting subsets of V..."
ncks --overwrite -q -C -v v,$time -d xi_v,1,$xm2 -d eta_v,0,$em3 $TMPNC $TMPVLB # v lower
ncks --overwrite -q -C -v v,$time -d xi_v,1,$xm2 -d eta_v,1,$em2 $TMPNC $TMPVUB # v upper

# average these two to get v on the rho points
echo "Averaging V onto rho points..."
nces --overwrite $TMPVLB $TMPVUB $TMPV
ncrename --dimension xi_v,xi_red $TMPV
ncrename --dimension eta_v,eta_red $TMPV

# get angle for this subset of rho points
echo "Extracting subsets of ANGLE..."
ncks --overwrite -q -v angle,lon_rho,lat_rho -d xi_rho,1,$xm2 -d eta_rho,1,$em2 $INPUT $TMPUV_ANGLE
ncrename --dimension xi_rho,xi_red $TMPUV_ANGLE
ncrename --dimension eta_rho,eta_red $TMPUV_ANGLE

# combine all into one file
echo "Combining U, V, and ANGLE files"
ncks -q -A $TMPU $TMPV
ncks -q -A $TMPV $TMPUV_ANGLE

# Now the file uvangle.nc has the u and v components averaged to the same rho points, and
# the angle centered at those same rho points.
#
# Next apply rotation with ncap2 ...
#
# I believe the appropriate equation is
# ueast=Real((Uroms+i*Vroms)*exp(i*angle))   ue  =u*cos(angle)-v*sin(angle)
# vnorth=Imag((Uroms+i*Vroms)*exp(i*angle))  vn = u*sin(angle)+v*cos(angle)
echo "Rotating vectors..."
ncap2 -O -s 'ue=u*cos(angle)-v*sin(angle)' -s 'vn=u*sin(angle)+v*cos(angle)' $TMPUV_ANGLE $NEWDATA

cat <<EOF > $NCOSCRIPT
defdim("eta_rho",\$eta_red.size+2);
defdim("xi_rho",\$xi_red.size+2);
u_rho[\$$time,\$s_rho,\$eta_rho,\$xi_rho]=ue@_FillValue;
u_rho(:,:,1:\$eta_rho.size-2,1:\$xi_rho.size-2)=ue;
v_rho[\$$time,\$s_rho,\$eta_rho,\$xi_rho]=vn@_FillValue;
v_rho(:,:,1:\$eta_rho.size-2,1:\$xi_rho.size-2)=vn;
EOF
ncap2 -v -S $NCOSCRIPT $NEWDATA $REGRIDDED

echo "Appending rotated U and V to original file..."
# append new data to copy of input file
cp $INPUT $OUTPUT
ncks -q -A -v u_rho,v_rho $REGRIDDED $OUTPUT

# make the coordinate names and attributes consistent
echo "Setting metadata attributes..."
ncatted -a coordinates,u_rho,o,c,"$time s_rho lon_rho lat_rho" \
        -a '_FillValue',u_rho,o,d,1.e+37 \
        -a units,u_rho,o,c,'meter second-1' \
        -a long_name,u_rho,o,c,'u-momentum component' \
        -a coordinates,v_rho,o,c,"$time s_rho lon_rho lat_rho" \
        -a '_FillValue',v_rho,o,d,1.e+37 \
        -a units,v_rho,o,c,'meter second-1' \
        -a long_name,v_rho,o,c,'v-momentum component' \
        $OUTPUT

# add standard name to new variables
ncatted -a standard_name,u_rho,o,c,"eastward_sea_water_velocity" \
        -a standard_name,v_rho,o,c,"northward_sea_water_velocity" \
        $OUTPUT

echo "Removing temporary files..."
rm -f $TMPNC $TMPULB $TMPUUB $TMPU $TMPVLB $TMPVUB $TMPV $TMPUV_ANGLE $NEWDATA $REGRIDDED $NCOSCRIPT

echo "Done!"

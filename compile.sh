#!/bin/bash

ODIN=/home/rolly/proj/Odin/odin

if ! test -f "$ODIN"; then
    echo "Please Edit compile.sh to point to the proper location for $ODIN"
    exit 1
fi

# Arguments
# if [ $# -ne 2 ]; then
#     echo "Usage: compile.sh <collection_dir> <bin_dir>"
#     exit 1
# fi
COLDIR=dep # Collection Directory
BINDIR=bin # Binary Directory
EXE=cass

# Bin
if ! test -d $BINDIR; then
    mkdir BINDIR
fi

echo "########################################"
echo "################# Cass #################"
echo "########################################"

# echo $(pwd)
# Executable
# export LD_LIBRARY_PATH="/home/rolly/proj/Odin/vendor/stb/lib"
# export LD_LIBRARY_PATH="/usr/local/lib"
# export LD_LIBRARY_PATH="/home/rolly/proj/ammo/deps/odin-vma/external"
# echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
# export PATH="/home/rolly/proj/Odin/vendor/stb/lib:$PATH"
# export PATH="/home/rolly/proj/Odin/vendor/stb/lib:$PATH"
# echo $PATH;/home/rolly/proj/odin_vulkan_cube/src/odin-vma/external/VulkanMemoryAllocator.lib
# /home/rolly/proj/Odin/vendor/stb/lib/stb_image.a
# $ODIN run ./src/kgs -debug -out:$EXE

$ODIN build ./src -extra-linker-flags:"-lstdc++ -lvulkan" -collection:violin=$COLDIR/violin \
    -debug -out:$BINDIR/$EXE

retval=$?
if [ $retval -ne 0 ]; then
    echo "########################################"
    echo "####### Compilation Failed : $retval ########"
    echo "########################################"
else
    echo "######## Compilation Succeeded #########"
    #  -- Running...
    cd $BINDIR
    ./$EXE
    cd -
#     # valgrind -s 
fi

exit $retval
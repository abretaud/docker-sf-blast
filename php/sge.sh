SGE_ROOT=/usr/local/sge; export SGE_ROOT

ARCH=`$SGE_ROOT/util/arch`
DEFAULTMANPATH=`$SGE_ROOT/util/arch -m`
MANTYPE=`$SGE_ROOT/util/arch -mt`

SGE_CELL=default; export SGE_CELL
unset SGE_QMASTER_PORT
unset SGE_EXECD_PORT

if [ "$MANPATH" = "" ]; then
   MANPATH=$DEFAULTMANPATH
fi
MANPATH=$SGE_ROOT/$MANTYPE:$MANPATH; export MANPATH

PATH=$SGE_ROOT/bin/$ARCH:$PATH; export PATH
shlib_path_name=`$SGE_ROOT/util/arch -lib`
old_value=`eval echo '$'$shlib_path_name`
if [ x$old_value = x ]; then
   eval $shlib_path_name=$SGE_ROOT/lib/$ARCH
else
   eval $shlib_path_name=$SGE_ROOT/lib/$ARCH:$old_value
fi
export $shlib_path_name
unset ARCH DEFAULTMANPATH MANTYPE shlib_path_name

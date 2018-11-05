if [ -z "$__Init_Default_Modules" ]; then
  export __Init_Default_Modules=1
  export EASYBUILD_MODULES_TOOL=Lmod 
  export EASYBUILD_PREFIX=/home/modules
  module use $EASYBUILD_PREFIX/modules/all
else
  module refresh
fi
%module crc

%{
#define SWIG_FILE_WITH_INIT
#include "srsran/phy/fec/crc.h"
%}

%include "numpy.i"
%init %{
    import_array();
%}

%apply (uint8_t* IN_ARRAY1, int DIM1) {(uint8_t* data, int len)}

#define SRSRAN_API
%include "stdint.i"
%include "srsran/phy/fec/crc.h"

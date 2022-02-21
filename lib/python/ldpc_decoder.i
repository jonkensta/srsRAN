%module ldpc_decoder

%{
#define SWIG_FILE_WITH_INIT
#include "srsran/phy/fec/ldpc/ldpc_decoder.h"
%}

#define SRSRAN_API
%include "stdint.i"
%include "srsran/phy/fec/ldpc/ldpc_decoder.h"

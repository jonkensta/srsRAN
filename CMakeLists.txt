#
# Copyright 2013-2021 Software Radio Systems Limited
#
# This file is part of srsRAN
#
# srsRAN is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# srsRAN is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# A copy of the GNU Affero General Public License can be found in
# the LICENSE file in the top-level directory of this distribution
# and at http://www.gnu.org/licenses/.
#

########################################################################
# Prevent in-tree builds
########################################################################
if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(FATAL_ERROR "Prevented in-tree build. This is bad practice.")
endif(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})

########################################################################
# Project setup
########################################################################
cmake_minimum_required(VERSION 2.6)
project( SRSRAN )
message( STATUS "CMAKE_SYSTEM: " ${CMAKE_SYSTEM} )
message( STATUS "CMAKE_SYSTEM_PROCESSOR: " ${CMAKE_SYSTEM_PROCESSOR} )
message( STATUS "CMAKE_CXX_COMPILER: " ${CMAKE_CXX_COMPILER} )

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/modules")
include(SRSRANVersion) #sets version information
include(SRSRANPackage) #setup cpack

if(NOT CMAKE_BUILD_TYPE)
   set(CMAKE_BUILD_TYPE Release)
   message(STATUS "Build type not specified: defaulting to Release.")
endif(NOT CMAKE_BUILD_TYPE)
set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} CACHE STRING "")

# Generate CMake to include build information
configure_file(
  ${PROJECT_SOURCE_DIR}/cmake/modules/SRSRANbuildinfo.cmake.in
  ${CMAKE_BINARY_DIR}/SRSRANbuildinfo.cmake
)

########################################################################
# Options
########################################################################
option(ENABLE_SRSLOG_TRACING "Enable event tracing using srslog"        OFF)
option(ASSERTS_ENABLED       "Enable srsRAN asserts"                    ON)
option(STOP_ON_WARNING       "Interrupt application on warning"         OFF)

if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")
  set(GCC_ARCH armv8-a CACHE STRING "GCC compile for specific architecture.")
  message(STATUS "Detected aarch64 processor")
else(${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")
  set(GCC_ARCH native CACHE STRING "GCC compile for specific architecture.")
endif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")

if (ENABLE_SRSLOG_TRACING)
  add_definitions(-DENABLE_SRSLOG_EVENT_TRACE)
endif (ENABLE_SRSLOG_TRACING)

if (ASSERTS_ENABLED)
  add_definitions(-DASSERTS_ENABLED)
endif()

if (STOP_ON_WARNING)
  add_definitions(-DSTOP_ON_WARNING)
endif()

########################################################################
# Find dependencies
########################################################################
find_package(FFTW3F REQUIRED)
if(FFTW3F_FOUND)
  include_directories(${FFTW3F_INCLUDE_DIRS})
  link_directories(${FFTW3F_LIBRARY_DIRS})
  if(BUILD_STATIC)
    set(FFT_LIBRARIES "${FFTW3F_STATIC_LIBRARIES}")
  else(BUILD_STATIC)
    set(FFT_LIBRARIES "${FFTW3F_LIBRARIES}")
  endif(BUILD_STATIC)
  message(STATUS "FFT_LIBRARIES: " ${FFT_LIBRARIES})
endif(FFTW3F_FOUND)

########################################################################
# Install Dirs
########################################################################
if (NOT CMAKE_INSTALL_LIBDIR)
    include(GNUInstallDirs)
endif (NOT CMAKE_INSTALL_LIBDIR)

# Fall back to just "lib" if the item provided by GNUInstallDirs doesn't exist
if (NOT EXISTS "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
    message(STATUS "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR} does not exist. Defaulting install location to ${CMAKE_INSTALL_PREFIX}/lib.")
    set(CMAKE_INSTALL_LIBDIR lib)
endif()

set(RUNTIME_DIR bin)
set(LIBRARY_DIR ${CMAKE_INSTALL_LIBDIR})
set(INCLUDE_DIR include)
set(DOC_DIR "share/doc/${CPACK_PACKAGE_NAME}")
set(DATA_DIR share/${CPACK_PACKAGE_NAME})

# Auto-generate config install helper and mark for installation
configure_file(
        ${PROJECT_SOURCE_DIR}/cmake/modules/SRSRAN_install_configs.sh.in
        ${CMAKE_BINARY_DIR}/srsran_install_configs.sh
)
install(PROGRAMS ${CMAKE_BINARY_DIR}/srsran_install_configs.sh DESTINATION ${RUNTIME_DIR})

# Disables the project to build when calling "make install"
set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE)

########################################################################
# Compiler specific setup
########################################################################
macro(ADD_C_COMPILER_FLAG_IF_AVAILABLE flag have)
    include(CheckCCompilerFlag)
    check_c_compiler_flag(${flag} ${have})
    if(${have})
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${flag}")
    endif(${have})
endmacro(ADD_C_COMPILER_FLAG_IF_AVAILABLE)

ADD_C_COMPILER_FLAG_IF_AVAILABLE("-Werror=incompatible-pointer-types" HAVE_ERROR_INCOMPATIBLE)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wno-comment -Wno-write-strings -Wno-unused-result -Wformat -Wmissing-field-initializers -Wtype-limits -std=c99 -fno-strict-aliasing -D_GNU_SOURCE")

find_package(SSE)
if (HAVE_AVX2)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpmath=sse -mavx2 -DLV_HAVE_AVX2 -DLV_HAVE_AVX -DLV_HAVE_SSE")
else (HAVE_AVX2)
  if(HAVE_AVX)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpmath=sse -mavx -DLV_HAVE_AVX -DLV_HAVE_SSE")
  elseif(HAVE_SSE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpmath=sse -msse4.1 -DLV_HAVE_SSE")
  endif(HAVE_AVX)
endif (HAVE_AVX2)

if (HAVE_FMA)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfma -DLV_HAVE_FMA")
endif (HAVE_FMA)

if (HAVE_AVX512)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mavx512f -mavx512cd -mavx512bw -mavx512dq -DLV_HAVE_AVX512")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx512f -mavx512cd -mavx512bw -mavx512dq -DLV_HAVE_AVX512")
endif(HAVE_AVX512)

if(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  if(HAVE_SSE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Ofast -funroll-loops")
  endif(HAVE_SSE)
endif(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")

set(CMAKE_REQUIRED_FLAGS ${CMAKE_C_FLAGS})

# Do not hide symbols in debug mode so backtraces can display function info.
if(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")
  if(NOT WIN32)
    ADD_C_COMPILER_FLAG_IF_AVAILABLE(-fvisibility=hidden HAVE_VISIBILITY_HIDDEN_C)
  endif(NOT WIN32)
endif(NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug")

# Add colored output when using the Ninja generator
if("Ninja" STREQUAL ${CMAKE_GENERATOR})
  ADD_C_COMPILER_FLAG_IF_AVAILABLE("-fdiagnostics-color=always" HAVE_DIAGNOSTIC_COLOR_C)
endif()

message(STATUS "CMAKE_C_FLAGS is ${CMAKE_C_FLAGS}")

########################################################################
# Create uninstall targets
########################################################################
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

########################################################################
# Add -fPIC property to all targets
########################################################################
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

########################################################################
# Print summary
########################################################################
message(STATUS "Using install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "Building for version: ${VERSION}")

########################################################################
# Add general includes and dependencies
########################################################################
include_directories(${PROJECT_BINARY_DIR}/lib/include)
include_directories(${PROJECT_SOURCE_DIR}/lib/include)

########################################################################
# Add the subdirectories
########################################################################
add_subdirectory(lib)

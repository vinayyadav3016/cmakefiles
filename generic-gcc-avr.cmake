##########################################################################
# "THE ANY BEVERAGE-WARE LICENSE" (Revision 42 - based on beer-ware
# license):
# <dev@layer128.net> wrote this file. As long as you retain this notice
# you can do whatever you want with this stuff. If we meet some day, and
# you think this stuff is worth it, you can buy me a be(ve)er(age) in
# return. (I don't like beer much.)
#
# Matthias Kleemann
##########################################################################

##########################################################################
# The toolchain requires some variables set.
#
# AVR_MCU (default: atmega8)
#     the type of AVR the application is built for
# AVR_L_FUSE (NO DEFAULT)
#     the LOW fuse value for the MCU used
# AVR_H_FUSE (NO DEFAULT)
#     the HIGH fuse value for the MCU used
# AVR_UPLOADTOOL (default: avrdude)
#     the application used to upload to the MCU
#     NOTE: The toolchain is currently quite specific about
#           the commands used, so it needs tweaking.
# AVR_UPLOADTOOL_PORT (default: usb)
#     the port used for the upload tool, e.g. usb
# AVR_PROGRAMMER (default: avrispmkII)
#     the programmer hardware used, e.g. avrispmkII
##########################################################################

#### my costum defination #########################################
#set the default path for built executables to the "bin" directory
#set the default path for built libraries to the "lib" directory
set(LIBRARY_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/lib/)
#set the default path for built libraries to the "map" directory
set(MAP_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin/)
#set the default path for built libraries to the "hex" directory
set(HEX_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin/)
#set the default path for built libraries to the "elf" directory
set(ELF_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin/)
#set the default path for built libraries to the "elf" directory
set(EEPROM_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin/)
include_directories(${PROJECT_SOURCE_DIR}/include ${CMAKE_CURRENT_BINARY_DIR})

###################################################################

##########################################################################
# options
##########################################################################
option(WITH_MCU "Add the mCU type to the target file name." ON)

SET(CMAKE_SYSTEM_PROCESSOR avr)
##########################################################################
# executables in use
##########################################################################
find_program(AVR_CC avr-gcc)
find_program(AVR_CXX avr-g++)
find_program(AVR_OBJCOPY avr-objcopy)
find_program(AVR_SIZE_TOOL avr-size)
find_program(AVR_OBJDUMP avr-objdump)

##########################################################################
# toolchain starts with defining mandatory variables
##########################################################################
#set(CMAKE_SYSTEM_NAME generic)
set(CMAKE_SYSTEM_PROCESSOR avr)
set(CMAKE_C_COMPILER ${AVR_CC})
set(CMAKE_CXX_COMPILER "/usr/bin/avr-g++")
set(CMAKE_SYSTEM_INCLUDE_PATH "${CMAKE_FIND_ROOT_PATH}/include")
set(CMAKE_SYSTEM_LIBRARY_PATH "${CMAKE_FIND_ROOT_PATH}/lib")

# default MCU (chip)
if(NOT AVR_MCU)
	set(
		AVR_MCU atmega8
		CACHE STRING "Set default MCU: atmega8 (see 'avr-gcc --target-help' for valid values)"
	)
endif(NOT AVR_MCU)

#default avr-size args
if(NOT AVR_SIZE_ARGS)
	if(APPLE)
		set(AVR_SIZE_ARGS -B)
	else(APPLE)
		set(AVR_SIZE_ARGS -C;--mcu=${AVR_MCU})
	endif(APPLE)
endif(NOT AVR_SIZE_ARGS)

##########################################################################
# target file name add-on
##########################################################################
if(WITH_MCU)
	set(MCU_TYPE_FOR_FILENAME "-${AVR_MCU}")
else(WITH_MCU)
	set(MCU_TYPE_FOR_FILENAME "")
endif(WITH_MCU)

##########################################################################
# add_avr_executable
# - IN_VAR: EXECUTABLE_NAME
#
# Creates targets and dependencies for AVR toolchain, building an
# executable. Calls add_executable with ELF file as target name, so
# any link dependencies need to be using that target, e.g. for
# target_link_libraries(<EXECUTABLE_NAME>-${AVR_MCU}.elf ...).
##########################################################################
function(add_avr_executable EXECUTABLE_NAME)
	if(NOT ARGN)
		  message(FATAL_ERROR "No source files given for ${EXECUTABLE_NAME}.")
	endif(NOT ARGN)

	# set file names
	set(elf_file ${ELF_PATH}${EXECUTABLE_NAME}${MCU_TYPE_FOR_FILENAME}.elf)
	set(hex_file ${HEX_OUTPUT_PATH}${EXECUTABLE_NAME}${MCU_TYPE_FOR_FILENAME}.hex)
	set(map_file  ${MAP_OUTPUT_PATH}${EXECUTABLE_NAME}${MCU_TYPE_FOR_FILENAME}.map)
	set(eeprom_image ${EEPROM_OUTPUT_PATH}${EXECUTABLE_NAME}${MCU_TYPE_FOR_FILENAME}-eeprom.hex)

	# elf file
	add_executable(${elf_file} EXCLUDE_FROM_ALL ${ARGN})

	set_target_properties(
		${elf_file}
		PROPERTIES
		COMPILE_FLAGS "-mmcu=${AVR_MCU} ${MY_COMPILE_FLAGS}"
		LINK_FLAGS "-mmcu=${AVR_MCU} ${MY_LINK_FLAGS} -Wl,-Map=${map_file},--cref"
	)

	add_custom_command(
		OUTPUT ${hex_file}
		COMMAND
			${AVR_OBJCOPY} -j .text -j .data -O ihex ${elf_file} ${hex_file}
		COMMAND
			${AVR_SIZE_TOOL} ${AVR_SIZE_ARGS} ${elf_file}
		DEPENDS ${elf_file}
	)

	# eeprom
	add_custom_command(
		OUTPUT ${eeprom_image}
		COMMAND
			${AVR_OBJCOPY} -j .eeprom --set-section-flags=.eeprom=alloc,load
				--change-section-lma .eeprom=0 --no-change-warnings
				-O ihex ${elf_file} ${eeprom_image}
		DEPENDS ${elf_file}
	)

	add_custom_target(
		${EXECUTABLE_NAME}
		ALL
		DEPENDS ${hex_file} ${eeprom_image}
	)

	set_target_properties(
		${EXECUTABLE_NAME}
		PROPERTIES
			OUTPUT_NAME "${elf_file}"
	)

	# clean
	get_directory_property(clean_files ADDITIONAL_MAKE_CLEAN_FILES)
	set_directory_properties(
		PROPERTIES
			ADDITIONAL_MAKE_CLEAN_FILES "${map_file}"
	)

endfunction(add_avr_executable)

##########################################################################
# add_avr_library
# - IN_VAR: LIBRARY_NAME
#
# Calls add_library with an optionally concatenated name
# <LIBRARY_NAME>${MCU_TYPE_FOR_FILENAME}.
# This needs to be used for linking against the library, e.g. calling
# target_link_libraries(...).
##########################################################################
function(add_avr_library LIBRARY_NAME)
	if(NOT ARGN)
		message(FATAL_ERROR "No source files given for ${LIBRARY_NAME}.")
	endif(NOT ARGN)

	set(lib_file ${LIBRARY_NAME}${MCU_TYPE_FOR_FILENAME})

	add_library(${lib_file} STATIC ${ARGN})

	set_target_properties(
		${lib_file}
		PROPERTIES
		COMPILE_FLAGS "-mmcu=${AVR_MCU} ${MY_COMPILE_FLAGS}"
			OUTPUT_NAME "${lib_file}"
	)

	if(NOT TARGET ${LIBRARY_NAME})
		add_custom_target(
			${LIBRARY_NAME}
			ALL
			DEPENDS ${lib_file}
		)

		set_target_properties(
			${LIBRARY_NAME}
			PROPERTIES
				OUTPUT_NAME "${lib_file}"
		)
	endif(NOT TARGET ${LIBRARY_NAME})

endfunction(add_avr_library)

##########################################################################
# avr_target_link_libraries
# - IN_VAR: EXECUTABLE_TARGET
# - ARGN  : targets and files to link to
#
# Calls target_link_libraries with AVR target names (concatenation,
# extensions and so on.
##########################################################################
function(avr_target_link_libraries EXECUTABLE_TARGET)
	if(NOT ARGN)
		message(FATAL_ERROR "Nothing to link to ${EXECUTABLE_TARGET}.")
	endif(NOT ARGN)

	get_target_property(TARGET_LIST ${EXECUTABLE_TARGET} OUTPUT_NAME)

	foreach(TGT ${ARGN})
		if(TARGET ${TGT})
			get_target_property(ARG_NAME ${TGT} OUTPUT_NAME)
			list(APPEND TARGET_LIST ${ARG_NAME})
		else(TARGET ${TGT})
			list(APPEND NON_TARGET_LIST ${TGT})
		endif(TARGET ${TGT})
	endforeach(TGT ${ARGN})

	target_link_libraries(${TARGET_LIST} ${NON_TARGET_LIST})
endfunction(avr_target_link_libraries EXECUTABLE_TARGET)

function(add_avr_executable_upload EXECUTABLE)
	if(NOT AVRDUDE)
		message(FATAL_ERROR "AVRDUDE not defined ${EXECUTABLE}.")
	endif(NOT AVRDUDE)
	if(NOT AVR_MCU)
		message(FATAL_ERROR "AVR_MCU not defined ${EXECUTABLE}.")
	endif(NOT AVR_MCU)
	if(NOT AVR_PROGRAMMER)
		message(FATAL_ERROR "AVR_PROGRAMMER not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER)
	if(NOT AVR_PROGRAMMER_PORT)
		message(FATAL_ERROR "AVR_PROGRAMMER_PORT not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_PORT)
	if(NOT AVR_PROGRAMMER_BAUDRATE)
		message(FATAL_ERROR "AVR_PROGRAMMER_BAUDRATE not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_BAUDRATE)
	if(NOT AVR_PROGRAMMER_OPTIONS)
		message(FATAL_ERROR "AVR_PROGRAMMER_OPTIONS not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_OPTIONS)

	# upload target
	message("upload_hex_${EXECUTABLE} ${AVRDUDE} -p${AVR_MCU} -c${AVR_PROGRAMMER} -P${AVR_PROGRAMMER_PORT} -b${AVR_PROGRAMMER_BAUDRATE} ${AVR_PROGRAMMER_OPTIONS} -Uflash:w:${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex:i")
	add_custom_target(upload_hex_${EXECUTABLE}
		COMMAND ${AVRDUDE} 
		-p${AVR_MCU} 
		-c${AVR_PROGRAMMER} 
		-P${AVR_PROGRAMMER_PORT} 
		-b${AVR_PROGRAMMER_BAUDRATE} 
		${AVR_PROGRAMMER_OPTIONS} 
		-Uflash:w:${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex:i 
		DEPENDS ${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex)
endfunction(add_avr_executable_upload)

function(add_avr_eeprom_upload EXECUTABLE)
	if(NOT AVRDUDE)
		message(FATAL_ERROR "AVRDUDE not defined ${EXECUTABLE}.")
	endif(NOT AVRDUDE)
	if(NOT AVR_MCU)
		message(FATAL_ERROR "AVR_MCU not defined ${EXECUTABLE}.")
	endif(NOT AVR_MCU)
	if(NOT AVR_PROGRAMMER)
		message(FATAL_ERROR "AVR_PROGRAMMER not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER)
	if(NOT AVR_PROGRAMMER_PORT)
		message(FATAL_ERROR "AVR_PROGRAMMER_PORT not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_PORT)
	if(NOT AVR_PROGRAMMER_BAUDRATE)
		message(FATAL_ERROR "AVR_PROGRAMMER_BAUDRATE not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_BAUDRATE)
	if(NOT AVR_PROGRAMMER_OPTIONS)
		message(FATAL_ERROR "AVR_PROGRAMMER_OPTIONS not defined ${EXECUTABLE}.")
	endif(NOT AVR_PROGRAMMER_OPTIONS)

	# upload target
	message("upload_eeprom_${EXECUTABLE} ${AVRDUDE} -p${AVR_MCU} -c${AVR_PROGRAMMER} -P${AVR_PROGRAMMER_PORT} -b${AVR_PROGRAMMER_BAUDRATE} ${AVR_PROGRAMMER_OPTIONS} -Uflash:w:${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex:i")
	add_custom_target(upload_eeprom_${EXECUTABLE}
		COMMAND ${AVRDUDE} 
		-p${AVR_MCU} 
		-c${AVR_PROGRAMMER} 
		-P${AVR_PROGRAMMER_PORT} 
		-b${AVR_PROGRAMMER_BAUDRATE} 
		${AVR_PROGRAMMER_OPTIONS} 
		-Uflash:w:${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex:i 
		DEPENDS ${HEX_OUTPUT_PATH}${EXECUTABLE}${MCU_TYPE_FOR_FILENAME}.hex)
endfunction(add_avr_eeprom_upload)

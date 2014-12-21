##########################################################################
# Some changes to make it compatible to my system
#
# Vinay Yadav
##########################################################################
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

INCLUDE(CMakeForceCompiler)
SET(CMAKE_SYSTEM_NAME Generic)
SET(CMAKE_SYSTEM_PROCESSOR avr)
SET(CMAKE_CROSSCOMPILING 1)

##########################################################################
# toolchain starts with defining mandatory variables
##########################################################################
CMAKE_FORCE_C_COMPILER(avr-gcc GNU)
CMAKE_FORCE_CXX_COMPILER(avr-g++ GNU)


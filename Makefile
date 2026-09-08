# Retro-Go SD — Atari 2600 (stella2014-go) standalone dynamic core.
#
#   make                  — build + pack → stella2014.bin (+ stella2014_defprops.bin)
#   make docker           — same inside the firmware builder image
#   make host             — Linux/macOS SDL binary
#
# Memory: hot M6502/TIA/RIOT/System .text in ITCM; TIA FBs + PageAccess in
# DTCM (fallback RAM_EMU). ITCM is not used for heap data. ROM properties
# DB is appended inside stella2014.bin (STDP trailer) — no sidecar file.
#
# Host: ./stella2014_host path/to/game.a26   (needs stella2014.bin in cwd)
# ROM dirname on SD stays a2600 (/roms/a2600/).

#######################################
# Project identity
#######################################
PROJECT_KIND ?= core

CORE_NAME  := stella2014
CORE_ENTRY := app_main_a2600

CORE_A2600 := src/stella2014-go

CORE_C_SOURCES := \
$(CORE_A2600)/stella/src/emucore/DefPropsBin.c

CORE_CXX_SOURCES := \
src/main_a2600.cxx \
$(CORE_A2600)/stella/src/common/StellaSound.cxx \
$(CORE_A2600)/stella/src/emucore/Booster.cxx \
$(CORE_A2600)/stella/src/emucore/StellaCart.cxx \
$(CORE_A2600)/stella/src/emucore/Cart0840.cxx \
$(CORE_A2600)/stella/src/emucore/Cart2K.cxx \
$(CORE_A2600)/stella/src/emucore/Cart3E.cxx \
$(CORE_A2600)/stella/src/emucore/Cart3F.cxx \
$(CORE_A2600)/stella/src/emucore/Cart4A50.cxx \
$(CORE_A2600)/stella/src/emucore/Cart4K.cxx \
$(CORE_A2600)/stella/src/emucore/Cart4KSC.cxx \
$(CORE_A2600)/stella/src/emucore/CartAR.cxx \
$(CORE_A2600)/stella/src/emucore/CartBF.cxx \
$(CORE_A2600)/stella/src/emucore/CartBFSC.cxx \
$(CORE_A2600)/stella/src/emucore/CartCM.cxx \
$(CORE_A2600)/stella/src/emucore/CartCTY.cxx \
$(CORE_A2600)/stella/src/emucore/CartCV.cxx \
$(CORE_A2600)/stella/src/emucore/CartDF.cxx \
$(CORE_A2600)/stella/src/emucore/CartDFSC.cxx \
$(CORE_A2600)/stella/src/emucore/CartDPC.cxx \
$(CORE_A2600)/stella/src/emucore/CartDPCPlus.cxx \
$(CORE_A2600)/stella/src/emucore/CartE0.cxx \
$(CORE_A2600)/stella/src/emucore/CartE7.cxx \
$(CORE_A2600)/stella/src/emucore/CartEF.cxx \
$(CORE_A2600)/stella/src/emucore/CartEFSC.cxx \
$(CORE_A2600)/stella/src/emucore/CartF0.cxx \
$(CORE_A2600)/stella/src/emucore/CartF4.cxx \
$(CORE_A2600)/stella/src/emucore/CartF4SC.cxx \
$(CORE_A2600)/stella/src/emucore/CartF6.cxx \
$(CORE_A2600)/stella/src/emucore/CartF6SC.cxx \
$(CORE_A2600)/stella/src/emucore/CartF8.cxx \
$(CORE_A2600)/stella/src/emucore/CartF8SC.cxx \
$(CORE_A2600)/stella/src/emucore/CartFA.cxx \
$(CORE_A2600)/stella/src/emucore/CartFA2.cxx \
$(CORE_A2600)/stella/src/emucore/CartFE.cxx \
$(CORE_A2600)/stella/src/emucore/CartMC.cxx \
$(CORE_A2600)/stella/src/emucore/CartSB.cxx \
$(CORE_A2600)/stella/src/emucore/CartUA.cxx \
$(CORE_A2600)/stella/src/emucore/CartX07.cxx \
$(CORE_A2600)/stella/src/emucore/StellaConsole.cxx \
$(CORE_A2600)/stella/src/emucore/StellaControl.cxx \
$(CORE_A2600)/stella/src/emucore/StellaJoystick.cxx \
$(CORE_A2600)/stella/src/emucore/StellaM6502.cxx \
$(CORE_A2600)/stella/src/emucore/StellaM6532.cxx \
$(CORE_A2600)/stella/src/emucore/NullDev.cxx \
$(CORE_A2600)/stella/src/emucore/Random.cxx \
$(CORE_A2600)/stella/src/emucore/Serializer.cxx \
$(CORE_A2600)/stella/src/emucore/StateManager.cxx \
$(CORE_A2600)/stella/src/emucore/StellaMD5.cxx \
$(CORE_A2600)/stella/src/emucore/StellaSettings.cxx \
$(CORE_A2600)/stella/src/emucore/StellaSwitches.cxx \
$(CORE_A2600)/stella/src/emucore/StellaSystem.cxx \
$(CORE_A2600)/stella/src/emucore/StellaTIA.cxx \
$(CORE_A2600)/stella/src/emucore/TIATables.cxx \
$(CORE_A2600)/stella/src/emucore/TIASnd.cxx \
$(CORE_A2600)/stella/src/emucore/Driving.cxx \
$(CORE_A2600)/stella/src/emucore/MindLink.cxx \
$(CORE_A2600)/stella/src/emucore/Paddles.cxx \
$(CORE_A2600)/stella/src/emucore/TrackBall.cxx \
$(CORE_A2600)/stella/src/emucore/StellaGenesis.cxx \
$(CORE_A2600)/stella/src/emucore/StellaKeyboard.cxx

CORE_C_INCLUDES := \
-I$(CORE_A2600)/stella \
-I$(CORE_A2600)/stella/src \
-I$(CORE_A2600)/stella/stubs \
-I$(CORE_A2600)/stella/src/emucore \
-I$(CORE_A2600)/stella/src/common \
-I$(CORE_A2600)/stella/src/gui \
-Isrc

CORE_LDSCRIPT := stella2014_core.ld
CORE_EXTRA_SEGMENTS := itcm:core_itcm

# Stella needs std::string (bspf.hxx).
CORE_LDLIBS := -lstdc++

GNW_CORE_SDK ?= sdk
BUILD_DIR ?= build/$(PROJECT_KIND)

#######################################
# Kind-specific compile defs + packing
#######################################
ifeq ($(PROJECT_KIND),core)
CORE_C_DEFS := \
-DPROJECT_KIND_CORE=1 \
-DCOVERFLOW=1 \
-DCHEAT_CODES=0 \
-DTARGET_GNW

PACKED_BIN  := $(CORE_NAME).bin
PAD_LOGO    := src/assets/pad.bmp
HEADER_LOGO := src/assets/header.bmp

else ifeq ($(PROJECT_KIND),homebrew)
$(error Atari 2600 is a dynamic core only — use PROJECT_KIND=core)
else
$(error PROJECT_KIND must be 'core' (got '$(PROJECT_KIND)'))
endif

include $(GNW_CORE_SDK)/Makefile

PACK_CORE := $(GNW_CORE_SDK)/tools/pack_core.py
APPEND_DEFPROPS := scripts/append_stella_defprops.py
DEFPROPS_BIN := $(BUILD_DIR)/stella2014_defprops.bin
DEFPROPS_SRC := $(CORE_A2600)/stella/src/emucore/DefProps.hxx
CONVERT_DEFPROPS := $(CORE_A2600)/convert_defprops.py

#######################################
# Packed header version
#######################################
CORE_VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)

#######################################
# Pack
#######################################
.PHONY: pack defprops

defprops: $(DEFPROPS_BIN)

$(DEFPROPS_BIN): $(DEFPROPS_SRC) $(CONVERT_DEFPROPS) | $(BUILD_DIR)
	$(V)$(ECHO) [ DEFPROPS ] $@
	$(V)python3 $(CONVERT_DEFPROPS) $(DEFPROPS_SRC) $@

pack: $(TARGET_BIN) $(PAD_LOGO) $(HEADER_LOGO) $(DEFPROPS_BIN)
	$(V)$(ECHO) [ PACK CORE ] $(PACKED_BIN) version=$(CORE_VERSION)
	$(V)python3 $(PACK_CORE) \
		--elf $(TARGET_ELF) --bin $(TARGET_BIN) \
		--system-name "Atari 2600" --dirname a2600 \
		--extensions "a26 bin" \
		--core-name "Stella 2014" \
		--version "$(CORE_VERSION)" \
		--pad-logo $(PAD_LOGO) \
		--header-logo $(HEADER_LOGO) \
		--out $(PACKED_BIN)
	$(V)python3 $(APPEND_DEFPROPS) --core $(PACKED_BIN) --defprops $(DEFPROPS_BIN)

all: pack

.PHONY: print-PROJECT_KIND print-PACKED_BIN print-SIDECARS print-RO_BIN print-CORE_NAME print-DOCKER_IMAGE \
	print-TARGET_ELF print-TARGET_MAP print-CORE_VERSION
print-PROJECT_KIND:
	@echo $(PROJECT_KIND)
print-PACKED_BIN:
	@echo $(PACKED_BIN)
# The shared stage_release.py asks every project for RO_BIN: the extra
# device file installed beside the packed binary. Empty here.
# Extra device files installed beside PACKED_BIN, space separated.
print-SIDECARS:
	@echo $(SIDECARS)
print-RO_BIN:
	@echo $(RO_BIN)
print-CORE_NAME:
	@echo $(CORE_NAME)
print-DOCKER_IMAGE:
	@echo $(DOCKER_IMAGE)
print-TARGET_ELF:
	@echo $(TARGET_ELF)
print-TARGET_MAP:
	@echo $(BUILD_DIR)/$(CORE_NAME)_core.map
print-CORE_VERSION:
	@echo $(CORE_VERSION)

clean::
	$(V)rm -f $(PACKED_BIN)

#######################################
# Docker
#######################################
.PHONY: docker docker_pull docker_shell

RELEASE_VERSION ?= v1.5
DOCKER_REPOSITORY ?= sylverb/retro-go-sd-builder
DOCKER_IMAGE ?= $(DOCKER_REPOSITORY):$(RELEASE_VERSION)

DOCKER_TTY_FLAG := $(shell if [ -t 0 ]; then echo -it; else echo; fi)
DOCKER_USER := $(shell id -u):$(shell id -g)
DOCKER_RUN := docker run --rm $(DOCKER_TTY_FLAG) \
	--user $(DOCKER_USER) \
	-v "$(CURDIR):/opt/workdir" \
	-w /opt/workdir \
	$(DOCKER_IMAGE)

docker:
	$(V)$(ECHO) "[ DOCKER ]" $(DOCKER_IMAGE) "PROJECT_KIND=$(PROJECT_KIND)"
	$(V)$(DOCKER_RUN) make --no-print-directory -j$$(nproc) PROJECT_KIND=$(PROJECT_KIND)

docker_pull:
	$(V)$(ECHO) "[ PULL ]" $(DOCKER_IMAGE)
	$(V)docker pull $(DOCKER_IMAGE)

docker_shell:
	$(DOCKER_RUN) bash

#######################################
# Host SDL (Linux / macOS)
#######################################
include host/Makefile.host

/*
 * Atari 2600 (stella2014) — RAM_EMU + ITCM hot code.
 *
 * Hot CPU / TIA / RIOT / System .text runs from ITCM (zero-wait). Data stays
 * out of ITCM: .rodata/.data/.bss remain in RAM_EMU; TIA framebuffers and
 * PageAccess tables use DTCM/RAM_EMU at runtime (see StellaTIA.cxx /
 * StellaSystem.cxx). main_a2600.o stays in RAM_EMU.
 *
 * Object paths must match BUILD_DIR (Makefile: build/core/…).
 */

INCLUDE gnw_ram_emu.ld
INCLUDE gnw_itcm_core.ld

MEMORY
{
  RAM_EMU (xrw) : ORIGIN = __RAM_EMU_START__, LENGTH = __RAM_EMU_LENGTH__
  ITCM    (xrw) : ORIGIN = __ITCM_CORE_START__, LENGTH = __ITCM_CORE_LENGTH__
}

SECTIONS
{
  .core_entry __RAM_EMU_START__ :
  {
    KEEP(*(.core_entry))
    KEEP(*(.gw_core_bridge_probe))
    . = ALIGN(4);
    EXCLUDE_FILE(
      build/core/StellaM6502.o
      build/core/StellaTIA.o
      build/core/TIASnd.o
      build/core/StellaM6532.o
      build/core/StellaSystem.o
    ) *(.text*)
    *(.rodata*)
    *(.glue_7)
    *(.glue_7t)

    . = ALIGN(4);
    __CORE_INIT_ARRAY_START__ = .;
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array*))
    __CORE_INIT_ARRAY_END__ = .;
  } >RAM_EMU

  .data :
  {
    *(.data*)
  } >RAM_EMU

  __CORE_CODE_END__ = .;

  .bss (NOLOAD) :
  {
    . = ALIGN(8);
    *(.bss*)
    *(COMMON)
    . = ALIGN(8);
  } >RAM_EMU

  __CORE_BSS_END__ = .;

  ASSERT(__CORE_BSS_END__ <= __RAM_EMU_END__,
         "Error: stella2014 core RAM_EMU segment (code+data+bss) overflows RAM_EMU")

  /* ITCM: hot Stella engines only — code, no data/bss. */
  .core_itcm __ITCM_CORE_START__ :
  {
    __CORE_ITCM_CODE_START__ = .;
    build/core/StellaM6502.o(.text*)
    build/core/StellaTIA.o(.text*)
    build/core/TIASnd.o(.text*)
    build/core/StellaM6532.o(.text*)
    build/core/StellaSystem.o(.text*)
    . = ALIGN(4);
    __CORE_ITCM_CODE_END__ = .;
  } >ITCM AT>RAM_EMU

  __CORE_ITCM_BSS_END__ = __CORE_ITCM_CODE_END__;

  ASSERT(__CORE_ITCM_BSS_END__ <= __ITCM_CORE_START__ + __ITCM_CORE_LENGTH__,
         "Error: stella2014 core ITCM segment overflows the 64K ITCM region")

  __exidx_start = .;
  __exidx_end = .;

  /DISCARD/ :
  {
    *(.fini_array*)
    *(.preinit_array*)
    *(.ARM.exidx*)
    *(.ARM.extab*)
    *(.comment)
    *(.ARM.attributes)
  }
}

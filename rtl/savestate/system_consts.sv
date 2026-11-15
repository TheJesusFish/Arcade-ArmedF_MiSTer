// Save-state constants.
package system_consts;
    parameter bit [31:0] SS_DDR_BASE = 32'h3E00_0000;   // CONF_STR "SS3E000000:400000"

    parameter int SSIDX_GLOBAL     = 0;   // 68K SSP + format tag
    parameter int SSIDX_MAIN_RAM   = 1;
    parameter int SSIDX_SPR_RAM    = 2;
    parameter int SSIDX_FG_RAM     = 3;
    parameter int SSIDX_BG_RAM     = 4;
    parameter int SSIDX_TILE_PAL   = 5;
    parameter int SSIDX_SPR_PAL    = 6;
    parameter int SSIDX_RAM2       = 7;
    parameter int SSIDX_RAM3       = 8;
    parameter int SSIDX_TXT_RAM    = 9;
    parameter int SSIDX_Z80A_RAM   = 10;
    parameter int SSIDX_Z80A_REGS  = 11;
    parameter int SSIDX_OPL        = 12;
    parameter int SSIDX_MISC       = 13;
    parameter int SSIDX_Z80B_RAM1  = 14;
    parameter int SSIDX_Z80B_RAM2  = 15;
    parameter int SSIDX_Z80B_REGS  = 16;
    parameter int SSIDX_COUNT      = 17;
endpackage

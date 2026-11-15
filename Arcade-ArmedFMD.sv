//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`default_nettype none

import system_consts::*;

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
`ifdef MISTER_FB
assign FB_FORCE_BLANK = 0;
`endif

assign AUDIO_MIX = 0;
assign LED_USER = 0 ;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

assign m68k_a[0] = 0;

// Save-state DDR interface.
ddr_if  ddr_ss();


wire [1:0]  aspect_ratio = status[9:8];
wire [2:0]  scan_lines = status[6:4];
wire [3:0]  hs_offset = status[27:24];
wire [3:0]  vs_offset = status[31:28];
wire [3:0]  hs_width  = status[59:56];
wire [3:0]  vs_width  = status[63:60];

wire gfx1_en = ~(status[37] | key_txt_enable);
wire gfx2_en = ~(status[38] | key_fg_enable );
wire gfx3_en = ~(status[39] | key_bg_enable);
wire gfx4_en = ~(status[40] | key_spr_enable);

// Vertical games: Armed F and Legion.
wire is_vertical = ( pcb == 2 || pcb == 5 || pcb == 6 || pcb == 7 );
wire rotate_off  = status[3];
wire show_rotated = is_vertical & ~rotate_off & ~direct_video;

assign VIDEO_ARX = (!aspect_ratio) ? (show_rotated ? 8'd3 : 8'd4) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (show_rotated ? 8'd4 : 8'd3) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
    "ArmedFMD;SS3E000000:400000;",
    "-;",
    "P1,Video Settings;",
    "P1-;",
    "P1O[9:8],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
    "H1P1O[3],Rotate Screen,Yes,No (Original);",
    "P1-;",
    "P1O[6:4],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%,CRT 100%;",
    "P1O[10],Force Scandoubler,Off,On;",
    "P1-;",
    "P1O[27:24],H-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1O[31:28],V-sync Pos Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1-;",
    "P1O[59:56],H-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1O[63:60],V-sync Width Adj,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P2,Pause Options;",
    "P2-;",
    "P2O[20],Pause when OSD is open,Off,On;",
    "P2O[21],Dim video after 10s,Off,On;",
    "P3,Debug Settings;",
    "P3-;",
    "P3O[11],Turbo (Legion Sets),Off,On;",
    "P3O[35],Service Menu,Off,On;",
    "P3O[36],Debug Menu,Off,On;",
    "P3-;",
    "P3O[37],Text Layer,On,Off;",
    "P3O[38],Foreground Layer,On,Off;",
    "P3O[39],Background Layer,On,Off;",
    "P3O[40],Sprite Layer,On,Off;",
    "-;",
    "DIP;",
    "-;",
    "O[65:64],Savestate Slot,1,2,3,4;",
    "O[66],Autoincrement Slot,Off,On;",
    "R[67],Save State (Alt-F1);",
    "R[68],Restore State (F1);",
    "-;",
    "H2O[69],Autosave Hiscores,On,Off;",
    "H2R[70],Save Hiscores;",
    "H2-;",
    "R[0],Reset;",
    "I,",
    "Load=DPAD Up|Save=Down|Slot=L+R,",
    "Active Slot 1,",
    "Active Slot 2,",
    "Active Slot 3,",
    "Active Slot 4,",
    "Save to state 1,",
    "Restore state 1,",
    "Save to state 2,",
    "Restore state 2,",
    "Save to state 3,",
    "Restore state 3,",
    "Save to state 4,",
    "Restore state 4;",
    "v,1;",
    "V,v",`BUILD_DATE
};


wire hps_forced_scandoubler;
wire forced_scandoubler = hps_forced_scandoubler | status[10];

wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;
wire [31:0] joy0_full, joy1_full;
wire [15:0] joy0 = joy0_full[15:0];
wire [15:0] joy1 = joy1_full[15:0];

// Menu mask: [0] direct video, [1] horizontal game, [2] no hiscore.
hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),

    .buttons(buttons),
    .ps2_key(ps2_key),
    .status(status),
    .status_in({status[127:66], ss_slot, status[63:0]}),
    .status_set(ss_status_set),
    .info_req(ss_info_req),
    .info(ss_info),
    .status_menumask({13'd0, ~hs_present, ~is_vertical, direct_video}),
    .forced_scandoubler(hps_forced_scandoubler),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),
    .video_rotated(video_rotated),
    
    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_req(ioctl_upload_req),
    .ioctl_upload_index(8'd4),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr_full),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joy0_full),
    .joystick_1(joy1_full)
);

// INPUT

// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wait = 1'b0;
wire        ioctl_wr;
wire [15:0] ioctl_index;
wire [26:0] ioctl_addr_full;
wire [24:0] ioctl_addr = ioctl_addr_full[24:0];
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

reg   [3:0] pcb;
wire        pcb_288 = ( pcb == 4 || pcb == 5 || pcb == 6 || pcb == 7 );   // 288x224 picture (Legion / Crazy Climber 2 boards)

always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==1)) begin
        pcb <= ioctl_dout;
    end
end

wire [21:0] gamma_bus;

// Joystick bits: [3:0] R L D U, [7:4] buttons 1-4, [8] Start, [9] Coin, [10] Pause, [13] Save/Load.
reg [15:0] p1 ;
reg [15:0] p2 ;
reg [15:0] dsw1 ;
reg [15:0] dsw2 ;

always @ (posedge clk_sys ) begin 
    p1 <= 16'hffff;
    p1[7:0] <= ~{ p1_buttons[3:0], p1_right, p1_left ,p1_down, p1_up};
     
    p2 <= 16'hffff;
    p2[7:0] <= ~{ p2_buttons[3:0], p2_right, p2_left ,p2_down, p2_up};
    
    p1[8] <= ~start1  ; 
    p1[9] <= ~start2  ;
    p1[10] <= ~coin_a ;
    p1[11] <= ~coin_b ;
    
    p2[8] <= ~key_service;
    p2[9] <= ~(key_test | status[35]);
end

wire        p1_right   = joy0[0] | key_p1_right;
wire        p1_left    = joy0[1] | key_p1_left;
wire        p1_down    = joy0[2] | key_p1_down;
wire        p1_up      = joy0[3] | key_p1_up;
wire [3:0]  p1_buttons = joy0[7:4] | {key_p1_d, key_p1_c, key_p1_b, key_p1_a};

wire        p2_right   = joy1[0] | key_p2_right;
wire        p2_left    = joy1[1] | key_p2_left;
wire        p2_down    = joy1[2] | key_p2_down;
wire        p2_up      = joy1[3] | key_p2_up | status[36];
wire [3:0]  p2_buttons = joy1[7:4] | {key_p2_d, key_p2_c, key_p2_b | status[36], key_p2_a | status[36]};

wire        start1  = joy0[8] | key_start_1p;
wire        start2  = joy1[8] | key_start_2p | status[11];
wire        coin_a  = joy0[9] | key_coin_a;
wire        coin_b  = joy1[9] | key_coin_b;
wire        b_pause = joy0[10] | joy1[10] | key_pause ;
wire        btn_ss  = joy0[13] | joy1[13];

// Keyboard handler

wire key_start_1p, key_start_2p, key_coin_a, key_coin_b;
wire key_test, key_reset, key_service, key_pause;
wire key_txt_enable, key_fg_enable, key_bg_enable, key_spr_enable;

wire key_p1_up, key_p1_left, key_p1_down, key_p1_right, key_p1_a, key_p1_b, key_p1_c, key_p1_d;
wire key_p2_up, key_p2_left, key_p2_down, key_p2_right, key_p2_a, key_p2_b, key_p2_c, key_p2_d;

wire pressed = ps2_key[9];

always @(posedge clk_sys) begin 
    reg old_state;

    old_state <= ps2_key[10];
    if(old_state ^ ps2_key[10]) begin
        casez(ps2_key[8:0])
            'h016: key_start_1p   <= pressed; // 1
            'h01e: key_start_2p   <= pressed; // 2
            'h02E: key_coin_a     <= pressed; // 5
            'h036: key_coin_b     <= pressed; // 6
            'h006: key_test       <= key_test ^ pressed; // f2
            'h004: key_reset      <= pressed; // f3
            'h046: key_service    <= pressed; // 9
            'h04D: key_pause      <= pressed; // p

            9'b?_0111_0101: key_p1_up      <= pressed; // up
            9'b?_0111_0010: key_p1_down    <= pressed; // down
            9'b?_0110_1011: key_p1_left    <= pressed; // left
            9'b?_0111_0100: key_p1_right   <= pressed; // right
            'h014: key_p1_a       <= pressed; // lctrl
            'h011: key_p1_b       <= pressed; // lalt
            'h029: key_p1_c       <= pressed; // spacebar
            'h012: key_p1_d       <= pressed; // lshift

            'h02d: key_p2_up      <= pressed; // r
            'h02b: key_p2_down    <= pressed; // f
            'h023: key_p2_left    <= pressed; // d
            'h034: key_p2_right   <= pressed; // g
            'h01c: key_p2_a       <= pressed; // a
            'h01b: key_p2_b       <= pressed; // s
            'h015: key_p2_c       <= pressed; // q
            'h01d: key_p2_d       <= pressed; // w

            'h083: key_txt_enable <= key_txt_enable ^ pressed; // f7
            'h00A: key_bg_enable  <= key_bg_enable  ^ pressed; // f8
            'h001: key_fg_enable  <= key_fg_enable  ^ pressed; // f9
            'h009: key_spr_enable <= key_spr_enable ^ pressed; // f10
        endcase
    end
end



reg user_flip;

wire pll_locked;

wire clk_sys;
reg  clk_4M,clk_8M,clk_16M,clk_ym;
reg  clk_6M;

wire clk_72M;

pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .outclk_0(clk_sys),     // 72
    .outclk_1(clk_72M),
    .locked(pll_locked)
);

assign    SDRAM_CLK = clk_72M;

localparam  CLKSYS=72;
localparam  CLKDIV8=CLKSYS/8,CLKDIV6=CLKSYS/6,CLKDIV4=CLKSYS/4,CLKDIVYM=(CLKSYS/4)*512 ;

reg [5:0] clk16_count;
reg [5:0] clk8_count;
reg [5:0] clk6_count;
reg [5:0] clk4_count;
reg [15:0] clk_ym_count;

reg prev_pause_cpu;
reg clk_16M_pause;

// Clock enables: ce_XM is high the cycle before each clk_XM pulse.
reg ce_16m, ce_6m, ce_4m;
// CPUs run unless paused or frozen by a save state.
wire cpu_run = ( ~pause_cpu & ~ss_pause ) | ss_cpu_execute;
// Sound CPU and OPL2 run unless paused, and always during a save-state sequence.
wire snd_run = ~pause_cpu | ss_pause;

always @ (posedge clk_sys) begin
    ce_16m <= ( clk16_count == CLKDIV8-1 ) || ( clk16_count == 3 && cpu_run );
    ce_6m  <= ( clk6_count  == CLKDIV6-1 );
    ce_4m  <= ( clk4_count  == CLKDIV4-1 );
end

always @ (posedge clk_sys) begin

    clk_6M <= ( clk6_count == 0 );

    if ( clk6_count == CLKDIV6-1 ) begin
        clk6_count <= 0;
    end else begin
        clk6_count <= clk6_count + 1;
    end
    
    clk_16M <= ( clk16_count == 0 || clk16_count == 4 );

    if ( clk16_count == CLKDIV8-1 ) begin
        clk16_count <= 0;
    end else if ( cpu_run ) begin
        clk16_count <= clk16_count + 1;
    end
    
    clk_8M <= ( clk8_count == 0 );

    if ( clk8_count == CLKDIV8-1 ) begin
        clk8_count <= 0;
    end else begin
        clk8_count <= clk8_count + 1;
    end    

    clk_4M <= ( clk4_count == 0 );

    if ( clk4_count == CLKDIV4-1 ) begin
        clk4_count <= 0;
    end else begin
        clk4_count <= clk4_count + 1;
    end
     
    clk_ym <= ( clk_ym_count == 0 );

    if ( clk_ym_count == CLKDIVYM-1 ) begin  // 4MHz / 512 = 7.8KHz
        clk_ym_count <= 0;
    end else begin
        clk_ym_count <= clk_ym_count + 1;
    end
     
end

// DIP changes apply at reset; only the load-time DIP push resets the core.
reg  dips_booted = 1'b0;   // load-time DIP push done
reg  ioctl_download_d;
always @(posedge clk_sys) begin
    ioctl_download_d <= ioctl_download;
    if (ioctl_download && ioctl_index == 16'd0)
        dips_booted <= 1'b0;
    else if (ioctl_download_d && !ioctl_download && ioctl_index == 16'd254)
        dips_booted <= 1'b1;
end
wire dip_push = ioctl_download && ( ioctl_index == 16'd254 ) && dips_booted;

wire    reset;
assign  reset = RESET | ( ioctl_download & ~dip_push ) | key_reset | status[0] ;

always @(posedge clk_sys) begin
    if ( reset ) begin
        dsw1 <= { 8'b0, sw[0] };
        dsw2 <= { 8'b0, sw[1] };
    end
end

//////////////////////////////////////////////////////////////////
// Flip screen (vreg bit 12) is drawn by the renderers; screen_rotate only rotates.
reg  flip_screen = 1'b0;
wire flip = 1'b0;   // unused
wire rotate_ccw = 1'b1;
wire no_rotate = ~show_rotated;
wire video_rotated ;

reg [23:0]     rgb;

wire hbl;
wire vbl;

wire [8:0] hc;
wire [8:0] vc;

wire hsync;
wire vsync;

wire hbl_delay, vbl_delay;

assign hbl_delay = hbl ;
assign vbl_delay = vbl ;

video_timing video_timing (
    .clk(clk_sys),
    .clk_pix(ce_6m),
    .reset(1'b0),
    .h288(pcb_288),
    .hc(hc),
    .vc(vc),
    .hs_offset(hs_offset),
    .vs_offset(vs_offset),
    .hs_width(hs_width),
    .vs_width(vs_width),
    .hbl(hbl),
    .vbl(vbl),
    .hsync(hsync),
    .vsync(vsync)
);

// PAUSE SYSTEM
wire    pause_cpu;
wire    hs_pause;

// 8 bits per colour, 72MHz sys clk
pause #(8,8,8,72) pause 
(
    .clk_sys(clk_sys),
    .reset(reset),
    .user_button(b_pause),
    .pause_request(hs_pause),
    .options(status[21:20]),
    .pause_cpu(pause_cpu),
    .dim_video(dim_video),
    .OSD_STATUS(OSD_STATUS),
    .r(rgb[23:16]),
    .g(rgb[15:8]),
    .b(rgb[7:0]),
    .rgb_out(rgb_pause_out)
);

wire [23:0] rgb_pause_out;
wire dim_video;

arcade_video #(320,24) arcade_video   // max active width
(
        .*,

        .clk_video(clk_sys),
        .ce_pix(clk_6M),

        .RGB_in(rgb_pause_out),

        .HBlank(hbl_delay),
        .VBlank(vbl_delay),
        .HSync(hsync),
        .VSync(vsync),

        .fx(scan_lines)
);

// Save states take the DDRAM port from screen_rotate while active.
wire [28:0] rot_ddr_addr;
wire [63:0] rot_ddr_din;
wire  [7:0] rot_ddr_be, rot_ddr_burst;
wire        rot_ddr_we, rot_ddr_rd, rot_ddr_clk;

screen_rotate screen_rotate (
    .CLK_VIDEO, .CE_PIXEL,
    .VGA_R, .VGA_G, .VGA_B, .VGA_HS, .VGA_VS, .VGA_DE,
    .rotate_ccw, .no_rotate, .flip, .video_rotated,
    .FB_EN, .FB_FORMAT, .FB_WIDTH, .FB_HEIGHT, .FB_BASE, .FB_STRIDE, .FB_VBL, .FB_LL,
    .DDRAM_CLK( rot_ddr_clk ),
    .DDRAM_BUSY( DDRAM_BUSY ),
    .DDRAM_BURSTCNT( rot_ddr_burst ),
    .DDRAM_ADDR( rot_ddr_addr ),
    .DDRAM_DIN( rot_ddr_din ),
    .DDRAM_BE( rot_ddr_be ),
    .DDRAM_WE( rot_ddr_we ),
    .DDRAM_RD( rot_ddr_rd )
);

assign DDRAM_CLK      = clk_sys;    // == CLK_VIDEO
assign DDRAM_BURSTCNT = ddr_ss.acquire ? ddr_ss.burstcnt   : rot_ddr_burst;
assign DDRAM_ADDR     = ddr_ss.acquire ? ddr_ss.addr[31:3] : rot_ddr_addr;
assign DDRAM_DIN      = ddr_ss.acquire ? ddr_ss.wdata      : rot_ddr_din;
assign DDRAM_BE       = ddr_ss.acquire ? ddr_ss.byteenable : rot_ddr_be;
assign DDRAM_WE       = ddr_ss.acquire ? ddr_ss.write      : rot_ddr_we;
assign DDRAM_RD       = ddr_ss.acquire ? ddr_ss.read       : rot_ddr_rd;
assign ddr_ss.rdata       = DDRAM_DOUT;
assign ddr_ss.rdata_ready = DDRAM_DOUT_READY;
assign ddr_ss.busy        = DDRAM_BUSY;

wire [9:0] tx_x ;
wire [9:0] tx_y ;

wire [9:0] tile_x_ofs = 10'd85;
wire [9:0] y_adj = pcb_288 ? 10'd0 : 10'd8 ;

// Render counters, mirrored about the visible window when flipped.
wire [9:0] vsum      = pcb_288 ? 10'd255 : 10'd271;
wire [9:0] hc_tile   = flip_screen ? 10'd341 - hc : { 1'b0, hc };
wire [8:0] hc_spr    = flip_screen ? 9'd345 - hc  : hc;
wire [9:0] vc_tile   = flip_screen ? vsum - vc : { 1'b0, vc };
wire [8:0] vc_spr    = flip_screen ? vsum[8:0] - 9'd1 - vc : vc;

always @ (*) begin
    if ( pcb == 2 || pcb == 3 ) begin
        tx_x <= hc_tile + tile_x_ofs;
        tx_y <= vc_tile - y_adj ;
    end else begin
        tx_x <= hc_tile - ( tile_x_ofs - 10'd42 );
        tx_y <= vc_tile - y_adj ;
    end
end


// layer 1 / gfx3
wire [9:0] bg_x = hc_tile + bg_scroll_x[9:0] + tile_x_ofs ; //ok
wire [9:0] bg_y = vc_tile + bg_scroll_y[9:0] - y_adj ;

// layer 2 / gfx2
wire [9:0] fg_x = hc_tile + fg_scroll_x[9:0] + tile_x_ofs ; //ok
wire [9:0] fg_y = vc_tile + fg_scroll_y[9:0] - y_adj ;

reg  [9:0] bg_x_latch ;
reg  [9:0] bg_y_latch ;

reg  [9:0] fg_x_latch ;
reg  [9:0] fg_y_latch ;

// layer 3 / gfx1
reg  [9:0] tx_x_latch ;
reg  [9:0] tx_y_latch ;


reg   [7:0] gfx_txt_attr_latch;
reg   [7:0] gfx_txt_attr_latch2;
reg   [7:0] gfx_txt_attr_latch3;

reg  [15:0] gfx_bg_latch;
reg  [15:0] gfx_fg_latch;
reg  [15:0] gfx_bg_latch2;
reg  [15:0] gfx_fg_latch2;

reg [10:0] bg_pal_addr ;
reg [10:0] fg_pal_addr ;
reg [10:0] tx_pal_addr ;

reg [10:0] sprite_pal_ofs = 11'h200;

always @ (posedge clk_sys) if ( ce_6m ) begin
    if ( reset == 1 ) begin

    end else begin

        sprite_fb_addr_r <= { ~vc[0], hc_spr } ;
        
        // make this a pipline
        fg_x_latch <= fg_x;
        fg_y_latch <= fg_y;

        bg_x_latch <= bg_x;
        bg_y_latch <= bg_y;

        tx_x_latch <= tx_x;
        tx_y_latch <= tx_y;
        
// background 0x3ff           
        
        // tile #
        bg_ram_addr <=  { bg_x[9:4], bg_y[8:4] }; 
        
        gfx_bg_latch <= bg_ram_dout;
        // bitmap 
        gfx3_addr <= { bg_ram_dout[9:0], bg_y[3:0], bg_x_latch[3:1] };
        
        gfx_bg_latch2 <= gfx_bg_latch;
        // palette
        //tile_pal_addr <= 11'h600 + { gfx_bg_latch[15:11] , bg_x[0]  ? gfx3_dout[3:0] : gfx3_dout[7:4] };
        bg_pal_addr <=  11'h600 + { gfx_bg_latch2[15:11] , bg_x[0]  ? gfx3_dout[3:0] : gfx3_dout[7:4] };
        
// foreground 0x7ff         

        fg_ram_addr <=  { fg_x[9:4], fg_y[8:4] };
        
        gfx_fg_latch <= fg_ram_dout;
        gfx2_addr    <= { fg_ram_dout[10:0], fg_y[3:0], fg_x_latch[3:1] };
        
        gfx_fg_latch2 <= gfx_fg_latch;
        
        //tile_pal_addr <= { gfx_fg_latch[15:11] , ( fg_x_latch[0] == 0 ) ? gfx2_dout[3:0] : gfx2_dout[7:4] };
        fg_pal_addr <= 11'h400 + { gfx_fg_latch2[15:11] , ( fg_x_latch[0] == 0 ) ? gfx2_dout[3:0] : gfx2_dout[7:4] };
    
    
// text layer
    
        // read from two addresses at once
        if ( pcb == 0 || pcb == 8 || pcb == 9 || pcb == 1 || pcb == 4) begin
            // terra force and crazy climber 2
            gfx_txt_addr      <= { tx_x[8], 1'b0, ~tx_y[7:3], tx_x[7:3] } ;//{ 1'b0, t1[9:0] };
            gfx_txt_attr_addr <= { tx_x[8], 1'b1, ~tx_y[7:3], tx_x[7:3] } ; //{ 1'b1, t1[9:0] } ;
        end else if ( pcb == 2 || pcb == 3 ) begin
            // armed f
            gfx_txt_addr      <= { 1'b0, tx_x[8:3], tx_y[7:3] } ; 
            gfx_txt_attr_addr <= { 1'b1, tx_x[8:3], tx_y[7:3] } ;
        end else if ( pcb == 5 || pcb == 6 || pcb == 7  ) begin
            // legion / big fighter
            gfx_txt_addr      <= { tx_x[8], 1'b0, tx_x[7:3], tx_y[7:3] } ;
            gfx_txt_attr_addr <= { tx_x[8], 1'b1, tx_x[7:3], tx_y[7:3] } ;
        end
        
        gfx1_addr <= { gfx_txt_attr_dout[1:0], ( has_nb1414m4 == 0 || gfx_txt_addr > 12'h12 ) ? gfx_txt_dout[7:0] : 8'h0 , tx_y[2:0], tx_x_latch[2:1] } ;  

        gfx_txt_attr_latch <= gfx_txt_attr_dout;

        gfx_txt_attr_latch2 <= gfx_txt_attr_latch;
        
        tx_pal_addr <= { gfx_txt_attr_latch2[7:4] , ( tx_x[0] ? gfx1_dout[3:0] : gfx1_dout[7:4] ) };
        gfx_txt_attr_latch3 <= gfx_txt_attr_latch2;
        
        draw_pix <= 0;
        
        
        // 15 == transparent
        // lowest priority
        if ( gfx1_en == 1 && tx_enable == 1 && tx_pal_addr[3:0] != 15 ) begin
            tile_pal_addr <= tx_pal_addr;
            draw_pix <= 1;
        end

        // background
        if ( gfx3_en == 1 && bg_enable == 1 && bg_pal_addr[3:0] != 15 ) begin
            tile_pal_addr <= bg_pal_addr ;
            draw_pix <= 1;
        end
         
        // sprite priority 2
        if ( gfx4_en == 1 && sp_enable == 1 && sprite_fb_out[1:0] == 2 ) begin  
            tile_pal_addr <= ( sprite_pal_ofs + sprite_fb_out[10:2] ) ;
            draw_pix <= 1;
        end
        
        if ( gfx2_en == 1 && fg_enable == 1 && fg_pal_addr[3:0] != 15 ) begin
            tile_pal_addr <= fg_pal_addr ;
            draw_pix <= 1;
        end
        
        // sprite priority 1
        if ( gfx4_en == 1 && sp_enable == 1 && sprite_fb_out[1:0] == 1 ) begin 
            tile_pal_addr <= ( sprite_pal_ofs + sprite_fb_out[10:2] ) ;
            draw_pix <= 1;
        end
        
        // highest priority 
        if ( gfx1_en == 1 && tx_enable == 1 && tx_pal_addr[3:0] != 15 && gfx_txt_attr_latch3[3] == 0) begin
            tile_pal_addr <=  tx_pal_addr;
            draw_pix <= 1;
        end
        
        // sprite priority 0
        if ( gfx4_en == 1 && sp_enable == 1 && sprite_fb_out[1:0] == 0 ) begin 
            tile_pal_addr <= ( sprite_pal_ofs + sprite_fb_out[10:2] ) ;
            draw_pix <= 1;
        end

        rgb <= 0;
                           
        if ( draw_pix == 1 ) begin
            rgb <= { tile_pal_dout[11:8], 4'b0, tile_pal_dout[7:4] , 4'b0, tile_pal_dout[3:0], 4'b0 } ;
        end

    end
end



reg draw_pix ;

wire mcu_hold_68k;   // holds the 68K's MCU latch read

/// 68k cpu

always @ (posedge clk_sys) begin

    if ( reset == 1 ) begin
        m68k_dtack_n <= 1;
        
//    end else if ( clk_8M == 1 ) begin
    end else if ( clk_16M == 1 ) begin
        // tell 68k to wait for valid data. 0=ready 1=wait
        // always ack when it's not program rom
        if ( ss_ovr_hit ) begin
            m68k_dtack_n <= 0;
        end else
        m68k_dtack_n <= m68k_rom_cs ? !m68k_rom_valid :
                        m68k_txt_ram_cs ? !txt_ram_valid :
                        irq_i8751_cs ? mcu_hold_68k :
//                        irq_z80_cs ? nb1414m4_busy :
                        0;

        // select cpu data input based on what is active 
        m68k_din <=  ss_ovr_hit   ? ss_ovr_data :
                     m68k_rom_cs  ? m68k_rom_data :
                     m68k_ram_cs  ? ram68k_dout :
                     m68k_ram_2_cs ? m68k_ram_2_dout :
                     m68k_ram_3_cs ? m68k_ram_3_dout :
                     m68k_tile_pal_cs ? m68k_tile_pal_dout :
                     m68k_spr_cs  ? ram68k_sprite_dout :
                     m68k_spr_pal_cs ? m68k_spr_pal_dout :
                     m68k_txt_ram_cs ? { 8'h00, m68k_txt_attr_ram_dout } :
                     m68k_bg_ram_cs ? m68k_bg_ram_dout :
                     m68k_fg_ram_cs ? m68k_fg_ram_dout :
                     input_p1_cs ? p1 :
                     input_p2_cs ? p2 :
                     input_dsw1_cs ? dsw1 :
                     input_dsw2_cs ? dsw2 :
                     16'd0;
                     
    end
end 

// vblank handling 
// process interrupt and sprite buffering
always @ (posedge clk_sys ) begin

end
 
reg         nb1414m4_busy;
reg  [7:0]  nb1414m4_cmd_state;
reg  [3:0]  nb1414m4_dma_state;
reg         nb1414m4_wr;
reg         nb1414m4_erase;
reg  [15:0] nb1414m4_cmd;
reg  [15:0] nb1414m4_next_cmd;
reg  [14:0] nb1414m4_cmd_addr;
reg  [14:0] nb1414m4_cmd_src;
reg  [13:0] nb1414m4_src;
reg  [13:0] nb1414m4_dst; // might need to change
reg  [13:0] nb1414m4_dst_attr;
reg  [13:0] nb1414m4_idx;
reg  [13:0] nb1414m4_dma_size;
reg  [4:0]  nb1414m4_frame;
reg         nb1414m4_use_buffer;
reg  [7:0]  nb1414m4_buffer[15:0];

reg  [13:0] nb1414m4_address;
wire [7:0]  nb1414m4_dout;
wire [7:0]  nb1414m4_din;
wire [7:0]  nb1414m4_tile;
wire [7:0]  nb1414m4_pal;
reg  [7:0]  nb1414m4_credits;
reg [23:0]  nb1414m4_p1;
reg [23:0]  nb1414m4_p2;

//	dst = (m_data[0x330 + ((mcu_cmd & 0xf) * 2)] << 8) | (m_data[0x331 + ((mcu_cmd & 0xf) * 2)] & 0xff);
//	dst &= 0x3fff;

always @ (posedge clk_sys) begin
    if ( reset == 1 || ss_restore_reset ) begin
        nb1414m4_cmd_state <= 0;
        nb1414m4_dma_state <= 0;
        nb1414m4_wr <= 0;
        nb1414m4_erase <= 0;
        nb1414m4_use_buffer <= 0;
    end else if ( nb1414m4_busy == 1 ) begin
        // 0x200 command
        // default to draw
        
        if ( nb1414m4_cmd[15:8] == 8'h02 ) begin
            // 200 command
            // lookup dst in m4 rom table. index is part of command
            if ( nb1414m4_cmd_state == 0 ) begin
                nb1414m4_cmd_state <= 1;
                // setup read for high byte of destination
                // mcu_cmd & 0x87
                nb1414m4_address[13:0] <= 14'h330 + { nb1414m4_cmd[2:0], 1'b0 } ;
            end else if ( nb1414m4_cmd_state == 1 ) begin
                // need a cycle to read
                nb1414m4_cmd_state <= 2;
            end else if ( nb1414m4_cmd_state == 2 ) begin
                // latch in high byte of source
                nb1414m4_src[13:8] <= nb1414m4_dout[5:0];
                // setup read for low byte of destination
                nb1414m4_address[13:0] <= 14'h331 + { nb1414m4_cmd[2:0], 1'b0 } ;
                nb1414m4_cmd_state <= 3;
            end else if ( nb1414m4_cmd_state == 3 ) begin
                // need a cycle to read
                nb1414m4_cmd_state <= 4;
            end else if ( nb1414m4_cmd_state == 4 ) begin
                // latch in low byte of source
                nb1414m4_src[7:0] <= nb1414m4_dout[7:0];
                // start dma
                nb1414m4_cmd_state <= 5;
            end else if ( nb1414m4_cmd_state == 5 ) begin
                nb1414m4_idx <= 0;
                if ( nb1414m4_src[10:0] == 0 ) begin
                    // start after command data
                    // dma(src, 0x0000, 0x400, 1, vram);
                    nb1414m4_dma_size <= 14'h400;
                    nb1414m4_dst <= 0;
                    nb1414m4_dma_state <= 4'h1;
                    nb1414m4_cmd_state <= 8'h06 ;
                end else begin
                    //fill(0x0000, m_data[src], m_data[src + 1], vram);
                    nb1414m4_cmd_state <= 8'h90;
                end
            end else if ( nb1414m4_cmd_state == 8'h06 ) begin                
                // wait for dma
                if ( nb1414m4_dma_state == 4'hf ) begin
                    // done
                    nb1414m4_cmd_state <= 8'hff;
                end
            end
        end if ( nb1414m4_cmd[15:8] == 8'h00 ) begin
            if ( nb1414m4_cmd_state == 0 ) begin
                // read credits
                nb1414m4_cmd_state <= 1;
                nb1414m4_use_buffer <= 0;

                // setup read for high byte of destination
                // mcu_cmd & 0x87
                // nb1414m4_address[13:0] <= 14'h00f ;
            end else if ( nb1414m4_cmd_state == 1 ) begin
                // need a cycle to read
                nb1414m4_cmd_state <= 2;
            end else if ( nb1414m4_cmd_state == 2 ) begin    
                if ( nb1414m4_credits == 0 ) begin
                    // insert coin
                    nb1414m4_cmd_addr  <= 14'h001 ;
                    nb1414m4_cmd_src   <= 14'h003 ;
                    nb1414m4_dma_size  <= 14'h010 ;
                    nb1414m4_erase     <= nb1414m4_frame[4];
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'h03 ;
                end else begin
                    // press start
                    nb1414m4_cmd_addr  <= 14'h049 ;
                    nb1414m4_cmd_src   <= 14'h04b ;
                    nb1414m4_dma_size  <= 14'h018 ;
                    nb1414m4_erase     <= 0;
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'h03 ;
                end
            end else if ( nb1414m4_cmd_state == 8'h03 ) begin                
                // credit
                nb1414m4_cmd_addr  <= 14'h023 ;
                nb1414m4_cmd_src   <= 14'h025 ;
                nb1414m4_dma_size  <= 14'h010 ;
                nb1414m4_erase     <= 0;
                nb1414m4_cmd_state <=   8'h80 ;
                nb1414m4_next_cmd  <=   8'h04 ;
            end else if ( nb1414m4_cmd_state == 8'h04 ) begin                
                // default - skip to next if no credits?
                nb1414m4_cmd_state <=   8'h05 ;
                if ( nb1414m4_credits == 1 ) begin
                    // press 1 player
                    nb1414m4_cmd_addr  <= 14'h07b ;
                    nb1414m4_cmd_src   <= 14'h07d ;
                    nb1414m4_dma_size  <= 14'h018 ;
                    nb1414m4_erase     <= nb1414m4_frame[4];
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'h05 ;
                end else if ( nb1414m4_credits > 1 ) begin
                    // press 1 or 2 players
                    nb1414m4_cmd_addr  <= 14'h0ad ;
                    nb1414m4_cmd_src   <= 14'h0af ;
                    nb1414m4_dma_size  <= 14'h018 ;
                    nb1414m4_erase     <= nb1414m4_frame[4];
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'h05 ;
                end
            end else if ( nb1414m4_cmd_state == 8'h05 ) begin                                    
                    nb1414m4_cmd_addr  <= 14'h045 ;
                    nb1414m4_cmd_src   <= 14'h045 ;
                    nb1414m4_dma_size  <= 14'h002 ;
                    nb1414m4_use_buffer <= 1;
                    nb1414m4_buffer[0] <= ( nb1414m4_credits[7:4] == 0 ) ? 8'h20 : { 4'h3, nb1414m4_credits[7:4] };
                    nb1414m4_buffer[1] <= { 4'h3, nb1414m4_credits[3:0] };
                    nb1414m4_erase     <= 0;
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'hff ;  // done

//                    nb1414m4_cmd_state <=   8'h06 ;
            end
            
        end else if ( nb1414m4_cmd[15:8] == 8'h06 ) begin
            // service mode
        end else if ( nb1414m4_cmd[15:8] == 8'h0e ) begin
            // gameplay
            if ( nb1414m4_cmd_state == 0 ) begin
                // read credits
                nb1414m4_cmd_state <= 1;
                nb1414m4_use_buffer <= 0;

                // setup read for high byte of destination
                // mcu_cmd & 0x87
                // nb1414m4_address[13:0] <= 14'h00f ;
            end else if ( nb1414m4_cmd_state == 1 ) begin
                // need a cycle to read
                nb1414m4_cmd_state <= 2;
            end else if ( nb1414m4_cmd_state == 2 ) begin    
                // p1 score
                nb1414m4_cmd_addr  <= 14'h10d ;
                nb1414m4_cmd_src   <= 14'h107 ;
                nb1414m4_dma_size  <= 14'h008 ;
                nb1414m4_use_buffer <= 1;
                nb1414m4_erase     <= 0;
                nb1414m4_cmd_state <=   8'h80 ;
                nb1414m4_next_cmd  <=   8'h03 ;
                
                nb1414m4_buffer[0] <= { (nb1414m4_p1[23:20] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[23:20] };
                nb1414m4_buffer[1] <= { (nb1414m4_p1[23:16] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[19:16] };
                nb1414m4_buffer[2] <= { (nb1414m4_p1[23:12] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[15:12] };
                nb1414m4_buffer[3] <= { (nb1414m4_p1[23:8]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[11:8] };
                nb1414m4_buffer[4] <= { (nb1414m4_p1[23:4]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[7:4] };
                nb1414m4_buffer[5] <= { (nb1414m4_p1[23:0]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p1[3:0] };
                nb1414m4_buffer[6] <=   (nb1414m4_p1[23:0]  == 0 ) ? 8'h20 : 8'h30;
                nb1414m4_buffer[7] <= 8'h30;
                
            end else if ( nb1414m4_cmd_state == 3 ) begin    
                // high score
                nb1414m4_cmd_addr  <= 14'h0df ;
                nb1414m4_cmd_src   <= 14'h0e1 ;
                nb1414m4_dma_size  <= 14'h008 ;
                nb1414m4_erase     <= 0;
                nb1414m4_cmd_state <=   8'h80 ;
                nb1414m4_next_cmd  <=   8'h04 ;
            end else if ( nb1414m4_cmd_state == 4 )  begin    
                // p1 message
                nb1414m4_cmd_addr  <= 14'h0fb ;
                nb1414m4_cmd_src   <= 14'h0fd ;
                nb1414m4_dma_size  <= 14'h008 ;
                nb1414m4_erase     <= ~nb1414m4_cmd[0] ;
                nb1414m4_cmd_state <=   8'h80 ;
                nb1414m4_next_cmd  <=   8'h05 ;
            end else if ( nb1414m4_cmd_state == 5 ) begin    
                if ( nb1414m4_cmd[7] == 1 ) begin
                    // p2 message
                    nb1414m4_cmd_addr  <= 14'h117 ;
                    nb1414m4_cmd_src   <= 14'h119 ;
                    nb1414m4_dma_size  <= 14'h008 ;
                    nb1414m4_erase     <= ~nb1414m4_cmd[1] ;
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'h06 ;
                end else begin
                    nb1414m4_cmd_state <=   8'h07 ;
                end
            end else if ( nb1414m4_cmd_state == 8'h06 ) begin    
                // p2 score
                nb1414m4_cmd_addr  <= 14'h129 ;
                nb1414m4_cmd_src   <= 14'h123 ;
                nb1414m4_dma_size  <= 14'h008 ;
                nb1414m4_use_buffer <= 1;
                nb1414m4_erase     <= 0;
                nb1414m4_cmd_state <=   8'h80 ;
                nb1414m4_next_cmd  <=   8'h07 ;
                
                nb1414m4_buffer[0] <= { (nb1414m4_p2[23:20] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[23:20] };
                nb1414m4_buffer[1] <= { (nb1414m4_p2[23:16] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[19:16] };
                nb1414m4_buffer[2] <= { (nb1414m4_p2[23:12] == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[15:12] };
                nb1414m4_buffer[3] <= { (nb1414m4_p2[23:8]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[11:8] };
                nb1414m4_buffer[4] <= { (nb1414m4_p2[23:4]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[7:4] };
                nb1414m4_buffer[5] <= { (nb1414m4_p2[23:0]  == 0 ) ? 4'h2 : 4'h3, nb1414m4_p2[3:0] };
                nb1414m4_buffer[6] <=   (nb1414m4_p2[23:0]  == 0 ) ? 8'h20 : 8'h30;
                nb1414m4_buffer[7] <= 8'h30;
            end else if ( nb1414m4_cmd_state == 8'h07 ) begin  
                if ( nb1414m4_cmd[6] == 1 ) begin
                    // game over man
                    nb1414m4_cmd_addr  <= 14'h133 ;
                    nb1414m4_cmd_src   <= 14'h135 ;
                    nb1414m4_dma_size  <= 14'h010 ;
                    nb1414m4_erase     <= 0;
                    nb1414m4_cmd_state <=   8'h80 ;
                    nb1414m4_next_cmd  <=   8'hff ;
                end else begin
                    nb1414m4_cmd_state <=   8'hff ;
                end
            end
        end
        
        // show message
        if ( nb1414m4_cmd_state == 8'h80 ) begin
            nb1414m4_cmd_state <= 8'h81;
            // setup read for high byte of destination
            nb1414m4_address[13:0] <= nb1414m4_cmd_addr ;
        end else if ( nb1414m4_cmd_state == 8'h81 ) begin
            // need a cycle to read
            nb1414m4_cmd_state <= 8'h82;
        end else if ( nb1414m4_cmd_state == 8'h82 ) begin
            // latch in high byte of source
            nb1414m4_dst[13:8] <= nb1414m4_dout[5:0];
            // setup read for low byte of destination
            nb1414m4_address[13:0] <= nb1414m4_cmd_addr + 1 ;
            nb1414m4_cmd_state <= 8'h83;
        end else if ( nb1414m4_cmd_state == 8'h83 ) begin
            // need a cycle to read
            nb1414m4_cmd_state <= 8'h84;
        end else if ( nb1414m4_cmd_state == 8'h84 ) begin
            nb1414m4_src <= nb1414m4_cmd_src;
            // latch in low byte of source
            nb1414m4_dst[7:0] <= nb1414m4_dout[7:0];
            // start dma
            nb1414m4_idx <= 0;
            nb1414m4_cmd_state <= 8'h85;
            // start a transfer
            nb1414m4_dma_state <= 4'h1;
        end else if ( nb1414m4_cmd_state == 8'h85 ) begin
            // wait until transfer is done
            if ( nb1414m4_dma_state == 4'hf ) begin
                nb1414m4_cmd_state <= nb1414m4_next_cmd ;
            end                
        end 
        
        // DMA transfer
        if ( nb1414m4_dma_state == 4'h1 ) begin 
            nb1414m4_dst_attr <= nb1414m4_dst + 14'h400;
            nb1414m4_dma_state <= 4'h2;
            nb1414m4_idx <= 0;
        end else if ( nb1414m4_dma_state == 4'h2 ) begin        
            // start transfer
            nb1414m4_address <= nb1414m4_src + nb1414m4_idx;
            nb1414m4_wr <= 0;
            nb1414m4_dma_state <= 4'h3;
        end else if ( nb1414m4_dma_state == 4'h3 ) begin
            // read takes a cycle
            nb1414m4_dma_state <= 4'h4;
        end else if ( nb1414m4_dma_state == 4'h4 ) begin
            if ( nb1414m4_use_buffer == 1 ) begin
                nb1414m4_din <= nb1414m4_buffer[nb1414m4_idx];
            end else if ( nb1414m4_erase == 0 ) begin
                nb1414m4_din <= nb1414m4_dout;
            end else begin
                nb1414m4_din <= 8'h20;
            end
            
            // address is valid.  clock in the read
            nb1414m4_dma_state <= 4'h5;
            // setup a write.  the data will be valid in the next clock
            // writes to shared ram at ofset nb1414m4_dst
            if ( nb1414m4_dst > 18 ) begin
                // only write if not in the command buffer
                nb1414m4_wr <= 1;
            end
        end else if ( nb1414m4_dma_state == 4'h5 ) begin
            nb1414m4_wr <= 0;
            // source data is valid.  write 
            // disable write
            // first 0x400 is char data, second 0x400 is attributes
            if ( nb1414m4_idx < (nb1414m4_dma_size-1) ) begin 
                if ( nb1414m4_dst > 18 ) begin
                    nb1414m4_wr <= 1;
                end

                nb1414m4_idx <= nb1414m4_idx + 1;
                nb1414m4_dst <= nb1414m4_dst + 1;

                nb1414m4_dma_state <= 4'h2;
            end else begin
                // done
                nb1414m4_idx <= 0;
                // start attributes
                nb1414m4_dst <= nb1414m4_dst_attr;
                nb1414m4_dma_state <= 4'h6;
            end
        end else if ( nb1414m4_dma_state == 4'h6 ) begin 
            // start attribute transfer
            if ( nb1414m4_erase == 0 ) begin
                nb1414m4_address <= nb1414m4_src + nb1414m4_dma_size + nb1414m4_idx;
            end else begin
                nb1414m4_address <= 14'h013;
            end
            nb1414m4_wr <= 0;
            nb1414m4_dma_state <= 4'h7;
        end else if ( nb1414m4_dma_state == 4'h7 ) begin
            // read takes a cycle
            nb1414m4_dma_state <= 4'h8;
        end else if ( nb1414m4_dma_state == 4'h8 ) begin
            nb1414m4_din <= nb1414m4_dout;
            
            // address is valid.  clock in the read
            nb1414m4_dma_state <= 4'h9;
            // setup a write.  the data will be valid in the next clock
            // writes to shared ram at ofset nb1414m4_dst
            nb1414m4_wr <= 1;
        end else if ( nb1414m4_dma_state == 4'h9 ) begin
            nb1414m4_wr <= 0;
            // source data is valid.  write 
            // disable write
            // first 0x400 is char data, second 0x400 is attributes
            if ( nb1414m4_idx < (nb1414m4_dma_size-1) ) begin 

                nb1414m4_idx <= nb1414m4_idx + 1;
                nb1414m4_dst <= nb1414m4_dst + 1;

                nb1414m4_dma_state <= 4'h6;
            end else begin
                // done
                nb1414m4_wr <= 0;
                nb1414m4_use_buffer <= 0;
                nb1414m4_dma_state <= 4'hf;
            end
            
        end 
        
        // fill
        if ( nb1414m4_cmd_state == 8'h90 ) begin 
            nb1414m4_wr <= 0;
            nb1414m4_dst <= 0;
            nb1414m4_idx <= 8'h0;
            nb1414m4_address[13:0] <= nb1414m4_src ;
            nb1414m4_cmd_state <= 8'h91;
        end else if ( nb1414m4_cmd_state == 8'h91 ) begin
            // need a cycle to read
            nb1414m4_cmd_state <= 8'h92;
        end else if ( nb1414m4_cmd_state == 8'h92 ) begin
            nb1414m4_tile <= nb1414m4_dout;
            nb1414m4_address[13:0] <= nb1414m4_src + 1 ;
            nb1414m4_cmd_state <= 8'h93;
        end else if ( nb1414m4_cmd_state == 8'h93 ) begin            
            nb1414m4_cmd_state <= 8'h94;
        end else if ( nb1414m4_cmd_state == 8'h94 ) begin
            nb1414m4_pal <= nb1414m4_dout;
            nb1414m4_cmd_state <= 8'h95;
            nb1414m4_din <= nb1414m4_tile;
            if ( nb1414m4_dst > 18 ) begin
                nb1414m4_wr <= 1;
            end
        end else if ( nb1414m4_cmd_state == 8'h95 ) begin
            nb1414m4_wr <= 0;
            if ( nb1414m4_idx < 14'h7ff ) begin
                if ( nb1414m4_dst > 18 ) begin
                    nb1414m4_wr <= 1;
                end

                // increment write pos
                nb1414m4_dst <= nb1414m4_dst + 1;
                // increment count
                nb1414m4_idx <= nb1414m4_idx + 1;
                if ( nb1414m4_idx == 14'h400 ) begin
                    // switch to writing the txt pal value
                    nb1414m4_din <= nb1414m4_pal;
                end
            end else begin
                // done
                nb1414m4_cmd_state <= 8'hff;
            end
        end
        
        // reset state
        if ( nb1414m4_cmd_state == 8'hff ) begin
            nb1414m4_wr <= 0;
            nb1414m4_cmd_state <= 0;
            nb1414m4_dma_state <= 0;
            nb1414m4_erase <= 0 ;
        end
    end
end

            
dual_port_ram #(.LEN(16384)) nb1414m4_rom (
    .clock_a ( clk_sys ),
    .address_a ( nb1414m4_address ),
    .wren_a ( 0 ),
    .data_a ( ),
    .q_a ( nb1414m4_dout ),

    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[13:0] ),
    .wren_b ( nb1414m4_ioctl_wr ),
    .data_b ( ioctl_dout ),
    .q_b(  )
    );

//IORQ gets together with M1-pin active/low. 
always @ (posedge clk_sys) begin
    
    if ( reset == 1 ) begin
        z80_a_irq_n <= 1;
    end else if ( clk_ym == 1 && snd_run ) begin
        z80_a_irq_n <= 0;
    end 
    
    // check for interrupt ack and deassert int
    if ( M1_a_n == 0 && z80_a_irq_n == 0 && IORQ_a_n == 0 ) begin
        z80_a_irq_n <= 1;
    end

    if ( ss_misc_wr ) z80_a_irq_n <= ssm_z80_a_irq_n;
end

reg scroll_msb;

always @ (posedge clk_sys) begin
     if ( clk_4M == 1 ) begin

       
        z80_a_wait_n <= 1;
        
        if ( z80_a_rd_n == 0 && z80_a_rom_valid == 0 && z80_a_rom_cs == 1 ) begin
            // wait if rom is selected and data is not yet available
            z80_a_wait_n <= 0;
        end 
        
        if ( z80_a_rd_n == 0 ) begin 
            if ( z80_a_rom_cs ) begin
                z80_a_din <= z80_a_rom_data;
            end else if ( z80_a_ram_cs ) begin
                z80_a_din <= z80_a_ram_data;
            end else if ( z80_a_latch_clr_cs ) begin
                // todo
                z80_a_din <= 0;
                sound_latch <= 8'h0;
            end else if ( z80_a_latch_r_cs ) begin
                z80_a_din <= sound_latch;
                // todo
            end else begin
                z80_a_din <= 8'h00;
            end                
        end

        sound_wr <= 0 ;
        if ( z80_a_wr_n == 0 ) begin 
            if ( z80_a_sound0_cs == 1 || z80_a_sound1_cs == 1) begin
                sound_data  <= z80_a_dout;
                sound_addr <= z80_a_sound1_cs ; //   opl2 is single bit address
                sound_wr <= 1;
            end else if (z80_a_dac1_cs == 1 ) begin
                    dac1 <= z80_a_dout;
                end else if (z80_a_dac2_cs == 1 ) begin
                    dac2 <= z80_a_dout;
                end
        end

    end
     
    z80_b_wait_n <= 1;
    
    if ( z80_b_rd_n == 0 ) begin 
        if ( z80_b_rom_cs ) begin
            z80_b_din <= z80_b_rom_data;
        end else if ( z80_b_ram_txt_cs ) begin
            z80_b_din <= z80_b_ram_txt_dout;
        end else if ( z80_b_ram_1_cs ) begin
            z80_b_din <= z80_b_ram_1_dout;
        end else if ( z80_b_ram_2_cs ) begin
            z80_b_din <= z80_b_ram_2_dout;
        end else begin
            z80_b_din <= 8'h00;
        end
    end

    // both the 68k and the bootleg z80 write to the scroll registers
    if ( clk_16M == 1 ) begin
        // 68k writes
        if ( !m68k_rw ) begin
            if ( bg_scroll_x_cs == 1) begin
              bg_scroll_x <= m68k_dout[15:0];
            end else if ( bg_scroll_y_cs == 1) begin
              bg_scroll_y <= m68k_dout[15:0];
            end else if ( fg_scroll_y_cs == 1 ) begin 
                if ( pcb == 2 || pcb == 3 ) begin
                    fg_scroll_y[9:0] <= m68k_dout[9:0];
                end else if ( pcb == 6 || pcb == 7 ) begin
                    // legion bootlegs
                    if ( m68k_a[7:0] == 8'h16 ) begin
                        fg_scroll_y[7:0] <= m68k_dout[7:0]; // b
                    end else if ( m68k_a[7:0] == 8'h18 ) begin
                        fg_scroll_y[9:8] <= m68k_dout[1:0]; // c
                    end 
                end else if ( pcb == 9 ) begin  
                    fg_scroll_y[7:0] <= m68k_dout[7:0];
                    scroll_msb <= 1;
                    // terrafb
                end
            end else if ( fg_scroll_x_cs == 1 ) begin  // && m68k_rw == 0
                if ( pcb == 2 || pcb == 3) begin
                    fg_scroll_x[9:0] <= m68k_dout[9:0];
                end else if ( pcb == 6 || pcb == 7 ) begin
                    // legion bootlegs
                    
                    if ( m68k_a[7:0] == 8'h1a ) begin
                        fg_scroll_x[7:0] <= m68k_dout[7:0];
                    end else if ( m68k_a[7:0] == 8'h1c ) begin
                        fg_scroll_x[9:8] <= m68k_dout[1:0];
                    end
                end else if ( pcb == 9 ) begin                                        
                    // terrafb
                    if ( scroll_msb == 1 ) begin
                        fg_scroll_x[9:8] <= m68k_dout[5:4];
                        fg_scroll_y[9:8] <= m68k_dout[1:0];
                    end else begin
                        fg_scroll_x[7:0] <= m68k_dout[7:0];
                    end
                end
            end else if ( terrafb_fg_scroll_msb_w == 1 ) begin
                scroll_msb <= 0;
            end else if ( sound_latch_cs == 1) begin
              sound_latch <= {m68k_dout[6:0],1'b1};
            end
        end
    end

    if ( reset == 1 ) begin
    end else begin
        if ( pcb == 8 ) begin
            // bootleg z80 controls foreground scrolling
            if ( z80_b_fg_scroll_x_cs == 1 && z80_b_wr_n == 0 ) begin
                fg_scroll_x[7:0] <= z80_b_dout;
            end else if ( z80_b_fg_scroll_y_cs == 1 && z80_b_wr_n == 0 ) begin
                fg_scroll_y[7:0] <= z80_b_dout;
            end else if ( z80_b_fg_scroll_msb_cs == 1 && z80_b_wr_n == 0 ) begin
                fg_scroll_x[9:8] <= z80_b_dout[3:2];
                fg_scroll_y[9:8] <= z80_b_dout[1:0];
            end
         end 
    end

    if ( reset == 1 ) begin
        m68k_ipl0_n  <= 1 ;
        m68k_ipl1_n  <= 1 ;
        int_ack <= 0;
        z80_b_irq_n <= 1;
        flip_screen <= 0;
        bg_enable <= 1;
        fg_enable <= 1;
        sp_enable <= 1;
        tx_enable <= 1;
        nb1414m4_frame <= 0;
    end else if ( clk_16M == 1 ) begin

        vbl_sr <= { vbl_sr[0], vbl };
        
        if ( nb1414m4_cmd_state == 8'hff ) begin
            nb1414m4_busy <= 0;
        end 
        
        // only a write to 0x07c00e clears to interrupt line
        if ( irq_ack_cs == 1 ) begin
            m68k_ipl0_n <= 1 ;
            m68k_ipl1_n <= 1 ;
        end else if ( irq_z80_cs == 1 ) begin
            //if (data & 0x4000 && ((m_vreg & 0x4000) == 0)) //0 -> 1 transition
            //    m_extra->set_input_line(0, HOLD_LINE);
            
           
            if ( has_nb1414m4 == 1 ) begin
                // nb1414m4
                if ( m68k_dout[14] == 1 ) begin 
                    // trigger nb1414m4 command handler
                    nb1414m4_busy <= 1;

                    fg_scroll_x[9:0] <= { nb_scroll_x_h[1:0], nb_scroll_x_l[7:0] };
                    fg_scroll_y[9:0] <= { nb_scroll_y_h[1:0], nb_scroll_y_l[7:0] };
                end
            end else begin
                if ( m68k_dout[14] == 1 ) begin 
                    z80_b_irq_n <= 0;
                end
            end
            flip_screen <= m68k_dout[12];
            bg_enable <= m68k_dout[11];
            fg_enable <= m68k_dout[10];
            sp_enable <= m68k_dout[9];
            tx_enable <= m68k_dout[8];

        end
        
        if ( pcb == 8 ) begin
            // terraf bootleg.  hack to deassert interrupt
            if ( z80_b_irq_n == 0 && z80_b_addr == 16'h0038 ) begin
                z80_b_irq_n <= 1;
            end
        end 
        
        if ( M1_b_n == 0 && IORQ_b_n == 0 && z80_b_irq_n == 0 ) begin
            // z80 acknowledged so deassert
            z80_b_irq_n <= 1;
        end
        

//        if ( clk_8M == 1 ) begin
//            int_ack <= ( m68k_as_n == 0 ) && ( m68k_fc == 3'b111 ); // cpu acknowledged the interrupt
//        end
        if ( vbl_sr == 2'b01 ) begin // rising edge
            // increment frame counter - used for flashing text
            nb1414m4_frame <= nb1414m4_frame + 1;
            //  68k vbl interrupt
            if ( pcb == 4 || pcb == 5 || pcb == 6 || pcb == 7 ) begin
                m68k_ipl1_n <= 0;
            end else begin
                m68k_ipl0_n <= 0;
            end
        end
    end

    // save-state restore
    if ( ss_misc_wr ) begin
        bg_scroll_x    <= ssm_bg_scroll_x;
        bg_scroll_y    <= ssm_bg_scroll_y;
        fg_scroll_x    <= ssm_fg_scroll_x;
        fg_scroll_y    <= ssm_fg_scroll_y;
        scroll_msb     <= ssm_scroll_msb;
        sound_latch    <= ssm_sound_latch;
        m68k_ipl0_n    <= ssm_ipl0_n;
        m68k_ipl1_n    <= ssm_ipl1_n;
        z80_b_irq_n    <= ssm_z80_b_irq_n;
        { flip_screen, bg_enable, fg_enable, sp_enable, tx_enable } <= ssm_layer_en;
        nb1414m4_frame <= ssm_nb_frame;
        dac1           <= ssm_dac1;
        dac2           <= ssm_dac2;
    end
    // blitter restarts idle
    if ( ss_restore_reset ) nb1414m4_busy <= 0;
end

wire has_nb1414m4 = ( pcb < 6 && pcb != 2 ) ;

// shared text ram write arbiter
reg shared_w;
reg [11:0] shared_addr;
reg  [7:0] shared_data;

// the text ram will need to be accessible from the 68k, bootleg z80, and nb1414m4
// need better arbitration

// for now hack in scrolling for nb1414m4

reg [7:0] nb_scroll_x_l;
reg [7:0] nb_scroll_x_h;
reg [7:0] nb_scroll_y_l;
reg [7:0] nb_scroll_y_h;

reg txt_ram_valid;

always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin
        nb1414m4_credits <= 0;
        nb1414m4_p1 <= 0;
    end else begin
        shared_w <= 0;
        
        // only 68k can read shared. the z80 is write only
        if ( clk_16M == 1 && m68k_txt_ram_cs & !m68k_lds_n ) begin
            shared_addr <= m68k_a[12:1];
            case ( m68k_a[12:1] )
                13'h00: nb1414m4_cmd[15:8] <= m68k_dout[7:0];
                13'h01: nb1414m4_cmd[7:0]  <= m68k_dout[7:0];
                13'h05: nb1414m4_p1[23:16] <= m68k_dout[7:0];
                13'h06: nb1414m4_p1[15:8]  <= m68k_dout[7:0];
                13'h07: nb1414m4_p1[7:0]   <= m68k_dout[7:0];
                13'h08: nb1414m4_p2[23:16] <= m68k_dout[7:0];
                13'h09: nb1414m4_p2[15:8]  <= m68k_dout[7:0];
                13'h0a: nb1414m4_p2[7:0]   <= m68k_dout[7:0];
                13'h0d: nb_scroll_x_l      <= m68k_dout[7:0];
                13'h0e: nb_scroll_x_h      <= m68k_dout[7:0];
                13'h0b: nb_scroll_y_l      <= m68k_dout[7:0];
                13'h0c: nb_scroll_y_h      <= m68k_dout[7:0];
            endcase

        end
        
        if ( has_nb1414m4 == 1 && nb1414m4_wr == 1 ) begin
            shared_addr <= nb1414m4_dst;
            shared_data <= nb1414m4_din;
            shared_w    <= 1;
            txt_ram_valid <= 0;
        end else if ( clk_16M == 1 && !m68k_rw && m68k_txt_ram_cs & !m68k_lds_n ) begin
            if ( m68k_a[23:0] == 24'h06801e ) begin
                nb1414m4_credits <= m68k_dout[7:0] ;
            end
            shared_data <= m68k_dout[7:0];
            // let the cpu know the write is done
            txt_ram_valid <= 1;
            shared_w <= 1;
        end else if (clk_4M == 1 && z80_b_ram_txt_cs & ~z80_b_wr_n) begin
            shared_addr <= z80_b_addr[11:0];
            shared_data <= z80_b_dout;
            txt_ram_valid <= 0;
            shared_w <= 1;
        end

        if ( ss_misc_wr ) begin
            nb1414m4_credits <= ssm_nb_credits;
            nb1414m4_p1      <= ssm_nb_p1;
            nb1414m4_p2      <= ssm_nb_p2;
            nb1414m4_cmd     <= ssm_nb_cmd;
            nb_scroll_x_l    <= ssm_nb_sxl;
            nb_scroll_x_h    <= ssm_nb_sxh;
            nb_scroll_y_l    <= ssm_nb_syl;
            nb_scroll_y_h    <= ssm_nb_syh;
        end
    end
end

wire    m68k_rom_cs;
wire    m68k_ram_cs;
wire    m68k_tile_pal_cs;
wire    m68k_txt_ram_cs;
wire    m68k_spr_cs;
wire    m68k_ram_2_cs;
wire    m68k_ram_3_cs;
wire    m68k_spr_pal_cs;
wire    m68k_fg_ram_cs;
wire    m68k_bg_ram_cs;
wire    input_p1_cs;
wire    input_p2_cs;
wire    input_dsw1_cs;
wire    input_dsw2_cs;
wire    irq_z80_cs;
wire    bg_scroll_x_cs;
wire    irq_i8751_cs;
wire    bg_scroll_y_cs;
wire    fg_scroll_x_cs;
wire    fg_scroll_y_cs;
wire    sound_latch_cs;
wire    irq_ack_cs;

wire z80_a_rom_cs;
wire z80_a_ram_cs;

wire z80_a_sound0_cs;
wire z80_a_sound1_cs;
wire z80_a_dac1_cs;
wire z80_a_dac2_cs;
wire z80_a_latch_clr_cs;
wire z80_a_latch_r_cs;
    
chip_select cs (
    .clk(clk_sys),
    .pcb(pcb),

    // 68k bus
    .m68k_a(m68k_a),
    .m68k_as_n(m68k_as_n),

    // 68k chip selects
    .m68k_rom_cs(m68k_rom_cs),
    .m68k_ram_cs(m68k_ram_cs),
    .m68k_tile_pal_cs(m68k_tile_pal_cs),
    .m68k_txt_ram_cs(m68k_txt_ram_cs),
    .m68k_spr_cs(m68k_spr_cs),
    .m68k_ram_2_cs(m68k_ram_2_cs),
    .m68k_ram_3_cs(m68k_ram_3_cs),
    .m68k_spr_pal_cs(m68k_spr_pal_cs),
    .m68k_fg_ram_cs(m68k_fg_ram_cs),
    .m68k_bg_ram_cs(m68k_bg_ram_cs),
    .input_p1_cs(input_p1_cs),
    .input_p2_cs(input_p2_cs),
    .input_dsw1_cs(input_dsw1_cs),
    .input_dsw2_cs(input_dsw2_cs),
    .irq_z80_cs(irq_z80_cs),
    .bg_scroll_x_cs(bg_scroll_x_cs),
    .bg_scroll_y_cs(bg_scroll_y_cs),
    .fg_scroll_x_cs(fg_scroll_x_cs),
    .fg_scroll_y_cs(fg_scroll_y_cs),
    .sound_latch_cs(sound_latch_cs),
    .irq_ack_cs(irq_ack_cs),
    .irq_i8751_cs(irq_i8751_cs),

    
    // sound z80 bus
    .z80_addr(z80_a_addr),
    .MREQ_n(MREQ_a_n),
    .IORQ_n(IORQ_a_n),
    .M1_n(M1_a_n),

    .z80_rom_cs(z80_a_rom_cs),
    .z80_ram_cs(z80_a_ram_cs),

    .z80_sound0_cs(z80_a_sound0_cs),
    .z80_sound1_cs(z80_a_sound1_cs),
    .z80_dac1_cs(z80_a_dac1_cs),
    .z80_dac2_cs(z80_a_dac2_cs),
    .z80_latch_clr_cs(z80_a_latch_clr_cs),
    .z80_latch_r_cs(z80_a_latch_r_cs)
);
 
wire terrafb_fg_scroll_msb_w = ( pcb == 9 && m68k_a[23:0] >= 24'h0c0000 && m68k_a[23:0] <= 24'h0c0001) & !m68k_as_n;
 
reg [15:0] bg_scroll_x;
reg [15:0] bg_scroll_y;

reg [7:0]  sound_latch;

// CPU outputs
wire m68k_rw         ;    // Read = 1, Write = 0
wire m68k_as_n       ;    // Address strobe
wire m68k_lds_n      ;    // Lower byte strobe
wire m68k_uds_n      ;    // Upper byte strobe
wire m68k_E;         
wire [2:0] m68k_fc    ;   // Processor state
wire m68k_reset_n_o  ;    // Reset output signal
wire m68k_halted_n   ;    // Halt output

// CPU busses
wire [15:0] m68k_dout       ;
wire [23:0] m68k_a   /* synthesis keep */       ;
reg  [15:0] m68k_din        ;   
//assign m68k_a[0] = 1'b0;

// CPU inputs
reg  m68k_dtack_n ;         // Data transfer ack (always ready)
reg  m68k_ipl0_n ;
reg  m68k_ipl1_n ;

wire reset_n;
// VPA is off only for the Sky Robo MCU latch read, so DTACK can hold it.
wire m68k_vpa_n = ( pcb == 3 ) && ( m68k_a[23:1] == 23'h200000 );

reg int_ack ;
reg [1:0] vbl_sr;

reg bg_enable;
reg fg_enable;
reg tx_enable;
reg sp_enable;

wire curr_line;

wire [9:0] sprite_y_adj = pcb_288 ? 10'd0 : 10'd128 ;

// armedf (2), cclimbr2 (4), legion (5,6,7)
// big fighter &  kozure (1) is 192 

wire [9:0] max_sprites = ( pcb == 0 || pcb == 8 || pcb == 9 ) ? 127 : (pcb == 1 || pcb == 3) ? 191 : 511;
reg  [9:0] sprite_count;

// Free-running vblank edge for the sprite-list copy.
reg  [1:0] spr_vbl_sr;
always @ (posedge clk_sys) spr_vbl_sr <= { spr_vbl_sr[0], vbl };

always @ (posedge clk_sys) begin
    //   copy sprite list to dedicated sprite list ram
    // start state machine for copy
    if ( copy_sprite_state == 0 && spr_vbl_sr == 2'b01 ) begin
        copy_sprite_state <= 1;    
        sprite_count <= 0;
    end else if ( copy_sprite_state == 1 ) begin
        sprite_shared_addr <= 0;
        copy_sprite_state <= 2;
        sprite_buffer_addr <= 0;
    end else if ( copy_sprite_state == 2 ) begin
        // address now 0
        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 3; 
    end else if ( copy_sprite_state == 3 ) begin        
       // address 0 result
        sprite_y_pos <= sprite_y_adj + y_adj + 239 - sprite_shared_ram_dout[8:0];
        sprite_pri   <= sprite_shared_ram_dout[13:12];
        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 4; 
    end else if ( copy_sprite_state == 4 ) begin    
        // address 1 result
        // tile #
        sprite_tile[11:0] <= sprite_shared_ram_dout[11:0];

        // flip y
        sprite_flip_y <= sprite_shared_ram_dout[12];

        // flip x
        sprite_flip_x <= sprite_shared_ram_dout[13];

        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 5; 
    end else if ( copy_sprite_state == 5 ) begin        
        // colour
        sprite_colour <= sprite_shared_ram_dout[12:8];
        sprite_spr_lut <= sprite_shared_ram_dout[6:0];
        
        sprite_shared_addr <= sprite_shared_addr + 1 ;

        copy_sprite_state <= 6; 
    end else if ( copy_sprite_state == 6 ) begin        
        sprite_x_pos <= sprite_shared_ram_dout[8:0] + 2 - tile_x_ofs ;
        
        copy_sprite_state <= 7; 
    end else if ( copy_sprite_state == 7 ) begin                
        sprite_buffer_w <= 1;
        sprite_buffer_din <= {sprite_tile,sprite_x_pos,sprite_y_pos,sprite_colour,sprite_spr_lut, sprite_flip_x,sprite_flip_y,sprite_pri};
        sprite_buffer_addr <= sprite_buffer_addr + 1;

        copy_sprite_state <= 8;
    end else if ( copy_sprite_state == 8 ) begin                
        sprite_count <= sprite_buffer_addr;
        // write is complete
        sprite_buffer_w <= 0;
        // sprite has been buffered.  are we done?
        if ( sprite_shared_addr[10:2] < max_sprites ) begin
            // start on next sprite
            copy_sprite_state <= 2;
        end else begin
            // we are done, go idle.  
            copy_sprite_state <= 0; 
        end
    // don't try to draw sprites while copying the buffer.
    end else if ( draw_sprite_state == 0 && hc >= 336 ) begin // off by one
    
        curr_line <= vc[0];
        // clear sprite buffer
        sprite_x_ofs <= 0;
        draw_sprite_state <= 1;
        sprite_buffer_addr <= 0;
        
        // enable writing
        sprite_fb_w <= 1;
        sprite_fb_addr_w <= { ~vc[0], 9'b0 };
        // set default to transparent value
        sprite_fb_din <= 15;
        
    end else if (draw_sprite_state == 1) begin

        sprite_fb_addr_w <= { ~vc[0], sprite_x_ofs }; 

        if ( sprite_x_ofs < 336 ) begin
            sprite_x_ofs <= sprite_x_ofs + 1;
        end else begin
            // done writing.  wait for start of next line
            sprite_fb_w <= 0;
            if ( curr_line != vc[0] ) begin
                // sprite buffer now blank
                draw_sprite_state <= 2;
            end
        end
    end else if (draw_sprite_state == 2) begin        
        // get current sprite attributes
        {sprite_tile,sprite_x_pos,sprite_y_pos,sprite_colour,sprite_spr_lut,sprite_flip_x,sprite_flip_y,sprite_pri} <= sprite_buffer_dout;
        draw_sprite_state <= 3;
        sprite_x_ofs <= 0;
    end else if (draw_sprite_state == 3) begin  
        sprite_fb_w <= 0;
        if ( sprite_pri != 3 && vc_spr >= sprite_y_pos && vc_spr < ( sprite_y_pos + 16 ) ) begin
            if ( sprite_x_ofs[2:0] == 0 ) begin  
                // fetch sprite bitmap 
                sprite_rom_addr <= { sprite_tile, flipped_y[3:0], flipped_x[3] };  
                sprite_rom_cs <= 1;
                
                draw_sprite_state <= 4;
            end else begin
                draw_sprite_state <= 5;
            end
        end else begin
            draw_sprite_state <= 7;
        end
    end else if (draw_sprite_state == 4) begin
    
        // wait for bitmap read to complete
        if ( sprite_rom_valid == 1 ) begin
            // bitmap is only valid for one clock.  latch it.
            sprite_data <= sprite_rom_data;
            sprite_rom_cs <= 0;
            
            draw_sprite_state <= 5;
        end
    end else if (draw_sprite_state == 5) begin   
        // need a clock cycle to read the sprite palette lut
        draw_sprite_state <= 6;
    end else if (draw_sprite_state == 6) begin       
        draw_sprite_state <= 3; 
        sprite_fb_w <= 0;

        if ( spr_pal_dout[3:0] != 15 && sprite_x_pos[8:0] < 336 ) begin // spr_pix

            sprite_fb_w <= 1;
            // 0-511 = even line / 512-1023 = odd line
            sprite_fb_addr_w <= { vc[0], sprite_x_pos[8:0] } ;
            sprite_fb_din    <= { sprite_colour[4:0],spr_pal_dout[3:0],sprite_pri[1:0] }; 

        end
        
        if ( sprite_x_ofs < 15 ) begin
            sprite_x_pos <= sprite_x_pos + 1;
            sprite_x_ofs <= sprite_x_ofs + 1;
        end else begin
            draw_sprite_state <= 7;
        end
    end else if (draw_sprite_state == 7) begin                        
        // done. next sprite
        if ( sprite_buffer_addr < sprite_count ) begin
            sprite_buffer_addr <= sprite_buffer_addr + 1;
            draw_sprite_state <= 2;
        end else begin
            // all sprites done
            draw_sprite_state <= 8;
        end
    end else if (draw_sprite_state == 8) begin                        
        // we are done. wait for end of line
//        if ( hc == 0 ) begin
            draw_sprite_state <= 0;
//        end
    end
end

wire [10:0] spr_pal_addr = { sprite_spr_lut, spr_pix };  // [10:0]

wire [3:0] spr_pix ;
always @ (*) begin
    case ( flipped_x[2:0] ) 
            3'b000: spr_pix <= sprite_data[27:24]  ;
            3'b001: spr_pix <= sprite_data[31:28]  ;
            3'b010: spr_pix <= sprite_data[19:16] ;
            3'b011: spr_pix <= sprite_data[23:20] ;
            3'b100: spr_pix <= sprite_data[11:8]  ;
            3'b101: spr_pix <= sprite_data[15:12] ;
            3'b110: spr_pix <= sprite_data[3:0]   ;
            3'b111: spr_pix <= sprite_data[7:4]   ;
    endcase  
end        
        
reg   [5:0] spr_pal_idx;
reg  [31:0] sprite_data;

wire  [3:0] sprite_y_ofs = vc_spr - sprite_y_pos ;

wire  [3:0] flipped_x = ( sprite_flip_x == 0 ) ? sprite_x_ofs : 15 - sprite_x_ofs;
wire  [3:0] flipped_y = ( sprite_flip_y == 0 ) ? sprite_y_ofs : 15 - sprite_y_ofs;

reg  [10:0] sprite_shared_addr;
wire [15:0] sprite_shared_ram_dout;

reg   [3:0] copy_sprite_state;
reg   [3:0] draw_sprite_state;

reg   [1:0] sprite_pri;
reg   [8:0] sprite_x_ofs;
reg   [9:0] sprite_idx;
reg  [11:0] sprite_tile ;  
reg   [8:0] sprite_y_pos;
reg   [8:0] sprite_x_pos;
reg   [4:0] sprite_colour;
reg   [6:0] sprite_spr_lut;

reg   sprite_x_256;
reg   sprite_flip_x;
reg   sprite_flip_y;

// fx68k clock generation
reg fx68_phi1;

always @(posedge clk_sys) begin
    if ( clk_16M == 1 ) begin
        fx68_phi1 <= ~fx68_phi1;
    end
end

fx68k fx68k (
    // clk_sys with phase enables
    .clk( clk_sys ),
    .HALTn( 1'b1 ),
    .enPhi1( ce_16m &  fx68_phi1 ),
    .enPhi2( ce_16m & ~fx68_phi1 ),

    .extReset(reset | ss_reset_68k),
    .pwrUp(reset | ss_reset_68k),

    // output
    .eRWn(m68k_rw),
    .ASn( m68k_as_n),
    .LDSn(m68k_lds_n),
    .UDSn(m68k_uds_n),
    .E(),
    .VMAn(),
    .FC0(m68k_fc[0]),
    .FC1(m68k_fc[1]),
    .FC2(m68k_fc[2]),
    .BGn(),
    .oRESETn(m68k_reset_n_o),
    .oHALTEDn(m68k_halted_n),

    // input
    .VPAn( m68k_vpa_n ),  
    .DTACKn( m68k_dtack_n ),     
    .BERRn(1'b1), 
    .BRn(1'b1),  
    .BGACKn(1'b1),
    
    .IPL0n(ss_irq ? 1'b0 : m68k_ipl0_n),   // save state: level 7
    .IPL1n(ss_irq ? 1'b0 : m68k_ipl1_n),
    .IPL2n(ss_irq ? 1'b0 : 1'b1),

    // busses
    .iEdb(m68k_din),
    .oEdb(m68k_dout),
    .eab(m68k_a[23:1])
);


// z80 audio 
wire    [7:0] z80_a_rom_data;
wire    [7:0] z80_a_ram_data;

wire   [15:0] z80_a_addr;
reg     [7:0] z80_a_din;
wire    [7:0] z80_a_dout;

wire z80_a_wr_n;
wire z80_a_rd_n;
reg  z80_a_wait_n;
reg  z80_a_irq_n;

wire IORQ_a_n;
wire MREQ_a_n;
wire M1_a_n;

T80pa z80_a (
    .RESET_n    ( ~(reset | ss_z80_reset) ),
    .CLK        ( clk_sys ),
    .CEN_p      (  clk_4M & ~z80a_hold & snd_run ),
    .CEN_n      ( ~clk_4M & ~z80a_hold & snd_run ),
    .WAIT_n     ( z80_a_wait_n ), 
    .INT_n      ( z80_a_irq_n ),  
    .NMI_n      ( 1'b1 ),
    .BUSRQ_n    ( 1'b1 ),
    .RD_n       ( z80_a_rd_n ),
    .WR_n       ( z80_a_wr_n ),
    .A          ( z80_a_addr ),
    .DI         ( z80_a_din  ),
    .DO         ( z80_a_dout ),
    // unused
    .DIRSET     ( ss_z80_dirset ),
    .DIR        ( z80a_dir ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     ( IORQ_a_n ),
    .M1_n       ( M1_a_n ), // for interrupt ack
    .BUSAK_n    (),
    .HALT_n     ( 1'b1 ),
    .MREQ_n     ( MREQ_a_n ),
    .REG        ( z80a_reg )
);

// z80 bootleg
wire    [7:0] z80_b_rom_data;
wire    [7:0] z80_b_ram_dout;

wire   [15:0] z80_b_addr;
reg     [7:0] z80_b_din;
wire    [7:0] z80_b_dout;

wire z80_b_wr_n;
wire z80_b_rd_n;
reg  z80_b_wait_n;
reg  z80_b_irq_n;

wire IORQ_b_n;
wire MREQ_b_n;
wire M1_b_n;

reg [9:0] fg_scroll_x;
reg [9:0] fg_scroll_y;

T80pa z80_b (
    .RESET_n    ( ~(reset | ss_z80_reset) & (pcb == 8) ),  // don't run if no bootleg cpu
    .CLK        ( clk_sys ),
    .CEN_p      (  clk_4M & ~z80b_hold ),
    .CEN_n      ( ~clk_4M & ~z80b_hold ),
    .WAIT_n     ( z80_b_wait_n ), // wait?
    .INT_n      ( z80_b_irq_n ),  // from 68k 7c000
    .NMI_n      ( 1'b1 ),
    .BUSRQ_n    ( 1'b1 ),
    .RD_n       ( z80_b_rd_n ),
    .WR_n       ( z80_b_wr_n ),
    .A          ( z80_b_addr ),
    .DI         ( z80_b_din  ),
    .DO         ( z80_b_dout ),
    // unused
    .DIRSET     ( ss_z80_dirset ),
    .DIR        ( z80b_dir ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     ( IORQ_b_n ),
    .M1_n       ( M1_b_n ), // for interrupt ack
    .BUSAK_n    (),
    .HALT_n     ( 1'b1 ),
    .MREQ_n     ( MREQ_b_n ),
    .REG        ( z80b_reg )
);


// bootleg protection hack 16k
wire z80_b_rom_cs          = ( MREQ_b_n == 0 && z80_b_addr[15:0]  < 16'h4000 );
// shared ram 4k
wire z80_b_ram_txt_cs      = ( MREQ_b_n == 0 && z80_b_addr[15:0] >= 16'h4000 && z80_b_addr[15:0] < 16'h5000);
// 4k
wire z80_b_ram_1_cs        = ( MREQ_b_n == 0 && z80_b_addr[15:0] >= 16'h5000 && z80_b_addr[15:0] < 16'h6000);
// 2k
wire z80_b_ram_2_cs        = ( MREQ_b_n == 0 && z80_b_addr[15:0] >= 16'h8000 && z80_b_addr[15:0] < 16'h8800);

wire z80_b_fg_scroll_x_cs   = ( IORQ_b_n == 0 && z80_b_addr[7:0] == 8'h00 );
wire z80_b_fg_scroll_y_cs   = ( IORQ_b_n == 0 && z80_b_addr[7:0] == 8'h01 );
wire z80_b_fg_scroll_msb_cs = ( IORQ_b_n == 0 && z80_b_addr[7:0] == 8'h02 );

/// I8751 MCU
wire [15:0] i8751_addr;
wire [15:0] i8751_ram_addr;
wire        i8751_ram_wr;
wire [7:0]  i8751_ram_dout;
wire [7:0]  i8751_rom_data;
wire [7:0]  i8751_shared_ram_data_h ;
wire [7:0]  i8751_shared_ram_data_l ;

// Each 68K read of the MCU latch (0x400000) requests INT0.
wire [7:0] i8751_p0_o, i8751_p1_o, i8751_p2_o, i8751_p3_o;
wire       i8751_x_quiet;
reg        irq_i8751_cs_d;
always @(posedge clk_sys) irq_i8751_cs_d <= irq_i8751_cs;
wire       i8751_int0_req = irq_i8751_cs & ~irq_i8751_cs_d;
wire       i8751_int0_busy;

i8751 i8751
(
    .clk( clk_sys ),
    .rst( reset | ss_mcu_reset ),
    .cen( clk_8M ),   // 8 MHz oscillator enable

    .int0_req( i8751_int0_req ),
    .int0_busy( i8751_int0_busy ),
    .freeze( ss_mcu_freeze ),
    .idle_addr( 16'h0129 ),   // firmware idle loop
    .idle( i8751_idle ),

    .p0_i( 8'hdf ),
    .p1_i( 8'hdf ),
    .p2_i( 8'h00 ),
    .p3_i( 8'h00 ),
    .p0_o( i8751_p0_o ),
    .p1_o( i8751_p1_o ),
    .p2_o( i8751_p2_o ),
    .p3_o( i8751_p3_o ),

    // 68K main RAM, port B
    .x_addr( i8751_ram_addr ),
    .x_dout( i8751_ram_dout ),
    .x_wr( i8751_ram_wr ),
    .x_din( ( i8751_ram_addr[0] == 0 ) ? i8751_shared_ram_data_h : i8751_shared_ram_data_l ),
    .x_quiet( i8751_x_quiet ),

    // ROM programming
    .prog_addr( ioctl_addr[11:0] ),
    .prog_din( ioctl_dout ),
    .prog_we( i8751_ioctl_wr ),

    // internal RAM port for save states
    .iram_ext_en( 1'b0 ),
    .iram_ext_addr( 7'd0 ),
    .iram_ext_din( 8'd0 ),
    .iram_ext_we( 1'b0 ),
    .iram_ext_dout( )
);
   
reg sound_addr ;
reg  [7:0] sound_data ;

// sound ic write enable
reg sound_wr;

wire [7:0] opl_dout;
wire opl_irq_n;

reg signed [15:0] sample;

assign AUDIO_S = 1'b1 ;

wire opl_sample_clk;

jtopl #(.OPL_TYPE(2)) opl
(
    .rst(reset),
    .clk(clk_sys),
    .cen( ce_4m & snd_run ),
    .din( opl_replay ? opl_rp_d  : sound_data ),
    .addr( opl_replay ? opl_rp_a0 : sound_addr ),
    .cs_n( opl_replay ? ~opl_rp_we : ~( z80_a_sound0_cs | z80_a_sound1_cs ) ),
    .wr_n( opl_replay ? ~opl_rp_we : ~sound_wr ),
    .dout(opl_dout),
    .irq_n(opl_irq_n),
    .snd(sample),
    .sample(opl_sample_clk)
);

always @ * begin
    // mix audio
    AUDIO_L <= sample + ($signed({ ~dac1[7], dac1[6:0], 8'b0 }) >>> 1) + ($signed({ ~dac2[7], dac2[6:0], 8'b0 }) >>> 1) ;
    AUDIO_R <= sample + ($signed({ ~dac1[7], dac1[6:0], 8'b0 }) >>> 1) + ($signed({ ~dac2[7], dac2[6:0], 8'b0 }) >>> 1) ;
end

reg [7:0] dac1;
reg [7:0] dac2;

wire [7:0] z80_b_ram_txt_dout;
wire [7:0] z80_b_ram_1_dout;
wire [7:0] z80_b_ram_2_dout;

reg [16:0] gfx1_addr;
reg [17:0] gfx2_addr;
reg [16:0] gfx3_addr;
reg [16:0] gfx4_addr;

reg [7:0] gfx1_dout;
reg [7:0] gfx2_dout;
reg [7:0] gfx3_dout;
reg [7:0] gfx4_dout;

wire [15:0] ram68k_dout;
wire [15:0] ram68k_sprite_dout;
wire [15:0] m68k_tile_pal_dout;

//wire [15:0] prog_rom_data;

// ioctl download addressing    
wire rom_download = ioctl_download && (ioctl_index==0);

// fg len 0x30000 192k
wire gfx2_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >= 24'h080000) & (ioctl_addr < 24'h0b0000) ;

// bg len 0x20000 128k
wire gfx3_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >= 24'h0c0000) & (ioctl_addr < 24'h0e0000) ;

// sprites
//wire gfx4_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >= 24'h100000) & (ioctl_addr < 24'h140000) ;

// text
wire gfx1_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >= 24'h140000) & (ioctl_addr < 24'h148000) ;

//wire z80_a_rom_ioctl_wr  = rom_download & ioctl_wr & (ioctl_addr >= 24'h150000) & (ioctl_addr < 24'h160000) ;
wire z80_b_rom_ioctl_wr  = rom_download & ioctl_wr & (ioctl_addr >= 24'h160000) & (ioctl_addr < 24'h164000) ;

//wire prom_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >= 24'h104000) & (ioctl_addr < 24'h0f4100) ;

wire i8751_ioctl_wr      = rom_download & ioctl_wr & (ioctl_addr >= 24'h170000) & (ioctl_addr < 24'h171000) ;
wire nb1414m4_ioctl_wr   = rom_download & ioctl_wr & (ioctl_addr >= 24'h180000) & (ioctl_addr < 24'h184000) ;

// High scores, through main work RAM port B.
wire        hs_present, hs_active;
wire        hs_ram_en, hs_ram_we;
wire [23:0] hs_ram_addr;
wire  [7:0] hs_ram_wdata;
wire  [7:0] hs_ram_rdata = hs_ram_addr[0] ? i8751_shared_ram_data_l : i8751_shared_ram_data_h;

reg save_hs_d;
always @(posedge clk_sys) save_hs_d <= status[70];

hiscore hiscore
(
    .clk( clk_sys ),
    .reset( reset ),

    .ioctl_download( ioctl_download ),
    .ioctl_upload( ioctl_upload ),
    .ioctl_wr( ioctl_wr ),
    .ioctl_index( ioctl_index ),
    .ioctl_addr( ioctl_addr ),
    .ioctl_dout( ioctl_dout ),
    .ioctl_din( ioctl_din ),
    .ioctl_upload_req( ioctl_upload_req ),

    .vblank( vbl ),
    .osd_open( OSD_STATUS ),
    .autosave( ~status[69] ),
    .save_now( status[70] & ~save_hs_d ),

    .present( hs_present ),
    .active( hs_active ),

    .ram_en( hs_ram_en ),
    .ram_addr( hs_ram_addr ),
    .ram_wdata( hs_ram_wdata ),
    .ram_we( hs_ram_we ),
    .ram_rdata( hs_ram_rdata ),
    .ram_grant( pcb != 3 || i8751_x_quiet )   // shared with the Sky Robo MCU
);

wire [12:0] ramb_addr = hs_ram_en ? hs_ram_addr[13:1] : i8751_ram_addr[13:1];
wire  [7:0] ramb_din  = hs_ram_en ? hs_ram_wdata      : i8751_ram_dout;
wire        mcu_we_ok = i8751_ram_wr & ( i8751_ram_addr >= 16'h600 );
wire        ramb_we_h = hs_ram_en ? ( hs_ram_we & ~hs_ram_addr[0] ) : ( mcu_we_ok & ~i8751_ram_addr[0] );
wire        ramb_we_l = hs_ram_en ? ( hs_ram_we &  hs_ram_addr[0] ) : ( mcu_we_ok &  i8751_ram_addr[0] );

// main 68k ram high    
dual_port_ram #(.LEN(8192)) ram8kx8_H (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_main_act ),
    .address_a ( ssr_main_addr ),
    .wren_a ( ssr_main_we[1] ),
    .data_a ( ssr_main_data[15:8] ),
    .q_a (  ram68k_dout[15:8] ) ,
    
    .clock_b ( clk_sys ),   // i8751 or hiscore
    .address_b ( ramb_addr ),
    .wren_b ( ramb_we_h ),
    .data_b ( ramb_din ),
    .q_b ( i8751_shared_ram_data_h )
    );

// main 68k ram low     
dual_port_ram #(.LEN(8192)) ram8kx8_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_main_act ),
    .address_a ( ssr_main_addr ),
    .wren_a ( ssr_main_we[0] ),
    .data_a ( ssr_main_data[7:0] ),
    .q_a ( ram68k_dout[7:0] ) ,
    
    .clock_b ( clk_sys ),   // i8751 or hiscore
    .address_b ( ramb_addr ),
    .wren_b ( ramb_we_l ),
    .data_b ( ramb_din ),
    .q_b ( i8751_shared_ram_data_l )
    );
//        .x_din( ( i8751_ram_addr[0] == 0 ) ? i8751_shared_ram_data_h : i8751_shared_ram_data_l ),
// main 68k sprite ram high  
// 2kx16
dual_port_ram #(.LEN(2048)) sprite_ram_H (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_spr_act ),
    .address_a ( ssr_spr_addr ),
    .wren_a ( ssr_spr_we[1] ),
    .data_a ( ssr_spr_data[15:8] ),
    .q_a (  ram68k_sprite_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( sprite_shared_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( sprite_shared_ram_dout[15:8] )
    
    );

// main 68k sprite ram low     
dual_port_ram #(.LEN(2048)) sprite_ram_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_spr_act ),
    .address_a ( ssr_spr_addr ),
    .wren_a ( ssr_spr_we[0] ),
    .data_a ( ssr_spr_data[7:0] ),
    .q_a ( ram68k_sprite_dout[7:0] ),
     
    .clock_b ( clk_sys ),
    .address_b ( sprite_shared_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( sprite_shared_ram_dout[7:0] )
    );

//    .clock_a ( clk_8M ),
//    .address_a ( i8751_ram_addr[13:0] ),
//    .wren_a ( i8751_ram_wr ),
//    .data_a ( i8751_ram_dout ),
//    .q_a ( i8751_shared_ram_data ),
    
reg  [10:0] fg_ram_addr;
wire [15:0] fg_ram_dout;

reg  [10:0] bg_ram_addr;
wire [15:0] bg_ram_dout;


wire [15:0] m68k_fg_ram_dout;

// foreground high   
dual_port_ram #(.LEN(2048)) ram_fg_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_fg_act ),
    .address_a ( ssr_fg_addr ),
    .wren_a ( ssr_fg_we[1] ),
    .data_a ( ssr_fg_data[15:8] ),
    .q_a ( m68k_fg_ram_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( fg_ram_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( fg_ram_dout[15:8] )
    
    );

// foreground low
dual_port_ram #(.LEN(2048)) ram_fg_l (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_fg_act ),
    .address_a ( ssr_fg_addr ),
    .wren_a ( ssr_fg_we[0] ),
    .data_a ( ssr_fg_data[7:0] ),
    .q_a ( m68k_fg_ram_dout[7:0] ),
     
    .clock_b ( clk_sys ),
    .address_b ( fg_ram_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( fg_ram_dout[7:0] )
    );
    
wire [15:0] m68k_bg_ram_dout;
    
// background high
dual_port_ram #(.LEN(2048)) ram_bg_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_bg_act ),
    .address_a ( ssr_bg_addr ),
    .wren_a ( ssr_bg_we[1] ),
    .data_a ( ssr_bg_data[15:8] ),
    .q_a ( m68k_bg_ram_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( bg_ram_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( bg_ram_dout[15:8] )
    
    );

// background low    
dual_port_ram #(.LEN(2048)) ram_fg_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_bg_act ),
    .address_a ( ssr_bg_addr ),
    .wren_a ( ssr_bg_we[0] ),
    .data_a ( ssr_bg_data[7:0] ),
    .q_a ( m68k_bg_ram_dout[7:0] ),
     
    .clock_b ( clk_sys ),
    .address_b ( bg_ram_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( bg_ram_dout[7:0] )
    );    
    
reg [15:0] tile_pal_dout;
reg [10:0] tile_pal_addr;
    
// tile palette high   
dual_port_ram #(.LEN(2048)) tile_pal_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_tpal_act ),
    .address_a ( ssr_tpal_addr ),
    .wren_a ( ssr_tpal_we[1] ),
    .data_a ( ssr_tpal_data[15:8] ),
    .q_a ( m68k_tile_pal_dout[15:8]  ),

    .clock_b ( clk_sys ),
    .address_b ( tile_pal_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( tile_pal_dout[15:8] )
    );

//  tile palette low
dual_port_ram #(.LEN(2048)) tile_pal_l (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_tpal_act ),
    .address_a ( ssr_tpal_addr ),
    .wren_a ( ssr_tpal_we[0] ),
    .data_a ( ssr_tpal_data[7:0] ),
    .q_a ( m68k_tile_pal_dout[7:0] ),
     
    .clock_b ( clk_sys ),
    .address_b ( tile_pal_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( tile_pal_dout[7:0] )
    );    
    
wire [15:0] spr_pal_dout ;
wire [15:0] m68k_spr_pal_dout ;


// sprite pal lut high
dual_port_ram #(.LEN(2048)) spr_pal_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_spal_act ),
    .address_a ( ssr_spal_addr ),
    .wren_a ( ssr_spal_we[1] ),
    .data_a ( ssr_spal_data[15:8] ),
    .q_a ( m68k_spr_pal_dout[15:8] ),

    .clock_b ( clk_sys ),
    .address_b ( spr_pal_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( spr_pal_dout[15:8] )
    
    );

// sprite pal lut high
dual_port_ram #(.LEN(2048)) spr_pal_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_spal_act ),
    .address_a ( ssr_spal_addr ),
    .wren_a ( ssr_spal_we[0] ),
    .data_a ( ssr_spal_data[7:0] ),
    .q_a (m68k_spr_pal_dout[7:0]),
     
    .clock_b ( clk_sys ),
    .address_b ( spr_pal_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( spr_pal_dout[7:0] )
    ); 

reg  [8:0]  sprite_buffer_addr;  // 128 sprites
reg  [63:0] sprite_buffer_din;
wire [63:0] sprite_buffer_dout;
reg  sprite_buffer_w;

dual_port_ram #(.LEN(512), .DATA_WIDTH(64)) sprite_buffer (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buffer_addr ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( sprite_buffer_dout ),
    
    .clock_b ( clk_sys ),
    .address_b ( sprite_buffer_addr ),
    .wren_b ( sprite_buffer_w ),
    .data_b ( sprite_buffer_din  ),
    .q_b( )

    );
    
reg          sprite_fb_w;
reg   [9:0]  sprite_fb_addr_w;
reg  [15:0]  sprite_fb_din;
wire [15:0]  sprite_fb_out;
reg   [9:0]  sprite_fb_addr_r ; 
    
// two line buffer for sprite rendering
dual_port_ram #(.LEN(1024), .DATA_WIDTH(16)) sprite_line_buffer_ram (
    .clock_a ( clk_sys ),
    .address_a ( sprite_fb_addr_w ),
    .wren_a ( sprite_fb_w ),
    .data_a ( sprite_fb_din ),
    .q_a ( ),

    .clock_b ( clk_sys ),
    .clken_b ( ce_6m ),
    .address_b ( sprite_fb_addr_r ),  
    .wren_b ( 0 ),
//    .data_b ( ),
    .q_b ( sprite_fb_out )
    );    
    
// m68_ram_2_cs

wire [15:0] m68k_ram_2_dout ;
wire [15:0] m68k_ram_3_dout ;

// 68k ram 2
dual_port_ram #(.LEN(4096)) ram_2_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_ram2_act ),
    .address_a ( ssr_ram2_addr ),
    .wren_a ( ssr_ram2_we[1] ),
    .data_a ( ssr_ram2_data[15:8] ),
    .q_a ( m68k_ram_2_dout[15:8] )

    );

// 68k ram 2
dual_port_ram #(.LEN(4096)) ram_2_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_ram2_act ),
    .address_a ( ssr_ram2_addr ),
    .wren_a ( ssr_ram2_we[0] ),
    .data_a ( ssr_ram2_data[7:0] ),
    .q_a ( m68k_ram_2_dout[7:0] )
     
    ); 

// 68k ram 3
dual_port_ram #(.LEN(4096)) ram_3_h (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_ram3_act ),
    .address_a ( ssr_ram3_addr ),
    .wren_a ( ssr_ram3_we[1] ),
    .data_a ( ssr_ram3_data[15:8] ),
    .q_a ( m68k_ram_3_dout[15:8] )

    );

// 68k ram 3
dual_port_ram #(.LEN(4096)) ram_3_L (
    .clock_a ( clk_sys ),
    .clken_a ( ce_16m | ssr_ram3_act ),
    .address_a ( ssr_ram3_addr ),
    .wren_a ( ssr_ram3_we[0] ),
    .data_a ( ssr_ram3_data[7:0] ),
    .q_a ( m68k_ram_3_dout[7:0] )
     
    );    
   
wire [7:0] txt_ram_dout ;
wire [15:0] m68k_txt_ram_dout ;
reg  [12:0] txt_ram_addr ;

dual_port_ram #(.LEN(2048)) z80_a_ram (
    .clock_a ( clk_sys ),
    .clken_a ( ce_4m | ssr_z80a_act ),
    .address_a ( ssr_z80a_addr ),
    .wren_a ( ssr_z80a_we ),
    .data_a ( ssr_z80a_data ),
    .q_a ( z80_a_ram_data )

    );
    
dual_port_ram #(.LEN(16384)) z80_b_rom (
    .clock_a ( clk_sys ),
    .clken_a ( ce_4m ),
    .address_a ( z80_b_addr[13:0] ),
    .wren_a ( z80_b_rom_cs & ~z80_b_wr_n ),
    .data_a ( ),
    .q_a ( z80_b_rom_data ),

    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[13:0] ),
    .wren_b ( z80_b_rom_ioctl_wr ),
    .data_b ( ioctl_dout ),
    .q_b(  )
    );

reg  [11:0] gfx_txt_addr;
wire  [7:0] gfx_txt_dout;

reg  [11:0] gfx_txt_attr_addr;
wire  [7:0] gfx_txt_attr_dout;

wire [15:0] m68k_txt_attr_ram_dout;


// 4 port ram - should figure out real abritration method
dual_port_ram #(.LEN(4096)) txt_ram_0 (
    // 68k read and write txt ram
    .clock_a ( clk_sys ),
    .address_a ( ssr_txt_addr ),
    .wren_a ( ssr_txt_we ),
    .data_a ( ssr_txt_data ),
    .q_a ( m68k_txt_attr_ram_dout[7:0] ),
    
    // tile render read txt tile #
    .clock_b ( clk_sys ),
    .address_b ( gfx_txt_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( gfx_txt_dout[7:0] )
    );
    
// shadow to allow z80 to read
dual_port_ram #(.LEN(4096)) txt_ram_1 (
    .clock_a ( clk_sys ),
    .address_a ( ssr_txt_addr ),
    .wren_a ( ssr_txt_we ),
    .data_a ( ssr_txt_data ),
    .q_a (  ),
    
    // z80 read and write txt ram
    .clock_b ( clk_sys ),
    .address_b ( z80_b_addr[11:0]  ),
    .wren_b ( 1'b0 ),
    .data_b (  ),
    .q_b( z80_b_ram_txt_dout[7:0]  )
    );
    
// shadow for text attribute    
dual_port_ram #(.LEN(4096)) txt_ram_2 (
    .clock_a ( clk_sys ),
    .address_a ( ssr_txt_addr ),
    .wren_a ( ssr_txt_we ),
    .data_a ( ssr_txt_data ),
    .q_a (),
    
    // tile render read txt tile attr
    .clock_b ( clk_sys ),
    .address_b ( gfx_txt_attr_addr ),  
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( gfx_txt_attr_dout[7:0] )
    );
    
// z80 protection ram 1  
dual_port_ram #(.LEN(4096)) z80_b_ram_1 (
    .clock_b ( clk_sys ),
    .clken_b ( ce_4m | ssr_z80b1_act ),
    .address_b ( ssr_z80b1_addr ),
    .wren_b ( ssr_z80b1_we ),
    .data_b ( ssr_z80b1_data ),
    .q_b ( z80_b_ram_1_dout )
    );

// z80 protection ram 1  
dual_port_ram #(.LEN(2048)) z80_b_ram_2 (
    .clock_b ( clk_sys ),
    .clken_b ( ce_4m | ssr_z80b2_act ),
    .address_b ( ssr_z80b2_addr ),
    .wren_b ( ssr_z80b2_we ),
    .data_b ( ssr_z80b2_data ),
    .q_b ( z80_b_ram_2_dout )
    );

    
//  <!-- gfx1       0x020000-0x021fff 8K -->
dual_port_ram #(.LEN(32768)) gfx1 (
    .clock_a ( clk_sys ),
    .clken_a ( ce_6m ),
    .address_a ( gfx1_addr[14:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx1_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[14:0] ),
    .wren_b ( gfx1_ioctl_wr ),
    .data_b ( ioctl_dout ),
    .q_b( )
    );

dual_port_ram #(.LEN(196608)) gfx2 (
    .clock_a ( clk_sys ),
    .clken_a ( ce_6m ),
    .address_a ( gfx2_addr[17:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx2_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[17:0] ),
    .wren_b ( gfx2_ioctl_wr ),
    .data_b ( ioctl_dout ),
    .q_b( )
    );

dual_port_ram #(.LEN(131072)) gfx3 (
    .clock_a ( clk_sys ),
    .clken_a ( ce_6m ),
    .address_a ( gfx3_addr[16:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx3_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[16:0] ),
    .wren_b ( gfx3_ioctl_wr ),
    .data_b ( ioctl_dout ),
    .q_b( )
    );
   
wire [15:0] m68k_rom_data;
wire m68k_rom_valid;

reg  [17:0] sprite_rom_addr;
wire [31:0] sprite_rom_data;
reg sprite_rom_cs;
wire sprite_rom_valid;

wire z80_a_rom_valid;

//wire        prog_cache_rom_cs;
//wire [22:0] prog_cache_addr;
//wire [15:0] prog_cache_data;
//wire        prog_cache_valid;
//
//wire [15:0] prog_rom_data;
//wire        prog_rom_data_valid;

    // is a oe needed?
rom_controller rom_controller 
(
    .reset(reset),

    // clock
    .clk(clk_sys),

    // program ROM interface
    .prog_rom_cs(m68k_rom_cs),
    .prog_rom_oe(1),
    .prog_rom_addr(m68k_a[23:1]),
    .prog_rom_data(m68k_rom_data),
    .prog_rom_data_valid(m68k_rom_valid),
    
    // program ROM interface
//    .prog_rom_cs(prog_cache_rom_cs),
//    .prog_rom_oe(1),
//    .prog_rom_addr(prog_cache_addr),
//    .prog_rom_data(prog_cache_data),
//    .prog_rom_data_valid(prog_cache_valid),

    // sprite ROM interface
    .sprite_rom_cs(sprite_rom_cs),
    .sprite_rom_oe(1),
    .sprite_rom_addr(sprite_rom_addr),
    .sprite_rom_data(sprite_rom_data),
    .sprite_rom_data_valid(sprite_rom_valid),
    
    // sound ROM #1 interface
    .sound_rom_cs(z80_a_rom_cs),
    .sound_rom_oe(1),
    .sound_rom_addr(z80_a_addr),
    .sound_rom_data(z80_a_rom_data),
    .sound_rom_data_valid(z80_a_rom_valid),    

    // IOCTL interface
    .ioctl_addr(ioctl_addr),
    .ioctl_data(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_download(rom_download),   // ROM downloads only

    // SDRAM interface
    .sdram_addr(sdram_addr),
    .sdram_data(sdram_data),
    .sdram_we(sdram_we),
    .sdram_req(sdram_req),
    .sdram_ack(sdram_ack),
    .sdram_valid(sdram_valid),
    .sdram_q(sdram_q)
  );

//cache prog_cache
//(
//    .reset(reset),
//    .clk(clk_sys),
//
//    // client
//    .cache_req(m68k_rom_cs),
//    .cache_addr(m68k_a[23:1]),
//    .cache_valid(m68k_rom_valid),
//    .cache_data(m68k_rom_data),
//
//    // to rom controller
//    .rom_req(prog_cache_rom_cs),
//    .rom_addr(prog_cache_addr),
//    .rom_valid(prog_cache_valid),
//    .rom_data(prog_cache_data)
//
//); 
    
reg  [22:0] sdram_addr;
reg  [31:0] sdram_data;
reg         sdram_we;
reg         sdram_req;

wire        sdram_ack;
wire        sdram_valid;
wire [31:0] sdram_q;

sdram #(.CLK_FREQ( (CLKSYS+0.0))) sdram
(
  .reset(~pll_locked),
  .clk(clk_sys),

  // controller interface
  .addr(sdram_addr),
  .data(sdram_data),
  .we(sdram_we),
  .req(sdram_req),
  
  .ack(sdram_ack),
  .valid(sdram_valid),
  .q(sdram_q),

  // SDRAM interface
  .sdram_a(SDRAM_A),
  .sdram_ba(SDRAM_BA),
  .sdram_dq(SDRAM_DQ),
  .sdram_cke(SDRAM_CKE),
  .sdram_cs_n(SDRAM_nCS),
  .sdram_ras_n(SDRAM_nRAS),
  .sdram_cas_n(SDRAM_nCAS),
  .sdram_we_n(SDRAM_nWE),
  .sdram_dqml(SDRAM_DQML),
  .sdram_dqmh(SDRAM_DQMH)
);    
    

// Save states: CPU registers, RAM and board registers.

// DDR / chunk bus
ssbus_if ssbus();
ssbus_if ssb[SSIDX_COUNT]();

ssbus_mux #(.COUNT(SSIDX_COUNT)) ss_mux (
    .clk( clk_sys ),
    .slave( ssbus ),
    .masters( ssb )
);

wire [1:0] ss_slot;
wire       ss_status_set, ss_info_req;
wire [7:0] ss_info;
wire       ss_ui_save, ss_ui_load;
reg        ss_write = 0, ss_read = 0;
wire       ss_busy;

memory_stream #(.COUNT(SSIDX_COUNT)) ss_stream (
    .clk( clk_sys ),
    .reset( RESET ),
    .ddr( ddr_ss ),
    .read_req( ssbus.read ),
    .read_data( ssbus.data_out ),
    .data_ack( ssbus.ack ),
    .write_req( ssbus.write ),
    .write_data( ssbus.data ),
    .start_addr( SS_DDR_BASE + { 8'd0, ss_slot, 22'd0 } ),
    .length( 32'h00400000 ),
    .read_start( ss_read ),
    .write_start( ss_write ),
    .busy( ss_busy ),
    .chunk_select( ssbus.select ),
    .chunk_address( ssbus.addr ),
    .query_req( ssbus.query )
);

savestate_ui #(.INFO_TIMEOUT_BITS(25)) savestate_ui (
    .clk           ( clk_sys ),
    .ps2_key       ( ps2_key[10:0] ),
    .allow_ss      ( ~reset ),
    .joySS         ( btn_ss ),
    .joyRight      ( joy0[0] | joy1[0] ),
    .joyLeft       ( joy0[1] | joy1[1] ),
    .joyDown       ( joy0[2] | joy1[2] ),
    .joyUp         ( joy0[3] | joy1[3] ),
    .joyStart      ( 1'b0 ),
    .joyRewind     ( 1'b0 ),
    .rewindEnable  ( 1'b0 ),
    .status_slot   ( status[65:64] ),
    .autoincslot   ( status[66] ),
    .OSD_saveload  ( status[68:67] ),
    .ss_save       ( ss_ui_save ),
    .ss_load       ( ss_ui_load ),
    .ss_info_req   ( ss_info_req ),
    .ss_info       ( ss_info ),
    .statusUpdate  ( ss_status_set ),
    .selected_slot ( ss_slot )
);

// RAM chunks
wire [15:0] ssr_main_q = ram68k_dout;
wire [15:0] ssr_spr_q  = ram68k_sprite_dout;
wire [15:0] ssr_fg_q   = m68k_fg_ram_dout;
wire [15:0] ssr_bg_q   = m68k_bg_ram_dout;
wire [15:0] ssr_tpal_q = m68k_tile_pal_dout;
wire [15:0] ssr_spal_q = m68k_spr_pal_dout;
wire [15:0] ssr_ram2_q = m68k_ram_2_dout;
wire [15:0] ssr_ram3_q = m68k_ram_3_dout;

wire [12:0] ssr_main_addr; wire [15:0] ssr_main_data; wire [1:0] ssr_main_we; wire ssr_main_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(13), .SS_IDX(SSIDX_MAIN_RAM)) ssa_main (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_MAIN_RAM] ),
    .addr_in( m68k_a[13:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_ram_cs & !m68k_uds_n, !m68k_rw & m68k_ram_cs & !m68k_lds_n } ),
    .addr_out( ssr_main_addr ), .data_out( ssr_main_data ), .we_out( ssr_main_we ),
    .ss_active( ssr_main_act ), .q( ssr_main_q ) );

wire [10:0] ssr_spr_addr; wire [15:0] ssr_spr_data; wire [1:0] ssr_spr_we; wire ssr_spr_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(11), .SS_IDX(SSIDX_SPR_RAM)) ssa_spr (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_SPR_RAM] ),
    .addr_in( m68k_a[11:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_spr_cs & !m68k_uds_n, !m68k_rw & m68k_spr_cs & !m68k_lds_n } ),
    .addr_out( ssr_spr_addr ), .data_out( ssr_spr_data ), .we_out( ssr_spr_we ),
    .ss_active( ssr_spr_act ), .q( ssr_spr_q ) );

wire [10:0] ssr_fg_addr; wire [15:0] ssr_fg_data; wire [1:0] ssr_fg_we; wire ssr_fg_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(11), .SS_IDX(SSIDX_FG_RAM)) ssa_fg (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_FG_RAM] ),
    .addr_in( m68k_a[11:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_fg_ram_cs & !m68k_uds_n, !m68k_rw & m68k_fg_ram_cs & !m68k_lds_n } ),
    .addr_out( ssr_fg_addr ), .data_out( ssr_fg_data ), .we_out( ssr_fg_we ),
    .ss_active( ssr_fg_act ), .q( ssr_fg_q ) );

wire [10:0] ssr_bg_addr; wire [15:0] ssr_bg_data; wire [1:0] ssr_bg_we; wire ssr_bg_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(11), .SS_IDX(SSIDX_BG_RAM)) ssa_bg (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_BG_RAM] ),
    .addr_in( m68k_a[11:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_bg_ram_cs & !m68k_uds_n, !m68k_rw & m68k_bg_ram_cs & !m68k_lds_n } ),
    .addr_out( ssr_bg_addr ), .data_out( ssr_bg_data ), .we_out( ssr_bg_we ),
    .ss_active( ssr_bg_act ), .q( ssr_bg_q ) );

wire [10:0] ssr_tpal_addr; wire [15:0] ssr_tpal_data; wire [1:0] ssr_tpal_we; wire ssr_tpal_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(11), .SS_IDX(SSIDX_TILE_PAL)) ssa_tpal (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_TILE_PAL] ),
    .addr_in( m68k_a[11:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_tile_pal_cs & !m68k_uds_n, !m68k_rw & m68k_tile_pal_cs & !m68k_lds_n } ),
    .addr_out( ssr_tpal_addr ), .data_out( ssr_tpal_data ), .we_out( ssr_tpal_we ),
    .ss_active( ssr_tpal_act ), .q( ssr_tpal_q ) );

wire [10:0] ssr_spal_addr; wire [15:0] ssr_spal_data; wire [1:0] ssr_spal_we; wire ssr_spal_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(11), .SS_IDX(SSIDX_SPR_PAL)) ssa_spal (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_SPR_PAL] ),
    .addr_in( m68k_a[11:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_spr_pal_cs & !m68k_uds_n, !m68k_rw & m68k_spr_pal_cs & !m68k_lds_n } ),
    .addr_out( ssr_spal_addr ), .data_out( ssr_spal_data ), .we_out( ssr_spal_we ),
    .ss_active( ssr_spal_act ), .q( ssr_spal_q ) );

wire [11:0] ssr_ram2_addr; wire [15:0] ssr_ram2_data; wire [1:0] ssr_ram2_we; wire ssr_ram2_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(12), .SS_IDX(SSIDX_RAM2)) ssa_ram2 (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_RAM2] ),
    .addr_in( m68k_a[12:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_ram_2_cs & !m68k_uds_n, !m68k_rw & m68k_ram_2_cs & !m68k_lds_n } ),
    .addr_out( ssr_ram2_addr ), .data_out( ssr_ram2_data ), .we_out( ssr_ram2_we ),
    .ss_active( ssr_ram2_act ), .q( ssr_ram2_q ) );

wire [11:0] ssr_ram3_addr; wire [15:0] ssr_ram3_data; wire [1:0] ssr_ram3_we; wire ssr_ram3_act;
ss_ram_port #(.WIDTH(16), .WIDTHAD(12), .SS_IDX(SSIDX_RAM3)) ssa_ram3 (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_RAM3] ),
    .addr_in( m68k_a[12:1] ), .data_in( m68k_dout ),
    .we_in( { !m68k_rw & m68k_ram_3_cs & !m68k_uds_n, !m68k_rw & m68k_ram_3_cs & !m68k_lds_n } ),
    .addr_out( ssr_ram3_addr ), .data_out( ssr_ram3_data ), .we_out( ssr_ram3_we ),
    .ss_active( ssr_ram3_act ), .q( ssr_ram3_q ) );

wire [11:0] ssr_txt_addr;  wire [7:0] ssr_txt_data;  wire ssr_txt_we;  wire ssr_txt_act;
ss_ram_port #(.WIDTH(8), .WIDTHAD(12), .SS_IDX(SSIDX_TXT_RAM)) ssa_txt (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_TXT_RAM] ),
    .addr_in( shared_addr ), .data_in( shared_data ), .we_in( shared_w ),
    .addr_out( ssr_txt_addr ), .data_out( ssr_txt_data ), .we_out( ssr_txt_we ),
    .ss_active( ssr_txt_act ), .q( m68k_txt_attr_ram_dout[7:0] ) );

wire [10:0] ssr_z80a_addr; wire [7:0] ssr_z80a_data; wire ssr_z80a_we; wire ssr_z80a_act;
ss_ram_port #(.WIDTH(8), .WIDTHAD(11), .SS_IDX(SSIDX_Z80A_RAM)) ssa_z80a (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_Z80A_RAM] ),
    .addr_in( z80_a_addr[10:0] ), .data_in( z80_a_dout ), .we_in( z80_a_ram_cs & ~z80_a_wr_n ),
    .addr_out( ssr_z80a_addr ), .data_out( ssr_z80a_data ), .we_out( ssr_z80a_we ),
    .ss_active( ssr_z80a_act ), .q( z80_a_ram_data ) );

wire [11:0] ssr_z80b1_addr; wire [7:0] ssr_z80b1_data; wire ssr_z80b1_we; wire ssr_z80b1_act;
ss_ram_port #(.WIDTH(8), .WIDTHAD(12), .SS_IDX(SSIDX_Z80B_RAM1)) ssa_z80b1 (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_Z80B_RAM1] ),
    .addr_in( z80_b_addr[11:0] ), .data_in( z80_b_dout ), .we_in( z80_b_ram_1_cs & ~z80_b_wr_n ),
    .addr_out( ssr_z80b1_addr ), .data_out( ssr_z80b1_data ), .we_out( ssr_z80b1_we ),
    .ss_active( ssr_z80b1_act ), .q( z80_b_ram_1_dout ) );

wire [10:0] ssr_z80b2_addr; wire [7:0] ssr_z80b2_data; wire ssr_z80b2_we; wire ssr_z80b2_act;
ss_ram_port #(.WIDTH(8), .WIDTHAD(11), .SS_IDX(SSIDX_Z80B_RAM2)) ssa_z80b2 (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_Z80B_RAM2] ),
    .addr_in( z80_b_addr[10:0] ), .data_in( z80_b_dout ), .we_in( z80_b_ram_2_cs & ~z80_b_wr_n ),
    .addr_out( ssr_z80b2_addr ), .data_out( ssr_z80b2_data ), .we_out( ssr_z80b2_we ),
    .ss_active( ssr_z80b2_act ), .q( z80_b_ram_2_dout ) );

// CPU register chunks
wire [211:0] z80a_reg, z80b_reg, z80a_dir, z80b_dir;

auto_save_adaptor #(.N_BITS(212), .SS_IDX(SSIDX_Z80A_REGS)) ssa_z80a_regs (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_Z80A_REGS] ),
    .bits_in( z80a_reg ), .bits_out( z80a_dir ), .bits_wr() );

auto_save_adaptor #(.N_BITS(212), .SS_IDX(SSIDX_Z80B_REGS)) ssa_z80b_regs (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_Z80B_REGS] ),
    .bits_in( z80b_reg ), .bits_out( z80b_dir ), .bits_wr() );

// Board registers
localparam SSM_BITS = 16+16+10+10+1+8+1+1+1+5+5+8+8+1+8+24+24+16+8+8+8+8;
wire [SSM_BITS-1:0] ss_misc_in = {
    bg_scroll_x, bg_scroll_y, fg_scroll_x, fg_scroll_y, scroll_msb, sound_latch,
    m68k_ipl0_n, m68k_ipl1_n, z80_b_irq_n, flip_screen, bg_enable, fg_enable, sp_enable, tx_enable,
    nb1414m4_frame, dac1, dac2, z80_a_irq_n, nb1414m4_credits, nb1414m4_p1, nb1414m4_p2,
    nb1414m4_cmd, nb_scroll_x_l, nb_scroll_x_h, nb_scroll_y_l, nb_scroll_y_h };
wire [SSM_BITS-1:0] ss_misc_out;
wire                ss_misc_wr;

wire [15:0] ssm_bg_scroll_x, ssm_bg_scroll_y;
wire  [9:0] ssm_fg_scroll_x, ssm_fg_scroll_y;
wire        ssm_scroll_msb, ssm_ipl0_n, ssm_ipl1_n, ssm_z80_b_irq_n, ssm_z80_a_irq_n;
wire  [7:0] ssm_sound_latch, ssm_dac1, ssm_dac2, ssm_nb_credits;
wire  [4:0] ssm_layer_en;   // { flip_screen, bg, fg, sp, tx }
wire  [4:0] ssm_nb_frame;
wire [23:0] ssm_nb_p1, ssm_nb_p2;
wire [15:0] ssm_nb_cmd;
wire  [7:0] ssm_nb_sxl, ssm_nb_sxh, ssm_nb_syl, ssm_nb_syh;
assign { ssm_bg_scroll_x, ssm_bg_scroll_y, ssm_fg_scroll_x, ssm_fg_scroll_y, ssm_scroll_msb, ssm_sound_latch,
         ssm_ipl0_n, ssm_ipl1_n, ssm_z80_b_irq_n, ssm_layer_en,
         ssm_nb_frame, ssm_dac1, ssm_dac2, ssm_z80_a_irq_n, ssm_nb_credits, ssm_nb_p1, ssm_nb_p2,
         ssm_nb_cmd, ssm_nb_sxl, ssm_nb_sxh, ssm_nb_syl, ssm_nb_syh } = ss_misc_out;

auto_save_adaptor #(.N_BITS(SSM_BITS), .SS_IDX(SSIDX_MISC)) ssa_misc (
    .clk( clk_sys ), .ssbus( ssb[SSIDX_MISC] ),
    .bits_in( ss_misc_in ), .bits_out( ss_misc_out ), .bits_wr( ss_misc_wr ) );

// OPL2 register shadow and replay
reg        opl_replay = 0;
reg        opl_rp_we, opl_rp_a0;
reg  [7:0] opl_rp_d;
reg  [8:0] opl_rp_idx;
reg [11:0] opl_rp_cnt;
reg        opl_rp_phase;
reg        opl_rp_start = 0;
wire [7:0] opl_sh_sel, opl_sh_q;

opl_shadow #(.SS_IDX(SSIDX_OPL)) opl_shadow (
    .clk( clk_sys ),
    .cpu_we( sound_wr & ~opl_replay ),
    .cpu_a0( sound_addr ),
    .cpu_d( sound_data ),
    .sel( opl_sh_sel ),
    .rd_addr( opl_rp_idx[7:0] ),
    .rd_q( opl_sh_q ),
    .ssbus( ssb[SSIDX_OPL] )
);

// Replay each register as a select write then a data write, with settle time.
always @(posedge clk_sys) begin
    opl_rp_we <= 1'b0;
    if (opl_rp_start) begin
        opl_replay   <= 1'b1;
        opl_rp_idx   <= 9'd0;
        opl_rp_cnt   <= 12'd0;
        opl_rp_phase <= 1'b0;
    end else if (opl_replay) begin
        opl_rp_cnt <= opl_rp_cnt + 12'd1;
        if (!opl_rp_phase) begin
            // register select; index 256 restores the CPU's last select
            opl_rp_a0 <= 1'b0;
            opl_rp_d  <= opl_rp_idx[8] ? opl_sh_sel : opl_rp_idx[7:0];
            opl_rp_we <= ( opl_rp_cnt < 12'd40 );
            if (opl_rp_cnt == 12'd340) begin
                opl_rp_cnt <= 12'd0;
                if (opl_rp_idx[8]) opl_replay <= 1'b0;
                else               opl_rp_phase <= 1'b1;
            end
        end else begin
            opl_rp_a0 <= 1'b1;
            opl_rp_d  <= opl_sh_q;
            opl_rp_we <= ( opl_rp_cnt < 12'd40 );
            if (opl_rp_cnt == 12'd2040) begin
                opl_rp_cnt   <= 12'd0;
                opl_rp_phase <= 1'b0;
                opl_rp_idx   <= opl_rp_idx + 9'd1;
            end
        end
    end
end

// 68000 save/restore handler
reg [31:0] ss_saved_ssp, ss_restore_ssp;

always @(posedge clk_sys) begin
    ssb[SSIDX_GLOBAL].setup(SSIDX_GLOBAL, 1, 2); // one 32-bit value
    if (ssb[SSIDX_GLOBAL].access(SSIDX_GLOBAL)) begin
        if (ssb[SSIDX_GLOBAL].read) begin
            ssb[SSIDX_GLOBAL].read_response(SSIDX_GLOBAL, { 32'd0, ss_saved_ssp });
        end else if (ssb[SSIDX_GLOBAL].write) begin
            ss_restore_ssp <= ssb[SSIDX_GLOBAL].data[31:0];
            ssb[SSIDX_GLOBAL].write_ack(SSIDX_GLOBAL);
        end
    end
end

// Push registers and USP, store SSP at $ff0000, then pop and RTE.
logic [15:0] ss_irq_handler [16] = '{
    16'h48e7, 16'hfffe,            // movem.l %d0-%d7/%a0-%a6,%a7@-
    16'h4e6e,                      // move.l %usp, %a6
    16'h2f0e,                      // move.l %a6, %a7@-
    16'h4df9, 16'h00ff, 16'h0000,  // lea 0xff0000, %a6      (0x8: restart point)
    16'h2c8f,                      // move.l %a7, %a6@
    16'h2c5f,                      // move.l %a7@+, %a6
    16'h4e66,                      // move.l %a6, %usp
    16'h4cdf, 16'h7fff,            // movem.l %a7@+, %d0-%d7/%a0-%a6
    16'h4e73,                      // rte
    16'h0000, 16'h0000, 16'h0000
};

wire ss_in_handler = ( m68k_a[23:8] == 16'hff00 );
wire ss_in_vec7    = ( m68k_a[23:2] == 22'h00001f );        // 0x7c / 0x7e
wire ss_in_reset   = ( m68k_a[23:3] == 21'd0 );             // 0x0 - 0x7
wire ss_ovr_hit    = ss_override & m68k_rw & !m68k_as_n & ( ss_in_handler | ss_in_vec7 | ss_in_reset );
wire [15:0] ss_ovr_data = ss_in_handler ? ss_irq_handler[m68k_a[4:1]] :
                          ss_in_vec7    ? ( m68k_a[1] ? 16'h0000 : 16'h00ff ) :
                          m68k_a[2] ? ( m68k_a[1] ? 16'h0008 : 16'h00ff ) :         // PC  = 0x00ff0008
                                      ( m68k_a[1] ? ss_restore_ssp[15:0] : ss_restore_ssp[31:16] );  // SSP

wire ss_iack7    = !m68k_as_n && m68k_fc == 3'b111 && m68k_a[3:1] == 3'b111;
wire ss_ssp_wr   = !m68k_as_n && !m68k_rw && !m68k_uds_n && !m68k_lds_n && m68k_a[23:2] == 22'h3fc000;
wire ss_returned = !m68k_as_n && m68k_rw && ( m68k_fc == 3'b110 || m68k_fc == 3'b010 ) &&
                   !ss_in_handler && !ss_in_vec7 && !ss_in_reset;

// Save-state sequencer
localparam SST_IDLE       = 4'd0,
           SST_FREEZE     = 4'd1,
           SST_SAVE_IRQ   = 4'd2,
           SST_SAVE_SSP   = 4'd3,
           SST_SAVE_WRITE = 4'd4,
           SST_SAVE_EXIT  = 4'd5,
           SST_LOAD_READ  = 4'd6,
           SST_LOAD_OPL   = 4'd7,
           SST_LOAD_DIR   = 4'd8,
           SST_LOAD_MCU   = 4'd9,
           SST_LOAD_RESET = 4'd10,
           SST_LOAD_RUN   = 4'd11;

reg  [3:0] ss_state = SST_IDLE;
reg        ss_is_load;
reg [23:0] ss_timer;

wire ss_pause         = ( ss_state != SST_IDLE );
wire ss_freeze        = ( ss_state != SST_IDLE );
wire ss_cpu_execute   = ( ss_state == SST_SAVE_IRQ  ) || ( ss_state == SST_SAVE_SSP ) || ( ss_state == SST_SAVE_EXIT ) ||
                        ( ss_state == SST_LOAD_RESET ) || ( ss_state == SST_LOAD_RUN );
wire ss_irq           = ( ss_state == SST_SAVE_IRQ );
wire ss_override      = ( ss_state == SST_SAVE_SSP  ) || ( ss_state == SST_SAVE_EXIT ) ||
                        ( ss_state == SST_LOAD_RESET ) || ( ss_state == SST_LOAD_RUN );
wire ss_reset_68k     = ( ss_state == SST_LOAD_RESET );
wire ss_z80_reset     = ( ss_state == SST_LOAD_READ ) || ( ss_state == SST_LOAD_OPL );
reg  ss_z80_dirset;
wire ss_mcu_reset     = ( pcb == 3 ) && ( ( ss_state == SST_LOAD_READ ) || ( ss_state == SST_LOAD_OPL ) );
wire ss_restore_reset = ( ss_state == SST_LOAD_DIR );

// Z80s stop at an opcode fetch, so REG/DIR is a full snapshot.
reg z80a_hold = 0, z80b_hold = 0, m1a_d, m1b_d;
always @(posedge clk_sys) begin
    m1a_d <= M1_a_n;
    m1b_d <= M1_b_n;
    if (!ss_freeze) begin
        z80a_hold <= 1'b0;
        z80b_hold <= 1'b0;
    end else begin
        if (m1a_d && !M1_a_n) z80a_hold <= 1'b1;
        if (m1b_d && !M1_b_n) z80b_hold <= 1'b1;
    end
end

// Freeze the i8751 only in its idle loop.
reg ss_mcu_frozen = 0;
always @(posedge clk_sys) begin
    if (!ss_freeze || ss_state == SST_LOAD_MCU || ss_mcu_reset) ss_mcu_frozen <= 1'b0;
    else if (i8751_idle) ss_mcu_frozen <= 1'b1;
end
wire ss_mcu_freeze = ss_mcu_frozen & ( ss_state != SST_LOAD_MCU );
wire       i8751_idle;

// Sky Robo: hold the MCU latch read until the i8751 has run its handler (14.6 ms timeout).
reg [19:0] mcu_hold_cnt;
always @(posedge clk_sys)
    mcu_hold_cnt <= irq_i8751_cs ? ( &mcu_hold_cnt ? mcu_hold_cnt : mcu_hold_cnt + 20'd1 ) : 20'd0;
assign mcu_hold_68k = ( pcb == 3 ) && irq_i8751_cs && ( i8751_int0_req | i8751_int0_busy ) &&
                      !ss_mcu_freeze && !( &mcu_hold_cnt );

wire ss_all_frozen = z80a_hold &
                     ( z80b_hold | ( pcb != 8 ) ) &
                     ( ss_mcu_frozen | ( pcb != 3 ) ) &
                     !nb1414m4_busy;

always @(posedge clk_sys) begin
    ss_write       <= 1'b0;
    ss_read        <= 1'b0;
    opl_rp_start   <= 1'b0;
    ss_z80_dirset  <= 1'b0;
    ss_timer       <= ss_timer + 24'd1;

    if (reset) begin
        ss_state <= SST_IDLE;
    end else case (ss_state)
        SST_IDLE: begin
            ss_timer <= 24'd0;
            if (ss_ui_save | ss_ui_load) begin
                ss_is_load <= ss_ui_load;
                ss_state   <= SST_FREEZE;
            end
        end

        SST_FREEZE: begin
            if (ss_all_frozen) begin
                ss_timer <= 24'd0;
                if (ss_is_load) begin
                    ss_read  <= 1'b1;
                    ss_state <= SST_LOAD_READ;
                end else begin
                    ss_state <= SST_SAVE_IRQ;
                end
            end else if (&ss_timer) begin
                ss_state <= SST_IDLE;   // timeout
            end
        end

        // save
        SST_SAVE_IRQ: begin
            if (ss_iack7) ss_state <= SST_SAVE_SSP;
            else if (&ss_timer) ss_state <= SST_IDLE;
        end
        SST_SAVE_SSP: begin
            if (ss_ssp_wr && !m68k_a[1]) ss_saved_ssp[31:16] <= m68k_dout;
            if (ss_ssp_wr &&  m68k_a[1]) begin
                ss_saved_ssp[15:0] <= m68k_dout;
                ss_write <= 1'b1;
                ss_state <= SST_SAVE_WRITE;
            end
        end
        SST_SAVE_WRITE: begin
            if (!ss_write && !ss_busy) ss_state <= SST_SAVE_EXIT;
        end
        SST_SAVE_EXIT: begin
            if (ss_returned) ss_state <= SST_IDLE;
        end

        // restore
        SST_LOAD_READ: begin
            if (!ss_read && !ss_busy) begin
                opl_rp_start <= 1'b1;
                ss_state     <= SST_LOAD_OPL;
            end
        end
        SST_LOAD_OPL: begin
            if (!opl_rp_start && !opl_replay) begin
                ss_timer <= 24'd0;
                ss_state <= SST_LOAD_DIR;
            end
        end
        SST_LOAD_DIR: begin
            // load the held Z80s' registers
            ss_z80_dirset <= ( ss_timer >= 24'd4 && ss_timer < 24'd8 );
            if (ss_timer == 24'd16) begin
                ss_timer <= 24'd0;
                ss_state <= SST_LOAD_MCU;
            end
        end
        SST_LOAD_MCU: begin
            // let the i8751 return to its idle loop
            if (pcb != 3 || (ss_timer > 24'd2000 && i8751_idle)) begin
                ss_timer <= 24'd0;
                ss_state <= SST_LOAD_RESET;
            end
        end
        SST_LOAD_RESET: begin
            // reset the 68000 into the restore handler
            if (ss_timer == 24'd2000) ss_state <= SST_LOAD_RUN;
        end
        SST_LOAD_RUN: begin
            if (ss_returned) ss_state <= SST_IDLE;
        end

        default: ss_state <= SST_IDLE;
    endcase
end


endmodule


module delay
(
    input clk,  
    input i,
    output o
);

reg [5:0] r;

assign o = r[5]; 

always @(posedge clk) begin
    r <= { r[4:0], i };
end

endmodule

`default_nettype wire

// Intel 8751 MCU (Sky Robo / Big Fighter): Oregano Systems MC8051 IP core v1.6 (LGPL) on a gated clk_sys.

`default_nettype none

module i8751
(
    input  wire        clk,         // clk_sys
    input  wire        rst,         // active high
    input  wire        cen,         // 8 MHz oscillator enable

    input  wire        int0_req,    // assert INT0 until serviced
    output wire        int0_busy,   // INT0 requested or being handled

    // save states: freeze stops the MCU; idle = in the idle loop, no INT0 pending
    input  wire        freeze,
    input  wire [15:0] idle_addr,
    output wire        idle,

    input  wire  [7:0] p0_i,
    input  wire  [7:0] p1_i,
    input  wire  [7:0] p2_i,
    input  wire  [7:0] p3_i,
    output reg   [7:0] p0_o,
    output reg   [7:0] p1_o,
    output reg   [7:0] p2_o,
    output reg   [7:0] p3_o,

    // external data memory (MOVX)
    output reg  [15:0] x_addr,
    output reg   [7:0] x_dout,
    output reg         x_wr,        // one pulse per write
    input  wire  [7:0] x_din,       // valid 2 clk after x_addr
    output reg         x_quiet,     // bus free for another master

    // program ROM download
    input  wire [11:0] prog_addr,
    input  wire  [7:0] prog_din,
    input  wire        prog_we,

    // internal RAM side port for save states
    input  wire        iram_ext_en,
    input  wire  [6:0] iram_ext_addr,
    input  wire  [7:0] iram_ext_din,
    input  wire        iram_ext_we,
    output wire  [7:0] iram_ext_dout
);

// Machine-cycle tick: one pulse per 12 cen.
reg  [3:0] div12;
reg        tick;          // gated clock enable
reg  [3:0] tick_sr;       // tick delayed by 1..4 clk

// Bus is free for another master from tick+6 to tick+90.
reg [6:0] since_tick;
always @(posedge clk) begin
    since_tick <= tick ? 7'd0 : (since_tick == 7'd127 ? since_tick : since_tick + 7'd1);
    x_quiet    <= (since_tick >= 7'd6) && (since_tick < 7'd90);
end

always @(posedge clk) begin
    tick <= 1'b0;
    if (cen && !freeze) begin
        if (div12 == 4'd11) begin
            div12 <= 4'd0;
            tick  <= 1'b1;
        end else begin
            div12 <= div12 + 4'd1;
        end
    end
    tick_sr <= { tick_sr[2:0], tick };
end

wire mcu_clk;

cyclonev_clkena #(
    .clock_type        ( "Global Clock" ),
    .ena_register_mode ( "falling edge" ),
    .lpm_type          ( "cyclonev_clkena" )
) u_mcu_clk_gate (
    .inclk  ( clk     ),
    .ena    ( tick    ),
    .enaout (         ),
    .outclk ( mcu_clk )
);

// Registered MCU inputs.
reg        mcu_in_int0_n;
reg  [7:0] mcu_in_p0, mcu_in_p1, mcu_in_p2, mcu_in_p3;
reg  [7:0] mcu_in_xdata;
reg        int0_hold;

// Captured MCU outputs.
wire [15:0] core_rom_addr;
wire  [7:0] core_ram_dout;
wire  [6:0] core_ram_addr;
wire        core_ram_wr;
wire        core_ram_en;
wire  [7:0] core_xdout;
wire [15:0] core_xaddr;
wire        core_xwr;
wire  [7:0] core_p0, core_p1, core_p2, core_p3;

reg  [15:0] mcu_out_rom_addr;
wire        at_idle = ( mcu_out_rom_addr == idle_addr || mcu_out_rom_addr == idle_addr + 16'd1 );
assign idle = at_idle && !int0_hold && !int0_req;

// INT0 tracking: in_isr from the 0003h vector fetch until back in the idle loop.
reg in_isr, int0_busy_r;
assign int0_busy = int0_busy_r;
reg   [7:0] mcu_out_xdout;
reg  [15:0] mcu_out_xaddr;
reg         mcu_out_xwr;

always @(posedge clk) begin
    x_wr <= 1'b0;

    if (rst) begin
        int0_hold     <= 1'b0;
        mcu_in_int0_n <= 1'b1;
        in_isr        <= 1'b0;
        int0_busy_r   <= 1'b0;
    end else begin
        if (int0_req) int0_hold <= 1'b1;

        if (int0_req) int0_busy_r <= 1'b1;
        if (tick_sr[0] && mcu_out_rom_addr == 16'h0003) begin
            in_isr <= 1'b1;
        end else if (tick_sr[0] && in_isr && at_idle && !int0_hold && !int0_req) begin
            in_isr      <= 1'b0;
            int0_busy_r <= 1'b0;
        end

        if (tick) begin
            // capture outputs at the tick
            mcu_out_rom_addr <= core_rom_addr;
            mcu_out_xdout    <= core_xdout;
            mcu_out_xaddr    <= core_xaddr;
            mcu_out_xwr      <= core_xwr;
            p0_o <= core_p0;
            p1_o <= core_p1;
            p2_o <= core_p2;
            p3_o <= core_p3;

            mcu_in_int0_n <= ~(int0_hold | int0_req);
            mcu_in_p0 <= p0_i;
            mcu_in_p1 <= p1_i;
            mcu_in_p2 <= p2_i;
            mcu_in_p3 <= p3_i;
        end

        // INT0 vector fetch clears the request
        if (tick_sr[0] && mcu_out_rom_addr == 16'h0003 && !int0_req) int0_hold <= 1'b0;

        // external access, one clk after the tick
        if (tick_sr[0]) begin
            x_addr <= mcu_out_xaddr;
            x_dout <= mcu_out_xdout;
            x_wr   <= mcu_out_xwr;
        end

        // sample read data at tick+4
        if (tick_sr[3]) mcu_in_xdata <= x_din;
    end
end

// Program ROM.
wire [7:0] rom_q;

dual_port_ram #(.LEN(4096)) u_prom (
    .clock_a   ( mcu_clk             ),
    .address_a ( core_rom_addr[11:0] ),
    .wren_a    ( 1'b0                ),
    .data_a    (                     ),
    .q_a       ( rom_q               ),

    .clock_b   ( clk                 ),
    .address_b ( prog_addr           ),
    .wren_b    ( prog_we             ),
    .data_b    ( prog_din            ),
    .q_b       (                     )
);

// Internal 128-byte RAM.
wire [7:0] iram_q;

// clear the RAM during reset
reg  [6:0] iram_clr_addr;
always @(posedge clk) iram_clr_addr <= rst ? iram_clr_addr + 7'd1 : 7'd0;

wire [6:0] iram_b_addr = rst ? iram_clr_addr : iram_ext_addr;
wire [7:0] iram_b_din  = rst ? 8'h00         : iram_ext_din;
wire       iram_b_we   = rst | (iram_ext_en & iram_ext_we);

dual_port_ram #(.LEN(128)) u_iram (
    .clock_a   ( mcu_clk                     ),
    .address_a ( core_ram_addr               ),
    .wren_a    ( core_ram_wr & core_ram_en   ),
    .data_a    ( core_ram_dout               ),
    .q_a       ( iram_q                      ),

    .clock_b   ( clk                         ),
    .address_b ( iram_b_addr                 ),
    .wren_b    ( iram_b_we                   ),
    .data_b    ( iram_b_din                  ),
    .q_b       ( iram_ext_dout               )
);

// MC8051 core.
mc8051_core u_mcu (
    .clk         ( mcu_clk        ),
    .reset       ( rst            ),

    .rom_data_i  ( rom_q          ),
    .rom_adr_o   ( core_rom_addr  ),

    .ram_data_i  ( iram_q         ),
    .ram_data_o  ( core_ram_dout  ),
    .ram_adr_o   ( core_ram_addr  ),
    .ram_wr_o    ( core_ram_wr    ),
    .ram_en_o    ( core_ram_en    ),

    .datax_i     ( mcu_in_xdata   ),
    .datax_o     ( core_xdout     ),
    .adrx_o      ( core_xaddr     ),
    .wrx_o       ( core_xwr       ),

    .int0_i      ( mcu_in_int0_n  ),
    .int1_i      ( 1'b1           ),

    .all_t0_i    ( 1'b0           ),
    .all_t1_i    ( 1'b0           ),
    .all_rxd_i   ( 1'b0           ),
    .all_rxd_o   (                ),
    .all_txd_o   (                ),
    .all_rxdwr_o (                ),

    .p0_i        ( mcu_in_p0      ),
    .p1_i        ( mcu_in_p1      ),
    .p2_i        ( mcu_in_p2      ),
    .p3_i        ( mcu_in_p3      ),
    .p0_o        ( core_p0        ),
    .p1_o        ( core_p1        ),
    .p2_o        ( core_p2        ),
    .p3_o        ( core_p3        )
);

endmodule

`default_nettype wire

// Save-state chunk adaptors (ssbus protocol from MiSTer-devel/Arcade-TaitoF2_MiSTer, Martin Donlon).

// Muxes one RAM port between its user and the save-state stream.
module ss_ram_port #(
    parameter int WIDTH   = 16,          // 8 or 16
    parameter int WIDTHAD = 13,
    parameter int SS_IDX  = -1
) (
    input                      clk,
    ssbus_if.slave             ssbus,

    input        [WIDTHAD-1:0] addr_in,
    input        [WIDTH-1:0]   data_in,
    input        [WIDTH/8-1:0] we_in,

    output       [WIDTHAD-1:0] addr_out,
    output       [WIDTH-1:0]   data_out,
    output       [WIDTH/8-1:0] we_out,
    output                     ss_active,  // force the RAM clock enable while high

    input        [WIDTH-1:0]   q
);

assign ss_active = ssbus.access(SS_IDX);
assign addr_out  = ss_active ? ssbus.addr[WIDTHAD-1:0] : addr_in;
assign data_out  = ss_active ? ssbus.data[WIDTH-1:0]   : data_in;
assign we_out    = ss_active ? {(WIDTH/8){ssbus.write}} : we_in;

reg read_delay;
always @(posedge clk) begin
    ssbus.setup(SS_IDX, 32'(2**WIDTHAD), (WIDTH == 16) ? 1 : 0);

    if (ss_active) begin
        if (ssbus.write) begin
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            if (read_delay) ssbus.read_response(SS_IDX, { {64-WIDTH{1'b0}}, q });
            read_delay <= 1'b1;
        end
    end else begin
        read_delay <= 1'b0;
    end
end

endmodule


// OPL2 register shadow: 256 register bytes, then the last selected register.
module opl_shadow #(
    parameter int SS_IDX = -1
) (
    input              clk,

    input              cpu_we,        // sound CPU write strobe
    input              cpu_a0,        // 0 = register select, 1 = data
    input        [7:0] cpu_d,

    output reg   [7:0] sel,           // last selected register
    input        [7:0] rd_addr,       // replay read port
    output reg   [7:0] rd_q,

    ssbus_if.slave     ssbus
);

reg [7:0] regs [256];

wire       ss_acc = ssbus.access(SS_IDX);
wire [8:0] ss_a   = ssbus.addr[8:0];

always @(posedge clk) begin
    ssbus.setup(SS_IDX, 32'd257, 0);

    if (ss_acc) begin
        if (ssbus.write) begin
            if (ss_a[8]) sel <= ssbus.data[7:0];
            else         regs[ss_a[7:0]] <= ssbus.data[7:0];
            ssbus.write_ack(SS_IDX);
        end else if (ssbus.read) begin
            ssbus.read_response(SS_IDX, { 56'd0, ss_a[8] ? sel : regs[ss_a[7:0]] });
        end
    end else if (cpu_we) begin
        if (!cpu_a0) sel <= cpu_d;
        else         regs[sel] <= cpu_d;
    end

    rd_q <= regs[rd_addr];
end

endmodule

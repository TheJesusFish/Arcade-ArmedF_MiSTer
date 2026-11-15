// High-score save/restore: MRA rom index 3 = hiscore.dat config, nvram index 4 = saved tables.

`default_nettype none

module hiscore #(
    parameter MAX_ENTRIES  = 4,
    parameter BUF_AW       = 8,          // 256-byte table buffer
    parameter START_DELAY  = 300,        // vblanks to wait after reset
    parameter CFG_INDEX    = 3,
    parameter DATA_INDEX   = 4
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        ioctl_download,
    input  wire        ioctl_upload,
    input  wire        ioctl_wr,
    input  wire [15:0] ioctl_index,
    input  wire [24:0] ioctl_addr,
    input  wire  [7:0] ioctl_dout,
    output reg   [7:0] ioctl_din,
    output reg         ioctl_upload_req,

    input  wire        vblank,
    input  wire        osd_open,
    input  wire        autosave,
    input  wire        save_now,         // OSD "Save Hiscores" pulse

    output wire        present,          // a config was loaded for this game
    output wire        active,           // tables found; saving allowed

    // RAM port (byte wide, 68K byte addressing)
    output reg         ram_en,
    output reg  [23:0] ram_addr,
    output reg   [7:0] ram_wdata,
    output reg         ram_we,
    input  wire  [7:0] ram_rdata,        // valid 2 clk after ram_addr
    input  wire        ram_grant         // an access may start
);

// Configuration.
reg  [31:0] e_addr  [MAX_ENTRIES];
reg  [15:0] e_len   [MAX_ENTRIES];
reg   [7:0] e_start [MAX_ENTRIES];
reg   [7:0] e_end   [MAX_ENTRIES];
reg   [2:0] n_entries;

wire cfg_wr  = ioctl_download & ioctl_wr & (ioctl_index == CFG_INDEX);
wire data_wr = ioctl_download & ioctl_wr & (ioctl_index == DATA_INDEX);

always @(posedge clk) begin
    if (ioctl_download && ioctl_index == 0 && ioctl_addr == 0 && ioctl_wr) n_entries <= 3'd0;  // new game
    if (cfg_wr && ioctl_addr[24:3] < MAX_ENTRIES) begin
        case (ioctl_addr[2:0])
            3'd0: e_addr [ioctl_addr[4:3]][31:24] <= ioctl_dout;
            3'd1: e_addr [ioctl_addr[4:3]][23:16] <= ioctl_dout;
            3'd2: e_addr [ioctl_addr[4:3]][15: 8] <= ioctl_dout;
            3'd3: e_addr [ioctl_addr[4:3]][ 7: 0] <= ioctl_dout;
            3'd4: e_len  [ioctl_addr[4:3]][15: 8] <= ioctl_dout;
            3'd5: e_len  [ioctl_addr[4:3]][ 7: 0] <= ioctl_dout;
            3'd6: e_start[ioctl_addr[4:3]]        <= ioctl_dout;
            3'd7: begin
                e_end[ioctl_addr[4:3]] <= ioctl_dout;
                n_entries <= ioctl_addr[4:3] + 3'd1;
            end
        endcase
    end
end

assign present = (n_entries != 0);

// Table buffer.
reg  [7:0] buffer [1 << BUF_AW];
reg        have_data;
reg [BUF_AW-1:0] buf_addr;
reg  [7:0] buf_wdata;
reg        buf_we;
reg  [7:0] buf_q;

always @(posedge clk) begin
    if (data_wr && ioctl_addr[24:BUF_AW] == 0) buffer[ioctl_addr[BUF_AW-1:0]] <= ioctl_dout;
    else if (buf_we) buffer[buf_addr] <= buf_wdata;
    buf_q     <= buffer[buf_addr];
    ioctl_din <= buffer[ioctl_addr[BUF_AW-1:0]];
end

always @(posedge clk) begin
    if (ioctl_download && ioctl_index == 0 && ioctl_addr == 0 && ioctl_wr) have_data <= 1'b0;
    if (data_wr) have_data <= 1'b1;
end

// Sequencer.
localparam S_IDLE     = 4'd0,
           S_DELAY    = 4'd1,
           S_CHK_START= 4'd2,
           S_CHK_END  = 4'd3,
           S_CHK_WAIT = 4'd4,
           S_COPY     = 4'd5,
           S_COPY_WAIT= 4'd6,
           S_READY    = 4'd7,
           S_DUMP     = 4'd8,
           S_DUMP_WAIT= 4'd9,
           S_DUMP_DONE= 4'd10;

reg  [3:0] state;
reg  [1:0] ent;
reg [15:0] cnt;
reg [BUF_AW-1:0] bptr;
reg  [9:0] delay;
reg  [2:0] wait_cnt;
reg        vbl_d, osd_d;
reg        check_end;           // checking the end byte

assign active = (state == S_READY) | (state >= S_DUMP);

wire vbl_rise = vblank & ~vbl_d;

always @(posedge clk) begin
    vbl_d <= vblank;
    osd_d <= osd_open;
    ram_we <= 1'b0;
    buf_we <= 1'b0;
    ioctl_upload_req <= 1'b0;

    if (reset || !present) begin
        state  <= S_DELAY;
        delay  <= 10'd0;
        ram_en <= 1'b0;
    end else begin
        case (state)
        S_DELAY: if (vbl_rise) begin
            delay <= delay + 10'd1;
            if (delay == START_DELAY) begin
                state <= S_CHK_START;
                ent   <= 2'd0;
            end
        end

        // check each entry's start/end bytes once per vblank
        S_CHK_START: if (ram_grant) begin
            ram_en    <= 1'b1;
            ram_addr  <= e_addr[ent][23:0];
            check_end <= 1'b0;
            wait_cnt  <= 3'd0;
            state     <= S_CHK_WAIT;
        end
        S_CHK_END: if (ram_grant) begin
            ram_en    <= 1'b1;
            ram_addr  <= e_addr[ent][23:0] + {8'd0, e_len[ent]} - 24'd1;
            check_end <= 1'b1;
            wait_cnt  <= 3'd0;
            state     <= S_CHK_WAIT;
        end
        S_CHK_WAIT: begin
            wait_cnt <= wait_cnt + 3'd1;
            if (wait_cnt == 3'd3) begin
                ram_en <= 1'b0;
                if (ram_rdata != (check_end ? e_end[ent] : e_start[ent])) begin
                    // not ready: retry next vblank
                    ram_en <= 1'b0;
                    ent    <= 2'd0;
                    state  <= S_IDLE;
                end else if (!check_end) begin
                    state <= S_CHK_END;
                end else if (ent + 3'd1 < n_entries) begin
                    ent   <= ent + 2'd1;
                    state <= S_CHK_START;
                end else begin
                    // tables found: restore saved data if any
                    ent  <= 2'd0;
                    cnt  <= 16'd0;
                    bptr <= {BUF_AW{1'b0}};
                    state <= have_data ? S_COPY : S_READY;
                end
            end
        end
        S_IDLE: if (vbl_rise) state <= S_CHK_START;

        // buffer to RAM
        S_COPY: if (ram_grant) begin
            buf_addr <= bptr;
            wait_cnt <= 3'd0;
            ram_en   <= 1'b1;
            state    <= S_COPY_WAIT;
        end
        S_COPY_WAIT: begin
            wait_cnt <= wait_cnt + 3'd1;
            if (wait_cnt == 3'd1) begin
                ram_addr  <= e_addr[ent][23:0] + {8'd0, cnt};
                ram_wdata <= buf_q;
            end
            if (wait_cnt == 3'd2) ram_we <= 1'b1;
            if (wait_cnt == 3'd3) begin
                ram_en <= 1'b0;
                bptr   <= bptr + 1'd1;
                if (cnt + 16'd1 < e_len[ent]) begin
                    cnt   <= cnt + 16'd1;
                    state <= S_COPY;
                end else if (ent + 3'd1 < n_entries) begin
                    ent   <= ent + 2'd1;
                    cnt   <= 16'd0;
                    state <= S_COPY;
                end else begin
                    state <= S_READY;
                end
            end
        end

        // running: save on OSD open or request
        S_READY: begin
            if ((autosave && osd_open && !osd_d) || save_now) begin
                ent    <= 2'd0;
                cnt    <= 16'd0;
                bptr   <= {BUF_AW{1'b0}};
                state  <= S_DUMP;
            end
        end
        S_DUMP: if (ram_grant) begin
            ram_en   <= 1'b1;
            ram_addr <= e_addr[ent][23:0] + {8'd0, cnt};
            wait_cnt <= 3'd0;
            state    <= S_DUMP_WAIT;
        end
        S_DUMP_WAIT: begin
            wait_cnt <= wait_cnt + 3'd1;
            if (wait_cnt == 3'd3) begin
                ram_en    <= 1'b0;
                buf_addr  <= bptr;
                buf_wdata <= ram_rdata;
                buf_we    <= 1'b1;
                bptr      <= bptr + 1'd1;
                if (cnt + 16'd1 < e_len[ent]) begin
                    cnt   <= cnt + 16'd1;
                    state <= S_DUMP;
                end else if (ent + 3'd1 < n_entries) begin
                    ent   <= ent + 2'd1;
                    cnt   <= 16'd0;
                    state <= S_DUMP;
                end else begin
                    state <= S_DUMP_DONE;
                end
            end
        end
        S_DUMP_DONE: begin
            ioctl_upload_req <= 1'b1;
            state            <= S_READY;
        end

        default: state <= S_DELAY;
        endcase
    end
end

endmodule

`default_nettype wire

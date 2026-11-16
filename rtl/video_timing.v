
module video_timing
(
    input       clk,
    input       clk_pix,
    input       reset,

    input        h288,          // 288x224 picture (Legion / Crazy Climber 2 boards)
    input  signed [3:0] hs_offset,
    input  signed [3:0] vs_offset,

    input  signed [3:0] hs_width,
    input  signed [3:0] vs_width,

    output [8:0] hc,
    output [8:0] vc,

    output reg  hsync,
    output reg  vsync,

    output reg  hbl,
    output reg  vbl 
);

// 6MHz
wire [8:0] h_ofs = 0;
wire [8:0] HBL_START  = h288 ? 288+32 : 320 + 16;
wire [8:0] HBL_END    = h288 ? 32 : 16;
wire [8:0] HS_START   = HBL_START + 8;
wire [8:0] HS_END     = HBL_START + 40;
wire [8:0] HTOTAL     = 387 -1;

wire [8:0] v_ofs = 0;
wire [8:0] VBL_START  = h288 ? 240 : 256;
wire [8:0] VBL_END    = h288 ? 16 : 16;
wire [8:0] VS_START   = h288 ? 244 : 0;
wire [8:0] VS_END     = h288 ? 248 : 8;
wire [8:0] VTOTAL     = 262 ;

// Wraps a signed position into 0..last.
function [8:0] wrap;
    input signed [10:0] x;
    input        [8:0]  last;
    begin
        if ( x < 11'sd0 )
            wrap = x + $signed({2'b00, last}) + 11'sd1;
        else if ( x > $signed({2'b00, last}) )
            wrap = x - $signed({2'b00, last}) - 11'sd1;
        else
            wrap = x[8:0];
    end
endfunction

// Sync edges with the signed OSD adjustments; V-sync stays at least one line long.
wire signed [10:0] hs_on  = $signed({2'b00, HS_START}) + hs_offset;
wire signed [10:0] hs_off = $signed({2'b00, HS_END}) + hs_offset + hs_width;
wire signed [10:0] vs_len = $signed({2'b00, VS_END - VS_START}) + vs_width;
wire signed [10:0] vs_on  = $signed({2'b00, VS_START}) + vs_offset;

wire [8:0] HS_ON  = wrap( hs_on,  HTOTAL );
wire [8:0] HS_OFF = wrap( hs_off, HTOTAL );

// V-sync starts no earlier than the first blank line, where HDMI and rotation begin a frame.
wire [8:0] VS_POS = wrap( vs_on, VTOTAL );
wire [8:0] VS_ON  = ( VS_POS >= VBL_END && VS_POS < VBL_START ) ? VBL_START : VS_POS;
wire signed [10:0] vs_off = $signed({2'b00, VS_ON}) + ( vs_len < 11'sd1 ? 11'sd1 : vs_len );
wire [8:0] VS_OFF = wrap( vs_off, VTOTAL );

reg [8:0] v;
reg [8:0] h;

assign vc = v - v_ofs;
assign hc = h - h_ofs;

always @ (posedge clk) begin
    if (reset) begin
        h <= 0;
        v <= 0;

        hbl <= 0;
        vbl <= 0;

        hsync <= 0;
        vsync <= 0;
    end else if ( clk_pix == 1 ) begin 
        // counter
        if (h == HTOTAL) begin
            h <= 0;
            v <= v + 1'd1;

            if ( v == VTOTAL ) begin
                v <= 0;
            end
        end else begin
            h <= h + 1'd1;
        end

        // h signals
        if ( h == HBL_START ) begin
            hbl <= 1;
        end else if ( h == HBL_END ) begin
            hbl <= 0;
        end

        // v signals
        if ( v == VBL_START ) begin
            vbl <= 1;
        end else if ( v == VBL_END ) begin
            vbl <= 0;
        end
   
        if ( v == VS_ON ) begin
            vsync <= 1;
        end else if ( v == VS_OFF ) begin
            vsync <= 0;
        end

        if ( h == HS_ON ) begin
            hsync <= 1;
        end else if ( h == HS_OFF ) begin
            hsync <= 0;
        end
    end

end

endmodule



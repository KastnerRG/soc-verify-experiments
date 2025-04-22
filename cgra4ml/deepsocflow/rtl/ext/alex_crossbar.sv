/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 crossbar
 */
module axi_crossbar #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Input ID field width (from AXI masters)
    parameter S_ID_WIDTH = 8,
    // Output ID field width (towards AXI slaves)
    // Additional bits required for response routing
    parameter M_ID_WIDTH = S_ID_WIDTH+$clog2(S_COUNT),
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    // Number of concurrent unique IDs for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_THREADS = {S_COUNT{32'd2}},
    // Number of concurrent operations for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_ACCEPT = {S_COUNT{32'd16}},
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_READ = {M_COUNT{{S_COUNT{1'b1}}}},
    // Write connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT_WRITE = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AW channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AW_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface W channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_W_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface B channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_B_REG_TYPE = {S_COUNT{2'd1}},
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AR_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_R_REG_TYPE = {S_COUNT{2'd2}},
    // Master interface AW channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AW_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface W channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_W_REG_TYPE = {M_COUNT{2'd2}},
    // Master interface B channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_B_REG_TYPE = {M_COUNT{2'd0}},
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_awid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [S_COUNT*8-1:0]             s_axi_awlen,
    input  wire [S_COUNT*3-1:0]             s_axi_awsize,
    input  wire [S_COUNT*2-1:0]             s_axi_awburst,
    input  wire [S_COUNT-1:0]               s_axi_awlock,
    input  wire [S_COUNT*4-1:0]             s_axi_awcache,
    input  wire [S_COUNT*3-1:0]             s_axi_awprot,
    input  wire [S_COUNT*4-1:0]             s_axi_awqos,
    input  wire [S_COUNT*AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire [S_COUNT-1:0]               s_axi_awvalid,
    output wire [S_COUNT-1:0]               s_axi_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire [S_COUNT-1:0]               s_axi_wlast,
    input  wire [S_COUNT*WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire [S_COUNT-1:0]               s_axi_wvalid,
    output wire [S_COUNT-1:0]               s_axi_wready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_bid,
    output wire [S_COUNT*2-1:0]             s_axi_bresp,
    output wire [S_COUNT*BUSER_WIDTH-1:0]   s_axi_buser,
    output wire [S_COUNT-1:0]               s_axi_bvalid,
    input  wire [S_COUNT-1:0]               s_axi_bready,
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_arid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [S_COUNT*8-1:0]             s_axi_arlen,
    input  wire [S_COUNT*3-1:0]             s_axi_arsize,
    input  wire [S_COUNT*2-1:0]             s_axi_arburst,
    input  wire [S_COUNT-1:0]               s_axi_arlock,
    input  wire [S_COUNT*4-1:0]             s_axi_arcache,
    input  wire [S_COUNT*3-1:0]             s_axi_arprot,
    input  wire [S_COUNT*4-1:0]             s_axi_arqos,
    input  wire [S_COUNT*ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire [S_COUNT-1:0]               s_axi_arvalid,
    output wire [S_COUNT-1:0]               s_axi_arready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_rid,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [S_COUNT*2-1:0]             s_axi_rresp,
    output wire [S_COUNT-1:0]               s_axi_rlast,
    output wire [S_COUNT*RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire [S_COUNT-1:0]               s_axi_rvalid,
    input  wire [S_COUNT-1:0]               s_axi_rready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_awid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [M_COUNT*8-1:0]             m_axi_awlen,
    output wire [M_COUNT*3-1:0]             m_axi_awsize,
    output wire [M_COUNT*2-1:0]             m_axi_awburst,
    output wire [M_COUNT-1:0]               m_axi_awlock,
    output wire [M_COUNT*4-1:0]             m_axi_awcache,
    output wire [M_COUNT*3-1:0]             m_axi_awprot,
    output wire [M_COUNT*4-1:0]             m_axi_awqos,
    output wire [M_COUNT*4-1:0]             m_axi_awregion,
    output wire [M_COUNT*AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire [M_COUNT-1:0]               m_axi_awvalid,
    input  wire [M_COUNT-1:0]               m_axi_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire [M_COUNT-1:0]               m_axi_wlast,
    output wire [M_COUNT*WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire [M_COUNT-1:0]               m_axi_wvalid,
    input  wire [M_COUNT-1:0]               m_axi_wready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [M_COUNT*2-1:0]             m_axi_bresp,
    input  wire [M_COUNT*BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire [M_COUNT-1:0]               m_axi_bvalid,
    output wire [M_COUNT-1:0]               m_axi_bready,
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_arid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [M_COUNT*8-1:0]             m_axi_arlen,
    output wire [M_COUNT*3-1:0]             m_axi_arsize,
    output wire [M_COUNT*2-1:0]             m_axi_arburst,
    output wire [M_COUNT-1:0]               m_axi_arlock,
    output wire [M_COUNT*4-1:0]             m_axi_arcache,
    output wire [M_COUNT*3-1:0]             m_axi_arprot,
    output wire [M_COUNT*4-1:0]             m_axi_arqos,
    output wire [M_COUNT*4-1:0]             m_axi_arregion,
    output wire [M_COUNT*ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire [M_COUNT-1:0]               m_axi_arvalid,
    input  wire [M_COUNT-1:0]               m_axi_arready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [M_COUNT*2-1:0]             m_axi_rresp,
    input  wire [M_COUNT-1:0]               m_axi_rlast,
    input  wire [M_COUNT*RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire [M_COUNT-1:0]               m_axi_rvalid,
    output wire [M_COUNT-1:0]               m_axi_rready
);

axi_crossbar_wr #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .S_ID_WIDTH(S_ID_WIDTH),
    .M_ID_WIDTH(M_ID_WIDTH),
    .AWUSER_ENABLE(AWUSER_ENABLE),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_ENABLE(WUSER_ENABLE),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_ENABLE(BUSER_ENABLE),
    .BUSER_WIDTH(BUSER_WIDTH),
    .S_THREADS(S_THREADS),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH(M_ADDR_WIDTH),
    .M_CONNECT(M_CONNECT_WRITE),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AW_REG_TYPE(S_AW_REG_TYPE),
    .S_W_REG_TYPE (S_W_REG_TYPE),
    .S_B_REG_TYPE (S_B_REG_TYPE)
)
axi_crossbar_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI slave interfaces
     */
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awuser(s_axi_awuser),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wuser(s_axi_wuser),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_buser(s_axi_buser),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),

    /*
     * AXI master interfaces
     */
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awqos(m_axi_awqos),
    .m_axi_awregion(m_axi_awregion),
    .m_axi_awuser(m_axi_awuser),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wuser(m_axi_wuser),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_buser(m_axi_buser),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready)
);

axi_crossbar_rd #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .S_ID_WIDTH(S_ID_WIDTH),
    .M_ID_WIDTH(M_ID_WIDTH),
    .ARUSER_ENABLE(ARUSER_ENABLE),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_ENABLE(RUSER_ENABLE),
    .RUSER_WIDTH(RUSER_WIDTH),
    .S_THREADS(S_THREADS),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_WIDTH(M_ADDR_WIDTH),
    .M_CONNECT(M_CONNECT_READ),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AR_REG_TYPE(S_AR_REG_TYPE),
    .S_R_REG_TYPE (S_R_REG_TYPE)
)
axi_crossbar_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI slave interfaces
     */
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(s_axi_arqos),
    .s_axi_aruser(s_axi_aruser),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_ruser(s_axi_ruser),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    /*
     * AXI master interfaces
     */
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arqos(m_axi_arqos),
    .m_axi_arregion(m_axi_arregion),
    .m_axi_aruser(m_axi_aruser),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_ruser(m_axi_ruser),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready)
);

endmodule
`resetall

/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 crossbar address decode and admission control
 */
module axi_crossbar_addr #
(
    // Slave interface index
    parameter S = 0,
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // ID field width
    parameter ID_WIDTH = 8,
    // Number of concurrent unique IDs
    parameter S_THREADS = 32'd2,
    // Number of concurrent operations
    parameter S_ACCEPT = 32'd16,
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Enable write command output
    parameter WC_OUTPUT = 0
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * Address input
     */
    input  wire [ID_WIDTH-1:0]        s_axi_aid,
    input  wire [ADDR_WIDTH-1:0]      s_axi_aaddr,
    input  wire [2:0]                 s_axi_aprot,
    input  wire [3:0]                 s_axi_aqos,
    input  wire                       s_axi_avalid,
    output wire                       s_axi_aready,

    /*
     * Address output
     */
    output wire [3:0]                 m_axi_aregion,
    output wire [$clog2(M_COUNT)-1:0] m_select,
    output wire                       m_axi_avalid,
    input  wire                       m_axi_aready,

    /*
     * Write command output
     */
    output wire [$clog2(M_COUNT)-1:0] m_wc_select,
    output wire                       m_wc_decerr,
    output wire                       m_wc_valid,
    input  wire                       m_wc_ready,

    /*
     * Reply command output
     */
    output wire                       m_rc_decerr,
    output wire                       m_rc_valid,
    input  wire                       m_rc_ready,

    /*
     * Completion input
     */
    input  wire [ID_WIDTH-1:0]        s_cpl_id,
    input  wire                       s_cpl_valid
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);

parameter S_INT_THREADS = S_THREADS > S_ACCEPT ? S_ACCEPT : S_THREADS;
parameter CL_S_INT_THREADS = $clog2(S_INT_THREADS);
parameter CL_S_ACCEPT = $clog2(S_ACCEPT);

// default address computation
function [M_COUNT*M_REGIONS*ADDR_WIDTH-1:0] calcBaseAddrs(input [31:0] dummy);
    integer i;
    reg [ADDR_WIDTH-1:0] base;
    reg [ADDR_WIDTH-1:0] width;
    reg [ADDR_WIDTH-1:0] size;
    reg [ADDR_WIDTH-1:0] mask;
    begin
        calcBaseAddrs = {M_COUNT*M_REGIONS*ADDR_WIDTH{1'b0}};
        base = 0;
        for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
            width = M_ADDR_WIDTH[i*32 +: 32];
            mask = {ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - width);
            size = mask + 1;
            if (width > 0) begin
                if ((base & mask) != 0) begin
                   base = base + size - (base & mask); // align
                end
                calcBaseAddrs[i * ADDR_WIDTH +: ADDR_WIDTH] = base;
                base = base + size; // increment
            end
        end
    end
endfunction

parameter M_BASE_ADDR_INT = M_BASE_ADDR ? M_BASE_ADDR : calcBaseAddrs(0);

integer i, j;

// check configuration
initial begin
    if (S_ACCEPT < 1) begin
        $error("Error: need at least 1 accept (instance %m)");
        $finish;
    end

    if (S_THREADS < 1) begin
        $error("Error: need at least 1 thread (instance %m)");
        $finish;
    end

    if (S_THREADS > S_ACCEPT) begin
        $warning("Warning: requested thread count larger than accept count; limiting thread count to accept count (instance %m)");
    end

    if (M_REGIONS < 1) begin
        $error("Error: need at least 1 region (instance %m)");
        $finish;
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: address width out of range (instance %m)");
            $finish;
        end
    end

    $display("Addressing configuration for axi_crossbar_addr instance %m");
    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32]) begin
            $display("%2d (%2d): %x / %02d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                M_ADDR_WIDTH[i*32 +: 32],
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
            );
        end
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if ((M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & (2**M_ADDR_WIDTH[i*32 +: 32]-1)) != 0) begin
            $display("Region not aligned:");
            $display("%2d (%2d): %x / %2d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                M_ADDR_WIDTH[i*32 +: 32],
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
            );
            $error("Error: address range not aligned (instance %m)");
            $finish;
        end
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        for (j = i+1; j < M_COUNT*M_REGIONS; j = j + 1) begin
            if (M_ADDR_WIDTH[i*32 +: 32] && M_ADDR_WIDTH[j*32 +: 32]) begin
                if (((M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32])) <= (M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[j*32 +: 32]))))
                        && ((M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[j*32 +: 32])) <= (M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))))) begin
                    $display("Overlapping regions:");
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        i/M_REGIONS, i%M_REGIONS,
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH],
                        M_ADDR_WIDTH[i*32 +: 32],
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[i*32 +: 32]),
                        M_BASE_ADDR_INT[i*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[i*32 +: 32]))
                    );
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        j/M_REGIONS, j%M_REGIONS,
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH],
                        M_ADDR_WIDTH[j*32 +: 32],
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] & ({ADDR_WIDTH{1'b1}} << M_ADDR_WIDTH[j*32 +: 32]),
                        M_BASE_ADDR_INT[j*ADDR_WIDTH +: ADDR_WIDTH] | ({ADDR_WIDTH{1'b1}} >> (ADDR_WIDTH - M_ADDR_WIDTH[j*32 +: 32]))
                    );
                    $error("Error: address ranges overlap (instance %m)");
                    $finish;
                end
            end
        end
    end
end

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_DECODE = 3'd1;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg s_axi_aready_reg = 0, s_axi_aready_next;

reg [3:0] m_axi_aregion_reg = 4'd0, m_axi_aregion_next;
reg [CL_M_COUNT-1:0] m_select_reg = 0, m_select_next;
reg m_axi_avalid_reg = 1'b0, m_axi_avalid_next;
reg m_decerr_reg = 1'b0, m_decerr_next;
reg m_wc_valid_reg = 1'b0, m_wc_valid_next;
reg m_rc_valid_reg = 1'b0, m_rc_valid_next;

assign s_axi_aready = s_axi_aready_reg;

assign m_axi_aregion = m_axi_aregion_reg;
assign m_select = m_select_reg;
assign m_axi_avalid = m_axi_avalid_reg;

assign m_wc_select = m_select_reg;
assign m_wc_decerr = m_decerr_reg;
assign m_wc_valid = m_wc_valid_reg;

assign m_rc_decerr = m_decerr_reg;
assign m_rc_valid = m_rc_valid_reg;

reg match;
reg trans_start;
reg trans_complete;

reg [$clog2(S_ACCEPT+1)-1:0] trans_count_reg = 0;
wire trans_limit = trans_count_reg >= S_ACCEPT && !trans_complete;

// transfer ID thread tracking
reg [ID_WIDTH-1:0] thread_id_reg[S_INT_THREADS-1:0];
reg [CL_M_COUNT-1:0] thread_m_reg[S_INT_THREADS-1:0];
reg [3:0] thread_region_reg[S_INT_THREADS-1:0];
reg [$clog2(S_ACCEPT+1)-1:0] thread_count_reg[S_INT_THREADS-1:0];

wire [S_INT_THREADS-1:0] thread_active;
wire [S_INT_THREADS-1:0] thread_match;
wire [S_INT_THREADS-1:0] thread_match_dest;
wire [S_INT_THREADS-1:0] thread_cpl_match;
wire [S_INT_THREADS-1:0] thread_trans_start;
wire [S_INT_THREADS-1:0] thread_trans_complete;

generate
    genvar n;

    for (n = 0; n < S_INT_THREADS; n = n + 1) begin
        initial begin
            thread_count_reg[n] <= 0;
        end

        assign thread_active[n] = thread_count_reg[n] != 0;
        assign thread_match[n] = thread_active[n] && thread_id_reg[n] == s_axi_aid;
        assign thread_match_dest[n] = thread_match[n] && thread_m_reg[n] == m_select_next && (M_REGIONS < 2 || thread_region_reg[n] == m_axi_aregion_next);
        assign thread_cpl_match[n] = thread_active[n] && thread_id_reg[n] == s_cpl_id;
        assign thread_trans_start[n] = (thread_match[n] || (!thread_active[n] && !thread_match && !(thread_trans_start & ({S_INT_THREADS{1'b1}} >> (S_INT_THREADS-n))))) && trans_start;
        assign thread_trans_complete[n] = thread_cpl_match[n] && trans_complete;

        always @(posedge clk) begin
            if (rst) begin
                thread_count_reg[n] <= 0;
            end else begin
                if (thread_trans_start[n] && !thread_trans_complete[n]) begin
                    thread_count_reg[n] <= thread_count_reg[n] + 1;
                end else if (!thread_trans_start[n] && thread_trans_complete[n]) begin
                    thread_count_reg[n] <= thread_count_reg[n] - 1;
                end
            end

            if (thread_trans_start[n]) begin
                thread_id_reg[n] <= s_axi_aid;
                thread_m_reg[n] <= m_select_next;
                thread_region_reg[n] <= m_axi_aregion_next;
            end
        end
    end
endgenerate

always @* begin
    state_next = STATE_IDLE;

    match = 1'b0;
    trans_start = 1'b0;
    trans_complete = 1'b0;

    s_axi_aready_next = 1'b0;

    m_axi_aregion_next = m_axi_aregion_reg;
    m_select_next = m_select_reg;
    m_axi_avalid_next = m_axi_avalid_reg && !m_axi_aready;
    m_decerr_next = m_decerr_reg;
    m_wc_valid_next = m_wc_valid_reg && !m_wc_ready;
    m_rc_valid_next = m_rc_valid_reg && !m_rc_ready;

    case (state_reg)
        STATE_IDLE: begin
            // idle state, store values
            s_axi_aready_next = 1'b0;

            if (s_axi_avalid && !s_axi_aready) begin
                match = 1'b0;
                for (i = 0; i < M_COUNT; i = i + 1) begin
                    for (j = 0; j < M_REGIONS; j = j + 1) begin
                        if (M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32] && (!M_SECURE[i] || !s_axi_aprot[1]) && (M_CONNECT & (1 << (S+i*S_COUNT))) && (s_axi_aaddr >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32]) == (M_BASE_ADDR_INT[(i*M_REGIONS+j)*ADDR_WIDTH +: ADDR_WIDTH] >> M_ADDR_WIDTH[(i*M_REGIONS+j)*32 +: 32])) begin
                            m_select_next = i;
                            m_axi_aregion_next = j;
                            match = 1'b1;
                        end
                    end
                end

                if (match) begin
                    // address decode successful
                    if (!trans_limit && (thread_match_dest || (!(&thread_active) && !thread_match))) begin
                        // transaction limit not reached
                        m_axi_avalid_next = 1'b1;
                        m_decerr_next = 1'b0;
                        m_wc_valid_next = WC_OUTPUT;
                        m_rc_valid_next = 1'b0;
                        trans_start = 1'b1;
                        state_next = STATE_DECODE;
                    end else begin
                        // transaction limit reached; block in idle
                        state_next = STATE_IDLE;
                    end
                end else begin
                    // decode error
                    m_axi_avalid_next = 1'b0;
                    m_decerr_next = 1'b1;
                    m_wc_valid_next = WC_OUTPUT;
                    m_rc_valid_next = 1'b1;
                    state_next = STATE_DECODE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DECODE: begin
            if (!m_axi_avalid_next && (!m_wc_valid_next || !WC_OUTPUT) && !m_rc_valid_next) begin
                s_axi_aready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DECODE;
            end
        end
    endcase

    // manage completions
    trans_complete = s_cpl_valid;
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axi_aready_reg <= 1'b0;
        m_axi_avalid_reg <= 1'b0;
        m_wc_valid_reg <= 1'b0;
        m_rc_valid_reg <= 1'b0;

        trans_count_reg <= 0;
    end else begin
        state_reg <= state_next;
        s_axi_aready_reg <= s_axi_aready_next;
        m_axi_avalid_reg <= m_axi_avalid_next;
        m_wc_valid_reg <= m_wc_valid_next;
        m_rc_valid_reg <= m_rc_valid_next;

        if (trans_start && !trans_complete) begin
            trans_count_reg <= trans_count_reg + 1;
        end else if (!trans_start && trans_complete) begin
            trans_count_reg <= trans_count_reg - 1;
        end
    end

    m_axi_aregion_reg <= m_axi_aregion_next;
    m_select_reg <= m_select_next;
    m_decerr_reg <= m_decerr_next;
end

endmodule

`resetall

/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 crossbar (read)
 */
module axi_crossbar_rd #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Input ID field width (from AXI masters)
    parameter S_ID_WIDTH = 8,
    // Output ID field width (towards AXI slaves)
    // Additional bits required for response routing
    parameter M_ID_WIDTH = S_ID_WIDTH+$clog2(S_COUNT),
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    // Number of concurrent unique IDs for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_THREADS = {S_COUNT{32'd2}},
    // Number of concurrent operations for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_ACCEPT = {S_COUNT{32'd16}},
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AR_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_R_REG_TYPE = {S_COUNT{2'd2}},
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_arid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [S_COUNT*8-1:0]             s_axi_arlen,
    input  wire [S_COUNT*3-1:0]             s_axi_arsize,
    input  wire [S_COUNT*2-1:0]             s_axi_arburst,
    input  wire [S_COUNT-1:0]               s_axi_arlock,
    input  wire [S_COUNT*4-1:0]             s_axi_arcache,
    input  wire [S_COUNT*3-1:0]             s_axi_arprot,
    input  wire [S_COUNT*4-1:0]             s_axi_arqos,
    input  wire [S_COUNT*ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire [S_COUNT-1:0]               s_axi_arvalid,
    output wire [S_COUNT-1:0]               s_axi_arready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_rid,
    output wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [S_COUNT*2-1:0]             s_axi_rresp,
    output wire [S_COUNT-1:0]               s_axi_rlast,
    output wire [S_COUNT*RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire [S_COUNT-1:0]               s_axi_rvalid,
    input  wire [S_COUNT-1:0]               s_axi_rready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_arid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [M_COUNT*8-1:0]             m_axi_arlen,
    output wire [M_COUNT*3-1:0]             m_axi_arsize,
    output wire [M_COUNT*2-1:0]             m_axi_arburst,
    output wire [M_COUNT-1:0]               m_axi_arlock,
    output wire [M_COUNT*4-1:0]             m_axi_arcache,
    output wire [M_COUNT*3-1:0]             m_axi_arprot,
    output wire [M_COUNT*4-1:0]             m_axi_arqos,
    output wire [M_COUNT*4-1:0]             m_axi_arregion,
    output wire [M_COUNT*ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire [M_COUNT-1:0]               m_axi_arvalid,
    input  wire [M_COUNT-1:0]               m_axi_arready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [M_COUNT*2-1:0]             m_axi_rresp,
    input  wire [M_COUNT-1:0]               m_axi_rlast,
    input  wire [M_COUNT*RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire [M_COUNT-1:0]               m_axi_rvalid,
    output wire [M_COUNT-1:0]               m_axi_rready
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);
parameter M_COUNT_P1 = M_COUNT+1;
parameter CL_M_COUNT_P1 = $clog2(M_COUNT_P1);

integer i;

// check configuration
initial begin
    if (M_ID_WIDTH < S_ID_WIDTH+$clog2(S_COUNT)) begin
        $error("Error: M_ID_WIDTH must be at least $clog2(S_COUNT) larger than S_ID_WIDTH (instance %m)");
        $finish;
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: value out of range (instance %m)");
            $finish;
        end
    end
end

wire [S_COUNT*S_ID_WIDTH-1:0]    int_s_axi_arid;
wire [S_COUNT*ADDR_WIDTH-1:0]    int_s_axi_araddr;
wire [S_COUNT*8-1:0]             int_s_axi_arlen;
wire [S_COUNT*3-1:0]             int_s_axi_arsize;
wire [S_COUNT*2-1:0]             int_s_axi_arburst;
wire [S_COUNT-1:0]               int_s_axi_arlock;
wire [S_COUNT*4-1:0]             int_s_axi_arcache;
wire [S_COUNT*3-1:0]             int_s_axi_arprot;
wire [S_COUNT*4-1:0]             int_s_axi_arqos;
wire [S_COUNT*4-1:0]             int_s_axi_arregion;
wire [S_COUNT*ARUSER_WIDTH-1:0]  int_s_axi_aruser;
wire [S_COUNT-1:0]               int_s_axi_arvalid;
wire [S_COUNT-1:0]               int_s_axi_arready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_arvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_arready;

wire [M_COUNT*M_ID_WIDTH-1:0]    int_m_axi_rid;
wire [M_COUNT*DATA_WIDTH-1:0]    int_m_axi_rdata;
wire [M_COUNT*2-1:0]             int_m_axi_rresp;
wire [M_COUNT-1:0]               int_m_axi_rlast;
wire [M_COUNT*RUSER_WIDTH-1:0]   int_m_axi_ruser;
wire [M_COUNT-1:0]               int_m_axi_rvalid;
wire [M_COUNT-1:0]               int_m_axi_rready;

wire [M_COUNT*S_COUNT-1:0]       int_axi_rvalid;
wire [S_COUNT*M_COUNT-1:0]       int_axi_rready;

generate

    genvar m, n;

    for (m = 0; m < S_COUNT; m = m + 1) begin : s_ifaces
        // address decode and admission control
        wire [CL_M_COUNT-1:0] a_select;

        wire m_axi_avalid;
        wire m_axi_aready;

        wire m_rc_decerr;
        wire m_rc_valid;
        wire m_rc_ready;

        wire [S_ID_WIDTH-1:0] s_cpl_id;
        wire s_cpl_valid;

        axi_crossbar_addr #(
            .S(m),
            .S_COUNT(S_COUNT),
            .M_COUNT(M_COUNT),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .S_THREADS(S_THREADS[m*32 +: 32]),
            .S_ACCEPT(S_ACCEPT[m*32 +: 32]),
            .M_REGIONS(M_REGIONS),
            .M_BASE_ADDR(M_BASE_ADDR),
            .M_ADDR_WIDTH(M_ADDR_WIDTH),
            .M_CONNECT(M_CONNECT),
            .M_SECURE(M_SECURE),
            .WC_OUTPUT(0)
        )
        addr_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Address input
             */
            .s_axi_aid(int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_aaddr(int_s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_aprot(int_s_axi_arprot[m*3 +: 3]),
            .s_axi_aqos(int_s_axi_arqos[m*4 +: 4]),
            .s_axi_avalid(int_s_axi_arvalid[m]),
            .s_axi_aready(int_s_axi_arready[m]),

            /*
             * Address output
             */
            .m_axi_aregion(int_s_axi_arregion[m*4 +: 4]),
            .m_select(a_select),
            .m_axi_avalid(m_axi_avalid),
            .m_axi_aready(m_axi_aready),

            /*
             * Write command output
             */
            .m_wc_select(),
            .m_wc_decerr(),
            .m_wc_valid(),
            .m_wc_ready(1'b1),

            /*
             * Response command output
             */
            .m_rc_decerr(m_rc_decerr),
            .m_rc_valid(m_rc_valid),
            .m_rc_ready(m_rc_ready),

            /*
             * Completion input
             */
            .s_cpl_id(s_cpl_id),
            .s_cpl_valid(s_cpl_valid)
        );

        assign int_axi_arvalid[m*M_COUNT +: M_COUNT] = m_axi_avalid << a_select;
        assign m_axi_aready = int_axi_arready[a_select*S_COUNT+m];

        // decode error handling
        reg [S_ID_WIDTH-1:0]  decerr_m_axi_rid_reg = {S_ID_WIDTH{1'b0}}, decerr_m_axi_rid_next;
        reg                   decerr_m_axi_rlast_reg = 1'b0, decerr_m_axi_rlast_next;
        reg                   decerr_m_axi_rvalid_reg = 1'b0, decerr_m_axi_rvalid_next;
        wire                  decerr_m_axi_rready;

        reg [7:0] decerr_len_reg = 8'd0, decerr_len_next;

        assign m_rc_ready = !decerr_m_axi_rvalid_reg;

        always @* begin
            decerr_len_next = decerr_len_reg;
            decerr_m_axi_rid_next = decerr_m_axi_rid_reg;
            decerr_m_axi_rlast_next = decerr_m_axi_rlast_reg;
            decerr_m_axi_rvalid_next = decerr_m_axi_rvalid_reg;

            if (decerr_m_axi_rvalid_reg) begin
                if (decerr_m_axi_rready) begin
                    if (decerr_len_reg > 0) begin
                        decerr_len_next = decerr_len_reg-1;
                        decerr_m_axi_rlast_next = (decerr_len_next == 0);
                        decerr_m_axi_rvalid_next = 1'b1;
                    end else begin
                        decerr_m_axi_rvalid_next = 1'b0;
                    end
                end
            end else if (m_rc_valid && m_rc_ready) begin
                decerr_len_next = int_s_axi_arlen[m*8 +: 8];
                decerr_m_axi_rid_next = int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH];
                decerr_m_axi_rlast_next = (decerr_len_next == 0);
                decerr_m_axi_rvalid_next = 1'b1;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                decerr_m_axi_rvalid_reg <= 1'b0;
            end else begin
                decerr_m_axi_rvalid_reg <= decerr_m_axi_rvalid_next;
            end

            decerr_m_axi_rid_reg <= decerr_m_axi_rid_next;
            decerr_m_axi_rlast_reg <= decerr_m_axi_rlast_next;
            decerr_len_reg <= decerr_len_next;
        end

        // read response arbitration
        wire [M_COUNT_P1-1:0] r_request;
        wire [M_COUNT_P1-1:0] r_acknowledge;
        wire [M_COUNT_P1-1:0] r_grant;
        wire r_grant_valid;
        wire [CL_M_COUNT_P1-1:0] r_grant_encoded;

        arbiter #(
            .PORTS(M_COUNT_P1),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        r_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(r_request),
            .acknowledge(r_acknowledge),
            .grant(r_grant),
            .grant_valid(r_grant_valid),
            .grant_encoded(r_grant_encoded)
        );

        // read response mux
        wire [S_ID_WIDTH-1:0]  m_axi_rid_mux    = {decerr_m_axi_rid_reg, int_m_axi_rid} >> r_grant_encoded*M_ID_WIDTH;
        wire [DATA_WIDTH-1:0]  m_axi_rdata_mux  = {{DATA_WIDTH{1'b0}}, int_m_axi_rdata} >> r_grant_encoded*DATA_WIDTH;
        wire [1:0]             m_axi_rresp_mux  = {2'b11, int_m_axi_rresp} >> r_grant_encoded*2;
        wire                   m_axi_rlast_mux  = {decerr_m_axi_rlast_reg, int_m_axi_rlast} >> r_grant_encoded;
        wire [RUSER_WIDTH-1:0] m_axi_ruser_mux  = {{RUSER_WIDTH{1'b0}}, int_m_axi_ruser} >> r_grant_encoded*RUSER_WIDTH;
        wire                   m_axi_rvalid_mux = ({decerr_m_axi_rvalid_reg, int_m_axi_rvalid} >> r_grant_encoded) & r_grant_valid;
        wire                   m_axi_rready_mux;

        assign int_axi_rready[m*M_COUNT +: M_COUNT] = (r_grant_valid && m_axi_rready_mux) << r_grant_encoded;
        assign decerr_m_axi_rready = (r_grant_valid && m_axi_rready_mux) && (r_grant_encoded == M_COUNT_P1-1);

        for (n = 0; n < M_COUNT; n = n + 1) begin
            assign r_request[n] = int_axi_rvalid[n*S_COUNT+m] && !r_grant[n];
            assign r_acknowledge[n] = r_grant[n] && int_axi_rvalid[n*S_COUNT+m] && m_axi_rlast_mux && m_axi_rready_mux;
        end

        assign r_request[M_COUNT_P1-1] = decerr_m_axi_rvalid_reg && !r_grant[M_COUNT_P1-1];
        assign r_acknowledge[M_COUNT_P1-1] = r_grant[M_COUNT_P1-1] && decerr_m_axi_rvalid_reg && decerr_m_axi_rlast_reg && m_axi_rready_mux;

        assign s_cpl_id = m_axi_rid_mux;
        assign s_cpl_valid = m_axi_rvalid_mux && m_axi_rready_mux && m_axi_rlast_mux;

        // S side register
        axi_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .ARUSER_ENABLE(ARUSER_ENABLE),
            .ARUSER_WIDTH(ARUSER_WIDTH),
            .RUSER_ENABLE(RUSER_ENABLE),
            .RUSER_WIDTH(RUSER_WIDTH),
            .AR_REG_TYPE(S_AR_REG_TYPE[m*2 +: 2]),
            .R_REG_TYPE(S_R_REG_TYPE[m*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_arid(s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_araddr(s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_arlen(s_axi_arlen[m*8 +: 8]),
            .s_axi_arsize(s_axi_arsize[m*3 +: 3]),
            .s_axi_arburst(s_axi_arburst[m*2 +: 2]),
            .s_axi_arlock(s_axi_arlock[m]),
            .s_axi_arcache(s_axi_arcache[m*4 +: 4]),
            .s_axi_arprot(s_axi_arprot[m*3 +: 3]),
            .s_axi_arqos(s_axi_arqos[m*4 +: 4]),
            .s_axi_arregion(4'd0),
            .s_axi_aruser(s_axi_aruser[m*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .s_axi_arvalid(s_axi_arvalid[m]),
            .s_axi_arready(s_axi_arready[m]),
            .s_axi_rid(s_axi_rid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_rdata(s_axi_rdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_rresp(s_axi_rresp[m*2 +: 2]),
            .s_axi_rlast(s_axi_rlast[m]),
            .s_axi_ruser(s_axi_ruser[m*RUSER_WIDTH +: RUSER_WIDTH]),
            .s_axi_rvalid(s_axi_rvalid[m]),
            .s_axi_rready(s_axi_rready[m]),
            .m_axi_arid(int_s_axi_arid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .m_axi_araddr(int_s_axi_araddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_arlen(int_s_axi_arlen[m*8 +: 8]),
            .m_axi_arsize(int_s_axi_arsize[m*3 +: 3]),
            .m_axi_arburst(int_s_axi_arburst[m*2 +: 2]),
            .m_axi_arlock(int_s_axi_arlock[m]),
            .m_axi_arcache(int_s_axi_arcache[m*4 +: 4]),
            .m_axi_arprot(int_s_axi_arprot[m*3 +: 3]),
            .m_axi_arqos(int_s_axi_arqos[m*4 +: 4]),
            .m_axi_arregion(),
            .m_axi_aruser(int_s_axi_aruser[m*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .m_axi_arvalid(int_s_axi_arvalid[m]),
            .m_axi_arready(int_s_axi_arready[m]),
            .m_axi_rid(m_axi_rid_mux),
            .m_axi_rdata(m_axi_rdata_mux),
            .m_axi_rresp(m_axi_rresp_mux),
            .m_axi_rlast(m_axi_rlast_mux),
            .m_axi_ruser(m_axi_ruser_mux),
            .m_axi_rvalid(m_axi_rvalid_mux),
            .m_axi_rready(m_axi_rready_mux)
        );
    end // s_ifaces

    for (n = 0; n < M_COUNT; n = n + 1) begin : m_ifaces
        // in-flight transaction count
        wire trans_start;
        wire trans_complete;
        reg [$clog2(M_ISSUE[n*32 +: 32]+1)-1:0] trans_count_reg = 0;

        wire trans_limit = trans_count_reg >= M_ISSUE[n*32 +: 32] && !trans_complete;

        always @(posedge clk) begin
            if (rst) begin
                trans_count_reg <= 0;
            end else begin
                if (trans_start && !trans_complete) begin
                    trans_count_reg <= trans_count_reg + 1;
                end else if (!trans_start && trans_complete) begin
                    trans_count_reg <= trans_count_reg - 1;
                end
            end
        end

        // address arbitration
        wire [S_COUNT-1:0] a_request;
        wire [S_COUNT-1:0] a_acknowledge;
        wire [S_COUNT-1:0] a_grant;
        wire a_grant_valid;
        wire [CL_S_COUNT-1:0] a_grant_encoded;

        arbiter #(
            .PORTS(S_COUNT),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        a_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(a_request),
            .acknowledge(a_acknowledge),
            .grant(a_grant),
            .grant_valid(a_grant_valid),
            .grant_encoded(a_grant_encoded)
        );

        // address mux
        wire [M_ID_WIDTH-1:0]   s_axi_arid_mux     = int_s_axi_arid[a_grant_encoded*S_ID_WIDTH +: S_ID_WIDTH] | (a_grant_encoded << S_ID_WIDTH);
        wire [ADDR_WIDTH-1:0]   s_axi_araddr_mux   = int_s_axi_araddr[a_grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
        wire [7:0]              s_axi_arlen_mux    = int_s_axi_arlen[a_grant_encoded*8 +: 8];
        wire [2:0]              s_axi_arsize_mux   = int_s_axi_arsize[a_grant_encoded*3 +: 3];
        wire [1:0]              s_axi_arburst_mux  = int_s_axi_arburst[a_grant_encoded*2 +: 2];
        wire                    s_axi_arlock_mux   = int_s_axi_arlock[a_grant_encoded];
        wire [3:0]              s_axi_arcache_mux  = int_s_axi_arcache[a_grant_encoded*4 +: 4];
        wire [2:0]              s_axi_arprot_mux   = int_s_axi_arprot[a_grant_encoded*3 +: 3];
        wire [3:0]              s_axi_arqos_mux    = int_s_axi_arqos[a_grant_encoded*4 +: 4];
        wire [3:0]              s_axi_arregion_mux = int_s_axi_arregion[a_grant_encoded*4 +: 4];
        wire [ARUSER_WIDTH-1:0] s_axi_aruser_mux   = int_s_axi_aruser[a_grant_encoded*ARUSER_WIDTH +: ARUSER_WIDTH];
        wire                    s_axi_arvalid_mux  = int_axi_arvalid[a_grant_encoded*M_COUNT+n] && a_grant_valid;
        wire                    s_axi_arready_mux;

        assign int_axi_arready[n*S_COUNT +: S_COUNT] = (a_grant_valid && s_axi_arready_mux) << a_grant_encoded;

        for (m = 0; m < S_COUNT; m = m + 1) begin
            assign a_request[m] = int_axi_arvalid[m*M_COUNT+n] && !a_grant[m] && !trans_limit;
            assign a_acknowledge[m] = a_grant[m] && int_axi_arvalid[m*M_COUNT+n] && s_axi_arready_mux;
        end

        assign trans_start = s_axi_arvalid_mux && s_axi_arready_mux && a_grant_valid;

        // read response forwarding
        wire [CL_S_COUNT-1:0] r_select = m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH] >> S_ID_WIDTH;

        assign int_axi_rvalid[n*S_COUNT +: S_COUNT] = int_m_axi_rvalid[n] << r_select;
        assign int_m_axi_rready[n] = int_axi_rready[r_select*M_COUNT+n];

        assign trans_complete = int_m_axi_rvalid[n] && int_m_axi_rready[n] && int_m_axi_rlast[n];

        // M side register
        axi_register_rd #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(M_ID_WIDTH),
            .ARUSER_ENABLE(ARUSER_ENABLE),
            .ARUSER_WIDTH(ARUSER_WIDTH),
            .RUSER_ENABLE(RUSER_ENABLE),
            .RUSER_WIDTH(RUSER_WIDTH),
            .AR_REG_TYPE(M_AR_REG_TYPE[n*2 +: 2]),
            .R_REG_TYPE(M_R_REG_TYPE[n*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_arid(s_axi_arid_mux),
            .s_axi_araddr(s_axi_araddr_mux),
            .s_axi_arlen(s_axi_arlen_mux),
            .s_axi_arsize(s_axi_arsize_mux),
            .s_axi_arburst(s_axi_arburst_mux),
            .s_axi_arlock(s_axi_arlock_mux),
            .s_axi_arcache(s_axi_arcache_mux),
            .s_axi_arprot(s_axi_arprot_mux),
            .s_axi_arqos(s_axi_arqos_mux),
            .s_axi_arregion(s_axi_arregion_mux),
            .s_axi_aruser(s_axi_aruser_mux),
            .s_axi_arvalid(s_axi_arvalid_mux),
            .s_axi_arready(s_axi_arready_mux),
            .s_axi_rid(int_m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .s_axi_rdata(int_m_axi_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_rresp(int_m_axi_rresp[n*2 +: 2]),
            .s_axi_rlast(int_m_axi_rlast[n]),
            .s_axi_ruser(int_m_axi_ruser[n*RUSER_WIDTH +: RUSER_WIDTH]),
            .s_axi_rvalid(int_m_axi_rvalid[n]),
            .s_axi_rready(int_m_axi_rready[n]),
            .m_axi_arid(m_axi_arid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_araddr(m_axi_araddr[n*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_arlen(m_axi_arlen[n*8 +: 8]),
            .m_axi_arsize(m_axi_arsize[n*3 +: 3]),
            .m_axi_arburst(m_axi_arburst[n*2 +: 2]),
            .m_axi_arlock(m_axi_arlock[n]),
            .m_axi_arcache(m_axi_arcache[n*4 +: 4]),
            .m_axi_arprot(m_axi_arprot[n*3 +: 3]),
            .m_axi_arqos(m_axi_arqos[n*4 +: 4]),
            .m_axi_arregion(m_axi_arregion[n*4 +: 4]),
            .m_axi_aruser(m_axi_aruser[n*ARUSER_WIDTH +: ARUSER_WIDTH]),
            .m_axi_arvalid(m_axi_arvalid[n]),
            .m_axi_arready(m_axi_arready[n]),
            .m_axi_rid(m_axi_rid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_rdata(m_axi_rdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_rresp(m_axi_rresp[n*2 +: 2]),
            .m_axi_rlast(m_axi_rlast[n]),
            .m_axi_ruser(m_axi_ruser[n*RUSER_WIDTH +: RUSER_WIDTH]),
            .m_axi_rvalid(m_axi_rvalid[n]),
            .m_axi_rready(m_axi_rready[n])
        );
    end // m_ifaces

endgenerate

endmodule

`resetall

/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 crossbar (write)
 */
module axi_crossbar_wr #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Input ID field width (from AXI masters)
    parameter S_ID_WIDTH = 8,
    // Output ID field width (towards AXI slaves)
    // Additional bits required for response routing
    parameter M_ID_WIDTH = S_ID_WIDTH+$clog2(S_COUNT),
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // Number of concurrent unique IDs for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_THREADS = {S_COUNT{32'd2}},
    // Number of concurrent operations for each slave interface
    // S_COUNT concatenated fields of 32 bits
    parameter S_ACCEPT = {S_COUNT{32'd16}},
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_WIDTH bits
    // set to zero for default addressing based on M_ADDR_WIDTH
    parameter M_BASE_ADDR = 0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_WIDTH = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Write connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AW channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AW_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface W channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_W_REG_TYPE = {S_COUNT{2'd0}},
    // Slave interface B channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_B_REG_TYPE = {S_COUNT{2'd1}},
    // Master interface AW channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AW_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface W channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_W_REG_TYPE = {M_COUNT{2'd2}},
    // Master interface B channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_B_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI slave interfaces
     */
    input  wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_awid,
    input  wire [S_COUNT*ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [S_COUNT*8-1:0]             s_axi_awlen,
    input  wire [S_COUNT*3-1:0]             s_axi_awsize,
    input  wire [S_COUNT*2-1:0]             s_axi_awburst,
    input  wire [S_COUNT-1:0]               s_axi_awlock,
    input  wire [S_COUNT*4-1:0]             s_axi_awcache,
    input  wire [S_COUNT*3-1:0]             s_axi_awprot,
    input  wire [S_COUNT*4-1:0]             s_axi_awqos,
    input  wire [S_COUNT*AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire [S_COUNT-1:0]               s_axi_awvalid,
    output wire [S_COUNT-1:0]               s_axi_awready,
    input  wire [S_COUNT*DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [S_COUNT*STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire [S_COUNT-1:0]               s_axi_wlast,
    input  wire [S_COUNT*WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire [S_COUNT-1:0]               s_axi_wvalid,
    output wire [S_COUNT-1:0]               s_axi_wready,
    output wire [S_COUNT*S_ID_WIDTH-1:0]    s_axi_bid,
    output wire [S_COUNT*2-1:0]             s_axi_bresp,
    output wire [S_COUNT*BUSER_WIDTH-1:0]   s_axi_buser,
    output wire [S_COUNT-1:0]               s_axi_bvalid,
    input  wire [S_COUNT-1:0]               s_axi_bready,

    /*
     * AXI master interfaces
     */
    output wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_awid,
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [M_COUNT*8-1:0]             m_axi_awlen,
    output wire [M_COUNT*3-1:0]             m_axi_awsize,
    output wire [M_COUNT*2-1:0]             m_axi_awburst,
    output wire [M_COUNT-1:0]               m_axi_awlock,
    output wire [M_COUNT*4-1:0]             m_axi_awcache,
    output wire [M_COUNT*3-1:0]             m_axi_awprot,
    output wire [M_COUNT*4-1:0]             m_axi_awqos,
    output wire [M_COUNT*4-1:0]             m_axi_awregion,
    output wire [M_COUNT*AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire [M_COUNT-1:0]               m_axi_awvalid,
    input  wire [M_COUNT-1:0]               m_axi_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire [M_COUNT-1:0]               m_axi_wlast,
    output wire [M_COUNT*WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire [M_COUNT-1:0]               m_axi_wvalid,
    input  wire [M_COUNT-1:0]               m_axi_wready,
    input  wire [M_COUNT*M_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [M_COUNT*2-1:0]             m_axi_bresp,
    input  wire [M_COUNT*BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire [M_COUNT-1:0]               m_axi_bvalid,
    output wire [M_COUNT-1:0]               m_axi_bready
);

parameter CL_S_COUNT = $clog2(S_COUNT);
parameter CL_M_COUNT = $clog2(M_COUNT);
parameter M_COUNT_P1 = M_COUNT+1;
parameter CL_M_COUNT_P1 = $clog2(M_COUNT_P1);

integer i;

// check configuration
initial begin
    if (M_ID_WIDTH < S_ID_WIDTH+$clog2(S_COUNT)) begin
        $error("Error: M_ID_WIDTH must be at least $clog2(S_COUNT) larger than S_ID_WIDTH (instance %m)");
        $finish;
    end

    for (i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_WIDTH[i*32 +: 32] && (M_ADDR_WIDTH[i*32 +: 32] < 12 || M_ADDR_WIDTH[i*32 +: 32] > ADDR_WIDTH)) begin
            $error("Error: value out of range (instance %m)");
            $finish;
        end
    end
end

wire [S_COUNT*S_ID_WIDTH-1:0]    int_s_axi_awid;
wire [S_COUNT*ADDR_WIDTH-1:0]    int_s_axi_awaddr;
wire [S_COUNT*8-1:0]             int_s_axi_awlen;
wire [S_COUNT*3-1:0]             int_s_axi_awsize;
wire [S_COUNT*2-1:0]             int_s_axi_awburst;
wire [S_COUNT-1:0]               int_s_axi_awlock;
wire [S_COUNT*4-1:0]             int_s_axi_awcache;
wire [S_COUNT*3-1:0]             int_s_axi_awprot;
wire [S_COUNT*4-1:0]             int_s_axi_awqos;
wire [S_COUNT*4-1:0]             int_s_axi_awregion;
wire [S_COUNT*AWUSER_WIDTH-1:0]  int_s_axi_awuser;
wire [S_COUNT-1:0]               int_s_axi_awvalid;
wire [S_COUNT-1:0]               int_s_axi_awready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_awvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_awready;

wire [S_COUNT*DATA_WIDTH-1:0]    int_s_axi_wdata;
wire [S_COUNT*STRB_WIDTH-1:0]    int_s_axi_wstrb;
wire [S_COUNT-1:0]               int_s_axi_wlast;
wire [S_COUNT*WUSER_WIDTH-1:0]   int_s_axi_wuser;
wire [S_COUNT-1:0]               int_s_axi_wvalid;
wire [S_COUNT-1:0]               int_s_axi_wready;

wire [S_COUNT*M_COUNT-1:0]       int_axi_wvalid;
wire [M_COUNT*S_COUNT-1:0]       int_axi_wready;

wire [M_COUNT*M_ID_WIDTH-1:0]    int_m_axi_bid;
wire [M_COUNT*2-1:0]             int_m_axi_bresp;
wire [M_COUNT*BUSER_WIDTH-1:0]   int_m_axi_buser;
wire [M_COUNT-1:0]               int_m_axi_bvalid;
wire [M_COUNT-1:0]               int_m_axi_bready;

wire [M_COUNT*S_COUNT-1:0]       int_axi_bvalid;
wire [S_COUNT*M_COUNT-1:0]       int_axi_bready;

generate

    genvar m, n;

    for (m = 0; m < S_COUNT; m = m + 1) begin : s_ifaces
        // address decode and admission control
        wire [CL_M_COUNT-1:0] a_select;

        wire m_axi_avalid;
        wire m_axi_aready;

        wire [CL_M_COUNT-1:0] m_wc_select;
        wire m_wc_decerr;
        wire m_wc_valid;
        wire m_wc_ready;

        wire m_rc_decerr;
        wire m_rc_valid;
        wire m_rc_ready;

        wire [S_ID_WIDTH-1:0] s_cpl_id;
        wire s_cpl_valid;

        axi_crossbar_addr #(
            .S(m),
            .S_COUNT(S_COUNT),
            .M_COUNT(M_COUNT),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .S_THREADS(S_THREADS[m*32 +: 32]),
            .S_ACCEPT(S_ACCEPT[m*32 +: 32]),
            .M_REGIONS(M_REGIONS),
            .M_BASE_ADDR(M_BASE_ADDR),
            .M_ADDR_WIDTH(M_ADDR_WIDTH),
            .M_CONNECT(M_CONNECT),
            .M_SECURE(M_SECURE),
            .WC_OUTPUT(1)
        )
        addr_inst (
            .clk(clk),
            .rst(rst),

            /*
             * Address input
             */
            .s_axi_aid(int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_aaddr(int_s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_aprot(int_s_axi_awprot[m*3 +: 3]),
            .s_axi_aqos(int_s_axi_awqos[m*4 +: 4]),
            .s_axi_avalid(int_s_axi_awvalid[m]),
            .s_axi_aready(int_s_axi_awready[m]),

            /*
             * Address output
             */
            .m_axi_aregion(int_s_axi_awregion[m*4 +: 4]),
            .m_select(a_select),
            .m_axi_avalid(m_axi_avalid),
            .m_axi_aready(m_axi_aready),

            /*
             * Write command output
             */
            .m_wc_select(m_wc_select),
            .m_wc_decerr(m_wc_decerr),
            .m_wc_valid(m_wc_valid),
            .m_wc_ready(m_wc_ready),

            /*
             * Response command output
             */
            .m_rc_decerr(m_rc_decerr),
            .m_rc_valid(m_rc_valid),
            .m_rc_ready(m_rc_ready),

            /*
             * Completion input
             */
            .s_cpl_id(s_cpl_id),
            .s_cpl_valid(s_cpl_valid)
        );

        assign int_axi_awvalid[m*M_COUNT +: M_COUNT] = m_axi_avalid << a_select;
        assign m_axi_aready = int_axi_awready[a_select*S_COUNT+m];

        // write command handling
        reg [CL_M_COUNT-1:0] w_select_reg = 0, w_select_next;
        reg w_drop_reg = 1'b0, w_drop_next;
        reg w_select_valid_reg = 1'b0, w_select_valid_next;

        assign m_wc_ready = !w_select_valid_reg;

        always @* begin
            w_select_next = w_select_reg;
            w_drop_next = w_drop_reg && !(int_s_axi_wvalid[m] && int_s_axi_wready[m] && int_s_axi_wlast[m]);
            w_select_valid_next = w_select_valid_reg && !(int_s_axi_wvalid[m] && int_s_axi_wready[m] && int_s_axi_wlast[m]);

            if (m_wc_valid && !w_select_valid_reg) begin
                w_select_next = m_wc_select;
                w_drop_next = m_wc_decerr;
                w_select_valid_next = m_wc_valid;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                w_select_valid_reg <= 1'b0;
            end else begin
                w_select_valid_reg <= w_select_valid_next;
            end

            w_select_reg <= w_select_next;
            w_drop_reg <= w_drop_next;
        end

        // write data forwarding
        assign int_axi_wvalid[m*M_COUNT +: M_COUNT] = (int_s_axi_wvalid[m] && w_select_valid_reg && !w_drop_reg) << w_select_reg;
        assign int_s_axi_wready[m] = int_axi_wready[w_select_reg*S_COUNT+m] || w_drop_reg;

        // decode error handling
        reg [S_ID_WIDTH-1:0]  decerr_m_axi_bid_reg = {S_ID_WIDTH{1'b0}}, decerr_m_axi_bid_next;
        reg                   decerr_m_axi_bvalid_reg = 1'b0, decerr_m_axi_bvalid_next;
        wire                  decerr_m_axi_bready;

        assign m_rc_ready = !decerr_m_axi_bvalid_reg;

        always @* begin
            decerr_m_axi_bid_next = decerr_m_axi_bid_reg;
            decerr_m_axi_bvalid_next = decerr_m_axi_bvalid_reg;

            if (decerr_m_axi_bvalid_reg) begin
                if (decerr_m_axi_bready) begin
                    decerr_m_axi_bvalid_next = 1'b0;
                end
            end else if (m_rc_valid && m_rc_ready) begin
                decerr_m_axi_bid_next = int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH];
                decerr_m_axi_bvalid_next = 1'b1;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                decerr_m_axi_bvalid_reg <= 1'b0;
            end else begin
                decerr_m_axi_bvalid_reg <= decerr_m_axi_bvalid_next;
            end

            decerr_m_axi_bid_reg <= decerr_m_axi_bid_next;
        end

        // write response arbitration
        wire [M_COUNT_P1-1:0] b_request;
        wire [M_COUNT_P1-1:0] b_acknowledge;
        wire [M_COUNT_P1-1:0] b_grant;
        wire b_grant_valid;
        wire [CL_M_COUNT_P1-1:0] b_grant_encoded;

        arbiter #(
            .PORTS(M_COUNT_P1),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        b_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(b_request),
            .acknowledge(b_acknowledge),
            .grant(b_grant),
            .grant_valid(b_grant_valid),
            .grant_encoded(b_grant_encoded)
        );

        // write response mux
        wire [S_ID_WIDTH-1:0]  m_axi_bid_mux    = {decerr_m_axi_bid_reg, int_m_axi_bid} >> b_grant_encoded*M_ID_WIDTH;
        wire [1:0]             m_axi_bresp_mux  = {2'b11, int_m_axi_bresp} >> b_grant_encoded*2;
        wire [BUSER_WIDTH-1:0] m_axi_buser_mux  = {{BUSER_WIDTH{1'b0}}, int_m_axi_buser} >> b_grant_encoded*BUSER_WIDTH;
        wire                   m_axi_bvalid_mux = ({decerr_m_axi_bvalid_reg, int_m_axi_bvalid} >> b_grant_encoded) & b_grant_valid;
        wire                   m_axi_bready_mux;

        assign int_axi_bready[m*M_COUNT +: M_COUNT] = (b_grant_valid && m_axi_bready_mux) << b_grant_encoded;
        assign decerr_m_axi_bready = (b_grant_valid && m_axi_bready_mux) && (b_grant_encoded == M_COUNT_P1-1);

        for (n = 0; n < M_COUNT; n = n + 1) begin
            assign b_request[n] = int_axi_bvalid[n*S_COUNT+m] && !b_grant[n];
            assign b_acknowledge[n] = b_grant[n] && int_axi_bvalid[n*S_COUNT+m] && m_axi_bready_mux;
        end

        assign b_request[M_COUNT_P1-1] = decerr_m_axi_bvalid_reg && !b_grant[M_COUNT_P1-1];
        assign b_acknowledge[M_COUNT_P1-1] = b_grant[M_COUNT_P1-1] && decerr_m_axi_bvalid_reg && m_axi_bready_mux;

        assign s_cpl_id = m_axi_bid_mux;
        assign s_cpl_valid = m_axi_bvalid_mux && m_axi_bready_mux;

        // S side register
        axi_register_wr #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(S_ID_WIDTH),
            .AWUSER_ENABLE(AWUSER_ENABLE),
            .AWUSER_WIDTH(AWUSER_WIDTH),
            .WUSER_ENABLE(WUSER_ENABLE),
            .WUSER_WIDTH(WUSER_WIDTH),
            .BUSER_ENABLE(BUSER_ENABLE),
            .BUSER_WIDTH(BUSER_WIDTH),
            .AW_REG_TYPE(S_AW_REG_TYPE[m*2 +: 2]),
            .W_REG_TYPE(S_W_REG_TYPE[m*2 +: 2]),
            .B_REG_TYPE(S_B_REG_TYPE[m*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_awaddr(s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .s_axi_awlen(s_axi_awlen[m*8 +: 8]),
            .s_axi_awsize(s_axi_awsize[m*3 +: 3]),
            .s_axi_awburst(s_axi_awburst[m*2 +: 2]),
            .s_axi_awlock(s_axi_awlock[m]),
            .s_axi_awcache(s_axi_awcache[m*4 +: 4]),
            .s_axi_awprot(s_axi_awprot[m*3 +: 3]),
            .s_axi_awqos(s_axi_awqos[m*4 +: 4]),
            .s_axi_awregion(4'd0),
            .s_axi_awuser(s_axi_awuser[m*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .s_axi_awvalid(s_axi_awvalid[m]),
            .s_axi_awready(s_axi_awready[m]),
            .s_axi_wdata(s_axi_wdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .s_axi_wstrb(s_axi_wstrb[m*STRB_WIDTH +: STRB_WIDTH]),
            .s_axi_wlast(s_axi_wlast[m]),
            .s_axi_wuser(s_axi_wuser[m*WUSER_WIDTH +: WUSER_WIDTH]),
            .s_axi_wvalid(s_axi_wvalid[m]),
            .s_axi_wready(s_axi_wready[m]),
            .s_axi_bid(s_axi_bid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .s_axi_bresp(s_axi_bresp[m*2 +: 2]),
            .s_axi_buser(s_axi_buser[m*BUSER_WIDTH +: BUSER_WIDTH]),
            .s_axi_bvalid(s_axi_bvalid[m]),
            .s_axi_bready(s_axi_bready[m]),
            .m_axi_awid(int_s_axi_awid[m*S_ID_WIDTH +: S_ID_WIDTH]),
            .m_axi_awaddr(int_s_axi_awaddr[m*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_awlen(int_s_axi_awlen[m*8 +: 8]),
            .m_axi_awsize(int_s_axi_awsize[m*3 +: 3]),
            .m_axi_awburst(int_s_axi_awburst[m*2 +: 2]),
            .m_axi_awlock(int_s_axi_awlock[m]),
            .m_axi_awcache(int_s_axi_awcache[m*4 +: 4]),
            .m_axi_awprot(int_s_axi_awprot[m*3 +: 3]),
            .m_axi_awqos(int_s_axi_awqos[m*4 +: 4]),
            .m_axi_awregion(),
            .m_axi_awuser(int_s_axi_awuser[m*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .m_axi_awvalid(int_s_axi_awvalid[m]),
            .m_axi_awready(int_s_axi_awready[m]),
            .m_axi_wdata(int_s_axi_wdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_wstrb(int_s_axi_wstrb[m*STRB_WIDTH +: STRB_WIDTH]),
            .m_axi_wlast(int_s_axi_wlast[m]),
            .m_axi_wuser(int_s_axi_wuser[m*WUSER_WIDTH +: WUSER_WIDTH]),
            .m_axi_wvalid(int_s_axi_wvalid[m]),
            .m_axi_wready(int_s_axi_wready[m]),
            .m_axi_bid(m_axi_bid_mux),
            .m_axi_bresp(m_axi_bresp_mux),
            .m_axi_buser(m_axi_buser_mux),
            .m_axi_bvalid(m_axi_bvalid_mux),
            .m_axi_bready(m_axi_bready_mux)
        );
    end // s_ifaces

    for (n = 0; n < M_COUNT; n = n + 1) begin : m_ifaces
        // in-flight transaction count
        wire trans_start;
        wire trans_complete;
        reg [$clog2(M_ISSUE[n*32 +: 32]+1)-1:0] trans_count_reg = 0;

        wire trans_limit = trans_count_reg >= M_ISSUE[n*32 +: 32] && !trans_complete;

        always @(posedge clk) begin
            if (rst) begin
                trans_count_reg <= 0;
            end else begin
                if (trans_start && !trans_complete) begin
                    trans_count_reg <= trans_count_reg + 1;
                end else if (!trans_start && trans_complete) begin
                    trans_count_reg <= trans_count_reg - 1;
                end
            end
        end

        // address arbitration
        reg [CL_S_COUNT-1:0] w_select_reg = 0, w_select_next;
        reg w_select_valid_reg = 1'b0, w_select_valid_next;
        reg w_select_new_reg = 1'b0, w_select_new_next;

        wire [S_COUNT-1:0] a_request;
        wire [S_COUNT-1:0] a_acknowledge;
        wire [S_COUNT-1:0] a_grant;
        wire a_grant_valid;
        wire [CL_S_COUNT-1:0] a_grant_encoded;

        arbiter #(
            .PORTS(S_COUNT),
            .ARB_TYPE_ROUND_ROBIN(1),
            .ARB_BLOCK(1),
            .ARB_BLOCK_ACK(1),
            .ARB_LSB_HIGH_PRIORITY(1)
        )
        a_arb_inst (
            .clk(clk),
            .rst(rst),
            .request(a_request),
            .acknowledge(a_acknowledge),
            .grant(a_grant),
            .grant_valid(a_grant_valid),
            .grant_encoded(a_grant_encoded)
        );

        // address mux
        wire [M_ID_WIDTH-1:0]   s_axi_awid_mux     = int_s_axi_awid[a_grant_encoded*S_ID_WIDTH +: S_ID_WIDTH] | (a_grant_encoded << S_ID_WIDTH);
        wire [ADDR_WIDTH-1:0]   s_axi_awaddr_mux   = int_s_axi_awaddr[a_grant_encoded*ADDR_WIDTH +: ADDR_WIDTH];
        wire [7:0]              s_axi_awlen_mux    = int_s_axi_awlen[a_grant_encoded*8 +: 8];
        wire [2:0]              s_axi_awsize_mux   = int_s_axi_awsize[a_grant_encoded*3 +: 3];
        wire [1:0]              s_axi_awburst_mux  = int_s_axi_awburst[a_grant_encoded*2 +: 2];
        wire                    s_axi_awlock_mux   = int_s_axi_awlock[a_grant_encoded];
        wire [3:0]              s_axi_awcache_mux  = int_s_axi_awcache[a_grant_encoded*4 +: 4];
        wire [2:0]              s_axi_awprot_mux   = int_s_axi_awprot[a_grant_encoded*3 +: 3];
        wire [3:0]              s_axi_awqos_mux    = int_s_axi_awqos[a_grant_encoded*4 +: 4];
        wire [3:0]              s_axi_awregion_mux = int_s_axi_awregion[a_grant_encoded*4 +: 4];
        wire [AWUSER_WIDTH-1:0] s_axi_awuser_mux   = int_s_axi_awuser[a_grant_encoded*AWUSER_WIDTH +: AWUSER_WIDTH];
        wire                    s_axi_awvalid_mux  = int_axi_awvalid[a_grant_encoded*M_COUNT+n] && a_grant_valid;
        wire                    s_axi_awready_mux;

        assign int_axi_awready[n*S_COUNT +: S_COUNT] = (a_grant_valid && s_axi_awready_mux) << a_grant_encoded;

        for (m = 0; m < S_COUNT; m = m + 1) begin
            assign a_request[m] = int_axi_awvalid[m*M_COUNT+n] && !a_grant[m] && !trans_limit && !w_select_valid_next;
            assign a_acknowledge[m] = a_grant[m] && int_axi_awvalid[m*M_COUNT+n] && s_axi_awready_mux;
        end

        assign trans_start = s_axi_awvalid_mux && s_axi_awready_mux && a_grant_valid;

        // write data mux
        wire [DATA_WIDTH-1:0]  s_axi_wdata_mux   = int_s_axi_wdata[w_select_reg*DATA_WIDTH +: DATA_WIDTH];
        wire [STRB_WIDTH-1:0]  s_axi_wstrb_mux   = int_s_axi_wstrb[w_select_reg*STRB_WIDTH +: STRB_WIDTH];
        wire                   s_axi_wlast_mux   = int_s_axi_wlast[w_select_reg];
        wire [WUSER_WIDTH-1:0] s_axi_wuser_mux   = int_s_axi_wuser[w_select_reg*WUSER_WIDTH +: WUSER_WIDTH];
        wire                   s_axi_wvalid_mux  = int_axi_wvalid[w_select_reg*M_COUNT+n] && w_select_valid_reg;
        wire                   s_axi_wready_mux;

        assign int_axi_wready[n*S_COUNT +: S_COUNT] = (w_select_valid_reg && s_axi_wready_mux) << w_select_reg;

        // write data routing
        always @* begin
            w_select_next = w_select_reg;
            w_select_valid_next = w_select_valid_reg && !(s_axi_wvalid_mux && s_axi_wready_mux && s_axi_wlast_mux);
            w_select_new_next = w_select_new_reg || !a_grant_valid || a_acknowledge;

            if (a_grant_valid && !w_select_valid_reg && w_select_new_reg) begin
                w_select_next = a_grant_encoded;
                w_select_valid_next = a_grant_valid;
                w_select_new_next = 1'b0;
            end
        end

        always @(posedge clk) begin
            if (rst) begin
                w_select_valid_reg <= 1'b0;
                w_select_new_reg <= 1'b1;
            end else begin
                w_select_valid_reg <= w_select_valid_next;
                w_select_new_reg <= w_select_new_next;
            end

            w_select_reg <= w_select_next;
        end

        // write response forwarding
        wire [CL_S_COUNT-1:0] b_select = m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH] >> S_ID_WIDTH;

        assign int_axi_bvalid[n*S_COUNT +: S_COUNT] = int_m_axi_bvalid[n] << b_select;
        assign int_m_axi_bready[n] = int_axi_bready[b_select*M_COUNT+n];

        assign trans_complete = int_m_axi_bvalid[n] && int_m_axi_bready[n];

        // M side register
        axi_register_wr #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .STRB_WIDTH(STRB_WIDTH),
            .ID_WIDTH(M_ID_WIDTH),
            .AWUSER_ENABLE(AWUSER_ENABLE),
            .AWUSER_WIDTH(AWUSER_WIDTH),
            .WUSER_ENABLE(WUSER_ENABLE),
            .WUSER_WIDTH(WUSER_WIDTH),
            .BUSER_ENABLE(BUSER_ENABLE),
            .BUSER_WIDTH(BUSER_WIDTH),
            .AW_REG_TYPE(M_AW_REG_TYPE[n*2 +: 2]),
            .W_REG_TYPE(M_W_REG_TYPE[n*2 +: 2]),
            .B_REG_TYPE(M_B_REG_TYPE[n*2 +: 2])
        )
        reg_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(s_axi_awid_mux),
            .s_axi_awaddr(s_axi_awaddr_mux),
            .s_axi_awlen(s_axi_awlen_mux),
            .s_axi_awsize(s_axi_awsize_mux),
            .s_axi_awburst(s_axi_awburst_mux),
            .s_axi_awlock(s_axi_awlock_mux),
            .s_axi_awcache(s_axi_awcache_mux),
            .s_axi_awprot(s_axi_awprot_mux),
            .s_axi_awqos(s_axi_awqos_mux),
            .s_axi_awregion(s_axi_awregion_mux),
            .s_axi_awuser(s_axi_awuser_mux),
            .s_axi_awvalid(s_axi_awvalid_mux),
            .s_axi_awready(s_axi_awready_mux),
            .s_axi_wdata(s_axi_wdata_mux),
            .s_axi_wstrb(s_axi_wstrb_mux),
            .s_axi_wlast(s_axi_wlast_mux),
            .s_axi_wuser(s_axi_wuser_mux),
            .s_axi_wvalid(s_axi_wvalid_mux),
            .s_axi_wready(s_axi_wready_mux),
            .s_axi_bid(int_m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .s_axi_bresp(int_m_axi_bresp[n*2 +: 2]),
            .s_axi_buser(int_m_axi_buser[n*BUSER_WIDTH +: BUSER_WIDTH]),
            .s_axi_bvalid(int_m_axi_bvalid[n]),
            .s_axi_bready(int_m_axi_bready[n]),
            .m_axi_awid(m_axi_awid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_awaddr(m_axi_awaddr[n*ADDR_WIDTH +: ADDR_WIDTH]),
            .m_axi_awlen(m_axi_awlen[n*8 +: 8]),
            .m_axi_awsize(m_axi_awsize[n*3 +: 3]),
            .m_axi_awburst(m_axi_awburst[n*2 +: 2]),
            .m_axi_awlock(m_axi_awlock[n]),
            .m_axi_awcache(m_axi_awcache[n*4 +: 4]),
            .m_axi_awprot(m_axi_awprot[n*3 +: 3]),
            .m_axi_awqos(m_axi_awqos[n*4 +: 4]),
            .m_axi_awregion(m_axi_awregion[n*4 +: 4]),
            .m_axi_awuser(m_axi_awuser[n*AWUSER_WIDTH +: AWUSER_WIDTH]),
            .m_axi_awvalid(m_axi_awvalid[n]),
            .m_axi_awready(m_axi_awready[n]),
            .m_axi_wdata(m_axi_wdata[n*DATA_WIDTH +: DATA_WIDTH]),
            .m_axi_wstrb(m_axi_wstrb[n*STRB_WIDTH +: STRB_WIDTH]),
            .m_axi_wlast(m_axi_wlast[n]),
            .m_axi_wuser(m_axi_wuser[n*WUSER_WIDTH +: WUSER_WIDTH]),
            .m_axi_wvalid(m_axi_wvalid[n]),
            .m_axi_wready(m_axi_wready[n]),
            .m_axi_bid(m_axi_bid[n*M_ID_WIDTH +: M_ID_WIDTH]),
            .m_axi_bresp(m_axi_bresp[n*2 +: 2]),
            .m_axi_buser(m_axi_buser[n*BUSER_WIDTH +: BUSER_WIDTH]),
            .m_axi_bvalid(m_axi_bvalid[n]),
            .m_axi_bready(m_axi_bready[n])
        );
    end // m_ifaces

endgenerate

endmodule

`resetall

/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 register (write)
 */
module axi_register_wr #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // AW channel register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter AW_REG_TYPE = 1,
    // W channel register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter W_REG_TYPE = 2,
    // B channel register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter B_REG_TYPE = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    /*
     * AXI master interface
     */
    output wire [ID_WIDTH-1:0]      m_axi_awid,
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awlock,
    output wire [3:0]               m_axi_awcache,
    output wire [2:0]               m_axi_awprot,
    output wire [3:0]               m_axi_awqos,
    output wire [3:0]               m_axi_awregion,
    output wire [AWUSER_WIDTH-1:0]  m_axi_awuser,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire [WUSER_WIDTH-1:0]   m_axi_wuser,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire [BUSER_WIDTH-1:0]   m_axi_buser,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready
);

generate

// AW channel

if (AW_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                    s_axi_awready_reg = 1'b0;

reg [ID_WIDTH-1:0]     m_axi_awid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   m_axi_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              m_axi_awlen_reg    = 8'd0;
reg [2:0]              m_axi_awsize_reg   = 3'd0;
reg [1:0]              m_axi_awburst_reg  = 2'd0;
reg                    m_axi_awlock_reg   = 1'b0;
reg [3:0]              m_axi_awcache_reg  = 4'd0;
reg [2:0]              m_axi_awprot_reg   = 3'd0;
reg [3:0]              m_axi_awqos_reg    = 4'd0;
reg [3:0]              m_axi_awregion_reg = 4'd0;
reg [AWUSER_WIDTH-1:0] m_axi_awuser_reg   = {AWUSER_WIDTH{1'b0}};
reg                    m_axi_awvalid_reg  = 1'b0, m_axi_awvalid_next;

reg [ID_WIDTH-1:0]     temp_m_axi_awid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   temp_m_axi_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              temp_m_axi_awlen_reg    = 8'd0;
reg [2:0]              temp_m_axi_awsize_reg   = 3'd0;
reg [1:0]              temp_m_axi_awburst_reg  = 2'd0;
reg                    temp_m_axi_awlock_reg   = 1'b0;
reg [3:0]              temp_m_axi_awcache_reg  = 4'd0;
reg [2:0]              temp_m_axi_awprot_reg   = 3'd0;
reg [3:0]              temp_m_axi_awqos_reg    = 4'd0;
reg [3:0]              temp_m_axi_awregion_reg = 4'd0;
reg [AWUSER_WIDTH-1:0] temp_m_axi_awuser_reg   = {AWUSER_WIDTH{1'b0}};
reg                    temp_m_axi_awvalid_reg  = 1'b0, temp_m_axi_awvalid_next;

// datapath control
reg store_axi_aw_input_to_output;
reg store_axi_aw_input_to_temp;
reg store_axi_aw_temp_to_output;

assign s_axi_awready  = s_axi_awready_reg;

assign m_axi_awid     = m_axi_awid_reg;
assign m_axi_awaddr   = m_axi_awaddr_reg;
assign m_axi_awlen    = m_axi_awlen_reg;
assign m_axi_awsize   = m_axi_awsize_reg;
assign m_axi_awburst  = m_axi_awburst_reg;
assign m_axi_awlock   = m_axi_awlock_reg;
assign m_axi_awcache  = m_axi_awcache_reg;
assign m_axi_awprot   = m_axi_awprot_reg;
assign m_axi_awqos    = m_axi_awqos_reg;
assign m_axi_awregion = m_axi_awregion_reg;
assign m_axi_awuser   = AWUSER_ENABLE ? m_axi_awuser_reg : {AWUSER_WIDTH{1'b0}};
assign m_axi_awvalid  = m_axi_awvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axi_awready_early = m_axi_awready | (~temp_m_axi_awvalid_reg & (~m_axi_awvalid_reg | ~s_axi_awvalid));

always @* begin
    // transfer sink ready state to source
    m_axi_awvalid_next = m_axi_awvalid_reg;
    temp_m_axi_awvalid_next = temp_m_axi_awvalid_reg;

    store_axi_aw_input_to_output = 1'b0;
    store_axi_aw_input_to_temp = 1'b0;
    store_axi_aw_temp_to_output = 1'b0;

    if (s_axi_awready_reg) begin
        // input is ready
        if (m_axi_awready | ~m_axi_awvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axi_awvalid_next = s_axi_awvalid;
            store_axi_aw_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axi_awvalid_next = s_axi_awvalid;
            store_axi_aw_input_to_temp = 1'b1;
        end
    end else if (m_axi_awready) begin
        // input is not ready, but output is ready
        m_axi_awvalid_next = temp_m_axi_awvalid_reg;
        temp_m_axi_awvalid_next = 1'b0;
        store_axi_aw_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_awready_reg <= 1'b0;
        m_axi_awvalid_reg <= 1'b0;
        temp_m_axi_awvalid_reg <= 1'b0;
    end else begin
        s_axi_awready_reg <= s_axi_awready_early;
        m_axi_awvalid_reg <= m_axi_awvalid_next;
        temp_m_axi_awvalid_reg <= temp_m_axi_awvalid_next;
    end

    // datapath
    if (store_axi_aw_input_to_output) begin
        m_axi_awid_reg <= s_axi_awid;
        m_axi_awaddr_reg <= s_axi_awaddr;
        m_axi_awlen_reg <= s_axi_awlen;
        m_axi_awsize_reg <= s_axi_awsize;
        m_axi_awburst_reg <= s_axi_awburst;
        m_axi_awlock_reg <= s_axi_awlock;
        m_axi_awcache_reg <= s_axi_awcache;
        m_axi_awprot_reg <= s_axi_awprot;
        m_axi_awqos_reg <= s_axi_awqos;
        m_axi_awregion_reg <= s_axi_awregion;
        m_axi_awuser_reg <= s_axi_awuser;
    end else if (store_axi_aw_temp_to_output) begin
        m_axi_awid_reg <= temp_m_axi_awid_reg;
        m_axi_awaddr_reg <= temp_m_axi_awaddr_reg;
        m_axi_awlen_reg <= temp_m_axi_awlen_reg;
        m_axi_awsize_reg <= temp_m_axi_awsize_reg;
        m_axi_awburst_reg <= temp_m_axi_awburst_reg;
        m_axi_awlock_reg <= temp_m_axi_awlock_reg;
        m_axi_awcache_reg <= temp_m_axi_awcache_reg;
        m_axi_awprot_reg <= temp_m_axi_awprot_reg;
        m_axi_awqos_reg <= temp_m_axi_awqos_reg;
        m_axi_awregion_reg <= temp_m_axi_awregion_reg;
        m_axi_awuser_reg <= temp_m_axi_awuser_reg;
    end

    if (store_axi_aw_input_to_temp) begin
        temp_m_axi_awid_reg <= s_axi_awid;
        temp_m_axi_awaddr_reg <= s_axi_awaddr;
        temp_m_axi_awlen_reg <= s_axi_awlen;
        temp_m_axi_awsize_reg <= s_axi_awsize;
        temp_m_axi_awburst_reg <= s_axi_awburst;
        temp_m_axi_awlock_reg <= s_axi_awlock;
        temp_m_axi_awcache_reg <= s_axi_awcache;
        temp_m_axi_awprot_reg <= s_axi_awprot;
        temp_m_axi_awqos_reg <= s_axi_awqos;
        temp_m_axi_awregion_reg <= s_axi_awregion;
        temp_m_axi_awuser_reg <= s_axi_awuser;
    end
end

end else if (AW_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                    s_axi_awready_reg = 1'b0;

reg [ID_WIDTH-1:0]     m_axi_awid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   m_axi_awaddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              m_axi_awlen_reg    = 8'd0;
reg [2:0]              m_axi_awsize_reg   = 3'd0;
reg [1:0]              m_axi_awburst_reg  = 2'd0;
reg                    m_axi_awlock_reg   = 1'b0;
reg [3:0]              m_axi_awcache_reg  = 4'd0;
reg [2:0]              m_axi_awprot_reg   = 3'd0;
reg [3:0]              m_axi_awqos_reg    = 4'd0;
reg [3:0]              m_axi_awregion_reg = 4'd0;
reg [AWUSER_WIDTH-1:0] m_axi_awuser_reg   = {AWUSER_WIDTH{1'b0}};
reg                    m_axi_awvalid_reg  = 1'b0, m_axi_awvalid_next;

// datapath control
reg store_axi_aw_input_to_output;

assign s_axi_awready  = s_axi_awready_reg;

assign m_axi_awid     = m_axi_awid_reg;
assign m_axi_awaddr   = m_axi_awaddr_reg;
assign m_axi_awlen    = m_axi_awlen_reg;
assign m_axi_awsize   = m_axi_awsize_reg;
assign m_axi_awburst  = m_axi_awburst_reg;
assign m_axi_awlock   = m_axi_awlock_reg;
assign m_axi_awcache  = m_axi_awcache_reg;
assign m_axi_awprot   = m_axi_awprot_reg;
assign m_axi_awqos    = m_axi_awqos_reg;
assign m_axi_awregion = m_axi_awregion_reg;
assign m_axi_awuser   = AWUSER_ENABLE ? m_axi_awuser_reg : {AWUSER_WIDTH{1'b0}};
assign m_axi_awvalid  = m_axi_awvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axi_awready_eawly = !m_axi_awvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axi_awvalid_next = m_axi_awvalid_reg;

    store_axi_aw_input_to_output = 1'b0;

    if (s_axi_awready_reg) begin
        m_axi_awvalid_next = s_axi_awvalid;
        store_axi_aw_input_to_output = 1'b1;
    end else if (m_axi_awready) begin
        m_axi_awvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_awready_reg <= 1'b0;
        m_axi_awvalid_reg <= 1'b0;
    end else begin
        s_axi_awready_reg <= s_axi_awready_eawly;
        m_axi_awvalid_reg <= m_axi_awvalid_next;
    end

    // datapath
    if (store_axi_aw_input_to_output) begin
        m_axi_awid_reg <= s_axi_awid;
        m_axi_awaddr_reg <= s_axi_awaddr;
        m_axi_awlen_reg <= s_axi_awlen;
        m_axi_awsize_reg <= s_axi_awsize;
        m_axi_awburst_reg <= s_axi_awburst;
        m_axi_awlock_reg <= s_axi_awlock;
        m_axi_awcache_reg <= s_axi_awcache;
        m_axi_awprot_reg <= s_axi_awprot;
        m_axi_awqos_reg <= s_axi_awqos;
        m_axi_awregion_reg <= s_axi_awregion;
        m_axi_awuser_reg <= s_axi_awuser;
    end
end

end else begin

    // bypass AW channel
    assign m_axi_awid = s_axi_awid;
    assign m_axi_awaddr = s_axi_awaddr;
    assign m_axi_awlen = s_axi_awlen;
    assign m_axi_awsize = s_axi_awsize;
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_awlock = s_axi_awlock;
    assign m_axi_awcache = s_axi_awcache;
    assign m_axi_awprot = s_axi_awprot;
    assign m_axi_awqos = s_axi_awqos;
    assign m_axi_awregion = s_axi_awregion;
    assign m_axi_awuser = AWUSER_ENABLE ? s_axi_awuser : {AWUSER_WIDTH{1'b0}};
    assign m_axi_awvalid = s_axi_awvalid;
    assign s_axi_awready = m_axi_awready;

end

// W channel

if (W_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   s_axi_wready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  m_axi_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  m_axi_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   m_axi_wlast_reg  = 1'b0;
reg [WUSER_WIDTH-1:0] m_axi_wuser_reg  = {WUSER_WIDTH{1'b0}};
reg                   m_axi_wvalid_reg = 1'b0, m_axi_wvalid_next;

reg [DATA_WIDTH-1:0]  temp_m_axi_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  temp_m_axi_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   temp_m_axi_wlast_reg  = 1'b0;
reg [WUSER_WIDTH-1:0] temp_m_axi_wuser_reg  = {WUSER_WIDTH{1'b0}};
reg                   temp_m_axi_wvalid_reg = 1'b0, temp_m_axi_wvalid_next;

// datapath control
reg store_axi_w_input_to_output;
reg store_axi_w_input_to_temp;
reg store_axi_w_temp_to_output;

assign s_axi_wready = s_axi_wready_reg;

assign m_axi_wdata  = m_axi_wdata_reg;
assign m_axi_wstrb  = m_axi_wstrb_reg;
assign m_axi_wlast  = m_axi_wlast_reg;
assign m_axi_wuser  = WUSER_ENABLE ? m_axi_wuser_reg : {WUSER_WIDTH{1'b0}};
assign m_axi_wvalid = m_axi_wvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axi_wready_early = m_axi_wready | (~temp_m_axi_wvalid_reg & (~m_axi_wvalid_reg | ~s_axi_wvalid));

always @* begin
    // transfer sink ready state to source
    m_axi_wvalid_next = m_axi_wvalid_reg;
    temp_m_axi_wvalid_next = temp_m_axi_wvalid_reg;

    store_axi_w_input_to_output = 1'b0;
    store_axi_w_input_to_temp = 1'b0;
    store_axi_w_temp_to_output = 1'b0;

    if (s_axi_wready_reg) begin
        // input is ready
        if (m_axi_wready | ~m_axi_wvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axi_wvalid_next = s_axi_wvalid;
            store_axi_w_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axi_wvalid_next = s_axi_wvalid;
            store_axi_w_input_to_temp = 1'b1;
        end
    end else if (m_axi_wready) begin
        // input is not ready, but output is ready
        m_axi_wvalid_next = temp_m_axi_wvalid_reg;
        temp_m_axi_wvalid_next = 1'b0;
        store_axi_w_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_wready_reg <= 1'b0;
        m_axi_wvalid_reg <= 1'b0;
        temp_m_axi_wvalid_reg <= 1'b0;
    end else begin
        s_axi_wready_reg <= s_axi_wready_early;
        m_axi_wvalid_reg <= m_axi_wvalid_next;
        temp_m_axi_wvalid_reg <= temp_m_axi_wvalid_next;
    end

    // datapath
    if (store_axi_w_input_to_output) begin
        m_axi_wdata_reg <= s_axi_wdata;
        m_axi_wstrb_reg <= s_axi_wstrb;
        m_axi_wlast_reg <= s_axi_wlast;
        m_axi_wuser_reg <= s_axi_wuser;
    end else if (store_axi_w_temp_to_output) begin
        m_axi_wdata_reg <= temp_m_axi_wdata_reg;
        m_axi_wstrb_reg <= temp_m_axi_wstrb_reg;
        m_axi_wlast_reg <= temp_m_axi_wlast_reg;
        m_axi_wuser_reg <= temp_m_axi_wuser_reg;
    end

    if (store_axi_w_input_to_temp) begin
        temp_m_axi_wdata_reg <= s_axi_wdata;
        temp_m_axi_wstrb_reg <= s_axi_wstrb;
        temp_m_axi_wlast_reg <= s_axi_wlast;
        temp_m_axi_wuser_reg <= s_axi_wuser;
    end
end

end else if (W_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   s_axi_wready_reg = 1'b0;

reg [DATA_WIDTH-1:0]  m_axi_wdata_reg  = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]  m_axi_wstrb_reg  = {STRB_WIDTH{1'b0}};
reg                   m_axi_wlast_reg  = 1'b0;
reg [WUSER_WIDTH-1:0] m_axi_wuser_reg  = {WUSER_WIDTH{1'b0}};
reg                   m_axi_wvalid_reg = 1'b0, m_axi_wvalid_next;

// datapath control
reg store_axi_w_input_to_output;

assign s_axi_wready = s_axi_wready_reg;

assign m_axi_wdata  = m_axi_wdata_reg;
assign m_axi_wstrb  = m_axi_wstrb_reg;
assign m_axi_wlast  = m_axi_wlast_reg;
assign m_axi_wuser  = WUSER_ENABLE ? m_axi_wuser_reg : {WUSER_WIDTH{1'b0}};
assign m_axi_wvalid = m_axi_wvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axi_wready_ewly = !m_axi_wvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axi_wvalid_next = m_axi_wvalid_reg;

    store_axi_w_input_to_output = 1'b0;

    if (s_axi_wready_reg) begin
        m_axi_wvalid_next = s_axi_wvalid;
        store_axi_w_input_to_output = 1'b1;
    end else if (m_axi_wready) begin
        m_axi_wvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_wready_reg <= 1'b0;
        m_axi_wvalid_reg <= 1'b0;
    end else begin
        s_axi_wready_reg <= s_axi_wready_ewly;
        m_axi_wvalid_reg <= m_axi_wvalid_next;
    end

    // datapath
    if (store_axi_w_input_to_output) begin
        m_axi_wdata_reg <= s_axi_wdata;
        m_axi_wstrb_reg <= s_axi_wstrb;
        m_axi_wlast_reg <= s_axi_wlast;
        m_axi_wuser_reg <= s_axi_wuser;
    end
end

end else begin

    // bypass W channel
    assign m_axi_wdata = s_axi_wdata;
    assign m_axi_wstrb = s_axi_wstrb;
    assign m_axi_wlast = s_axi_wlast;
    assign m_axi_wuser = WUSER_ENABLE ? s_axi_wuser : {WUSER_WIDTH{1'b0}};
    assign m_axi_wvalid = s_axi_wvalid;
    assign s_axi_wready = m_axi_wready;

end

// B channel

if (B_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   m_axi_bready_reg = 1'b0;

reg [ID_WIDTH-1:0]    s_axi_bid_reg    = {ID_WIDTH{1'b0}};
reg [1:0]             s_axi_bresp_reg  = 2'b0;
reg [BUSER_WIDTH-1:0] s_axi_buser_reg  = {BUSER_WIDTH{1'b0}};
reg                   s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;

reg [ID_WIDTH-1:0]    temp_s_axi_bid_reg    = {ID_WIDTH{1'b0}};
reg [1:0]             temp_s_axi_bresp_reg  = 2'b0;
reg [BUSER_WIDTH-1:0] temp_s_axi_buser_reg  = {BUSER_WIDTH{1'b0}};
reg                   temp_s_axi_bvalid_reg = 1'b0, temp_s_axi_bvalid_next;

// datapath control
reg store_axi_b_input_to_output;
reg store_axi_b_input_to_temp;
reg store_axi_b_temp_to_output;

assign m_axi_bready = m_axi_bready_reg;

assign s_axi_bid    = s_axi_bid_reg;
assign s_axi_bresp  = s_axi_bresp_reg;
assign s_axi_buser  = BUSER_ENABLE ? s_axi_buser_reg : {BUSER_WIDTH{1'b0}};
assign s_axi_bvalid = s_axi_bvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire m_axi_bready_early = s_axi_bready | (~temp_s_axi_bvalid_reg & (~s_axi_bvalid_reg | ~m_axi_bvalid));

always @* begin
    // transfer sink ready state to source
    s_axi_bvalid_next = s_axi_bvalid_reg;
    temp_s_axi_bvalid_next = temp_s_axi_bvalid_reg;

    store_axi_b_input_to_output = 1'b0;
    store_axi_b_input_to_temp = 1'b0;
    store_axi_b_temp_to_output = 1'b0;

    if (m_axi_bready_reg) begin
        // input is ready
        if (s_axi_bready | ~s_axi_bvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            s_axi_bvalid_next = m_axi_bvalid;
            store_axi_b_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_s_axi_bvalid_next = m_axi_bvalid;
            store_axi_b_input_to_temp = 1'b1;
        end
    end else if (s_axi_bready) begin
        // input is not ready, but output is ready
        s_axi_bvalid_next = temp_s_axi_bvalid_reg;
        temp_s_axi_bvalid_next = 1'b0;
        store_axi_b_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axi_bready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
        temp_s_axi_bvalid_reg <= 1'b0;
    end else begin
        m_axi_bready_reg <= m_axi_bready_early;
        s_axi_bvalid_reg <= s_axi_bvalid_next;
        temp_s_axi_bvalid_reg <= temp_s_axi_bvalid_next;
    end

    // datapath
    if (store_axi_b_input_to_output) begin
        s_axi_bid_reg   <= m_axi_bid;
        s_axi_bresp_reg <= m_axi_bresp;
        s_axi_buser_reg <= m_axi_buser;
    end else if (store_axi_b_temp_to_output) begin
        s_axi_bid_reg   <= temp_s_axi_bid_reg;
        s_axi_bresp_reg <= temp_s_axi_bresp_reg;
        s_axi_buser_reg <= temp_s_axi_buser_reg;
    end

    if (store_axi_b_input_to_temp) begin
        temp_s_axi_bid_reg   <= m_axi_bid;
        temp_s_axi_bresp_reg <= m_axi_bresp;
        temp_s_axi_buser_reg <= m_axi_buser;
    end
end

end else if (B_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   m_axi_bready_reg = 1'b0;

reg [ID_WIDTH-1:0]    s_axi_bid_reg    = {ID_WIDTH{1'b0}};
reg [1:0]             s_axi_bresp_reg  = 2'b0;
reg [BUSER_WIDTH-1:0] s_axi_buser_reg  = {BUSER_WIDTH{1'b0}};
reg                   s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;

// datapath control
reg store_axi_b_input_to_output;

assign m_axi_bready = m_axi_bready_reg;

assign s_axi_bid    = s_axi_bid_reg;
assign s_axi_bresp  = s_axi_bresp_reg;
assign s_axi_buser  = BUSER_ENABLE ? s_axi_buser_reg : {BUSER_WIDTH{1'b0}};
assign s_axi_bvalid = s_axi_bvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire m_axi_bready_early = !s_axi_bvalid_next;

always @* begin
    // transfer sink ready state to source
    s_axi_bvalid_next = s_axi_bvalid_reg;

    store_axi_b_input_to_output = 1'b0;

    if (m_axi_bready_reg) begin
        s_axi_bvalid_next = m_axi_bvalid;
        store_axi_b_input_to_output = 1'b1;
    end else if (s_axi_bready) begin
        s_axi_bvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axi_bready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
    end else begin
        m_axi_bready_reg <= m_axi_bready_early;
        s_axi_bvalid_reg <= s_axi_bvalid_next;
    end

    // datapath
    if (store_axi_b_input_to_output) begin
        s_axi_bid_reg   <= m_axi_bid;
        s_axi_bresp_reg <= m_axi_bresp;
        s_axi_buser_reg <= m_axi_buser;
    end
end

end else begin

    // bypass B channel
    assign s_axi_bid = m_axi_bid;
    assign s_axi_bresp = m_axi_bresp;
    assign s_axi_buser = BUSER_ENABLE ? m_axi_buser : {BUSER_WIDTH{1'b0}};
    assign s_axi_bvalid = m_axi_bvalid;
    assign m_axi_bready = s_axi_bready;

end

endgenerate

endmodule

`resetall

/*

Copyright (c) 2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 register (read)
 */
module axi_register_rd #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    // AR channel register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter AR_REG_TYPE = 1,
    // R channel register type
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter R_REG_TYPE = 2
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    /*
     * AXI master interface
     */
    output wire [ID_WIDTH-1:0]      m_axi_arid,
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arlock,
    output wire [3:0]               m_axi_arcache,
    output wire [2:0]               m_axi_arprot,
    output wire [3:0]               m_axi_arqos,
    output wire [3:0]               m_axi_arregion,
    output wire [ARUSER_WIDTH-1:0]  m_axi_aruser,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [ID_WIDTH-1:0]      m_axi_rid,
    input  wire [DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire [RUSER_WIDTH-1:0]   m_axi_ruser,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready
);

generate

// AR channel

if (AR_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                    s_axi_arready_reg = 1'b0;

reg [ID_WIDTH-1:0]     m_axi_arid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   m_axi_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              m_axi_arlen_reg    = 8'd0;
reg [2:0]              m_axi_arsize_reg   = 3'd0;
reg [1:0]              m_axi_arburst_reg  = 2'd0;
reg                    m_axi_arlock_reg   = 1'b0;
reg [3:0]              m_axi_arcache_reg  = 4'd0;
reg [2:0]              m_axi_arprot_reg   = 3'd0;
reg [3:0]              m_axi_arqos_reg    = 4'd0;
reg [3:0]              m_axi_arregion_reg = 4'd0;
reg [ARUSER_WIDTH-1:0] m_axi_aruser_reg   = {ARUSER_WIDTH{1'b0}};
reg                    m_axi_arvalid_reg  = 1'b0, m_axi_arvalid_next;

reg [ID_WIDTH-1:0]     temp_m_axi_arid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   temp_m_axi_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              temp_m_axi_arlen_reg    = 8'd0;
reg [2:0]              temp_m_axi_arsize_reg   = 3'd0;
reg [1:0]              temp_m_axi_arburst_reg  = 2'd0;
reg                    temp_m_axi_arlock_reg   = 1'b0;
reg [3:0]              temp_m_axi_arcache_reg  = 4'd0;
reg [2:0]              temp_m_axi_arprot_reg   = 3'd0;
reg [3:0]              temp_m_axi_arqos_reg    = 4'd0;
reg [3:0]              temp_m_axi_arregion_reg = 4'd0;
reg [ARUSER_WIDTH-1:0] temp_m_axi_aruser_reg   = {ARUSER_WIDTH{1'b0}};
reg                    temp_m_axi_arvalid_reg  = 1'b0, temp_m_axi_arvalid_next;

// datapath control
reg store_axi_ar_input_to_output;
reg store_axi_ar_input_to_temp;
reg store_axi_ar_temp_to_output;

assign s_axi_arready  = s_axi_arready_reg;

assign m_axi_arid     = m_axi_arid_reg;
assign m_axi_araddr   = m_axi_araddr_reg;
assign m_axi_arlen    = m_axi_arlen_reg;
assign m_axi_arsize   = m_axi_arsize_reg;
assign m_axi_arburst  = m_axi_arburst_reg;
assign m_axi_arlock   = m_axi_arlock_reg;
assign m_axi_arcache  = m_axi_arcache_reg;
assign m_axi_arprot   = m_axi_arprot_reg;
assign m_axi_arqos    = m_axi_arqos_reg;
assign m_axi_arregion = m_axi_arregion_reg;
assign m_axi_aruser   = ARUSER_ENABLE ? m_axi_aruser_reg : {ARUSER_WIDTH{1'b0}};
assign m_axi_arvalid  = m_axi_arvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire s_axi_arready_early = m_axi_arready | (~temp_m_axi_arvalid_reg & (~m_axi_arvalid_reg | ~s_axi_arvalid));

always @* begin
    // transfer sink ready state to source
    m_axi_arvalid_next = m_axi_arvalid_reg;
    temp_m_axi_arvalid_next = temp_m_axi_arvalid_reg;

    store_axi_ar_input_to_output = 1'b0;
    store_axi_ar_input_to_temp = 1'b0;
    store_axi_ar_temp_to_output = 1'b0;

    if (s_axi_arready_reg) begin
        // input is ready
        if (m_axi_arready | ~m_axi_arvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axi_arvalid_next = s_axi_arvalid;
            store_axi_ar_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axi_arvalid_next = s_axi_arvalid;
            store_axi_ar_input_to_temp = 1'b1;
        end
    end else if (m_axi_arready) begin
        // input is not ready, but output is ready
        m_axi_arvalid_next = temp_m_axi_arvalid_reg;
        temp_m_axi_arvalid_next = 1'b0;
        store_axi_ar_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_arready_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        temp_m_axi_arvalid_reg <= 1'b0;
    end else begin
        s_axi_arready_reg <= s_axi_arready_early;
        m_axi_arvalid_reg <= m_axi_arvalid_next;
        temp_m_axi_arvalid_reg <= temp_m_axi_arvalid_next;
    end

    // datapath
    if (store_axi_ar_input_to_output) begin
        m_axi_arid_reg <= s_axi_arid;
        m_axi_araddr_reg <= s_axi_araddr;
        m_axi_arlen_reg <= s_axi_arlen;
        m_axi_arsize_reg <= s_axi_arsize;
        m_axi_arburst_reg <= s_axi_arburst;
        m_axi_arlock_reg <= s_axi_arlock;
        m_axi_arcache_reg <= s_axi_arcache;
        m_axi_arprot_reg <= s_axi_arprot;
        m_axi_arqos_reg <= s_axi_arqos;
        m_axi_arregion_reg <= s_axi_arregion;
        m_axi_aruser_reg <= s_axi_aruser;
    end else if (store_axi_ar_temp_to_output) begin
        m_axi_arid_reg <= temp_m_axi_arid_reg;
        m_axi_araddr_reg <= temp_m_axi_araddr_reg;
        m_axi_arlen_reg <= temp_m_axi_arlen_reg;
        m_axi_arsize_reg <= temp_m_axi_arsize_reg;
        m_axi_arburst_reg <= temp_m_axi_arburst_reg;
        m_axi_arlock_reg <= temp_m_axi_arlock_reg;
        m_axi_arcache_reg <= temp_m_axi_arcache_reg;
        m_axi_arprot_reg <= temp_m_axi_arprot_reg;
        m_axi_arqos_reg <= temp_m_axi_arqos_reg;
        m_axi_arregion_reg <= temp_m_axi_arregion_reg;
        m_axi_aruser_reg <= temp_m_axi_aruser_reg;
    end

    if (store_axi_ar_input_to_temp) begin
        temp_m_axi_arid_reg <= s_axi_arid;
        temp_m_axi_araddr_reg <= s_axi_araddr;
        temp_m_axi_arlen_reg <= s_axi_arlen;
        temp_m_axi_arsize_reg <= s_axi_arsize;
        temp_m_axi_arburst_reg <= s_axi_arburst;
        temp_m_axi_arlock_reg <= s_axi_arlock;
        temp_m_axi_arcache_reg <= s_axi_arcache;
        temp_m_axi_arprot_reg <= s_axi_arprot;
        temp_m_axi_arqos_reg <= s_axi_arqos;
        temp_m_axi_arregion_reg <= s_axi_arregion;
        temp_m_axi_aruser_reg <= s_axi_aruser;
    end
end

end else if (AR_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                    s_axi_arready_reg = 1'b0;

reg [ID_WIDTH-1:0]     m_axi_arid_reg     = {ID_WIDTH{1'b0}};
reg [ADDR_WIDTH-1:0]   m_axi_araddr_reg   = {ADDR_WIDTH{1'b0}};
reg [7:0]              m_axi_arlen_reg    = 8'd0;
reg [2:0]              m_axi_arsize_reg   = 3'd0;
reg [1:0]              m_axi_arburst_reg  = 2'd0;
reg                    m_axi_arlock_reg   = 1'b0;
reg [3:0]              m_axi_arcache_reg  = 4'd0;
reg [2:0]              m_axi_arprot_reg   = 3'd0;
reg [3:0]              m_axi_arqos_reg    = 4'd0;
reg [3:0]              m_axi_arregion_reg = 4'd0;
reg [ARUSER_WIDTH-1:0] m_axi_aruser_reg   = {ARUSER_WIDTH{1'b0}};
reg                    m_axi_arvalid_reg  = 1'b0, m_axi_arvalid_next;

// datapath control
reg store_axi_ar_input_to_output;

assign s_axi_arready  = s_axi_arready_reg;

assign m_axi_arid     = m_axi_arid_reg;
assign m_axi_araddr   = m_axi_araddr_reg;
assign m_axi_arlen    = m_axi_arlen_reg;
assign m_axi_arsize   = m_axi_arsize_reg;
assign m_axi_arburst  = m_axi_arburst_reg;
assign m_axi_arlock   = m_axi_arlock_reg;
assign m_axi_arcache  = m_axi_arcache_reg;
assign m_axi_arprot   = m_axi_arprot_reg;
assign m_axi_arqos    = m_axi_arqos_reg;
assign m_axi_arregion = m_axi_arregion_reg;
assign m_axi_aruser   = ARUSER_ENABLE ? m_axi_aruser_reg : {ARUSER_WIDTH{1'b0}};
assign m_axi_arvalid  = m_axi_arvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire s_axi_arready_early = !m_axi_arvalid_next;

always @* begin
    // transfer sink ready state to source
    m_axi_arvalid_next = m_axi_arvalid_reg;

    store_axi_ar_input_to_output = 1'b0;

    if (s_axi_arready_reg) begin
        m_axi_arvalid_next = s_axi_arvalid;
        store_axi_ar_input_to_output = 1'b1;
    end else if (m_axi_arready) begin
        m_axi_arvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        s_axi_arready_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
    end else begin
        s_axi_arready_reg <= s_axi_arready_early;
        m_axi_arvalid_reg <= m_axi_arvalid_next;
    end

    // datapath
    if (store_axi_ar_input_to_output) begin
        m_axi_arid_reg <= s_axi_arid;
        m_axi_araddr_reg <= s_axi_araddr;
        m_axi_arlen_reg <= s_axi_arlen;
        m_axi_arsize_reg <= s_axi_arsize;
        m_axi_arburst_reg <= s_axi_arburst;
        m_axi_arlock_reg <= s_axi_arlock;
        m_axi_arcache_reg <= s_axi_arcache;
        m_axi_arprot_reg <= s_axi_arprot;
        m_axi_arqos_reg <= s_axi_arqos;
        m_axi_arregion_reg <= s_axi_arregion;
        m_axi_aruser_reg <= s_axi_aruser;
    end
end

end else begin

    // bypass AR channel
    assign m_axi_arid = s_axi_arid;
    assign m_axi_araddr = s_axi_araddr;
    assign m_axi_arlen = s_axi_arlen;
    assign m_axi_arsize = s_axi_arsize;
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arlock = s_axi_arlock;
    assign m_axi_arcache = s_axi_arcache;
    assign m_axi_arprot = s_axi_arprot;
    assign m_axi_arqos = s_axi_arqos;
    assign m_axi_arregion = s_axi_arregion;
    assign m_axi_aruser = ARUSER_ENABLE ? s_axi_aruser : {ARUSER_WIDTH{1'b0}};
    assign m_axi_arvalid = s_axi_arvalid;
    assign s_axi_arready = m_axi_arready;

end

// R channel

if (R_REG_TYPE > 1) begin
// skid buffer, no bubble cycles

// datapath registers
reg                   m_axi_rready_reg = 1'b0;

reg [ID_WIDTH-1:0]    s_axi_rid_reg    = {ID_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0]  s_axi_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             s_axi_rresp_reg  = 2'b0;
reg                   s_axi_rlast_reg  = 1'b0;
reg [RUSER_WIDTH-1:0] s_axi_ruser_reg  = {RUSER_WIDTH{1'b0}};
reg                   s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;

reg [ID_WIDTH-1:0]    temp_s_axi_rid_reg    = {ID_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0]  temp_s_axi_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             temp_s_axi_rresp_reg  = 2'b0;
reg                   temp_s_axi_rlast_reg  = 1'b0;
reg [RUSER_WIDTH-1:0] temp_s_axi_ruser_reg  = {RUSER_WIDTH{1'b0}};
reg                   temp_s_axi_rvalid_reg = 1'b0, temp_s_axi_rvalid_next;

// datapath control
reg store_axi_r_input_to_output;
reg store_axi_r_input_to_temp;
reg store_axi_r_temp_to_output;

assign m_axi_rready = m_axi_rready_reg;

assign s_axi_rid    = s_axi_rid_reg;
assign s_axi_rdata  = s_axi_rdata_reg;
assign s_axi_rresp  = s_axi_rresp_reg;
assign s_axi_rlast  = s_axi_rlast_reg;
assign s_axi_ruser  = RUSER_ENABLE ? s_axi_ruser_reg : {RUSER_WIDTH{1'b0}};
assign s_axi_rvalid = s_axi_rvalid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
wire m_axi_rready_early = s_axi_rready | (~temp_s_axi_rvalid_reg & (~s_axi_rvalid_reg | ~m_axi_rvalid));

always @* begin
    // transfer sink ready state to source
    s_axi_rvalid_next = s_axi_rvalid_reg;
    temp_s_axi_rvalid_next = temp_s_axi_rvalid_reg;

    store_axi_r_input_to_output = 1'b0;
    store_axi_r_input_to_temp = 1'b0;
    store_axi_r_temp_to_output = 1'b0;

    if (m_axi_rready_reg) begin
        // input is ready
        if (s_axi_rready | ~s_axi_rvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            s_axi_rvalid_next = m_axi_rvalid;
            store_axi_r_input_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_s_axi_rvalid_next = m_axi_rvalid;
            store_axi_r_input_to_temp = 1'b1;
        end
    end else if (s_axi_rready) begin
        // input is not ready, but output is ready
        s_axi_rvalid_next = temp_s_axi_rvalid_reg;
        temp_s_axi_rvalid_next = 1'b0;
        store_axi_r_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axi_rready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;
        temp_s_axi_rvalid_reg <= 1'b0;
    end else begin
        m_axi_rready_reg <= m_axi_rready_early;
        s_axi_rvalid_reg <= s_axi_rvalid_next;
        temp_s_axi_rvalid_reg <= temp_s_axi_rvalid_next;
    end

    // datapath
    if (store_axi_r_input_to_output) begin
        s_axi_rid_reg   <= m_axi_rid;
        s_axi_rdata_reg <= m_axi_rdata;
        s_axi_rresp_reg <= m_axi_rresp;
        s_axi_rlast_reg <= m_axi_rlast;
        s_axi_ruser_reg <= m_axi_ruser;
    end else if (store_axi_r_temp_to_output) begin
        s_axi_rid_reg   <= temp_s_axi_rid_reg;
        s_axi_rdata_reg <= temp_s_axi_rdata_reg;
        s_axi_rresp_reg <= temp_s_axi_rresp_reg;
        s_axi_rlast_reg <= temp_s_axi_rlast_reg;
        s_axi_ruser_reg <= temp_s_axi_ruser_reg;
    end

    if (store_axi_r_input_to_temp) begin
        temp_s_axi_rid_reg   <= m_axi_rid;
        temp_s_axi_rdata_reg <= m_axi_rdata;
        temp_s_axi_rresp_reg <= m_axi_rresp;
        temp_s_axi_rlast_reg <= m_axi_rlast;
        temp_s_axi_ruser_reg <= m_axi_ruser;
    end
end

end else if (R_REG_TYPE == 1) begin
// simple register, inserts bubble cycles

// datapath registers
reg                   m_axi_rready_reg = 1'b0;

reg [ID_WIDTH-1:0]    s_axi_rid_reg    = {ID_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0]  s_axi_rdata_reg  = {DATA_WIDTH{1'b0}};
reg [1:0]             s_axi_rresp_reg  = 2'b0;
reg                   s_axi_rlast_reg  = 1'b0;
reg [RUSER_WIDTH-1:0] s_axi_ruser_reg  = {RUSER_WIDTH{1'b0}};
reg                   s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;

// datapath control
reg store_axi_r_input_to_output;

assign m_axi_rready = m_axi_rready_reg;

assign s_axi_rid    = s_axi_rid_reg;
assign s_axi_rdata  = s_axi_rdata_reg;
assign s_axi_rresp  = s_axi_rresp_reg;
assign s_axi_rlast  = s_axi_rlast_reg;
assign s_axi_ruser  = RUSER_ENABLE ? s_axi_ruser_reg : {RUSER_WIDTH{1'b0}};
assign s_axi_rvalid = s_axi_rvalid_reg;

// enable ready input next cycle if output buffer will be empty
wire m_axi_rready_early = !s_axi_rvalid_next;

always @* begin
    // transfer sink ready state to source
    s_axi_rvalid_next = s_axi_rvalid_reg;

    store_axi_r_input_to_output = 1'b0;

    if (m_axi_rready_reg) begin
        s_axi_rvalid_next = m_axi_rvalid;
        store_axi_r_input_to_output = 1'b1;
    end else if (s_axi_rready) begin
        s_axi_rvalid_next = 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        m_axi_rready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;
    end else begin
        m_axi_rready_reg <= m_axi_rready_early;
        s_axi_rvalid_reg <= s_axi_rvalid_next;
    end

    // datapath
    if (store_axi_r_input_to_output) begin
        s_axi_rid_reg   <= m_axi_rid;
        s_axi_rdata_reg <= m_axi_rdata;
        s_axi_rresp_reg <= m_axi_rresp;
        s_axi_rlast_reg <= m_axi_rlast;
        s_axi_ruser_reg <= m_axi_ruser;
    end
end

end else begin

    // bypass R channel
    assign s_axi_rid = m_axi_rid;
    assign s_axi_rdata = m_axi_rdata;
    assign s_axi_rresp = m_axi_rresp;
    assign s_axi_rlast = m_axi_rlast;
    assign s_axi_ruser = RUSER_ENABLE ? m_axi_ruser : {RUSER_WIDTH{1'b0}};
    assign s_axi_rvalid = m_axi_rvalid;
    assign m_axi_rready = s_axi_rready;

end

endgenerate

endmodule

`resetall

/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Arbiter module
 */
module arbiter #
(
    parameter PORTS = 4,
    // select round robin arbitration
    parameter ARB_TYPE_ROUND_ROBIN = 0,
    // blocking arbiter enable
    parameter ARB_BLOCK = 0,
    // block on acknowledge assert when nonzero, request deassert when 0
    parameter ARB_BLOCK_ACK = 1,
    // LSB priority selection
    parameter ARB_LSB_HIGH_PRIORITY = 0
)
(
    input  wire                     clk,
    input  wire                     rst,

    input  wire [PORTS-1:0]         request,
    input  wire [PORTS-1:0]         acknowledge,

    output wire [PORTS-1:0]         grant,
    output wire                     grant_valid,
    output wire [$clog2(PORTS)-1:0] grant_encoded
);

reg [PORTS-1:0] grant_reg = 0, grant_next;
reg grant_valid_reg = 0, grant_valid_next;
reg [$clog2(PORTS)-1:0] grant_encoded_reg = 0, grant_encoded_next;

assign grant_valid = grant_valid_reg;
assign grant = grant_reg;
assign grant_encoded = grant_encoded_reg;

wire request_valid;
wire [$clog2(PORTS)-1:0] request_index;
wire [PORTS-1:0] request_mask;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
priority_encoder_inst (
    .input_unencoded(request),
    .output_valid(request_valid),
    .output_encoded(request_index),
    .output_unencoded(request_mask)
);

reg [PORTS-1:0] mask_reg = 0, mask_next;

wire masked_request_valid;
wire [$clog2(PORTS)-1:0] masked_request_index;
wire [PORTS-1:0] masked_request_mask;

priority_encoder #(
    .WIDTH(PORTS),
    .LSB_HIGH_PRIORITY(ARB_LSB_HIGH_PRIORITY)
)
priority_encoder_masked (
    .input_unencoded(request & mask_reg),
    .output_valid(masked_request_valid),
    .output_encoded(masked_request_index),
    .output_unencoded(masked_request_mask)
);

always @* begin
    grant_next = 0;
    grant_valid_next = 0;
    grant_encoded_next = 0;
    mask_next = mask_reg;

    if (ARB_BLOCK && !ARB_BLOCK_ACK && grant_reg & request) begin
        // granted request still asserted; hold it
        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (ARB_BLOCK && ARB_BLOCK_ACK && grant_valid && !(grant_reg & acknowledge)) begin
        // granted request not yet acknowledged; hold it
        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (request_valid) begin
        if (ARB_TYPE_ROUND_ROBIN) begin
            if (masked_request_valid) begin
                grant_valid_next = 1;
                grant_next = masked_request_mask;
                grant_encoded_next = masked_request_index;
                if (ARB_LSB_HIGH_PRIORITY) begin
                    mask_next = {PORTS{1'b1}} << (masked_request_index + 1);
                end else begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - masked_request_index);
                end
            end else begin
                grant_valid_next = 1;
                grant_next = request_mask;
                grant_encoded_next = request_index;
                if (ARB_LSB_HIGH_PRIORITY) begin
                    mask_next = {PORTS{1'b1}} << (request_index + 1);
                end else begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - request_index);
                end
            end
        end else begin
            grant_valid_next = 1;
            grant_next = request_mask;
            grant_encoded_next = request_index;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        grant_reg <= 0;
        grant_valid_reg <= 0;
        grant_encoded_reg <= 0;
        mask_reg <= 0;
    end else begin
        grant_reg <= grant_next;
        grant_valid_reg <= grant_valid_next;
        grant_encoded_reg <= grant_encoded_next;
        mask_reg <= mask_next;
    end
end

endmodule

`resetall

/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Priority encoder module
 */
module priority_encoder #
(
    parameter WIDTH = 4,
    // LSB priority selection
    parameter LSB_HIGH_PRIORITY = 0
)
(
    input  wire [WIDTH-1:0]         input_unencoded,
    output wire                     output_valid,
    output wire [$clog2(WIDTH)-1:0] output_encoded,
    output wire [WIDTH-1:0]         output_unencoded
);

parameter LEVELS = WIDTH > 2 ? $clog2(WIDTH) : 1;
parameter W = 2**LEVELS;

// pad input to even power of two
wire [W-1:0] input_padded = {{W-WIDTH{1'b0}}, input_unencoded};

wire [W/2-1:0] stage_valid[LEVELS-1:0];
wire [W/2-1:0] stage_enc[LEVELS-1:0];

generate
    genvar l, n;

    // process input bits; generate valid bit and encoded bit for each pair
    for (n = 0; n < W/2; n = n + 1) begin : loop_in
        assign stage_valid[0][n] = |input_padded[n*2+1:n*2];
        if (LSB_HIGH_PRIORITY) begin
            // bit 0 is highest priority
            assign stage_enc[0][n] = !input_padded[n*2+0];
        end else begin
            // bit 0 is lowest priority
            assign stage_enc[0][n] = input_padded[n*2+1];
        end
    end

    // compress down to single valid bit and encoded bus
    for (l = 1; l < LEVELS; l = l + 1) begin : loop_levels
        for (n = 0; n < W/(2*2**l); n = n + 1) begin : loop_compress
            assign stage_valid[l][n] = |stage_valid[l-1][n*2+1:n*2];
            if (LSB_HIGH_PRIORITY) begin
                // bit 0 is highest priority
                assign stage_enc[l][(n+1)*(l+1)-1:n*(l+1)] = stage_valid[l-1][n*2+0] ? {1'b0, stage_enc[l-1][(n*2+1)*l-1:(n*2+0)*l]} : {1'b1, stage_enc[l-1][(n*2+2)*l-1:(n*2+1)*l]};
            end else begin
                // bit 0 is lowest priority
                assign stage_enc[l][(n+1)*(l+1)-1:n*(l+1)] = stage_valid[l-1][n*2+1] ? {1'b1, stage_enc[l-1][(n*2+2)*l-1:(n*2+1)*l]} : {1'b0, stage_enc[l-1][(n*2+1)*l-1:(n*2+0)*l]};
            end
        end
    end
endgenerate

assign output_valid = stage_valid[LEVELS-1];
assign output_encoded = stage_enc[LEVELS-1];
assign output_unencoded = 1 << output_encoded;

endmodule

`resetall
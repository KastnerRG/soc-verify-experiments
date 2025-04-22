/* 
    Top module for simulation
    Components
    RTL on-chip Top
        - DNN engine
        - Controller
            -BRAM and register
        - axilite interface (connected but not used in simulation), we write to controller reg directly using DPI-C
        - 3 Alex DMAs
    3 Zip cpus converting AXI4 requests to ram rw requests
*/
`timescale 1ns/1ps
`define VERILOG
`include "../../rtl/defines.svh"
`include "config_tb.svh"
`undef  VERILOG

module cgra4ml_axi2ram_tb #(
    // Parameters for DNN engine
    parameter   ROWS                    = `ROWS               ,
                COLS                    = `COLS               ,
                X_BITS                  = `X_BITS             , 
                K_BITS                  = `K_BITS             , 
                Y_BITS                  = `Y_BITS             ,
                Y_OUT_BITS              = `Y_OUT_BITS         ,
                M_DATA_WIDTH_HF_CONV    = COLS  * ROWS  * Y_BITS,
                M_DATA_WIDTH_HF_CONV_DW = ROWS  * Y_BITS,

                AXI_WIDTH               = `AXI_WIDTH  ,
                AXI_MAX_BURST_LEN       = `AXI_MAX_BURST_LEN,
                W_BPT                   = `W_BPT,

                OUT_ADDR_WIDTH          = 10,
                OUT_BITS                = 32,
    // Parameters for controller
                SRAM_RD_DATA_WIDTH      = 256,
                SRAM_RD_DEPTH           = `MAX_N_BUNDLES,
                COUNTER_WIDTH           = 16,
                AXI_ADDR_WIDTH          = 32,
                AXIL_WIDTH              = 32,
                AXI_LEN_WIDTH           = 32,
                AXIL_BASE_ADDR          = `CONFIG_BASEADDR,
    
    // Parameters for axilite to ram
                DATA_WR_WIDTH           = 32,
                DATA_RD_WIDTH           = 32,
                AXIL_ADDR_WIDTH              = 40,
                STRB_WIDTH              = 4,
                TIMEOUT                 = 2,

    // Alex AXI DMA RD
                AXI_DATA_WIDTH_PS       = AXI_WIDTH,
                //AXI_ADDR_WIDTH          = 32, same as above
                AXI_STRB_WIDTH          = (AXI_WIDTH/8),
                AXI_ID_WIDTH            = 6,
                AXIS_DATA_WIDTH         = AXI_WIDTH,//AXIL_DATA_WIDTH,
                AXIS_KEEP_ENABLE        = 1,//(AXIS_DATA_WIDTH>8),
                AXIS_KEEP_WIDTH         = (AXI_WIDTH/8),//(AXIS_DATA_WIDTH/8),
                AXIS_LAST_ENABLE        = 1,
                AXIS_ID_ENABLE          = 0,
                AXIS_ID_WIDTH           = 6,
                AXIS_DEST_ENABLE        = 0,
                AXIS_DEST_WIDTH         = 8,
                AXIS_USER_ENABLE        = 1,
                AXIS_USER_WIDTH         = 1,
                LEN_WIDTH               = 32,
                TAG_WIDTH               = 8,
                ENABLE_SG               = 0,
                ENABLE_UNALIGNED        = 1,
    
    // Parameters for zip cpu
		        C_S_AXI_ID_WIDTH	    = 6,
		        C_S_AXI_DATA_WIDTH	    = AXI_WIDTH,
		        C_S_AXI_ADDR_WIDTH	    = 32,
		        OPT_LOCK                = 1'b0,
		        OPT_LOCKID              = 1'b1,
		        OPT_LOWPOWER            = 1'b0,
    // Randomizer for AXI4 requests
                VALID_PROB              = `VALID_PROB,
                READY_PROB              = `READY_PROB,

    localparam	LSB = $clog2(C_S_AXI_DATA_WIDTH)-3                
)(
    // axilite interface for configuration
    input  logic                   clk,
    input  logic                   rstn,

    /*
     * AXI-Lite slave interface
     */
    input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  logic [2:0]             s_axil_awprot,
    input  logic                   s_axil_awvalid,
    output logic                   s_axil_awready,
    input  logic [DATA_WR_WIDTH-1:0]  s_axil_wdata,
    input  logic [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  logic                   s_axil_wvalid,
    output logic                   s_axil_wready,
    output logic [1:0]             s_axil_bresp,
    output logic                   s_axil_bvalid,
    input  logic                   s_axil_bready,
    input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  logic [2:0]             s_axil_arprot,
    input  logic                   s_axil_arvalid,
    output logic                   s_axil_arready,
    output logic [DATA_RD_WIDTH-1:0]  s_axil_rdata,
    output logic [1:0]             s_axil_rresp,
    output logic                   s_axil_rvalid,
    input  logic                   s_axil_rready,
    
    // ram rw interface for interacting with DDR in sim
    output logic                   o_rd_pixel,
    output logic   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_pixel,
    input  logic   [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_pixel,

    output logic                   o_rd_weights,
    output logic   [C_S_AXI_ADDR_WIDTH-LSB-1:0]   o_raddr_weights,
    input  logic  [C_S_AXI_DATA_WIDTH-1:0]       i_rdata_weights,

    output logic                   o_we_output,
    output logic  [C_S_AXI_ADDR_WIDTH-LSB-1:0]    o_waddr_output,
    output logic  [C_S_AXI_DATA_WIDTH-1:0]        o_wdata_output,
    output logic  [C_S_AXI_DATA_WIDTH/8-1:0]      o_wstrb_output
);

// AXI ports from top on-chip module
    logic [AXI_ID_WIDTH-1:0]    m_axi_pixel_arid;
    logic [AXI_ADDR_WIDTH-1:0]  m_axi_pixel_araddr;
    logic [7:0]                 m_axi_pixel_arlen;
    logic [2:0]                 m_axi_pixel_arsize;
    logic [1:0]                 m_axi_pixel_arburst;
    logic                       m_axi_pixel_arlock;
    logic [3:0]                 m_axi_pixel_arcache;
    logic [2:0]                 m_axi_pixel_arprot;
    logic                       m_axi_pixel_arvalid;
    logic                       m_axi_pixel_arvalid_zipcpu;
    logic                       m_axi_pixel_arready;
    logic                       m_axi_pixel_arready_zipcpu;
    logic [AXI_ID_WIDTH-1:0]    m_axi_pixel_rid;
    logic [AXI_DATA_WIDTH_PS-1:0]  m_axi_pixel_rdata;
    logic [1:0]                 m_axi_pixel_rresp;
    logic                       m_axi_pixel_rlast;
    logic                       m_axi_pixel_rvalid;
    logic                       m_axi_pixel_rvalid_zipcpu;
    logic                       m_axi_pixel_rready;
    logic                       m_axi_pixel_rready_zipcpu;

    logic [AXI_ID_WIDTH-1:0]    m_axi_weights_arid;
    logic [AXI_ADDR_WIDTH-1:0]  m_axi_weights_araddr;
    logic [7:0]                 m_axi_weights_arlen;
    logic [2:0]                 m_axi_weights_arsize;
    logic [1:0]                 m_axi_weights_arburst;
    logic                       m_axi_weights_arlock;
    logic [3:0]                 m_axi_weights_arcache;
    logic [2:0]                 m_axi_weights_arprot;
    logic                       m_axi_weights_arvalid;
    logic                       m_axi_weights_arvalid_zipcpu;
    logic                       m_axi_weights_arready;
    logic                       m_axi_weights_arready_zipcpu;
    logic [AXI_ID_WIDTH-1:0]    m_axi_weights_rid;
    logic [AXI_DATA_WIDTH_PS-1:0]  m_axi_weights_rdata;
    logic [1:0]                 m_axi_weights_rresp;
    logic                       m_axi_weights_rlast;
    logic                       m_axi_weights_rvalid;
    logic                       m_axi_weights_rvalid_zipcpu;
    logic                       m_axi_weights_rready;
    logic                       m_axi_weights_rready_zipcpu;

    logic [AXI_ID_WIDTH-1:0]    m_axi_output_awid;
    logic [AXI_ADDR_WIDTH-1:0]  m_axi_output_awaddr;
    logic [7:0]                 m_axi_output_awlen;
    logic [2:0]                 m_axi_output_awsize;
    logic [1:0]                 m_axi_output_awburst;
    logic                       m_axi_output_awlock;
    logic [3:0]                 m_axi_output_awcache;
    logic [2:0]                 m_axi_output_awprot;
    logic                       m_axi_output_awvalid;
    logic                       m_axi_output_awvalid_zipcpu;
    logic                       m_axi_output_awready;
    logic                       m_axi_output_awready_zipcpu;
    logic [AXI_DATA_WIDTH_PS-1:0]  m_axi_output_wdata;
    logic [AXI_STRB_WIDTH-1:0]  m_axi_output_wstrb;
    logic                       m_axi_output_wlast;
    logic                       m_axi_output_wvalid;
    logic                       m_axi_output_wvalid_zipcpu;
    logic                       m_axi_output_wready;
    logic                       m_axi_output_wready_zipcpu;
    logic [AXI_ID_WIDTH-1:0]    m_axi_output_bid;
    logic [1:0]                 m_axi_output_bresp;
    logic                       m_axi_output_bvalid;
    logic                       m_axi_output_bvalid_zipcpu;
    logic                       m_axi_output_bready;
    logic                       m_axi_output_bready_zipcpu;

    logic weights_ar  ;
    logic weights_r   ;

    logic rand_pixel_ar  ;
    logic rand_pixel_r   ;
    logic rand_weights_ar;
    logic rand_weights_r ;
    logic rand_output_aw;
    logic rand_output_w;
    logic rand_output_b;

    // Randomizer for AXI4 requests
    // Always yield to output. Give to weights only if weights asks and 20% prob, else give to pixel all other times

    always_ff @( posedge clk ) begin
        rand_weights_r  <= $urandom_range(0, 10) < 2;
        rand_weights_ar <= $urandom_range(0, 10) < 2;
    end

    always_comb begin
        assign weights_ar = m_axi_weights_arvalid & rand_weights_ar; // pixel has the bus
        assign weights_r  = m_axi_weights_rvalid_zipcpu & rand_weights_r; // pixel has the bus

        {m_axi_pixel_arvalid_zipcpu, m_axi_pixel_arready    } = {2{~weights_ar}} & {m_axi_pixel_arvalid, m_axi_pixel_arready_zipcpu    };
        {m_axi_weights_arvalid_zipcpu, m_axi_weights_arready} = {2{ weights_ar}} & {m_axi_weights_arvalid, m_axi_weights_arready_zipcpu};
        {m_axi_pixel_rvalid, m_axi_pixel_rready_zipcpu      } = {2{~weights_r }} & {m_axi_pixel_rvalid_zipcpu, m_axi_pixel_rready      };
        {m_axi_weights_rvalid, m_axi_weights_rready_zipcpu  } = {2{ weights_r }} & {m_axi_weights_rvalid_zipcpu, m_axi_weights_rready  };
        //Output always ready
        {m_axi_output_awvalid_zipcpu, m_axi_output_awready  } = {m_axi_output_awvalid, m_axi_output_awready_zipcpu  };
        {m_axi_output_wvalid_zipcpu, m_axi_output_wready    } = {m_axi_output_wvalid, m_axi_output_wready_zipcpu    };
        {m_axi_output_bvalid, m_axi_output_bready_zipcpu    } = {m_axi_output_bvalid_zipcpu, m_axi_output_bready    };
    end


    // always_comb begin
    //     {m_axi_pixel_arvalid_zipcpu, m_axi_pixel_arready    } = {2{rand_pixel_ar  }} & {m_axi_pixel_arvalid, m_axi_pixel_arready_zipcpu    };
    //     {m_axi_pixel_rvalid, m_axi_pixel_rready_zipcpu      } = {2{rand_pixel_r   }} & {m_axi_pixel_rvalid_zipcpu, m_axi_pixel_rready      };
    //     {m_axi_weights_arvalid_zipcpu, m_axi_weights_arready} = {2{rand_weights_ar}} & {m_axi_weights_arvalid, m_axi_weights_arready_zipcpu};
    //     {m_axi_weights_rvalid, m_axi_weights_rready_zipcpu  } = {2{rand_weights_r }} & {m_axi_weights_rvalid_zipcpu, m_axi_weights_rready  };
    //     //Output always ready
    //     {m_axi_output_awvalid_zipcpu, m_axi_output_awready  } = {2{rand_output_aw }} & {m_axi_output_awvalid, m_axi_output_awready_zipcpu  };
    //     {m_axi_output_wvalid_zipcpu, m_axi_output_wready    } = {2{rand_output_w  }} & {m_axi_output_wvalid, m_axi_output_wready_zipcpu    };
    //     {m_axi_output_bvalid, m_axi_output_bready_zipcpu    } = {2{rand_output_b  }} & {m_axi_output_bvalid_zipcpu, m_axi_output_bready    };
    // end

zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_PIXELS (
    .o_we(),
    .o_waddr(),
    .o_wdata(),
    .o_wstrb(),
    .o_rd(o_rd_pixel),
    .o_raddr(o_raddr_pixel),
    .i_rdata(i_rdata_pixel),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(),
    .S_AXI_AWADDR(),
    .S_AXI_AWLEN(),
    .S_AXI_AWSIZE(),
    .S_AXI_AWBURST(),
    .S_AXI_AWLOCK(),
    .S_AXI_AWCACHE(),
    .S_AXI_AWPROT(),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID(1'b0),
    .S_AXI_AWREADY(),
    .S_AXI_WDATA(),
    .S_AXI_WSTRB(),
    .S_AXI_WLAST(),
    .S_AXI_WVALID(1'b0),
    .S_AXI_WREADY(),
    .S_AXI_BID(),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(),
    .S_AXI_BREADY(),
    .S_AXI_ARID(m_axi_pixel_arid),
    .S_AXI_ARADDR(m_axi_pixel_araddr),
    .S_AXI_ARLEN(m_axi_pixel_arlen),
    .S_AXI_ARSIZE(m_axi_pixel_arsize),
    .S_AXI_ARBURST(m_axi_pixel_arburst),
    .S_AXI_ARLOCK(m_axi_pixel_arlock),
    .S_AXI_ARCACHE(m_axi_pixel_arcache),
    .S_AXI_ARPROT(m_axi_pixel_arprot),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(m_axi_pixel_arvalid_zipcpu),
    .S_AXI_ARREADY(m_axi_pixel_arready_zipcpu),
    .S_AXI_RID(m_axi_pixel_rid),
    .S_AXI_RDATA(m_axi_pixel_rdata),
    .S_AXI_RRESP(m_axi_pixel_rresp),
    .S_AXI_RLAST(m_axi_pixel_rlast),
    .S_AXI_RVALID(m_axi_pixel_rvalid_zipcpu),
    .S_AXI_RREADY(m_axi_pixel_rready_zipcpu)
);

zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_WEIGHTS (
    .o_we(),
    .o_waddr(),
    .o_wdata(),
    .o_wstrb(),
    .o_rd(o_rd_weights),
    .o_raddr(o_raddr_weights),
    .i_rdata(i_rdata_weights),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(),
    .S_AXI_AWADDR(),
    .S_AXI_AWLEN(),
    .S_AXI_AWSIZE(),
    .S_AXI_AWBURST(),
    .S_AXI_AWLOCK(),
    .S_AXI_AWCACHE(),
    .S_AXI_AWPROT(),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID('0),
    .S_AXI_AWREADY(),
    .S_AXI_WDATA(),
    .S_AXI_WSTRB(),
    .S_AXI_WLAST(),
    .S_AXI_WVALID(1'b0),
    .S_AXI_WREADY(),
    .S_AXI_BID(),
    .S_AXI_BRESP(),
    .S_AXI_BVALID(),
    .S_AXI_BREADY(),
    .S_AXI_ARID(m_axi_weights_arid),
    .S_AXI_ARADDR(m_axi_weights_araddr),
    .S_AXI_ARLEN(m_axi_weights_arlen),
    .S_AXI_ARSIZE(m_axi_weights_arsize),
    .S_AXI_ARBURST(m_axi_weights_arburst),
    .S_AXI_ARLOCK(m_axi_weights_arlock),
    .S_AXI_ARCACHE(m_axi_weights_arcache),
    .S_AXI_ARPROT(m_axi_weights_arprot),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(m_axi_weights_arvalid_zipcpu),
    .S_AXI_ARREADY(m_axi_weights_arready_zipcpu),
    .S_AXI_RID(m_axi_weights_rid),
    .S_AXI_RDATA(m_axi_weights_rdata),
    .S_AXI_RRESP(m_axi_weights_rresp),
    .S_AXI_RLAST(m_axi_weights_rlast),
    .S_AXI_RVALID(m_axi_weights_rvalid_zipcpu),
    .S_AXI_RREADY(m_axi_weights_rready_zipcpu)
);

zipcpu_axi2ram #(
    .C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
    .OPT_LOCK(OPT_LOCK),
    .OPT_LOCKID(OPT_LOCKID),
    .OPT_LOWPOWER(OPT_LOWPOWER)
) ZIP_OUTPUT (
    .o_we(o_we_output),
    .o_waddr(o_waddr_output),
    .o_wdata(o_wdata_output),
    .o_wstrb(o_wstrb_output),
    .o_rd(),
    .o_raddr(),
    .i_rdata(),
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(rstn),
    .S_AXI_AWID(m_axi_output_awid),
    .S_AXI_AWADDR(m_axi_output_awaddr),
    .S_AXI_AWLEN(m_axi_output_awlen),
    .S_AXI_AWSIZE(m_axi_output_awsize),
    .S_AXI_AWBURST(m_axi_output_awburst),
    .S_AXI_AWLOCK(m_axi_output_awlock),
    .S_AXI_AWCACHE(m_axi_output_awcache),
    .S_AXI_AWPROT(m_axi_output_awprot),
    .S_AXI_AWQOS(),
    .S_AXI_AWVALID(m_axi_output_awvalid_zipcpu),
    .S_AXI_AWREADY(m_axi_output_awready_zipcpu),
    .S_AXI_WDATA(m_axi_output_wdata),
    .S_AXI_WSTRB(m_axi_output_wstrb),
    .S_AXI_WLAST(m_axi_output_wlast),
    .S_AXI_WVALID(m_axi_output_wvalid_zipcpu),
    .S_AXI_WREADY(m_axi_output_wready_zipcpu),
    .S_AXI_BID(m_axi_output_bid),
    .S_AXI_BRESP(m_axi_output_bresp),
    .S_AXI_BVALID(m_axi_output_bvalid_zipcpu),
    .S_AXI_BREADY(m_axi_output_bready_zipcpu),
    .S_AXI_ARID(),
    .S_AXI_ARADDR(),
    .S_AXI_ARLEN(),
    .S_AXI_ARSIZE(),
    .S_AXI_ARBURST(),
    .S_AXI_ARLOCK(),
    .S_AXI_ARCACHE(),
    .S_AXI_ARPROT(),
    .S_AXI_ARQOS(),
    .S_AXI_ARVALID(1'b0),
    .S_AXI_ARREADY(),
    .S_AXI_RID(),
    .S_AXI_RDATA(),
    .S_AXI_RRESP(),
    .S_AXI_RLAST(),
    .S_AXI_RVALID(),
    .S_AXI_RREADY(1'b0)
);

axi_cgra4ml #(
    .ROWS(ROWS),
    .COLS(COLS),
    .X_BITS(X_BITS),
    .K_BITS(K_BITS),
    .Y_BITS(Y_BITS),
    .Y_OUT_BITS(Y_OUT_BITS),
    .M_DATA_WIDTH_HF_CONV(M_DATA_WIDTH_HF_CONV),
    .M_DATA_WIDTH_HF_CONV_DW(M_DATA_WIDTH_HF_CONV_DW),

    .AXI_WIDTH(AXI_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),

    .AXIL_WIDTH(AXIL_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .W_BPT(W_BPT)
) OC_TOP (
    .*
);

endmodule
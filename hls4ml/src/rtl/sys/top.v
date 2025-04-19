`timescale 1ns/1ps

module top #(
    parameter
        R  = 8,
        C  = 8,
        WK = 8,
        WX = 8,
        WA = 8,
        WY = 8,
        LM = 1,
        LA = 1,

        // Full AXI
        AXI_WIDTH               = 128,
        AXI_ID_WIDTH            = 6,
        AXI_STRB_WIDTH          = (AXI_WIDTH/8),
        AXI_MAX_BURST_LEN       = 32,
        AXI_ADDR_WIDTH          = 32,
        AXIS_USER_WIDTH         = 8,         
        // AXI-Lite
        AXIL_WIDTH              = 32,
        AXIL_ADDR_WIDTH         = 40,
        STRB_WIDTH              = 4,
        AXIL_BASE_ADDR          = 32'hA0000000

) (
    // axilite interface for configuration
    input  wire                   clk,
    input  wire                   rstn,

    /*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [AXIL_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [AXIL_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,
    /*
        * AXI 4 Master interface
    */
    // Input
    output wire [AXI_ID_WIDTH-1:0]    m_axi_mm2s_0_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_mm2s_0_araddr,
    output wire [7:0]                 m_axi_mm2s_0_arlen,
    output wire [2:0]                 m_axi_mm2s_0_arsize,
    output wire [1:0]                 m_axi_mm2s_0_arburst,
    output wire                       m_axi_mm2s_0_arlock,
    output wire [3:0]                 m_axi_mm2s_0_arcache,
    output wire [2:0]                 m_axi_mm2s_0_arprot,
    output wire                       m_axi_mm2s_0_arvalid,
    input  wire                       m_axi_mm2s_0_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_mm2s_0_rid,
    input  wire [AXI_WIDTH   -1:0]    m_axi_mm2s_0_rdata,
    input  wire [1:0]                 m_axi_mm2s_0_rresp,
    input  wire                       m_axi_mm2s_0_rlast,
    input  wire                       m_axi_mm2s_0_rvalid,
    output wire                       m_axi_mm2s_0_rready,

    // Output
    // (* mark_debug = "true" *) 
    output wire [AXI_ID_WIDTH-1:0]    m_axi_s2mm_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_s2mm_awaddr,
    output wire [7:0]                 m_axi_s2mm_awlen,
    output wire [2:0]                 m_axi_s2mm_awsize,
    output wire [1:0]                 m_axi_s2mm_awburst,
    output wire                       m_axi_s2mm_awlock,
    output wire [3:0]                 m_axi_s2mm_awcache,
    output wire [2:0]                 m_axi_s2mm_awprot,
    output wire                       m_axi_s2mm_awvalid,
    input  wire                       m_axi_s2mm_awready,
    output wire [AXI_WIDTH   -1:0]    m_axi_s2mm_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_s2mm_wstrb,
    output wire                       m_axi_s2mm_wlast,
    output wire                       m_axi_s2mm_wvalid,
    input  wire                       m_axi_s2mm_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_s2mm_bid,
    input  wire [1:0]                 m_axi_s2mm_bresp,
    input  wire                       m_axi_s2mm_bvalid,
    output wire                       m_axi_s2mm_bready
);

// Stream Acc Side


localparam IN_BUS_W = 32;
localparam OUT_BUS_W = 32;
(* MARK_DEBUG = "TRUE" *) wire                       s_tvalid;
(* MARK_DEBUG = "TRUE" *) wire                       s_tready;
(* MARK_DEBUG = "TRUE" *) wire                       s_tlast ;
(* MARK_DEBUG = "TRUE" *) wire [IN_BUS_W-1:0]        s_tdata ;
                          wire [AXIS_USER_WIDTH-1:0] s_tuser ;
(* MARK_DEBUG = "TRUE" *) wire                       m_tvalid;
(* MARK_DEBUG = "TRUE" *) wire                       m_tready;
(* MARK_DEBUG = "TRUE" *) wire                       m_tlast ;
(* MARK_DEBUG = "TRUE" *) wire [OUT_BUS_W-1:0]       m_tdata ;
                          wire [AXIS_USER_WIDTH-1:0] m_tuser ;


myproject_axi ACC_axis (
    .in_r_TDATA(s_tdata), // new variable
    .in_r_TLAST(s_tlast),
    .out_r_TDATA(m_tdata),
    .out_r_TLAST(m_tlast),
    .ap_clk(clk),
    .ap_rst_n(rstn),
    .in_r_TVALID(s_tvalid),
    .in_r_TREADY(s_tready),
    .out_r_TVALID(m_tvalid),
    .out_r_TREADY(m_tready)
);
    
// AXIS DMA side

wire                       s_axis_mm2s_0_tready;
wire                       s_axis_mm2s_0_tvalid;
wire                       s_axis_mm2s_0_tlast ;
wire [AXI_WIDTH      -1:0] s_axis_mm2s_0_tdata ;
wire [AXI_WIDTH/8    -1:0] s_axis_mm2s_0_tkeep ;
wire [AXIS_USER_WIDTH-1:0] s_axis_mm2s_0_tuser ;

wire                       m_axis_s2mm_tready;
wire                       m_axis_s2mm_tvalid;
wire                       m_axis_s2mm_tlast ;
wire [AXI_WIDTH   -1:0]    m_axis_s2mm_tdata ;
wire [AXI_WIDTH/8 -1:0]    m_axis_s2mm_tkeep ;


alex_axis_adapter_any #(
  .S_DATA_WIDTH  (AXI_WIDTH),
  .S_KEEP_ENABLE (1),
  .S_KEEP_WIDTH  (AXI_WIDTH/8),
  .M_DATA_WIDTH  (IN_BUS_W),
  .M_KEEP_ENABLE (1),
  .USER_ENABLE   (1),
  .USER_WIDTH    (AXIS_USER_WIDTH)
) ADAPTER_MM2S (
  .clk           (clk),
  .rstn          (rstn),
  .s_axis_tready (s_axis_mm2s_0_tready),
  .s_axis_tvalid (s_axis_mm2s_0_tvalid),
  .s_axis_tlast  (s_axis_mm2s_0_tlast ),
  .s_axis_tdata  (s_axis_mm2s_0_tdata ),
  .s_axis_tkeep  (s_axis_mm2s_0_tkeep ),
  .s_axis_tuser  (s_axis_mm2s_0_tuser ),
  .s_axis_tid    (),
  .s_axis_tdest  (),
  .m_axis_tready (s_tready),
  .m_axis_tvalid (s_tvalid),
  .m_axis_tlast  (s_tlast ),
  .m_axis_tdata  (s_tdata ),
  .m_axis_tuser  (s_tuser ),
  .m_axis_tkeep  (),
  .m_axis_tid    (),
  .m_axis_tdest  ()
);

localparam OUT_KEEP_W = OUT_BUS_W/8;
alex_axis_adapter_any #(
  .S_DATA_WIDTH  (OUT_BUS_W),
  .S_KEEP_ENABLE (1),
  .M_DATA_WIDTH  (AXI_WIDTH),
  .M_KEEP_ENABLE (1),
  .USER_ENABLE   (0)
) ADAPTER_S2MM (
  .clk           (clk),
  .rstn          (rstn),
  .s_axis_tready (m_tready),
  .s_axis_tvalid (m_tvalid),
  .s_axis_tlast  (m_tlast ),
  .s_axis_tdata  (m_tdata ),
  .s_axis_tkeep  ({OUT_KEEP_W{1'b1}}),
  .s_axis_tuser  (),
  .s_axis_tid    (),
  .s_axis_tdest  (),
  .m_axis_tready (m_axis_s2mm_tready),
  .m_axis_tvalid (m_axis_s2mm_tvalid),
  .m_axis_tlast  (m_axis_s2mm_tlast ),
  .m_axis_tdata  (m_axis_s2mm_tdata ),
  .m_axis_tkeep  (m_axis_s2mm_tkeep ),
  .m_axis_tuser  (),
  .m_axis_tid    (),
  .m_axis_tdest  ()
);



// Wires connecting AXIL2RAM to CONTROLLER
wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr;
wire [AXIL_WIDTH-1:0] reg_wr_data;
wire [STRB_WIDTH-1:0] reg_wr_strb;
wire reg_wr_en;
wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr;
wire reg_rd_en;
wire [AXIL_WIDTH-1:0] reg_rd_data;

// Veriltor width mismatch bullshit
localparam AXIL_ADDR_EXTRA = AXIL_ADDR_WIDTH - 32;
wire [AXIL_ADDR_EXTRA -1:0] axil_addr_zeros = 0;
wire [AXIL_ADDR_WIDTH-1:0] reg_wr_addr_ctrl = (reg_wr_addr-{axil_addr_zeros, AXIL_BASE_ADDR}) >> 2;
wire [AXIL_ADDR_WIDTH-1:0] reg_rd_addr_ctrl = (reg_rd_addr-{axil_addr_zeros,AXIL_BASE_ADDR})  >> 2;


localparam      AXI_LEN_WIDTH           = 32,
                TIMEOUT                 = 2, // since 0 gives error

    // Alex AXI DMA RD                
                AXIS_ID_WIDTH           = AXI_ID_WIDTH,
                AXIS_KEEP_ENABLE        = 1,
                AXIS_KEEP_WIDTH         = (AXI_WIDTH/8),
                AXIS_LAST_ENABLE        = 1,
                AXIS_ID_ENABLE          = 0,
                AXIS_DEST_ENABLE        = 0,
                AXIS_DEST_WIDTH         = 8,
                LEN_WIDTH               = AXI_LEN_WIDTH,
                TAG_WIDTH               = 8,
                ENABLE_SG               = 0,
                ENABLE_UNALIGNED        = 1;
    

// Controller with Alex DMAs: desc signals (including od tag) and status signals
wire [AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:0] s2mm_desc_tdata;
wire [TAG_WIDTH-1:0]                    s2mm_desc_tag;
wire                                    s2mm_desc_tvalid;
wire                                    s2mm_desc_tready;
wire [TAG_WIDTH-1:0]                    s2mm_status_tag;
wire [3:0]                              s2mm_status_error;
wire                                    s2mm_status_valid;

wire [AXI_ADDR_WIDTH+AXI_LEN_WIDTH-1:0] mm2s_0_desc_tdata;
wire [AXIS_USER_WIDTH-1:0]              mm2s_0_desc_tuser;
wire                                    mm2s_0_desc_tvalid;
wire                                    mm2s_0_desc_tready;
wire [3:0]                              mm2s_0_status_error;
wire                                    mm2s_0_status_valid;

alex_axilite_ram #(
    .DATA_WR_WIDTH(AXIL_WIDTH),
    .DATA_RD_WIDTH(AXIL_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .TIMEOUT(TIMEOUT)
) AXIL2RAM (
    .clk(clk),
    .rstn(rstn),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(1'b0),
    .reg_wr_ack(1'b1),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(reg_rd_data),
    .reg_rd_wait(1'b0),
    .reg_rd_ack(1'b1)
);

dma_controller #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .AXI_DATA_WIDTH(AXIL_WIDTH),
    .AXI_LEN_WIDTH(AXI_LEN_WIDTH),
    .AXI_TAG_WIDTH(TAG_WIDTH)
) CONTROLLER (
    .clk(clk),
    .rstn(rstn),

    .reg_wr_en  (reg_wr_en),
    .reg_wr_addr(reg_wr_addr_ctrl[AXI_ADDR_WIDTH-1:0]),
    .reg_wr_data(reg_wr_data),
    .reg_rd_en  (reg_rd_en),
    .reg_rd_addr(reg_rd_addr_ctrl[AXI_ADDR_WIDTH-1:0]),
    .reg_rd_data(reg_rd_data),

    .s2mm_desc        (s2mm_desc_tdata  ),
    .s2mm_tag         (s2mm_desc_tag    ),
    .s2mm_valid       (s2mm_desc_tvalid ),
    .s2mm_ready       (s2mm_desc_tready ),
    .s2mm_status_error(s2mm_status_error),
    .s2mm_status_valid(s2mm_status_valid),

    .mm2s_0_desc        (mm2s_0_desc_tdata ),
    .mm2s_0_user        (mm2s_0_desc_tuser ),
    .mm2s_0_valid       (mm2s_0_desc_tvalid),
    .mm2s_0_ready       (mm2s_0_desc_tready),
    .mm2s_0_status_error(mm2s_0_status_error),
    .mm2s_0_status_valid(mm2s_0_status_valid)
    
);

alex_axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
) MM2S_0_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_read_desc_tag         ({TAG_WIDTH{1'b0}}),
    .s_axis_read_desc_tid         ({AXI_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_tdest       ({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_tdata       (mm2s_0_desc_tdata),
    .s_axis_read_desc_tuser       (mm2s_0_desc_tuser),
    .s_axis_read_desc_tvalid      (mm2s_0_desc_tvalid),
    .s_axis_read_desc_tready      (mm2s_0_desc_tready),
    .m_axis_read_desc_status_error(mm2s_0_status_error),
    .m_axis_read_desc_status_valid(mm2s_0_status_valid),
    .m_axis_read_desc_status_tag  (),

    // External Stream
    .m_axis_read_data_tdata (s_axis_mm2s_0_tdata),
    .m_axis_read_data_tkeep (s_axis_mm2s_0_tkeep),
    .m_axis_read_data_tvalid(s_axis_mm2s_0_tvalid),
    .m_axis_read_data_tready(s_axis_mm2s_0_tready),
    .m_axis_read_data_tlast (s_axis_mm2s_0_tlast),
    .m_axis_read_data_tuser (s_axis_mm2s_0_tuser),
    .m_axis_read_data_tid   (),
    .m_axis_read_data_tdest (),
    // External AXI
    .m_axi_arid   (m_axi_mm2s_0_arid),
    .m_axi_araddr (m_axi_mm2s_0_araddr),
    .m_axi_arlen  (m_axi_mm2s_0_arlen),
    .m_axi_arsize (m_axi_mm2s_0_arsize),
    .m_axi_arburst(m_axi_mm2s_0_arburst),
    .m_axi_arlock (m_axi_mm2s_0_arlock),
    .m_axi_arcache(m_axi_mm2s_0_arcache),
    .m_axi_arprot (m_axi_mm2s_0_arprot),
    .m_axi_arvalid(m_axi_mm2s_0_arvalid),
    .m_axi_arready(m_axi_mm2s_0_arready),
    .m_axi_rid    (m_axi_mm2s_0_rid),
    .m_axi_rdata  (m_axi_mm2s_0_rdata),
    .m_axi_rresp  (m_axi_mm2s_0_rresp),
    .m_axi_rlast  (m_axi_mm2s_0_rlast),
    .m_axi_rvalid (m_axi_mm2s_0_rvalid),
    .m_axi_rready (m_axi_mm2s_0_rready),
    .enable(1'b1)
);


alex_axi_dma_wr #(
    .AXI_DATA_WIDTH(AXI_WIDTH   ),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(0),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
) S2MM_DMA (
    .clk(clk),
    .rstn(rstn),
    .s_axis_write_desc_tdata       (s2mm_desc_tdata  ),
    .s_axis_write_desc_tag         (s2mm_desc_tag    ),
    .s_axis_write_desc_tvalid      (s2mm_desc_tvalid ),
    .s_axis_write_desc_tready      (s2mm_desc_tready ),
    .m_axis_write_desc_status_len  (                 ),
    .m_axis_write_desc_status_tag  (s2mm_status_tag  ),
    .m_axis_write_desc_status_id   (                 ),
    .m_axis_write_desc_status_dest (                 ),
    .m_axis_write_desc_status_user (                 ),
    .m_axis_write_desc_status_error(s2mm_status_error),
    .m_axis_write_desc_status_valid(s2mm_status_valid),

    // External Stream
    .s_axis_write_data_tdata (m_axis_s2mm_tdata),
    .s_axis_write_data_tkeep (m_axis_s2mm_tkeep),
    .s_axis_write_data_tvalid(m_axis_s2mm_tvalid),
    .s_axis_write_data_tready(m_axis_s2mm_tready),
    .s_axis_write_data_tlast (m_axis_s2mm_tlast),
    .s_axis_write_data_tid   (),
    .s_axis_write_data_tdest (),
    .s_axis_write_data_tuser (),
    // External AXI
    .m_axi_awid(m_axi_s2mm_awid),
    .m_axi_awaddr(m_axi_s2mm_awaddr),
    .m_axi_awlen(m_axi_s2mm_awlen),
    .m_axi_awsize(m_axi_s2mm_awsize),
    .m_axi_awburst(m_axi_s2mm_awburst),
    .m_axi_awlock(m_axi_s2mm_awlock),
    .m_axi_awcache(m_axi_s2mm_awcache),
    .m_axi_awprot(m_axi_s2mm_awprot),
    .m_axi_awvalid(m_axi_s2mm_awvalid),
    .m_axi_awready(m_axi_s2mm_awready),
    .m_axi_wdata(m_axi_s2mm_wdata),
    .m_axi_wstrb(m_axi_s2mm_wstrb),
    .m_axi_wlast(m_axi_s2mm_wlast),
    .m_axi_wvalid(m_axi_s2mm_wvalid),
    .m_axi_wready(m_axi_s2mm_wready),
    .m_axi_bid(m_axi_s2mm_bid),
    .m_axi_bresp(m_axi_s2mm_bresp),
    .m_axi_bvalid(m_axi_s2mm_bvalid),
    .m_axi_bready(m_axi_s2mm_bready),
    .enable(1'b1),
    .abort(1'b0)
);

endmodule

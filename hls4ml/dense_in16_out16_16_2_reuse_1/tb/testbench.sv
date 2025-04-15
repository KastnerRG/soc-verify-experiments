`timescale 1ns/1ps

module testbench;

    // Parameters
    localparam CLK_PERIOD = 10;

    // Testbench signals
    reg ap_clk;
    reg ap_rst_n;

    reg [31:0] in_r_TDATA;
    reg [0:0] in_r_TLAST;
    reg in_r_TVALID;
    wire in_r_TREADY;

    wire [31:0] out_r_TDATA;
    wire [0:0] out_r_TLAST;
    wire out_r_TVALID;
    reg out_r_TREADY;

    // DUT instantiation
    myproject_axi dut (
        .in_r_TDATA(in_r_TDATA),
        .in_r_TLAST(in_r_TLAST),
        .out_r_TDATA(out_r_TDATA),
        .out_r_TLAST(out_r_TLAST),
        .ap_clk(ap_clk),
        .ap_rst_n(ap_rst_n),
        .in_r_TVALID(in_r_TVALID),
        .in_r_TREADY(in_r_TREADY),
        .out_r_TVALID(out_r_TVALID),
        .out_r_TREADY(out_r_TREADY)
    );

    // Clock generation
    initial begin
        ap_clk = 0;
        forever #(CLK_PERIOD / 2) ap_clk = ~ap_clk;
    end

    // Reset generation
    initial begin
        ap_rst_n = 0;
        #(2 * CLK_PERIOD);
        ap_rst_n = 1;
    end

    // Stimulus
    initial begin
        // Initialize inputs
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
        in_r_TDATA = 0;
        in_r_TLAST = 0;
        in_r_TVALID = 0;
        out_r_TREADY = 0;

        // Wait for reset deassertion
        @(posedge ap_rst_n);
        @(posedge ap_clk);

        // Apply some stimulus
        in_r_TDATA = 32'h1FFF1FFF;
        in_r_TLAST = 1'b0;
        in_r_TVALID = 1'b1;
        out_r_TREADY = 1'b1;

        repeat (150) @(posedge ap_clk);
        //in_r_TVALID = 1'b0;
        in_r_TLAST = 1'b1;
        @(posedge ap_clk);
        in_r_TVALID = 1'b0;
        in_r_TLAST = 1'b0;

        // Wait for a few clock cycles
        repeat (1000) @(posedge ap_clk);

        // Finish simulation
        $finish;
    end

endmodule
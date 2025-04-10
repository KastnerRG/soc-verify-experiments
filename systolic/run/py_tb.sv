`timescale 1ns/1ps
`define DIAG(a, b) (a+b)

module py_tb;
  localparam 
    R          = `R , // Rows of SA == rows of output matrix
    C          = `C , // Cols of SA == cols of output matrix
    K          = `K , // Cols of matrix_k and rows of matrix_k
    WX         = `WXK, // word width of matrix_k
    WK         = `WXK, // word width of matrix_k
    WXK        = `WXK,
    LM         = `LM, // latency of multiplier
    LA         = `LA, // latency of accumulator
    WM         = WX + WK,        // word width of multiplier
    WY         = WM + $clog2(K), // word width of accumulator
    WXK_BUS    = WX*R + WK*C,    // input bus width, R rows of matrix_x and C cols of matrix_k
    WY_BUS     = WY*R,           // output bus width, R rows of matrix_y
    P_VALID    = `P_VALID, // Probability with which s_valid is toggled
    P_READY    = `P_READY, // Probability with which m_ready is toggled
    CLK_PERIOD = 10;

  logic clk=0, rstn=0;
  initial forever #(CLK_PERIOD/2) clk = ~clk;

  int file_in, file_out, status;

  // Systolic Array
  logic s_ready, s_valid, s_last, m_ready, m_valid, m_last;
  logic [R-1:0][WX-1:0] sx_data;
  logic [C-1:0][WK-1:0] sk_data;
  logic [R-1:0][WY-1:0] m_data;
  axis_sa #(.R(R), .C(C), .WX(WX), .WK(WK), .WY(WY), .LM(LM), .LA(LA)) DUT (.*);

  // AXI Stream Source and Sink
  logic [WXK_BUS    -1:0] s_data;
  logic [WXK_BUS/WXK-1:0] s_keep;
  logic [R-1          :0] m_keep = '1;

  AXIS_Source #(.WORD_WIDTH(WXK), .BUS_WIDTH(WXK_BUS), .PROB_VALID(P_VALID)) source (.aclk(clk), .aresetn(rstn), .*);
  AXIS_Sink   #(.WORD_WIDTH(WY) , .BUS_WIDTH(WY_BUS ), .PROB_READY(P_READY)) sink   (.aclk(clk), .aresetn(rstn), .*);
  assign {sk_data, sx_data} = s_data;

  initial source.axis_push ("../vectors/xk.txt");

  initial begin
    $dumpfile ("axis_tb.vcd"); $dumpvars;
    rstn = 0;
    repeat(2) @(posedge clk);
    rstn = 1;
    sink.axis_pull("../vectors/y.txt");
    $finish();
  end

endmodule 
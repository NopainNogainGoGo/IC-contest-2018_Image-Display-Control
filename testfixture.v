/*
`timescale 1ns/10ps
`define CYCLE    10.0         	        // Modify your clock period here
//gls 一堆 setup time violation 的時候 才可以改 
//或者你的電路負荷不了10ns的時候 調成13ns去合成，用13ns去模擬

`define SDFFILE  "./LCD_CTRL_syn.sdf"	// Modify your sdf file name

`ifdef tb1
  `define EXPECT "./tb1_goal.dat"
  `define CMD "./cmd1.dat"
  `define IMAGE "image1.dat"
`endif

`ifdef tb2
  `define EXPECT "./tb2_goal.dat"
  `define CMD "./cmd2.dat"
  `define IMAGE "image2.dat"
`endif

`ifdef tb3
  `define EXPECT "./tb3_goal.dat"
  `define CMD "./cmd3.dat"
  `define IMAGE "image3.dat"
`endif


module test;
parameter IMAGE_N_PAT = 64;
parameter CMD_N_PAT = 46;
parameter t_reset = `CYCLE*2;


reg clk;
reg reset;
reg [6:0] err_IRAM;
reg [3:0] cmd;
reg cmd_valid;
reg [7:0]  out_mem[0:63];


wire IROM_rd;
wire [5:0] IROM_A;
wire IRAM_valid;
wire [7:0] IRAM_D;
wire [5:0] IRAM_A;
wire busy;
wire done;
wire [7:0]  IROM_Q;


integer i, j, k, l, err;

reg over;
reg   [3:0]   cmd_mem   [0:CMD_N_PAT-1];



	LCD_CTRL LCD_CTRL(.clk(clk), .reset(reset), 
		     .cmd(cmd), .cmd_valid(cmd_valid), 
                     .IROM_rd(IROM_rd), .IROM_A(IROM_A), .IROM_Q(IROM_Q), 
                     .IRAM_valid(IRAM_valid), .IRAM_D(IRAM_D), .IRAM_A(IRAM_A),
		     .busy(busy), .done(done));

	IROM  IROM_1(.IROM_rd(IROM_rd), .IROM_data(IROM_Q), .IROM_addr(IROM_A), .clk(clk), .reset(reset));

	IRAM IRAM_1 (.clk(clk), .IRAM_data(IRAM_D), .IRAM_addr(IRAM_A), .IRAM_valid(IRAM_valid));


//initial $sdf_annotate(`SDFFILE, top);

`ifdef SDF
	initial $sdf_annotate(`SDFFILE, LCD_CTRL);
`endif

initial	$readmemh (`CMD,    cmd_mem);
initial	$readmemh (`EXPECT, out_mem);

initial begin

$fsdbDumpfile("LCD_CTRL.fsdb");
$fsdbDumpvars;
$fsdbDumpMDA;
end





initial begin
   clk         = 1'b0;
   reset       = 1'b0;
   over	       = 1'b0;
   l	       = 0;
   err         = 0;   
end

always begin #(`CYCLE/2) clk = ~clk; end

initial begin
   @(negedge clk)  reset = 1'b1;
   #t_reset        reset = 1'b0;
                                  
end  

            
 always @(negedge clk)
begin

	begin
	if (l < CMD_N_PAT)
	begin
		if(!busy) 
		begin
        	cmd = cmd_mem[l];
        	cmd_valid = 1'b1;
		l=l+1;
		end  
		else
		cmd_valid = 1'b0;
	end
	else
	begin
		l=l;
		cmd_valid = 1'b0;
	end
	end
end


initial @(posedge done) 
begin
   for(k=0;k<64;k=k+1)begin
         if( IRAM_1.IRAM_M[k] !== out_mem[k]) 
		begin
         	$display("ERROR at %d:output %h !=expect %h ",k, IRAM_1.IRAM_M[k], out_mem[k]);
         	err = err+1 ;
		end
         else if ( out_mem[k] === 8'dx)
                begin
                $display("ERROR at %d:output %h !=expect %h ",k, IRAM_1.IRAM_M[k], out_mem[k]);
		err=err+1;
                end   
 over=1'b1;
end
        begin
	if (err === 0 &&  over===1'b1  )  begin
	            $display("All data have been generated successfully!\n");
	            $display("-------------------PASS-------------------\n");
		    #10 $finish;
	         end
	         else if( over===1'b1 )
		 begin 
	            $display("There are %d errors!\n", err);
	            $display("---------------------------------------------\n");
		    #10 $finish;
         	 end
	
	end
end

endmodule


//-----------------------------------------------------------------------
//-----------------------------------------------------------------------
module IROM (IROM_rd, IROM_data, IROM_addr, clk, reset);
input		IROM_rd;
input	[5:0] 	IROM_addr;
output	[7:0]	IROM_data;
input		clk, reset;

reg [7:0] sti_M [0:63];
integer i;

reg	[7:0]	IROM_data;

initial begin
	@ (negedge reset) $readmemb (`IMAGE , sti_M);
	end

always@(negedge clk) 
	if (IROM_rd) IROM_data <= sti_M[IROM_addr];
	
endmodule



//-----------------------------------------------------------------------
//-----------------------------------------------------------------------

module IRAM (IRAM_valid, IRAM_data, IRAM_addr, clk);
input		IRAM_valid;
input	[5:0] 	IRAM_addr;
input	[7:0]	IRAM_data;
input		clk;

reg [7:0] IRAM_M [0:63];
integer i;

initial begin
	for (i=0; i<=63; i=i+1) IRAM_M[i] = 0;
end

always@(negedge clk) 
	if (IRAM_valid) IRAM_M[ IRAM_addr ] <= IRAM_data;

endmodule
*/



`timescale 1ns/10ps
`define CYCLE    10.0         	        // Modify your clock period here


`define SDFFILE  "./LCD_CTRL_syn.sdf"	// Modify your sdf file name

`ifdef tb1
  `define EXPECT "./tb1_goal.dat"
  `define CMD "./cmd1.dat"
  `define IMAGE "image1.dat"
`endif

`ifdef tb2
  `define EXPECT "./tb2_goal.dat"
  `define CMD "./cmd2.dat"
  `define IMAGE "image2.dat"
`endif

`ifdef tb3
  `define EXPECT "./tb3_goal.dat"
  `define CMD "./cmd3.dat"
  `define IMAGE "image3.dat"
`endif


module test;
parameter IMAGE_N_PAT = 64;
parameter CMD_N_PAT = 46;
parameter t_reset = `CYCLE*2;

// ========================================
// 終止條件參數
// ========================================
parameter MAX_CYCLES = 10000;        // 最大仿真週期數
parameter TIMEOUT_CYCLES = 1000;      // 超時週期數（如果長時間沒有進展）

reg clk;
reg reset;
reg [6:0] err_IRAM;
reg [3:0] cmd;
reg cmd_valid;
reg [7:0]  out_mem[0:63];

// ========================================
// 終止條件相關信號
// ========================================
reg [31:0] cycle_count;               // 週期計數器
reg [31:0] last_progress_cycle;       // 上次進展的週期
reg simulation_timeout;               // 仿真超時標誌
reg force_terminate;                  // 強制終止標誌

wire IROM_rd;
wire [5:0] IROM_A;
wire IRAM_valid;
wire [7:0] IRAM_D;
wire [5:0] IRAM_A;
wire busy;
wire done;
wire [7:0]  IROM_Q;

integer i, j, k, l, err;

reg over;
reg   [3:0]   cmd_mem   [0:CMD_N_PAT-1];

	LCD_CTRL LCD_CTRL(.clk(clk), .reset(reset), 
		     .cmd(cmd), .cmd_valid(cmd_valid), 
                     .IROM_rd(IROM_rd), .IROM_A(IROM_A), .IROM_Q(IROM_Q), 
                     .IRAM_valid(IRAM_valid), .IRAM_D(IRAM_D), .IRAM_A(IRAM_A),
		     .busy(busy), .done(done));

	IROM  IROM_1(.IROM_rd(IROM_rd), .IROM_data(IROM_Q), .IROM_addr(IROM_A), .clk(clk), .reset(reset));

	IRAM IRAM_1 (.clk(clk), .IRAM_data(IRAM_D), .IRAM_addr(IRAM_A), .IRAM_valid(IRAM_valid));

//initial $sdf_annotate(`SDFFILE, top);

`ifdef SDF
	initial $sdf_annotate(`SDFFILE, LCD_CTRL);
`endif

initial	$readmemh (`CMD,    cmd_mem);
initial	$readmemh (`EXPECT, out_mem);

initial begin
$fsdbDumpfile("LCD_CTRL.fsdb");
$fsdbDumpvars;
$fsdbDumpMDA;
end

initial begin
   clk         = 1'b0;
   reset       = 1'b0;
   over	       = 1'b0;
   l	       = 0;
   err         = 0;   
   
   // ========================================
   // 終止條件初始化
   // ========================================
   cycle_count = 0;
   last_progress_cycle = 0;
   simulation_timeout = 1'b0;
   force_terminate = 1'b0;
end

always begin #(`CYCLE/2) clk = ~clk; end

initial begin
   @(negedge clk)  reset = 1'b1;
   #t_reset        reset = 1'b0;
end  

// ========================================
// 週期計數器
// ========================================
always @(posedge clk) begin
    cycle_count <= cycle_count + 1;
    
    // 檢查是否有進展（指令執行或狀態變化）
    if (cmd_valid || IROM_rd || IRAM_valid || !busy) begin
        last_progress_cycle <= cycle_count;
    end
end

// ========================================
// 終止條件檢查
// ========================================
always @(posedge clk) begin
    // 檢查最大週期數
    if (cycle_count >= MAX_CYCLES) begin
        $display("ERROR: Simulation reached maximum cycles (%d)", MAX_CYCLES);
        $display("Terminating simulation due to cycle limit");
        force_terminate = 1'b1;
    end
    
    // 檢查超時（長時間沒有進展）
    if ((cycle_count - last_progress_cycle) >= TIMEOUT_CYCLES) begin
        $display("ERROR: Simulation timeout - no progress for %d cycles", TIMEOUT_CYCLES);
        $display("Last progress at cycle: %d, Current cycle: %d", last_progress_cycle, cycle_count);
        simulation_timeout = 1'b1;
        force_terminate = 1'b1;
    end
    
    // 強制終止
    if (force_terminate) begin
        $display("SIMULATION TERMINATED");
        $display("Total cycles: %d", cycle_count);
        $display("---------------------------------------------");
        #10 $finish;
    end
end

always @(negedge clk) begin
    if (l < CMD_N_PAT) begin
        if(!busy) begin
            cmd = cmd_mem[l];
            cmd_valid = 1'b1;
            l=l+1;
        end  
        else
            cmd_valid = 1'b0;
    end
    else begin
        l=l;
        cmd_valid = 1'b0;
    end
end

// ========================================
// 正常完成檢查
// ========================================
initial @(posedge done) begin
    $display("Simulation completed at cycle: %d", cycle_count);
    
    for(k=0;k<64;k=k+1)begin
        if( IRAM_1.IRAM_M[k] !== out_mem[k]) begin
            $display("ERROR at %d:output %h !=expect %h ",k, IRAM_1.IRAM_M[k], out_mem[k]);
            err = err+1 ;
        end
        else if ( out_mem[k] === 8'dx) begin
            $display("ERROR at %d:output %h !=expect %h ",k, IRAM_1.IRAM_M[k], out_mem[k]);
            err=err+1;
        end   
    end
    over=1'b1;
end

// ========================================
// 結果輸出
// ========================================
always @(posedge clk) begin
    if (err === 0 && over===1'b1) begin
        $display("All data have been generated successfully!");
        $display("Total simulation cycles: %d", cycle_count);
        $display("-------------------PASS-------------------");
        #10 $finish;
    end
    else if(over===1'b1) begin 
        $display("There are %d errors!", err);
        $display("Total simulation cycles: %d", cycle_count);
        $display("---------------------------------------------");
        #10 $finish;
    end
end

endmodule

//-----------------------------------------------------------------------
//-----------------------------------------------------------------------
module IROM (IROM_rd, IROM_data, IROM_addr, clk, reset);
input		IROM_rd;
input	[5:0] 	IROM_addr;
output	[7:0]	IROM_data;
input		clk, reset;

reg [7:0] sti_M [0:63];
integer i;

reg	[7:0]	IROM_data;

initial begin
	@ (negedge reset) $readmemb (`IMAGE , sti_M);
end

always@(negedge clk) 
	if (IROM_rd) IROM_data <= sti_M[IROM_addr];
	
endmodule

//-----------------------------------------------------------------------
//-----------------------------------------------------------------------

module IRAM (IRAM_valid, IRAM_data, IRAM_addr, clk);
input		IRAM_valid;
input	[5:0] 	IRAM_addr;
input	[7:0]	IRAM_data;
input		clk;

reg [7:0] IRAM_M [0:63];
integer i;

initial begin
	for (i=0; i<=63; i=i+1) IRAM_M[i] = 0;
end

always@(negedge clk) 
	if (IRAM_valid) IRAM_M[ IRAM_addr ] <= IRAM_data;

endmodule

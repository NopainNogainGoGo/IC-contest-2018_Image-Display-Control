module LCD_CTRL(
input               clk,
input               reset, 
input [3:0]         cmd,
input               cmd_valid,
input [7:0]         IROM_Q,
output reg          IROM_rd,
output reg [5:0]    IROM_A,
output reg          IRAM_valid,
output reg [7:0]    IRAM_D,
output reg [5:0]    IRAM_A,
output reg          busy,
output reg          done
);



//================================================================
// Parameter Definitions
//================================================================
reg [1:0] state, next_state;
localparam READ  = 2'd0,  // 從 IROM 讀取資料
           IDLE  = 2'd1,  // 等待輸入指令 (cmd_valid)
           CALC  = 2'd2,  // 根據 cmd 對資料做平移/旋轉/鏡像/平均等處理
           WRITE = 2'd3;  // 將處理完的資料寫入 IRAM
           // DONE  = 3'd4;  // 不需要多一個狀態

reg [7:0] image_data [63:0]; // image buffer (8x8 pixels)
reg [5:0] counter;

//================================================================
//  FSM - cs
//================================================================
always @(posedge clk or posedge reset) begin
    if (reset)
        state <= READ;
    else
        state <= next_state;
end


//================================================================
//  FSM - ns
//================================================================
always @(*) begin
    case (state)
        READ:   next_state = (IROM_A == 63) ? IDLE : READ ;
        IDLE:   begin       // cmd 決定下一個狀態
                if (cmd_valid && cmd != 4'd0) next_state = CALC;
                else if (cmd_valid && cmd == 4'd0) next_state = WRITE;
                else next_state = IDLE;
        end
        CALC:   next_state = IDLE;  //wait for another cmd    
        WRITE:  next_state = WRITE;  
        default: next_state = READ;
    endcase
end


//================================================================
// Output logic
//================================================================

// IROM_rd 
always @(*) begin 
    if (state == READ) //盡量用flag 去控制
        IROM_rd = 1;
    else 
        IROM_rd = 0;
end


// IRAM_valid  
always @(*) begin
    if (state == WRITE) 
        IRAM_valid = 1;
    else 
        IRAM_valid = 0;
end


// 控制 busy 訊號
always @(*) begin
    if (reset)
        busy = 1'b1;
    else if (IROM_rd || IRAM_valid || state == CALC)
        busy = 1'b1;
    else 
        busy = 1'b0;
end


    
// IRAM Address Counter    
always @(posedge clk or posedge reset) begin
    if (reset) 
        counter <= 0;
    else if (IRAM_valid) begin
        if (counter == 6'd63) 
            counter <= counter;
        else 
            counter <= counter + 1;
    end
end


// IRAM Address Delay (1 clock cycle)
always @(posedge clk or posedge reset) begin
    if (reset) 
        IRAM_A <= 0;
    else
        IRAM_A <= counter;
end



//singal done
always @(posedge clk)begin
        if (IRAM_A == 6'd63) 
            done <= 1'd1;
        else 
            done <= 1'd0;
end




//  操作點座標 (Operation Point Coordinates) 
reg [2:0] op_x, op_y;   //1--7

//  2x2 操作區塊的像素值 
reg [7:0] p_tl, p_tr, p_bl, p_br; // Top-Left, Top-Right, Bottom-Left, Bottom-Right
//  2x2 操作區塊的位址 
reg [5:0] addr_tl, addr_tr, addr_bl, addr_br;


//  計算 2x2 操作區塊的位址 
always @(*) begin 
    addr_tl = (op_y - 1) * 8 + (op_x - 1);
    addr_tr = (op_y - 1) * 8 + op_x;
    addr_bl = op_y * 8 + (op_x - 1);
    addr_br = op_y * 8 + op_x;
end

//  取得 2x2 操作區塊的像素值 
always @(*) begin 
    p_tl = image_data[addr_tl];
    p_tr = image_data[addr_tr];
    p_bl = image_data[addr_bl];
    p_br = image_data[addr_br];
end

//  指令定義 
localparam //WRITE_RAM    = 4'd0,   // 0000: 寫入  用fsm去執行
           SHIFT_UP     = 4'd1,   // 0001: 上移
           SHIFT_DOWN   = 4'd2,   // 0010: 下移
           SHIFT_LEFT   = 4'd3,   // 0011: 左移
           SHIFT_RIGHT  = 4'd4,   // 0100: 右移
           MAX_OP       = 4'd5,   // 0101: 最大值
           MIN_OP       = 4'd6,   // 0110: 最小值
           AVG_OP       = 4'd7,   // 0111: 平均值
           ROT_CCW      = 4'd8,   // 1000: 逆時針旋轉
           ROT_CW       = 4'd9,   // 1001: 順時針旋轉
           MIRROR_X     = 4'd10,  // 1010: X軸鏡射
           MIRROR_Y     = 4'd11;  // 1011: Y軸鏡射


// 操作點座標控制
always @(posedge clk or posedge reset) begin
    if (reset) begin
        op_x <= 3'd4; // 初始操作點 X=4
        op_y <= 3'd4; // 初始操作點 Y=4
    end else if (state == CALC) begin 
        case (cmd)
            SHIFT_UP: begin
                if (op_y > 1) op_y <= op_y - 1;
            end
            SHIFT_DOWN: begin
                if (op_y < 7) op_y <= op_y + 1;
            end
            SHIFT_LEFT: begin
                if (op_x > 1) op_x <= op_x - 1;
            end
            SHIFT_RIGHT: begin
                if (op_x < 7) op_x <= op_x + 1;
            end
            // 其他操作不改變座標
        endcase
    end 
end

reg [7:0] max_top, max_bottom, max_val;
reg [7:0] min_top, min_bottom, min_val;
reg [9:0] sum, avg_val;

always @(*) begin
    max_top = (p_tl > p_tr) ? p_tl : p_tr;        // 上排最大值
    max_bottom = (p_bl > p_br) ? p_bl : p_br;     // 下排最大值
    max_val = (max_top > max_bottom) ? max_top : max_bottom;  // 整體最大值

    min_top = (p_tl < p_tr) ? p_tl : p_tr;        // 上排最小值
    min_bottom = (p_bl < p_br) ? p_bl : p_br;     // 下排最小值
    min_val = (min_top < min_bottom) ? min_top : min_bottom;  // 整體最小值

    // 平均值計算
    sum = p_tl + p_tr + p_bl + p_br;
    avg_val = sum >> 2;
end


// 合併 IROM_A 、image_data 寫入、IRAM_D 寫入 *(要把image_data放在一起)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IROM_A   <= 6'd0;
        IRAM_D   <= 8'd0;
    end
    else begin
        // 1) IROM_rd：更新 IROM_A 並把 IROM_Q 存入 image_data
        if (IROM_rd) begin
            if (IROM_A == 6'd63)
                IROM_A <= 6'd0;
            else
                IROM_A <= IROM_A + 6'd1;
                image_data[IROM_A] <= IROM_Q;
        end

        // 2) IRAM_valid：把處理完的資料放到 IRAM_D
        if (IRAM_valid) begin
            IRAM_D <= image_data[counter];
        end

        // 3) state == CALC 時的 image_data 操作
        if (state == CALC) begin
            case (cmd)
                MAX_OP: begin
                    image_data[addr_tl] <= max_val;
                    image_data[addr_tr] <= max_val;
                    image_data[addr_bl] <= max_val;
                    image_data[addr_br] <= max_val;
                end
                MIN_OP: begin
                    image_data[addr_tl] <= min_val;
                    image_data[addr_tr] <= min_val;
                    image_data[addr_bl] <= min_val;
                    image_data[addr_br] <= min_val;
                end
                AVG_OP: begin
                    image_data[addr_tl] <= avg_val;
                    image_data[addr_tr] <= avg_val;
                    image_data[addr_bl] <= avg_val;
                    image_data[addr_br] <= avg_val;
                end
                ROT_CCW: begin
                    image_data[addr_tl] <= p_tr;
                    image_data[addr_tr] <= p_br;
                    image_data[addr_bl] <= p_tl;
                    image_data[addr_br] <= p_bl;
                end
                ROT_CW: begin
                    image_data[addr_tl] <= p_bl;
                    image_data[addr_tr] <= p_tl;
                    image_data[addr_bl] <= p_br;
                    image_data[addr_br] <= p_tr;
                end
                MIRROR_X: begin
                    image_data[addr_tl] <= p_bl;
                    image_data[addr_tr] <= p_br;
                    image_data[addr_bl] <= p_tl;
                    image_data[addr_br] <= p_tr;
                end
                MIRROR_Y: begin
                    image_data[addr_tl] <= p_tr;
                    image_data[addr_tr] <= p_tl;
                    image_data[addr_bl] <= p_br;
                    image_data[addr_br] <= p_bl;
                end
                default: ; // 其它 cmd 不做修改
            endcase
        end
    end
end
endmodule

/*
優化版
module LCD_CTRL(
input               clk,
input               reset, //in fact 都是negedge
input [3:0]         cmd,
input               cmd_valid,
input [7:0]         IROM_Q,
output reg          IROM_rd,
output reg [5:0]    IROM_A,
output reg          IRAM_valid,
output reg [7:0]    IRAM_D,
output reg [5:0]    IRAM_A,
output reg          busy,
output reg          done
);

//para

localparam  READ = 2'd0,
            IDLE = 2'd1,
            CALC = 2'd2,
            WRITE = 2'd3;

reg[1:0] state, next_state;
reg[7:0] image_data[63:0];


//cs
always @(posedge clk or posedge reset)begin
    if(reset)
        state <= READ;
    else
        state <= next_state;
end


//ns 
always @(*)begin
    case(state)
        READ: next_state = (IROM_A == 6'd63) ? IDLE : READ;
        IDLE: begin
            if(cmd_valid && cmd != 0) next_state = CALC;
            else if(cmd_valid && cmd == 0) next_state = WRITE;
            else next_state = IDLE;
        end
        CALC: next_state = IDLE;
        WRITE: next_state = WRITE;
    endcase
end

//ol
//control logic
always @(*)begin
    case(state)
        READ: begin
            IROM_rd = 1;
            IRAM_valid = 0;
            busy = 1;
        end

        IDLE:  begin
            IROM_rd = 0;
            IRAM_valid = 0;
            busy = 0;
        end

        CALC:  begin
            IROM_rd = 0;
            IRAM_valid = 0;
            busy = 1;
        end

        WRITE:  begin
            IROM_rd = 0;
            IRAM_valid = 1;
            busy = 1;
        end
    endcase
end


reg[5:0] counter; //同時把欲寫入的位址及資料分別放在IRAM_A 及 IRAM_D 匯流排 
                  //這樣要多一個 counter 幫忙 不然會差一個cycle 
//IRAM_A counter
always @(posedge clk or posedge reset)begin
    if(reset)
        counter <= 0;
    else if (IRAM_valid)begin
        if(counter == 6'd63) 
            counter <= counter;
        else
            counter <= counter + 1;
    end
end

//IRAM_A delay
always @(posedge clk)begin
    IRAM_A <= counter;
end


//done
always @(posedge clk)begin
    if(IRAM_A == 6'd63) 
        done <= 1;
    else
        done <= 0;
end


localparam //WRITE_RAM    = 4'd0,   // 0000: 寫入  用fsm去執行
           SHIFT_UP     = 4'd1,   // 0001: 上移
           SHIFT_DOWN   = 4'd2,   // 0010: 下移
           SHIFT_LEFT   = 4'd3,   // 0011: 左移
           SHIFT_RIGHT  = 4'd4,   // 0100: 右移
           MAX_OP       = 4'd5,   // 0101: 最大值
           MIN_OP       = 4'd6,   // 0110: 最小值
           AVG_OP       = 4'd7,   // 0111: 平均值
           ROT_CCW      = 4'd8,   // 1000: 逆時針旋轉
           ROT_CW       = 4'd9,   // 1001: 順時針旋轉
           MIRROR_X     = 4'd10,  // 1010: X軸鏡射
           MIRROR_Y     = 4'd11;  // 1011: Y軸鏡射


reg[2:0] op_x, op_y;
//reg[7:0] pt_l, pt_r, pb_l, pb_r;   area overhead
reg[5:0] addr_tl, addr_tr, addr_bl, addr_br;   


//使用移位運算代替乘法 ({op_y, 3'd0} 等於 op_y * 8) leftshift 3
always @(*) begin
    addr_tl = {op_y - 1'b1, 3'd0} + {op_x - 1'b1};  // (op_y-1)*8 + (op_x-1)
    addr_tr = {op_y - 1'b1, 3'd0} + op_x;           // (op_y-1)*8 + op_x
    addr_bl = {op_y, 3'd0} + {op_x - 1'b1};         // op_y*8 + (op_x-1)
    addr_br = {op_y, 3'd0} + op_x;                  // op_y*8 + op_x
end


always@(posedge clk or posedge reset)begin
    if(reset)begin
        op_x <= 3'd4;
        op_y <= 3'd4;
    end
    else if(state == CALC)begin
      case (cmd)
                SHIFT_UP:    op_y <= (op_y > 3'd1) ? op_y - 1'b1 : op_y;
                SHIFT_DOWN:  op_y <= (op_y < 3'd7) ? op_y + 1'b1 : op_y;
                SHIFT_LEFT:  op_x <= (op_x > 3'd1) ? op_x - 1'b1 : op_x;
                SHIFT_RIGHT: op_x <= (op_x < 3'd7) ? op_x + 1'b1 : op_x;
        endcase
    end
end


reg[7:0]max1, max2, max;
reg[7:0]min1, min2, min;
reg[7:0]avg;
reg[9:0]sum;


always@(*)begin
    max1 = (image_data[addr_tl]  > image_data[addr_tr]) ? image_data[addr_tl] : image_data[addr_tr];
    max2 = (image_data[addr_bl] > image_data[addr_br]) ? image_data[addr_bl] : image_data[addr_br];
    max = (max1 > max2) ? max1 : max2;

    min1 = (image_data[addr_tl] < image_data[addr_tr]) ? image_data[addr_tl] : image_data[addr_tr];
    min2 = (image_data[addr_bl] < image_data[addr_br]) ? image_data[addr_bl] : image_data[addr_br];
    min = (min1 < min2) ? min1 : min2;

    //不加括號會變 (((A+B)+C)+D)
    sum = (image_data[addr_tl] + image_data[addr_tr]) + (image_data[addr_bl] + image_data[addr_br]);
    avg = sum[9:2];  // 不要取後兩位 = 右移2位 = 除以4
end



// image_data
always@(posedge clk or posedge reset)begin
    if (reset) begin
        IROM_A   <= 6'd0;
        IRAM_D   <= 8'd0;
    end
    else if(IROM_rd)begin
        if(IROM_A == 6'd63) 
            IROM_A <= IROM_A;
        else
            IROM_A <= IROM_A + 1; 
            image_data[IROM_A] <= IROM_Q;
    end    
    else if(state == CALC)begin
        case(cmd)
            MAX_OP:begin
                image_data[addr_tl] <= max;
                image_data[addr_tr] <= max;
                image_data[addr_bl] <= max;
                image_data[addr_br] <= max;
            end      

            MIN_OP:begin
                image_data[addr_tl] <= min;
                image_data[addr_tr] <= min;
                image_data[addr_bl] <= min;
                image_data[addr_br] <= min;
            end      

            AVG_OP:begin
                image_data[addr_tl] <= avg;
                image_data[addr_tr] <= avg;
                image_data[addr_bl] <= avg;
                image_data[addr_br] <= avg;
            end       

            ROT_CCW:begin
                image_data[addr_tl] <= image_data[addr_tr];
                image_data[addr_tr] <= image_data[addr_br];
                image_data[addr_bl] <= image_data[addr_tl];
                image_data[addr_br] <= image_data[addr_bl];
            end      

            ROT_CW:begin
                image_data[addr_tl] <= image_data[addr_bl];
                image_data[addr_tr] <= image_data[addr_tl];
                image_data[addr_bl] <= image_data[addr_br];
                image_data[addr_br] <= image_data[addr_tr];
            end      

            MIRROR_X:begin
                image_data[addr_tl] <= image_data[addr_bl];
                image_data[addr_tr] <= image_data[addr_br];
                image_data[addr_bl] <= image_data[addr_tl];
                image_data[addr_br] <= image_data[addr_tr];
            end   

            MIRROR_Y:begin
                image_data[addr_tl] <= image_data[addr_tr];
                image_data[addr_tr] <= image_data[addr_tl];
                image_data[addr_bl] <= image_data[addr_br];
                image_data[addr_br] <= image_data[addr_bl];
            end    
        endcase
    end
    else if(IRAM_valid)      
        IRAM_D <= image_data[counter];
end

endmodule
*/



*/

module I2C_Slave_Byte
       #
       (
           // 时钟频率
           parameter [31: 0]CLK_FREQ = 32'd100_000_000,
           
           // SCL速率
           parameter [31: 0]SCL_RATE = 32'd5_000_000,
           // 从机地址
           parameter [6: 0]SLAVE_ADDR = 7'h00
       )
       (
           // 时钟信号
           input clk,
           // 复位信号
           input rst_n,
           // 使能信号
           input en,
           
           //I2C信号
           input SCL,
           inout SDA,
           
           // 读/写使能信号
           output reg rd_wr_n,
           // 寄存器地址
           output reg [7: 0]addr,
           // 写入的字节
           output reg [7: 0]data_byte_wr,
           // 读出的字节
           input [7: 0]data_byte_rd,
           
           // 读/写中断
           output reg irq,
           
           //I2C STOP
           output reg stop
       );
       
// 波特率分频系数
localparam [31: 0]BAUD_SET = (CLK_FREQ * 10 / (SCL_RATE * 2) + 5) / 10;

//state
localparam [2: 0]STOP = 2'd0;
localparam [2: 0]START = 2'd1;
localparam [2: 0]TRANSCEIVE = 2'd2;

//transceive_state
localparam [2: 0]ADDR_SLAVE = 2'd0;
localparam [2: 0]ADDR_REG = 2'd1;
localparam [2: 0]TRANSCEIVE_DATA = 2'd2;

// wire
wire clk_baud;
wire [31: 0]cnt_baud;

wire SCL_sync;
wire SDA_sync;
wire SDA_in;

// reg
reg [1: 0]state;

reg SCL_sync_pre;
reg SDA_in_pre;
reg clk_baud_pre;

reg restart;
reg transceive;

reg [1: 0]transceive_state;

reg SDA_out;
reg ack;

reg [7: 0]addr_next;
reg [7: 0]data_byte_tmp;

reg irq_tmp;

// SCL同步链
Sync_Chain Sync_Chain_inst
           (
               .clk(clk) ,
               .rst_n(rst_n) ,
               .sig(SCL) ,
               .sig_sync(SCL_sync)
           );
// SDA同步链
Sync_Chain Sync_Chain_inst2
           (
               .clk(clk) ,
               .rst_n(rst_n) ,
               .sig(SDA) ,
               .sig_sync(SDA_sync)
           );
           
assign SDA_in = (SDA_sync === 1'd0) ? 1'd0 : 1'd1; // 用于仿真
// assign SDA_in = SDA_sync;
assign SDA = SDA_out ? 1'hz : 1'd0;

// 波特时钟
Clk_Div_Cnt #(BAUD_SET, BAUD_SET[31: 1])Clk_Div_Cnt_inst
            (
                .clk(clk) ,
                .rst_n(rst_n) ,
                // 位同步
                .phase_rst(SCL_sync_pre ^ SCL_sync) ,
                .clk_div(clk_baud) ,
                .cnt()
            );
            
// 码元计数
Clk_Div_Cnt #(32'd17, 32'd8)Clk_Div_Cnt_inst2
            (
                .clk(clk_baud) ,
                .rst_n(rst_n) ,
                // 帧同步
                .phase_rst(~transceive) ,
                .clk_div() ,
                .cnt(cnt_baud)
            );
            
// 帧状态机
always@(posedge clk or negedge en or negedge rst_n)
begin
	if (!rst_n || !en)
	begin
		state <= STOP;
		
		SCL_sync_pre <= 1'd1;
		SDA_in_pre <= 1'd1;
		clk_baud_pre <= 1'd1;
		
		stop <= 1'd1;
		restart <= 1'd0;
		transceive <= 1'd0;
	end
	else
	begin
		SCL_sync_pre <= SCL_sync;
		SDA_in_pre <= SDA_in;
		clk_baud_pre <= clk_baud;
		
		case (state)
			STOP:
			begin
				if (SCL_sync)
				begin
					if (SDA_in_pre && !SDA_in)
					begin
						state <= START;
					end
				end
			end
			START:
			begin
				if (SCL_sync)
				begin
					if (!SDA_in_pre && SDA_in)
					begin
						state <= STOP;
					end
				end
				else if (SCL_sync_pre && !SCL_sync)
				begin
					state <= TRANSCEIVE;
					
					stop <= 1'd0;
				end
			end
			TRANSCEIVE:
			begin
				if (SCL_sync)
				begin
					if (!SDA_in_pre && SDA_in)
					begin
						state <= STOP;
						
						stop <= 1'd1;
						transceive <= 1'd0;
					end
					else if (SDA_in_pre && !SDA_in)
					begin
						state <= START;
						
						if (transceive_state == TRANSCEIVE_DATA)
						begin
							restart <= 1'd1;
						end
						else
						begin
							stop <= 1'd1;
						end
						transceive <= 1'd0;
					end
				end
				
				if (!ack && !transceive)
				begin
					if (!SCL_sync_pre && SCL_sync)
					begin
						transceive <= 1'd1;
					end
				end
				
				if (clk_baud_pre && !clk_baud) // clk_baud下降沿
				begin
					if (cnt_baud == 16)
					begin
						if (restart)
						begin
							restart <= 1'd0;
						end
						transceive <= 1'd0;
					end
				end
			end
			default:
			begin
			end
		endcase
	end
end

// 位状态机
always@(negedge clk_baud or posedge stop or negedge rst_n)
begin
	if (!rst_n || stop)
	begin
		transceive_state <= 1'd0;
		
		SDA_out <= 1'd1;
		ack <= 1'd0;
		
		addr_next <= 1'd0;
		data_byte_tmp <= 1'd0;
		
		rd_wr_n <= 1'd0;
		addr <= 1'd0;
		data_byte_wr <= 8'hFF;
		
		irq_tmp <= 1'd0;
	end
	else
	begin
		case (cnt_baud)
			0:
			begin
				if (!ack)
				begin
					if (!SCL_sync)
					begin
						if (!restart && rd_wr_n)
						begin
							SDA_out <= data_byte_rd[7]; // Read MSB
							
							data_byte_tmp <= data_byte_rd;
						end
						else
						begin
							SDA_out <= 1'd1; // 释放SDA
						end
					end
					else
					begin
						if (restart || !rd_wr_n)
						begin
							data_byte_tmp[7] <= SDA_in; // Write MSB
						end
					end
				end
			end
			1, 3, 5, 7, 9, 11, 13:
			begin
				if (!restart && rd_wr_n)
				begin
					SDA_out <= data_byte_tmp[6 - cnt_baud[31: 1]]; // Read MSB
				end
			end
			2, 4, 6, 8, 10, 12, 14:
			begin
				if (restart || !rd_wr_n)
				begin
					data_byte_tmp[7 - cnt_baud[31: 1]] <= SDA_in; // Write MSB
				end
				
				if (cnt_baud == 6)
				begin
					irq_tmp <= 1'd0;
				end
			end
			15:
			begin
				case (transceive_state)
					ADDR_SLAVE:
					begin
						if (!rd_wr_n)
						begin
							if (data_byte_tmp == {SLAVE_ADDR, 1'd0}) // Write
							begin
								transceive_state <= ADDR_REG;
								
								SDA_out <= 1'd0; // ACK
								ack <= 1'd0;
							end
							else
							begin
								SDA_out <= 1'd1; // NACK
								ack <= 1'd1;
							end
						end
					end
					ADDR_REG:
					begin
						if (!rd_wr_n)
						begin
							transceive_state <= TRANSCEIVE_DATA;
							
							SDA_out <= 1'd0; // ACK
							ack <= 1'd0;
							
							addr_next <= data_byte_tmp;
						end
					end
					TRANSCEIVE_DATA:
					begin
						if (restart)
						begin
							data_byte_wr <= 8'hFF;
							
							if (data_byte_tmp == {SLAVE_ADDR, 1'd0}) // Write
							begin
								SDA_out <= 1'd0; // ACK
								ack <= 1'd0;
								
								rd_wr_n <= 1'd0;
							end
							else if (data_byte_tmp == {SLAVE_ADDR, 1'd1}) // Read
							begin
								SDA_out <= 1'd0; // ACK
								ack <= 1'd0;
								
								rd_wr_n <= 1'd1;
							end
							else
							begin
								SDA_out <= 1'd1; // NACK
								ack <= 1'd1;
								
								rd_wr_n <= 1'd0;
							end
						end
						else
						begin
							if (!rd_wr_n)
							begin
								SDA_out <= 1'd0; // ACK
								ack <= 1'd0;
								
								addr_next <= addr_next + 1'd1;
								
								addr <= addr_next;
								data_byte_wr <= data_byte_tmp;
								
								irq_tmp <= 1'd1;
							end
							else
							begin
								SDA_out <= 1'd1; // 释放SDA
							end
						end
					end
					default:
					begin
					end
				endcase
			end
			16:
			begin
				data_byte_tmp <= 1'd0;
				
				if (rd_wr_n)
				begin
					if (!SDA_in) // ACK
					begin
						ack <= 1'd0;
						
						addr_next <= addr_next + 1'd1;
						
						addr <= addr_next;
						
						irq_tmp <= 1'd1;
					end
					else // NACK
					begin
						ack <= 1'd1;
						
						rd_wr_n <= 1'd0;
					end
				end
			end
			default:
			begin
			end
		endcase
	end
end

// irq延迟一个周期
always@(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		irq <= 1'd0;
	end
	else
	begin
		irq <= irq_tmp;
	end
end

endmodule

module Clk_Div_Cnt
       #
       (
           // 分频系数
           parameter [31: 0]CNT_MAX = 32'd1_000,
           // 占空比系数
           parameter [31: 0]CNT_THRESH = 32'd500
       )
       (
           // 输入时钟
           input clk,
           // 复位信号
           input rst_n,
           
           // 相位复位
           input phase_rst,
           
           // 分频时钟
           output reg clk_div,
           
           // 计数值
           output reg [31: 0]cnt
       );
       
// 根据对应的分频系数以及占空比系数进行分频，同时输出计数值，分频时钟初始值为1
// freq_div = freq_in / CNT_MAX
// duty = CNT_THRESH / CNT_MAX
// cnt = 0,1,2,...,CNT_MAX-1

// wire

// reg

// 分频 计数
always@(posedge clk or posedge phase_rst or negedge rst_n)
begin
	if (!rst_n || phase_rst)
	begin
		cnt <= 1'd0;
		
		clk_div <= 1'd1;
	end
	else
	begin
		if (cnt == CNT_MAX - 1'd1)
		begin
			cnt <= 1'd0;
			
			clk_div <= 1'd1;
		end
		else
		begin
			cnt <= cnt + 1'd1;
			
			if (cnt == CNT_THRESH - 1'd1)
			begin
				clk_div <= 1'd0;
			end
		end
	end
end

endmodule

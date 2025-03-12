module Sync_Chain
       (
           // 同步时钟
           input clk,
           // 复位信号
           input rst_n,
           
           // 输入信号
           input sig,
           
           // 同步信号
           output reg sig_sync
       );
       
// 锁存两次，防止亚稳态
// 多用于异步信号

// wire

// reg
reg sig_tmp;

// 锁存
always@(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
		sig_tmp <= 1'd0;
		sig_sync <= 1'd0;
	end
	else
	begin
		sig_tmp <= sig;
		sig_sync <= sig_tmp;
	end
end

endmodule

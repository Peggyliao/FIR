module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin

// write your code here!
    
//Configuration Register Address map
//AXI lite
//posedge can change state
reg [pDATA_WIDTH-1:0] ap_reg;
reg ap_start;
reg ap_idle;
reg ap_done;
    
reg [pDATA_WIDTH-1:0] data_leg_r;
reg config_en_r;
reg [5:0]  awadrr;
reg [5：0] araddr;

reg [pADDR_WIDTH-1:0] tap_A_r;
reg [pDATA_WIDTH-1:0] tap_Di_r;
reg tap_EN_r;
reg [3:0] tap_WE_r;
assign tap_A = tap_A_r;
assign tap_Di = tap_Di_r;
assign tap_EN = tap_EN_r;
assign tap_WE = tap_WE_r;

reg rready_r;
reg [pDATA_WIDTH-1:0] rdata_r;
assign rready = rready_r;
assign rdata = rdata_r;

assign awready = 1'b1;
wready = awready;


always @(*) begin
	ap_start = ap_reg[0];
	ap_done = ap_reg[1];
	ap_idle = ap_reg[2];
end

always @ (posedge axis_clk) begin
	config_en <= awvalid & wvalid & (~awadrr[6]);
	tap_A_r <= (awvalid | wvalid) ? awaddr[5:0] : araddr[5:0] ;
	tap_Di_r <= wdata ; 
	tap_EN_r <= awaddr[6];
	tap_WE_r <= awvalid & wvalid ;
	rready_r <= #1 ~(awvalid | wvalid);
	
	if(araddr[6] == 1)begin
		rdata_r <= tap_Do;
	end
	else if (araddr == 0)begin
		rdata_r <= ap_reg;
	end
	else begin
		rdata_r = data_leg_r;
	end
end

always @ (posedge axis_clk or negedge axis_rst_n) begin
	if(!axis_rst_n)begin
		ap_reg <= 32'h00000002;  // if done = 1
		data_leg_r <= 32'h0;
	end
	else begin
		if(config_en_r && awaddr == 12'h00) begin
			ap_reg <= wdata;
		end
		else if(config_en_r && awaddr == 12'h10) begin
			data_leg_r <= wdata;
		end
		else begin
			ap_reg <= ap_reg;
		end
	end
end


	
// Stream  write  data  in data_Ram
reg [pADDR_WIDTH-1:0] data_A_r;
reg [pDATA_WIDTH-1:0] data_Di_r;
reg data_EN_r;
reg [3:0] data_WE_r;
assign data_A = data_A_r;
assign data_Di = data_Di_r;
assign data_EN = data_EN_r;
assign data_WE = data_WE_r;
	
always @(posedge axis_clk) begin
	data_EN_r <= 1'b0;
	data_WE_r <= 4'b0000;
end

reg [pADDR_WIDTH-1:0] data_FF_r;
reg ss_tready_r;
wire [pADDR_WIDTH-1:0] data_FF_out;
wire FF_en;  
assign data_FF_out = data_FF_r;
assign ss_tready = ss_tready_r;
assign FF_en = ss_tready_r;

always @ (posedge axis_clk or negedge axis_rst_n)begin
		if(!axis_rst_n) begin
			data_FF_r <= 0;
			ss_tready_r <= 0;
		end
		else begin
			if(ap_start) begin
				if(ss_tvalid && ~ss_tready_r) begin
					data_FF_r <= ss_tdata;
					ss_tready_r <= 1;
				end
				else if(~ss_tvalid)begin
					ss_tready_r <= 0;
				end
			end
		end
end

reg [5:0] data_num1;
reg [3:0] data_num_count;
always @ (posedge axis_clk or negedge axis_rst_n)begin
	if(!axis_rst_n)begin
		data_num1 <= 0;
		data_num_count <= 0;
	end
	else begin
		if(ap_start)begin
			if(FF_en)begin
				if(data_num1 == 0)begin
					data_num1 <= 44;
				end
				else if(data_num_count > 0)begin
					data_num1 <= data_num1 - 4;	
				end
				data_num_count <= data_num_count - 1;
			end
			else begin
				data_num_count <= 11;
			end
		end
		else begin
			data_num1 <= data_num1;
			data_num_count <= 0;
		end
	end
end

always @ (posedge axis_clk)begin
	if(FF_en)begin
		data_A_r <= data_num1;
		data_Di_r <= data_FF_out;
		data_EN_r <= 1;
		data_WE_r <= 4'b1111;
	end
end

// Lite  write  data  in Tap_Ram

reg [5:0] tap_num1;
reg [3:0] tap_num_count;
always @ (posedge axis_clk or negedge axis_rst_n)begin
	if(!axis_rst_n)begin
		tap_num1 <= 0;
		tap_num_count <= 0;
	end
	else begin
		if(ap_start)begin
			if(FF_en)begin
				if(tap_num1 == 0)begin
					tap_num1 <= 44;
				end
				else if(tap_num_count > 0)begin
					tap_num1 <= tap_num1 - 4;	
				end
				tap_num_count <= tap_num_count - 1;
			end
			else begin
				tap_num_count <= 11;
			end
		end
		else begin
			tap_num1 <= tap_num1;
			tap_num_count <= 0;
		end
	end
end


//caculate
reg [pADDR_WIDTH-1:0] mul_r;
reg [pADDR_WIDTH-1:0] add_r;
reg [pADDR_WIDTH-1:0] y_r;
reg [3:0] count;

reg sm_tvalid_r;
reg [pADDR_WIDTH-1:0] sm_tdata_r;
assign sm_tvalid = sm_tvalid_r;
assign sm_tdata = sm_tdata_r;

always @ (posedge axis_clk or negedge axis_rst_n)begin
	if(!axis_rst_n)begin
		mul_r <= 0;
		add_r <= 0;
		out_r <= 0;
		count <= 0;
	end
	else
		if(ap_start)begin
			if(count < 11)begin
				mul_r <= data_r * tap_r;
				add_r <= add_r + mul_r;
				y_r <= add_r;
				count <= count + 1;
			end
			else if(count == datalength_reg)begin
				sm_tvalid_r <= 1;
				sm_tdata_r <= y_r;
				ap_start <= 0;
				ap_idle <= 1;
				ap_done <= 1;
			end
			else begin
				sm_tvalid_r <= 1;
				sm_tdata_r <= y_r;
				count <= 0;
				mul_r <= data_r * tap_r;
				add_r <= add_r + mul_r;
				y_r <= add_r;
				count <= count + 1;
			end
		end
	end
end	
	

endmodule
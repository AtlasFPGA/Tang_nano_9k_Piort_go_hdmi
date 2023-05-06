`timescale 1 ps / 1 ps

module piotr_go_hdmi (
    input wire clk27M,
    output wire reset, 
	input wire [1:0] 	BTN,	// BTN[1]=reset

// HDMI
	output wire      tmds_clk_n,
	output wire      tmds_clk_p,
	output wire [2:0] tmds_d_n,
	output wire [2:0] tmds_d_p,

// SD
	input	wire	spi_miso,		// SD Card Data 		(MISO)
	output	wire	spi_mosi,		// SD Card Command Signal 	(MOSI)
	output	wire	spi_clk,		// SD Card Clock 		(SCK)
	output	wire	mmc_ncs,		// SD Card Data 3 		(CSn)

// PS2
	inout	wire			ps2_kb_clk,
	inout	wire			ps2_kb_dat
  
  );

	wire [7:0] VGA_R;
	wire [7:0] VGA_G;
	wire [7:0] VGA_B;
	wire VGA_H;
	wire VGA_V;
	wire VGA_CLK;
	wire bufpll_lock, clk25m,dviclk;

// clk125m:125.875  clk25m:25.175
  Gowin_rPLL2 u_pll (.clkin(clk27M), .clkout(clk125m), .lock(pll_lock2));
  Gowin_CLKDIV u_div_5 ( .clkout(clk25m), .hclkin(clk125m), .resetn(pll_lock2));
	
	
	 svo_hdmi_out u_hdmi (
	//.clk(clk_p),
	.resetn(~breset),//(sys_resetn),
	// video clocks
	.clk_pixel(clk25m),
	.clk_5x_pixel(clk125m),
	.locked(pll_lock2),
	// input VGA
	.rout(VGA_R[7:2]),
	.gout(VGA_G[7:2]),
	.bout(VGA_B[7:2]),
	.hsync_n(VGA_H),
	.vsync_n(VGA_V),
	.hblnk_n(~de),
	// output signals
	.tmds_clk_n(tmds_clk_n),
	.tmds_clk_p(tmds_clk_p),
	.tmds_d_n(tmds_d_n),
	.tmds_d_p(tmds_d_p),
	.tmds_ts()
);

	wire [10:0] bgnd_hcount;
	wire [10:0] bgnd_vcount;
	wire H, V, de;

	video_gen vido_piotr (
		.clk(clk25m),

		.hcount(bgnd_hcount),
		.vcount(bgnd_vcount),
		.picture(de),

		.hsync(H),
		.vsync(V)
	);
reg [7:0] red_data, green_data, blue_data;

	always @(posedge clk25m) begin
		if(bgnd_hcount < 64 || bgnd_hcount >= 576 || bgnd_vcount < 8 || bgnd_vcount >= 472) begin
			red_data <= 128;
			green_data <= 128;
			blue_data <= 128;
		end
		else begin
			red_data <= 255 - ((bgnd_vcount+32)>>1);
			green_data <= ((bgnd_hcount-64)>>1);
			blue_data <= ((bgnd_vcount+32)>>1);
		end
	end
	
	assign VGA_R = de ? red_data[7:0] : 8'b0;
	assign VGA_G = de ? green_data[7:0] : 8'b0;
	assign VGA_B = de ? blue_data[7:0] : 8'b0;
	assign VGA_H = ~H;
	assign VGA_V = ~V;
	assign VGA_CLK = clk25m;


  wire pll_lock2;
  wire clk125m;
  wire clk25m;
  wire breset = ~BTN[1];	
endmodule

module video_gen(
	input  wire        clk,

	output wire [10:0] hcount,
	output wire [10:0] vcount,
	output wire        picture,
//  output wire        hblank,
	output wire        hsync,
	output wire        vsync
	);

	//640x480@60Hz
	parameter HPIXELS = 11'd640;
	parameter HSYNCS  = 11'd656;
	parameter HSYNCE  = 11'd720;
	parameter HMAX    = 11'd834 - 11'd1;
	parameter VPIXELS = 11'd480;
	parameter VSYNCS  = 11'd481;
	parameter VSYNCE  = 11'd484;
	parameter VMAX    = 11'd500 - 11'd1;

	reg [10:0] hcnt;
	reg [10:0] vcnt;

	assign picture = (hcnt < HPIXELS) && (vcnt < VPIXELS);
	assign hsync = (hcnt > HSYNCS) && (hcnt <= HSYNCE);
	assign vsync = (vcnt > VSYNCS) && (vcnt <= VSYNCE);
	assign hcount = hcnt;
	assign vcount = vcnt;
    //assign de = vsync && hsync;

	always @ (posedge clk) begin
		if (hcnt<HMAX)
			hcnt <= hcnt + 11'd1;
		else begin
			hcnt <= 11'd0;
			if (vcnt<VMAX)
				vcnt <= vcnt + 11'd1;
			else
				vcnt <= 11'd0;
		end
	end
endmodule

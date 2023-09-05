`timescale 1ns/1ps
//function: oD = number of used bits in iD
module RSA_getNumBit (
	input			iClk, iRstn,
	input			iStart,
	input		[1023:0]iD,
	output		[10:0]	oD,
	output	reg		oDone	);

reg		isActive;
reg	[5:0]	D_out_MSB;
wire	[5:0]	D_out_MSB_w;
reg	[4:0]	D_out_LSB;

reg	[4:0]	Counter;
wire	[31:0]	D_in;

wire	[31:0]	a;
wire	[1:0]	b15, b14, b13, b12, b11, b10, b9 , b8 ,
		b7 , b6 , b5 , b4 , b3 , b2 , b1 , b0 ;
wire	[2:0]	c7 , c6 , c5 , c4 , c3 , c2 , c1 , c0 ;
wire	[3:0]	d3 , d2 , d1 , d0 ;
wire	[4:0]	e1 , e0 ;
wire	[5:0]	numbit32;

wire		numbit32_0, numbit32_0_n;
wire		D_0, D_0_n;
wire		stopCond;

/****************************************************/
/*		Muxing in			*/
/****************************************************/
always@(posedge iClk) begin
	if(~iRstn|~isActive)	Counter <= 5'd0;
	else			Counter <= Counter + 1'b1; end

/*
always@(*) begin
	case(Counter)
		5'd0:	D_in = iD[1023:992];
		5'd1:	D_in = iD[991:960];
		5'd2:	D_in = iD[959:928];
		5'd3:	D_in = iD[927:896];
		5'd4:	D_in = iD[895:864];
		5'd5:	D_in = iD[863:832];
		5'd6:	D_in = iD[831:800];
		5'd7:	D_in = iD[799:768];
		5'd8:	D_in = iD[767:736];
		5'd9:	D_in = iD[735:704];
		5'd10:	D_in = iD[703:672];
		5'd11:	D_in = iD[671:640];
		5'd12:	D_in = iD[639:608];
		5'd13:	D_in = iD[607:576];
		5'd14:	D_in = iD[575:544];
		5'd15:	D_in = iD[543:512];
		5'd16:	D_in = iD[511:480];
		5'd17:	D_in = iD[479:448];
		5'd18:	D_in = iD[447:416];
		5'd19:	D_in = iD[415:384];
		5'd20:	D_in = iD[383:352];
		5'd21:	D_in = iD[351:320];
		5'd22:	D_in = iD[319:288];
		5'd23:	D_in = iD[287:256];
		5'd24:	D_in = iD[255:224];
		5'd25:	D_in = iD[223:192];
		5'd26:	D_in = iD[191:160];
		5'd27:	D_in = iD[159:128];
		5'd28:	D_in = iD[127:96];
		5'd29:	D_in = iD[95:64];
		5'd30:	D_in = iD[63:32];
		5'd31:	D_in = iD[31:0];
	endcase end
*/
assign D_in =
	(Counter[4]) ?
		( (Counter[3]) ?
			( (Counter[2]) ?
				( (Counter[1]) ?
					( (Counter[0]) ? iD[31:0]    : iD[63:32]    ) :
					( (Counter[0]) ? iD[95:64]   : iD[127:96]   ) ) :
				( (Counter[1]) ?
					( (Counter[0]) ? iD[159:128] : iD[191:160]  ) :
					( (Counter[0]) ? iD[223:192] : iD[255:224]  ) ) ) :
			( (Counter[2]) ?
				( (Counter[1]) ?
					( (Counter[0]) ? iD[287:256] : iD[319:288]  ) :
					( (Counter[0]) ? iD[351:320] : iD[383:352]  ) ) :
				( (Counter[1]) ?
					( (Counter[0]) ? iD[415:384] : iD[447:416]  ) :
					( (Counter[0]) ? iD[479:448] : iD[511:480]  ) ) ) ) :
		( (Counter[3]) ?
			( (Counter[2]) ?
				( (Counter[1]) ?
					( (Counter[0]) ? iD[543:512] : iD[575:544]  ) :
					( (Counter[0]) ? iD[607:576] : iD[639:608]  ) ) :
				( (Counter[1]) ?
					( (Counter[0]) ? iD[671:640] : iD[703:672]  ) :
					( (Counter[0]) ? iD[735:704] : iD[767:736]  ) ) ) :
			( (Counter[2]) ?
				( (Counter[1]) ?
					( (Counter[0]) ? iD[799:768] : iD[831:800]  ) :
					( (Counter[0]) ? iD[863:832] : iD[895:864]  ) ) :
				( (Counter[1]) ?
					( (Counter[0]) ? iD[927:896] : iD[959:928]  ) :
					( (Counter[0]) ? iD[991:960] : iD[1023:992] ) ) ) );

/****************************************************/
/*	Get number of used bits in D_in		*/
/****************************************************/
assign a[31] = D_in[31];
assign a[30] = a[31] | D_in[30];
assign a[29] = a[30] | D_in[29];
assign a[28] = a[29] | D_in[28];
assign a[27] = a[28] | D_in[27];
assign a[26] = a[27] | D_in[26];
assign a[25] = a[26] | D_in[25];
assign a[24] = a[25] | D_in[24];
assign a[23] = a[24] | D_in[23];
assign a[22] = a[23] | D_in[22];
assign a[21] = a[22] | D_in[21];
assign a[20] = a[21] | D_in[20];
assign a[19] = a[20] | D_in[19];
assign a[18] = a[19] | D_in[18];
assign a[17] = a[18] | D_in[17];
assign a[16] = a[17] | D_in[16];
assign a[15] = a[16] | D_in[15];
assign a[14] = a[15] | D_in[14];
assign a[13] = a[14] | D_in[13];
assign a[12] = a[13] | D_in[12];
assign a[11] = a[12] | D_in[11];
assign a[10] = a[11] | D_in[10];
assign a[9]  = a[10] | D_in[9] ;
assign a[8]  = a[9]  | D_in[8] ;
assign a[7]  = a[8]  | D_in[7] ;
assign a[6]  = a[7]  | D_in[6] ;
assign a[5]  = a[6]  | D_in[5] ;
assign a[4]  = a[5]  | D_in[4] ;
assign a[3]  = a[4]  | D_in[3] ;
assign a[2]  = a[3]  | D_in[2] ;
assign a[1]  = a[2]  | D_in[1] ;
assign a[0]  = a[1]  | D_in[0] ;

assign b15 = a[31] + a[30];
assign b14 = a[29] + a[28];
assign b13 = a[27] + a[26];
assign b12 = a[25] + a[24];
assign b11 = a[23] + a[22];
assign b10 = a[21] + a[20];
assign b9  = a[19] + a[18];
assign b8  = a[17] + a[16];
assign b7  = a[15] + a[14];
assign b6  = a[13] + a[12];
assign b5  = a[11] + a[10];
assign b4  = a[9]  + a[8];
assign b3  = a[7]  + a[6];
assign b2  = a[5]  + a[4];
assign b1  = a[3]  + a[2];
assign b0  = a[1]  + a[0];

assign c7 = b15 + b14;
assign c6 = b13 + b12;
assign c5 = b11 + b10;
assign c4 = b9  + b8;
assign c3 = b7  + b6;
assign c2 = b5  + b4;
assign c1 = b3  + b2;
assign c0 = b1  + b0;

assign d3 = c7 + c6;
assign d2 = c5 + c4;
assign d1 = c3 + c2;
assign d0 = c1 + c0;

assign e1 = d3 + d2;
assign e0 = d1 + d0;

assign numbit32 = e1 + e0;

/****************************************************/
/*		Status				*/
/****************************************************/
assign numbit32_0_n = |(numbit32);	//numbit32!=6'd0
assign numbit32_0 = ~numbit32_0_n;	//numbit32==6'd0
assign D_0_n = |(D_out_MSB);		//D_out_MSB!=11'd0
assign D_0 = ~D_0_n;			//D_out_MSB==11'd0

always@(posedge iClk) begin
	if(~iRstn|stopCond)	isActive <= 1'b0;
	else			isActive <= (iStart|isActive); end

assign stopCond = isActive & (numbit32_0_n | D_0);

always@(posedge iClk) begin
	oDone <= stopCond; end

/****************************************************/
/*		Data out			*/
/****************************************************/
/*always@(posedge iClk) begin
	if(iStart)	D_out_MSB <= 6'd31;
	else if(isActive & numbit32_0_n)
			D_out_MSB <= D_out_MSB + numbit32[5];
	else if(isActive & D_0_n)
			D_out_MSB <= D_out_MSB - 1'b1;
	else		D_out_MSB <= D_out_MSB; end*/
assign D_out_MSB_w = (isActive&numbit32_0_n) ? (D_out_MSB+numbit32[5]) :
			(isActive&D_0_n) ? (D_out_MSB-1'b1) : D_out_MSB;
always@(posedge iClk) begin
	if(iStart)	D_out_MSB <= 6'd31;
	else		D_out_MSB <= D_out_MSB_w; end

always@(posedge iClk) begin
	if(iStart)			D_out_LSB <= 5'b0;
	else if(isActive&numbit32_0_n)	D_out_LSB <= numbit32[4:0];
	else				D_out_LSB <= D_out_LSB; end

assign oD = {D_out_MSB,D_out_LSB};

endmodule


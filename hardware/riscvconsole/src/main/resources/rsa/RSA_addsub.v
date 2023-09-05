`timescale 1ns/1ps
// function: oD = (iAddSub) ? (iA-iB) : (iA+iB)
module RSA_addsub (
	input		iClk, iRstn,
	input		iStart,
	input		iAddSub,	//0: add;	1: sub
	output		oDataShift,
	input	[31:0]	iA, iB,
	output	[31:0]	oD,
	output		oOverflow,
	output		oDone	);

reg	[4:0]	Counter;
wire		CounterNot0, Counter31;

wire	[31:0]	B, D;

reg		Carry;
wire		Cin, Cout;

/****************************************************/
/*		Counter				*/
/****************************************************/
assign CounterNot0 = |(Counter);	//Counter!=5'd0
assign Counter31 = &(Counter);		//Counter==5'd31

assign oDataShift = iStart|CounterNot0;

always@(posedge iClk) begin
	if(~iRstn)		Counter <= 5'd0;
	else if(oDataShift)	Counter <= Counter + 1'b1;
	else			Counter <= Counter; end

assign oDone = Counter31;

/****************************************************/
/*		Compute				*/
/****************************************************/
// Carry in
always@(posedge iClk) begin
	Carry <= Cout; end
assign Cin = (iStart) ? iAddSub : Carry;

// invert for sub
assign B = (iAddSub) ? ~iB : iB;

// add
assign {Cout, oD} = iA + B + Cin;

// Overflow carry out
assign oOverflow = Cout;

endmodule


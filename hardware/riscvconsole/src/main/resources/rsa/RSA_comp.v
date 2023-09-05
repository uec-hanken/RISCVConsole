`timescale 1ns/1ps
module RSA_comp (
	input	[1023:0]iA, iB,
	output		Out );
assign Out = ~(iA<iB);
endmodule


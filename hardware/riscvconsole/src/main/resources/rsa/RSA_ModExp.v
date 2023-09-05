`timescale 1ns/1ps
//function: oR = (iM^iE) % iN
module RSA_ModExp (
	input		iClk, iRstn,
	input		iStart,
	input		iWrM, iWrE, iWrN,
	input	[63:0]	iM, iE, iN,
	input		iRdR,
	output	[63:0]	oR,
	output	reg	oDone	);

//registers
reg	[1023:0]M;
wire	[1023:0]M_w;
reg		M_reset0, M_shift32;

reg	[1023:0]Mbin;
wire	[1023:0]Mbin_w;
reg		Mbin_update, Mbin_shift1;

reg	[1023:0]E;
wire	[1023:0]E_w;
reg		E_shift1;

reg	[1023:0]N;
wire	[1023:0]N_w;
reg		N_shift32;

reg	[1023:0]R;
wire	[1023:0]R_w;
reg		R_reset0, R_reset1, R_shift32;

reg	[1023:0]tmp;
wire	[1023:0]tmp_w;
reg		tmp_getR, tmp_getM, tmp_mul2, tmp_shift32, tmp_shift32_update;

//submodules
reg		addsub_start, addsub_addsub;
wire		addsub_dataShift, addsub_done;
wire	[31:0]	addsub_A, addsub_B, addsub_D;
wire		addsub_overflow;

reg		getNumBit_start;
wire	[1023:0]getNumBit_iD;
wire	[10:0]	getNumBit_oD;
wire		getNumBit_done;

wire	[1023:0]comp_A;
wire		comp_O;
wire		comp_ret;

//control submodules
reg		comp_A_R, comp_A_M;

reg		getNumBit_E;
reg		addsub_R, addsub_M;
reg		addsub_N;

//FSM
reg	[4:0]	State;
reg	[10:0]	lenE, lenM, lenMR;
wire	[10:0]	lenE_w, lenM_w, lenMR_w;
reg		overflow;
wire		overflow_w;

//FSM optimized
wire		S0 , S1 , S2 , S3 , S4 , S5 , S6 , S7 ,
		S8 , S9 , S10, S11, S12, S13, S14, S15,
		S16, S17, S18, S19;
wire		E0, MR0, M0;
wire	[4:0]	nextState;

/****************************************************/
/*		Registers			*/
/****************************************************/
/*always@(posedge iClk) begin
	if(M_reset0)	M <= 1024'b0;
	else if(iWrM)	M <= {iM,M[1023:64]};		//shift-right data in
	else if(M_shift32 & addsub_dataShift)
			M <= {addsub_D,M[1023:32]};	//shift-right for addsub
	else		M <= M; end*/
assign M_w = (iWrM) ? {iM,M[1023:64]} :
	     (M_shift32&addsub_dataShift) ? {addsub_D,M[1023:32]} : M;
always@(posedge iClk) begin
	if(M_reset0)	M <= 1024'b0;
	else		M <= M_w; end

/*always@(posedge iClk) begin
	if(Mbin_update)		Mbin <= M;			//update the whole reg
	else if(Mbin_shift1)	Mbin <= {1'b0,Mbin[1023:1]};	//shift-right for exec loop
	else			Mbin <= Mbin; end*/
assign Mbin_w = (Mbin_update) ? M :
		(Mbin_shift1) ? {1'b0,Mbin[1023:1]} : Mbin;
always@(posedge iClk) begin
	Mbin <= Mbin_w; end

/*always@(posedge iClk) begin
	if(iWrE)		E <= {iE,E[1023:64]};	//shift-right data in
	else if(E_shift1)	E <= {1'b0,E[1023:1]};	//shift-right for exec loop
	else			E <= E; end*/
assign E_w = (iWrE) ? {iE,E[1023:64]} :
	     (E_shift1) ? {1'b0,E[1023:1]} : E;
always@(posedge iClk) begin
	E <= E_w; end

/*always@(posedge iClk) begin
	if(iWrN)		N <= {iN,N[1023:64]};		//shift-right data in
	else if(N_shift32)	N <= {N[31:0],N[1023:32]};	//shift-right for addsub
	else			N <= N; end*/
assign N_w = (iWrN) ? {iN,N[1023:64]} :
	     (N_shift32) ? {N[31:0],N[1023:32]} : N;
always@(posedge iClk) begin
	N <= N_w; end

/*always@(posedge iClk) begin
	if(R_reset0)		R <= 1024'b0;			//reset to5'd0
	else if(R_reset1)	R <= 1024'd1;			//reset to5'd1
	else if(iRdR)		R <= {R[63:0],R[1023:64]};	//shift-right data out
	else if(R_shift32 & addsub_dataShift)
				R <= {addsub_D,R[1023:32]};	//shift-right for addsub
	else			R <= R; end*/
assign R_w[1023:1] = (iRdR) ? {R[63:0],R[1023:65]} :
		     (R_shift32&addsub_dataShift) ? {addsub_D,R[1023:33]} : R[1023:1];
always@(posedge iClk) begin
	if(R_reset0|R_reset1)	R[1023:1] <= 1023'b0;
	else			R[1023:1] <= R_w[1023:1]; end
assign R_w[0] = R_reset1 | ( (iRdR) ? R[64] :
		((R_shift32&addsub_dataShift) ? R[32] : R[0]) );
always@(posedge iClk) begin
	if(R_reset0)	R[0] <= 1'b0;
	else		R[0] <= R_w[0]; end
assign oR = R[1023:960];

/*always@(posedge iClk) begin
	if(tmp_getR)		tmp <= R;				//tmp=R
	else if(tmp_getM)	tmp <= M;				//tmp=M
	else if(tmp_mul2)	tmp <= {tmp[1022:0],1'b0};		//tmp=tmp*2
	else if(tmp_shift32)	tmp <= {tmp[31:0],tmp[1023:32]};	//shift-right for addsub
	else if(tmp_shift32_update & addsub_dataShift)
				tmp <= {addsub_D,tmp[1023:32]};		//shift-right for addsub
	else			tmp <= tmp; end*/
assign tmp_w = (tmp_getR) ? R :
		(tmp_getM) ? M :
		(tmp_mul2) ? {tmp[1022:0],1'b0} :
		(tmp_shift32) ? {tmp[31:0],tmp[1023:32]} :
		(tmp_shift32_update&addsub_dataShift) ? {addsub_D,tmp[1023:32]} : tmp;
always@(posedge iClk) begin
	tmp <= tmp_w; end

/****************************************************/
/*		Submodules			*/
/****************************************************/
RSA_addsub addsub (
	.iClk		(iClk),
	.iRstn		(iRstn),
	.iStart		(addsub_start),
	.iAddSub	(addsub_addsub),	//0: add;	1: sub
	.oDataShift	(addsub_dataShift),
	.iA		(addsub_A),
	.iB		(addsub_B),
	.oD		(addsub_D),
	.oOverflow	(addsub_overflow),
	.oDone		(addsub_done)	);

RSA_getNumBit getNumBit (
	.iClk		(iClk),
	.iRstn		(iRstn),
	.iStart		(getNumBit_start),
	.iD		(getNumBit_iD),
	.oD		(getNumBit_oD),
	.oDone		(getNumBit_done)	);

RSA_comp comp (
	.iA		(comp_A),
	.iB		(N),
	.Out		(comp_O)	);
assign comp_ret = comp_O | overflow;

/****************************************************/
/*	Control regs & submodules		*/
/****************************************************/
assign comp_A = (comp_A_R) ? R :
		(comp_A_M) ? M : tmp;

assign getNumBit_iD = (getNumBit_E) ? E : M;

assign addsub_A = (addsub_R) ? R[31:0] :
		  (addsub_M) ? M[31:0] : tmp[31:0];
assign addsub_B = (addsub_N) ? N[31:0] : tmp[31:0];

/****************************************************/
/*		FSM				*/
/****************************************************/
/*always@(posedge iClk) begin
	if(~iRstn) begin
		oDone <= 1'b0;
		State <= 5'b0;
		M_reset0 <= 1'b0;
		M_shift32 <= 1'b0;
		Mbin_update <= 1'b0;
		Mbin_shift1 <= 1'b0;
		E_shift1 <= 1'b0;
		N_shift32 <= 1'b0;
		R_reset0 <= 1'b0;
		R_reset1 <= 1'b0;
		R_shift32 <= 1'b0;
		tmp_getR <= 1'b0;
		tmp_getM <= 1'b0;
		tmp_mul2 <= 1'b0;
		tmp_shift32 <= 1'b0;
		tmp_shift32_update <= 1'b0;
		addsub_start <= 1'b0;
		addsub_addsub <= 1'b0;
		getNumBit_start <= 1'b0;
		comp_A_R <= 1'b0;
		comp_A_M <= 1'b0;
		getNumBit_E <= 1'b0;
		addsub_R <= 1'b0;
		addsub_M <= 1'b0;
		addsub_N <= 1'b0;
		lenE <= 11'b0;
		lenM <= 11'b0;
		overflow <= 1'b0;
	end
	else begin
		case(State)
			5'd0: begin
				oDone <= 1'b0;
				if(iStart) begin
					State <= 5'd1;
					getNumBit_start <= 1'b1;
					getNumBit_E <= 1'b1; end
				else	State <= State; end
			5'd1: begin
				getNumBit_start <= 1'b0;
				if(getNumBit_done) begin
					lenE <= getNumBit_oD;
					R_reset1 <= 1'b1;
					State <= 5'd2; end
				else	State <= State; end
			5'd2: begin
				R_reset1 <= 1'b0;
				if(lenE==11'b0) begin
					oDone <= 1'b1;
					State <= 5'd0; end
				else begin
					getNumBit_start <= 1'b1;
					getNumBit_E <= 1'b0;
					State <= 5'd3; end end
			5'd3: begin
				getNumBit_start <= 1'b0;
				if(getNumBit_done) begin
					lenM <= getNumBit_oD;
					lenMR <= getNumBit_oD;
					Mbin_update <= 1'b1;
					State <= 5'd4; end
				else	State <= State; end
			5'd4: begin
				E_shift1 <= 1'b1;
				if(E[0]) begin
					Mbin_update <= 1'b0;
					tmp_getR <= 1'b1;
					R_reset0 <= 1'b1;
					State <= 5'd5; end
				else begin
					Mbin_update <= 1'b1;
					tmp_getM <= 1'b1;
					M_reset0 <= 1'b1;
					State <= 5'd12; end end
			5'd5: begin
				E_shift1 <= 1'b0;
				tmp_getR <= 1'b0;
				R_reset0 <= 1'b0;
				if(lenMR==11'b0) begin
					Mbin_update <= 1'b1;
					tmp_getM <= 1'b1;
					M_reset0 <= 1'b1;
					State <= 5'd12; end
				else begin
					Mbin_shift1 <= 1'b1;
					if(Mbin[0]) begin
						addsub_start <= 1'b1;
						addsub_addsub <= 1'b0;	//add
						addsub_R <= 1'b1;	//A=R
						addsub_N <= 1'b0;	//B=tmp
						R_shift32 <= 1'b1;
						tmp_shift32 <= 1'b1;
						State <= 5'd6; end
					else begin
						tmp_mul2 <= 1'b1;
						State <= 5'd9; end end end
			5'd6: begin
				Mbin_shift1 <= 1'b0;
				addsub_start <= 1'b0;
				if(addsub_done) begin
					overflow <= addsub_overflow;
					R_shift32 <= 1'b0;
					tmp_shift32 <= 1'b0;
					comp_A_R <= 1'b1;
					State <= 5'd7; end
				else	State <= State; end
			5'd7: begin
				if(comp_ret) begin
					overflow <= 1'b0;
					addsub_start <= 1'b1;
					addsub_addsub <= 1'b1;	//sub
					addsub_R <= 1'b1;	//A=R
					addsub_N <= 1'b1;	//B=N
					R_shift32 <= 1'b1;
					N_shift32 <= 1'b1;
					State <= 5'd8; end
				else begin
					tmp_mul2 <= 1'b1;
					State <= 5'd9; end end
			5'd8: begin
				addsub_start <= 1'b0;
				if(addsub_done) begin
					R_shift32 <= 1'b0;
					N_shift32 <= 1'b0;
					tmp_mul2 <= 1'b1;
					State <= 5'd9; end
				else	State <= State; end
			5'd9: begin
				Mbin_shift1 <= 1'b0;
				tmp_mul2 <= 1'b0;
				overflow <= tmp[1023];
				comp_A_R <= 1'b0;
				comp_A_M <= 1'b0;
				State <= 5'd10; end
			5'd10: begin
				overflow <= 1'b0;
				if(comp_ret) begin
					addsub_start <= 1'b1;
					addsub_addsub <= 1'b1;	//sub
					addsub_R <= 1'b0;
					addsub_M <= 1'b0;	//A=tmp
					addsub_N <= 1'b1;	//B=N
					tmp_shift32_update <= 1'b1;
					N_shift32 <= 1'b1;
					State <= 5'd11; end
				else begin
					lenMR <= lenMR - 1'b1;
					State <= 5'd5; end end
			5'd11: begin
				addsub_start <= 1'b0;
				if(addsub_done) begin
					tmp_shift32_update <= 1'b0;
					N_shift32 <= 1'b0;
					lenMR <= lenMR - 1'b1;
					State <= 5'd5; end
				else	State <= State; end
			5'd12: begin
				E_shift1 <= 1'b0;
				Mbin_update <= 1'b0;
				tmp_getM <= 1'b0;
				M_reset0 <= 1'b0;
				if(lenM==11'b0) begin
					lenE <= lenE - 1'b1;
					State <= 5'd2; end
				else		State <= 5'd13; end
			5'd13: begin
				Mbin_shift1 <= 1'b1;
				if(Mbin[0]) begin
					addsub_start <= 1'b1;
					addsub_addsub <= 1'b0;	//add
					addsub_R <= 1'b0;
					addsub_M <= 1'b1;	//A=M
					addsub_N <= 1'b0;	//B=tmp
					M_shift32 <= 1'b1;
					tmp_shift32 <= 1'b1;
					State <= 5'd14; end
				else begin
					tmp_mul2 <= 1'b1;
					State <= 5'd17; end end
			5'd14: begin
				Mbin_shift1 <= 1'b0;
				addsub_start <= 1'b0;
				if(addsub_done) begin
					overflow <= addsub_overflow;
					M_shift32 <= 1'b0;
					tmp_shift32 <= 1'b0;
					comp_A_R <= 1'b0;
					comp_A_M <= 1'b1;
					State <= 5'd15; end
				else	State <= State; end
			5'd15: begin
				if(comp_ret) begin
					overflow <= 1'b0;
					addsub_start <= 1'b1;
					addsub_addsub <= 1'b1;	//sub
					addsub_R <= 1'b0;
					addsub_M <= 1'b1;	//A=M
					addsub_N <= 1'b1;	//B=N
					M_shift32 <= 1'b1;
					N_shift32 <= 1'b1;
					State <= 5'd16; end
				else begin
					tmp_mul2 <= 1'b1;
					State <= 5'd17; end end
			5'd16: begin
				addsub_start <= 1'b0;
				if(addsub_done) begin
					M_shift32 <= 1'b0;
					N_shift32 <= 1'b0;
					tmp_mul2 <= 1'b1;
					State <= 5'd17; end
				else	State <= State; end
			5'd17: begin
				Mbin_shift1 <= 1'b0;
				tmp_mul2 <= 1'b0;
				overflow <= tmp[1023];
				comp_A_R <= 1'b0;
				comp_A_M <= 1'b0;
				State <= 5'd18; end
			5'd18: begin
				overflow <= 1'b0;
				if(comp_ret) begin
					addsub_start <= 1'b1;
					addsub_addsub <= 1'b1;	//sub
					addsub_R <= 1'b0;
					addsub_M <= 1'b0;	//A=tmp
					addsub_N <= 1'b1;	//B=N
					tmp_shift32_update <= 1'b1;
					N_shift32 <= 1'b1;
					State <= 5'd19; end
				else begin
					lenM <= lenM - 1'b1;
					State <= 5'd12; end end
			5'd19: begin
				addsub_start <= 1'b0;
				if(addsub_done) begin
					tmp_shift32_update <= 1'b0;
					N_shift32 <= 1'b0;
					lenM <= lenM - 1'b1;
					State <= 5'd12; end
				else	State <= State; end
			default: ;
		endcase end end*/

/****************************************************/
/*		FSM optimized			*/
/****************************************************/
assign S0  = ~State[4] & ~State[3] & ~State[2] & ~State[1] & ~State[0];
assign S1  = ~State[4] & ~State[3] & ~State[2] & ~State[1] &  State[0];
assign S2  = ~State[4] & ~State[3] & ~State[2] &  State[1] & ~State[0];
assign S3  = ~State[4] & ~State[3] & ~State[2] &  State[1] &  State[0];
assign S4  = ~State[4] & ~State[3] &  State[2] & ~State[1] & ~State[0];
assign S5  = ~State[4] & ~State[3] &  State[2] & ~State[1] &  State[0];
assign S6  = ~State[4] & ~State[3] &  State[2] &  State[1] & ~State[0];
assign S7  = ~State[4] & ~State[3] &  State[2] &  State[1] &  State[0];
assign S8  = ~State[4] &  State[3] & ~State[2] & ~State[1] & ~State[0];
assign S9  = ~State[4] &  State[3] & ~State[2] & ~State[1] &  State[0];
assign S10 = ~State[4] &  State[3] & ~State[2] &  State[1] & ~State[0];
assign S11 = ~State[4] &  State[3] & ~State[2] &  State[1] &  State[0];
assign S12 = ~State[4] &  State[3] &  State[2] & ~State[1] & ~State[0];
assign S13 = ~State[4] &  State[3] &  State[2] & ~State[1] &  State[0];
assign S14 = ~State[4] &  State[3] &  State[2] &  State[1] & ~State[0];
assign S15 = ~State[4] &  State[3] &  State[2] &  State[1] &  State[0];
assign S16 =  State[4] & ~State[3] & ~State[2] & ~State[1] & ~State[0];
assign S17 =  State[4] & ~State[3] & ~State[2] & ~State[1] &  State[0];
assign S18 =  State[4] & ~State[3] & ~State[2] &  State[1] & ~State[0];
assign S19 =  State[4] & ~State[3] & ~State[2] &  State[1] &  State[0];

assign E0 = ~(|(lenE));		//lenE==11'b0
assign MR0 = ~(|(lenMR));	//lenMR==11'b0
assign M0 = ~(|(lenM));		//lenM==11'b0

always@(posedge iClk) begin
	oDone <= S2&E0; end

always@(posedge iClk) begin
	M_reset0 <= (S4&~E[0])|(S5&MR0); end

always@(posedge iClk) begin
	M_shift32 <= (S13&Mbin[0])|((S14|S16)&~addsub_done)|(S15&comp_ret); end

always@(posedge iClk) begin
	Mbin_update <= (S3&getNumBit_done)|(S4&~E[0])|(S5&MR0); end

always@(posedge iClk) begin
	Mbin_shift1 <= ((S5&~MR0)|S13); end

always@(posedge iClk) begin
	E_shift1 <= S4; end

always@(posedge iClk) begin
	N_shift32 <= ((S7|S10|S15|S18)&comp_ret)|((S8|S11|S16|S19)&~addsub_done); end

always@(posedge iClk) begin
	R_reset0 <= S4&E[0]; end

always@(posedge iClk) begin
	R_reset1 <= S1&getNumBit_done; end

always@(posedge iClk) begin
	R_shift32 <= (S5&Mbin[0])|((S6|S8)&~addsub_done)|(S7&comp_ret); end

always@(posedge iClk) begin
	tmp_getR <= S4&E[0]; end

always@(posedge iClk) begin
	tmp_getM <= (S4&~E[0])|(S5&MR0); end

always@(posedge iClk) begin
	tmp_mul2 <= ((S5|S13)&~Mbin[0])|((S7|S15)&~comp_ret)|((S8|S16)&addsub_done); end

always@(posedge iClk) begin
	tmp_shift32 <= ((S5|S13)&Mbin[0])|((S6|S14)&~addsub_done); end

always@(posedge iClk) begin
	tmp_shift32_update <= ((S10|S18)&comp_ret)|((S11|S19)&~addsub_done); end

always@(posedge iClk) begin
	getNumBit_start <= (S0&iStart)|(S2&~E0); end

always@(posedge iClk) begin
	getNumBit_E <= (S0&iStart)|S1; end

assign lenE_w = (S1&getNumBit_done) ? getNumBit_oD :
		(S12&M0) ? (lenE-1'b1) : lenE;
always@(posedge iClk) begin
	lenE <= lenE_w; end

assign lenM_w = (S3&getNumBit_done) ? getNumBit_oD :
		((S18&~comp_ret)|(S19&addsub_done)) ? (lenM-1'b1) : lenM;
always@(posedge iClk) begin
	lenM <= lenM_w; end

assign lenMR_w = (S3&getNumBit_done) ? getNumBit_oD :
		 ((S10&~comp_ret)|(S11&addsub_done)) ? (lenMR-1'b1) : lenMR;
always@(posedge iClk) begin
	lenMR <= lenMR_w; end

always@(posedge iClk) begin
	comp_A_R <= S6&addsub_done; end

always@(posedge iClk) begin
	comp_A_M <= S14&addsub_done; end

always@(posedge iClk) begin
	addsub_start <= ((S5|S13)&Mbin[0]) | ((S7|S10|S15|S18)&comp_ret);  end

always@(posedge iClk) begin
	addsub_addsub <= ~(S5|S13) & (S7|S10|S15|S18|addsub_addsub); end

always@(posedge iClk) begin
	addsub_R <= ~(S10|S13|S15|S18) & (S5|S7|addsub_R); end

always@(posedge iClk) begin
	addsub_M <= ~(S10|S18) & (S13|S15|addsub_M); end

always@(posedge iClk) begin
	addsub_N <= ~(S5|S13) & (S7|S10|S15|S18|addsub_N); end

assign overflow_w = ((S6|S14) & addsub_done & addsub_overflow) |
		    ((S9|S17) & tmp[1023]) | overflow;
always@(posedge iClk) begin
	if(~iRstn|((S7|S15)&comp_ret)|S10|S18)	overflow <= 1'b0;
	else					overflow <= overflow_w; end

/*always@(*) begin
	case(State)
		5'd0:	if(iStart)		nextState = 5'd1;
			else			nextState = 5'd0;
		5'd1:	if(getNumBit_done)	nextState = 5'd2;
			else			nextState = 5'd1;
		5'd2:	if(E0)			nextState = 5'd0;
			else			nextState = 5'd3;
		5'd3:	if(getNumBit_done)	nextState = 5'd4;
			else			nextState = 5'd3;
		5'd4:	if(E[0])		nextState = 5'd5;
			else			nextState = 5'd12;
		5'd5:	if(MR0)			nextState = 5'd12;
			else if(Mbin[0])	nextState = 5'd6;
			else			nextState = 5'd9;
		5'd6:	if(addsub_done)		nextState = 5'd7;
			else			nextState = 5'd6;
		5'd7:	if(comp_ret)		nextState = 5'd8;
			else			nextState = 5'd9;
		5'd8:	if(addsub_done)		nextState = 5'd9;
			else			nextState = 5'd8;
		5'd9:	nextState = 5'd10;
		5'd10:	if(comp_ret)		nextState = 5'd11;
			else			nextState = 5'd5;
		5'd11:	if(addsub_done)		nextState = 5'd5;
			else			nextState = 5'd11;
		5'd12:	if(M0)			nextState = 5'd2;
			else			nextState = 5'd13;
		5'd13:	if(Mbin[0])		nextState = 5'd14;
			else			nextState = 5'd17;
		5'd14:	if(addsub_done)		nextState = 5'd15;
			else			nextState = 5'd14;
		5'd15:	if(comp_ret)		nextState = 5'd16;
			else			nextState = 5'd17;
		5'd16:	if(addsub_done)		nextState = 5'd17;
			else			nextState = 5'd16;
		5'd17:	nextState = 5'd18;
		5'd18:	if(comp_ret)		nextState = 5'd19;
			else			nextState = 5'd12;
		5'd19:	if(addsub_done)		nextState = 5'd12;
			else			nextState = 5'd19;
	endcase end*/
assign nextState[0] = (S0&iStart) |
			((S1|S3)&~getNumBit_done) |
			(S2&~E0) | (S4&E[0]) |
			(((S5&~MR0)|S13)&~Mbin[0]) |
			((S6|S8|S14|S16)&addsub_done) |
			((S7|S15)&~comp_ret) | S10|S11 |
			(S12&~M0) | (S18&comp_ret)|
			(S19&~addsub_done);
assign nextState[1] = (S1&getNumBit_done) |
			(S2&~E0) | (S12&M0) |
			(S3&~getNumBit_done) |
			(((S5&~MR0)|S13)&Mbin[0]) |
			S6|S9|S14|S17 |
			((S10|S18)&comp_ret) | 
			((S11|S19)&~addsub_done);
assign nextState[2] = (S3&getNumBit_done) |
			S4|S6|S14 | (S5&(MR0|Mbin[0])) |
			((S10|S18)&~comp_ret) |
			((S11|S19)&addsub_done) |
			(S12&~M0) | (S13&Mbin[0]);
assign nextState[3] = (S4&~E[0]) | (S5&(MR0|~Mbin[0])) |
			S7|S8|S9|S14 | (S10&comp_ret) |
			(S11&~addsub_done) |
			(S12&~M0) | (S13&Mbin[0]) |
			(S18&~comp_ret) | (S19&addsub_done);
assign nextState[4] = (S13&~Mbin[0]) | S15|S16|S17|
			(S18&comp_ret) | (S19&~addsub_done);
always@(posedge iClk) begin
	if(~iRstn)	State <= 5'b0;
	else		State <= nextState; end

endmodule

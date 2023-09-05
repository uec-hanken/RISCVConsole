`define WT_DCACHE
`define DISABLE_TRACER
`define SRAM_NO_INIT
`define VERILATOR
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* if "oAck" is 1, then current input has been used. */

module f_permutation(
	input				iClk,
	input				iRst,
	input		[575:0]	iData,
	input				iReady,
	output				oAck,
	output		[511:0]	oData
	//output	reg		oReady
);

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
 
 reg	[10:0]		i; /* select round constant */
 reg	[1599:0]	round;
 wire	[1599:0]	round_in, round_out;
 wire	[6:0]		rc1, rc2;
 wire				update;
 wire				accept;
 
 reg				calc; /* == 1: calculating rounds */

/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/

 assign accept = iReady & ~calc;	//iReady & (i==0)
 assign round_in = (accept) ? {iData^round[1599:1024], round[1023:0]} : round;
 
 assign update = calc | accept;
 assign oAck = accept;
 assign oData = round[1599:1088];

/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/
 
 always@(posedge iClk) begin
	if(iRst)	i <= 11'b0;
	else		i <= {i[9:0], accept};
 end
 
 always@(posedge iClk) begin
	if(iRst)	calc <= 1'b0;
	else		calc <= (calc & ~i[10]) | accept;
 end
/*
 always@(posedge iClk) begin
	if(iRst | accept)	oReady <= 1'b0;
	// only change at the last round
	else if(i[10])		oReady <= 1'b1;
	else				oReady <= oReady;
 end
*/
 always@(posedge iClk) begin
	if(iRst)		round <= 1600'b0;
	else if(update)	round <= round_out;
	else			round <= round;
 end

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
 
 rconst2in1 rconst_ (
	.i		({i, accept}),
	.rc1	(rc1),
	.rc2	(rc2)
 );

 round2in1 round_ (
	.in		(round_in),
	.rc1	(rc1),
	.rc2	(rc2),
	.out	(round_out)
 );

endmodule
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module round2in1(
	input	[1599:0]	in,
	input	[6:0]		rc1,
	input	[6:0]		rc2,
	output	[1599:0]	out
);

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
 
 /* "a ~ g" for round 1 */
 wire	[63:0]	a[4:0][4:0];
 wire	[63:0]	b[4:0];
 wire	[63:0]	c[4:0][4:0];
 wire	[63:0]	d[4:0][4:0];
 wire	[63:0]	e[4:0][4:0];
 wire	[63:0]	f[4:0][4:0];
 wire	[63:0]	g[4:0][4:0];

 /* "aa ~ gg" for round 2 */
 wire	[63:0]	bb[4:0];
 wire	[63:0]	cc[4:0][4:0];
 wire	[63:0]	dd[4:0][4:0];
 wire	[63:0]	ee[4:0][4:0];
 wire	[63:0]	ff[4:0][4:0];
 wire	[63:0]	gg[4:0][4:0];

/*****************************************************************************
 *                                 Inputs                                    *
 *****************************************************************************/
 
 assign a[0][0] = in[1599:1536];
 assign a[1][0] = in[1535:1472];
 assign a[2][0] = in[1471:1408];
 assign a[3][0] = in[1407:1344];
 assign a[4][0] = in[1343:1280];
 assign a[0][1] = in[1279:1216];
 assign a[1][1] = in[1215:1152];
 assign a[2][1] = in[1151:1088];
 assign a[3][1] = in[1087:1024];
 assign a[4][1] = in[1023:960];
 assign a[0][2] = in[959:896];
 assign a[1][2] = in[895:832];
 assign a[2][2] = in[831:768];
 assign a[3][2] = in[767:704];
 assign a[4][2] = in[703:640];
 assign a[0][3] = in[639:576];
 assign a[1][3] = in[575:512];
 assign a[2][3] = in[511:448];
 assign a[3][3] = in[447:384];
 assign a[4][3] = in[383:320];
 assign a[0][4] = in[319:256];
 assign a[1][4] = in[255:192];
 assign a[2][4] = in[191:128];
 assign a[3][4] = in[127:64];
 assign a[4][4] = in[63:0];

/*****************************************************************************
 *                                 Round 1                                   *
 *****************************************************************************/
 
 assign b[0] = a[0][0] ^ a[0][1] ^ a[0][2] ^ a[0][3] ^ a[0][4];
 assign b[1] = a[1][0] ^ a[1][1] ^ a[1][2] ^ a[1][3] ^ a[1][4];
 assign b[2] = a[2][0] ^ a[2][1] ^ a[2][2] ^ a[2][3] ^ a[2][4];
 assign b[3] = a[3][0] ^ a[3][1] ^ a[3][2] ^ a[3][3] ^ a[3][4];
 assign b[4] = a[4][0] ^ a[4][1] ^ a[4][2] ^ a[4][3] ^ a[4][4];

 /* calc "c == theta(a)" */
 assign c[0][0] = a[0][0] ^ b[4] ^ {b[1][62:0], b[1][63]};
 assign c[1][0] = a[1][0] ^ b[0] ^ {b[2][62:0], b[2][63]};
 assign c[2][0] = a[2][0] ^ b[1] ^ {b[3][62:0], b[3][63]};
 assign c[3][0] = a[3][0] ^ b[2] ^ {b[4][62:0], b[4][63]};
 assign c[4][0] = a[4][0] ^ b[3] ^ {b[0][62:0], b[0][63]};
 assign c[0][1] = a[0][1] ^ b[4] ^ {b[1][62:0], b[1][63]};
 assign c[1][1] = a[1][1] ^ b[0] ^ {b[2][62:0], b[2][63]};
 assign c[2][1] = a[2][1] ^ b[1] ^ {b[3][62:0], b[3][63]};
 assign c[3][1] = a[3][1] ^ b[2] ^ {b[4][62:0], b[4][63]};
 assign c[4][1] = a[4][1] ^ b[3] ^ {b[0][62:0], b[0][63]};
 assign c[0][2] = a[0][2] ^ b[4] ^ {b[1][62:0], b[1][63]};
 assign c[1][2] = a[1][2] ^ b[0] ^ {b[2][62:0], b[2][63]};
 assign c[2][2] = a[2][2] ^ b[1] ^ {b[3][62:0], b[3][63]};
 assign c[3][2] = a[3][2] ^ b[2] ^ {b[4][62:0], b[4][63]};
 assign c[4][2] = a[4][2] ^ b[3] ^ {b[0][62:0], b[0][63]};
 assign c[0][3] = a[0][3] ^ b[4] ^ {b[1][62:0], b[1][63]};
 assign c[1][3] = a[1][3] ^ b[0] ^ {b[2][62:0], b[2][63]};
 assign c[2][3] = a[2][3] ^ b[1] ^ {b[3][62:0], b[3][63]};
 assign c[3][3] = a[3][3] ^ b[2] ^ {b[4][62:0], b[4][63]};
 assign c[4][3] = a[4][3] ^ b[3] ^ {b[0][62:0], b[0][63]};
 assign c[0][4] = a[0][4] ^ b[4] ^ {b[1][62:0], b[1][63]};
 assign c[1][4] = a[1][4] ^ b[0] ^ {b[2][62:0], b[2][63]};
 assign c[2][4] = a[2][4] ^ b[1] ^ {b[3][62:0], b[3][63]};
 assign c[3][4] = a[3][4] ^ b[2] ^ {b[4][62:0], b[4][63]};
 assign c[4][4] = a[4][4] ^ b[3] ^ {b[0][62:0], b[0][63]};

 /* calc "d == rho(c)" */
 assign d[0][0] = c[0][0];
 assign d[1][0] = {c[1][0][62:0], c[1][0][63]};
 assign d[2][0] = {c[2][0][1:0] , c[2][0][63:2]};
 assign d[3][0] = {c[3][0][35:0], c[3][0][63:36]};
 assign d[4][0] = {c[4][0][36:0], c[4][0][63:37]};
 assign d[0][1] = {c[0][1][27:0], c[0][1][63:28]};
 assign d[1][1] = {c[1][1][19:0], c[1][1][63:20]};
 assign d[2][1] = {c[2][1][57:0], c[2][1][63:58]};
 assign d[3][1] = {c[3][1][8:0] , c[3][1][63:9]};
 assign d[4][1] = {c[4][1][43:0], c[4][1][63:44]};
 assign d[0][2] = {c[0][2][60:0], c[0][2][63:61]};
 assign d[1][2] = {c[1][2][53:0], c[1][2][63:54]};
 assign d[2][2] = {c[2][2][20:0], c[2][2][63:21]};
 assign d[3][2] = {c[3][2][38:0], c[3][2][63:39]};
 assign d[4][2] = {c[4][2][24:0], c[4][2][63:25]};
 assign d[0][3] = {c[0][3][22:0], c[0][3][63:23]};
 assign d[1][3] = {c[1][3][18:0], c[1][3][63:19]};
 assign d[2][3] = {c[2][3][48:0], c[2][3][63:49]};
 assign d[3][3] = {c[3][3][42:0], c[3][3][63:43]};
 assign d[4][3] = {c[4][3][55:0], c[4][3][63:56]};
 assign d[0][4] = {c[0][4][45:0], c[0][4][63:46]};
 assign d[1][4] = {c[1][4][61:0], c[1][4][63:62]};
 assign d[2][4] = {c[2][4][2:0] , c[2][4][63:3]};
 assign d[3][4] = {c[3][4][7:0] , c[3][4][63:8]};
 assign d[4][4] = {c[4][4][49:0], c[4][4][63:50]};

 /* calc "e == pi(d)" */
 assign e[0][0] = d[0][0];
 assign e[0][2] = d[1][0];
 assign e[0][4] = d[2][0];
 assign e[0][1] = d[3][0];
 assign e[0][3] = d[4][0];
 assign e[1][3] = d[0][1];
 assign e[1][0] = d[1][1];
 assign e[1][2] = d[2][1];
 assign e[1][4] = d[3][1];
 assign e[1][1] = d[4][1];
 assign e[2][1] = d[0][2];
 assign e[2][3] = d[1][2];
 assign e[2][0] = d[2][2];
 assign e[2][2] = d[3][2];
 assign e[2][4] = d[4][2];
 assign e[3][4] = d[0][3];
 assign e[3][1] = d[1][3];
 assign e[3][3] = d[2][3];
 assign e[3][0] = d[3][3];
 assign e[3][2] = d[4][3];
 assign e[4][2] = d[0][4];
 assign e[4][4] = d[1][4];
 assign e[4][1] = d[2][4];
 assign e[4][3] = d[3][4];
 assign e[4][0] = d[4][4];

 /* calc "f = chi(e)" */
 assign f[0][0] = e[0][0] ^ (~e[1][0] & e[2][0]);
 assign f[1][0] = e[1][0] ^ (~e[2][0] & e[3][0]);
 assign f[2][0] = e[2][0] ^ (~e[3][0] & e[4][0]);
 assign f[3][0] = e[3][0] ^ (~e[4][0] & e[0][0]);
 assign f[4][0] = e[4][0] ^ (~e[0][0] & e[1][0]);
 assign f[0][1] = e[0][1] ^ (~e[1][1] & e[2][1]);
 assign f[1][1] = e[1][1] ^ (~e[2][1] & e[3][1]);
 assign f[2][1] = e[2][1] ^ (~e[3][1] & e[4][1]);
 assign f[3][1] = e[3][1] ^ (~e[4][1] & e[0][1]);
 assign f[4][1] = e[4][1] ^ (~e[0][1] & e[1][1]);
 assign f[0][2] = e[0][2] ^ (~e[1][2] & e[2][2]);
 assign f[1][2] = e[1][2] ^ (~e[2][2] & e[3][2]);
 assign f[2][2] = e[2][2] ^ (~e[3][2] & e[4][2]);
 assign f[3][2] = e[3][2] ^ (~e[4][2] & e[0][2]);
 assign f[4][2] = e[4][2] ^ (~e[0][2] & e[1][2]);
 assign f[0][3] = e[0][3] ^ (~e[1][3] & e[2][3]);
 assign f[1][3] = e[1][3] ^ (~e[2][3] & e[3][3]);
 assign f[2][3] = e[2][3] ^ (~e[3][3] & e[4][3]);
 assign f[3][3] = e[3][3] ^ (~e[4][3] & e[0][3]);
 assign f[4][3] = e[4][3] ^ (~e[0][3] & e[1][3]);
 assign f[0][4] = e[0][4] ^ (~e[1][4] & e[2][4]);
 assign f[1][4] = e[1][4] ^ (~e[2][4] & e[3][4]);
 assign f[2][4] = e[2][4] ^ (~e[3][4] & e[4][4]);
 assign f[3][4] = e[3][4] ^ (~e[4][4] & e[0][4]);
 assign f[4][4] = e[4][4] ^ (~e[0][4] & e[1][4]);

 /* calc "g = iota(f)" */
 assign g[0][0][63]    = f[0][0][63] ^ rc1[6];
 assign g[0][0][62:32] = f[0][0][62:32];
 assign g[0][0][31]    = f[0][0][31] ^ rc1[5];
 assign g[0][0][30:16] = f[0][0][30:16];
 assign g[0][0][15]    = f[0][0][15] ^ rc1[4];
 assign g[0][0][14:8]  = f[0][0][14:8];
 assign g[0][0][7]     = f[0][0][7] ^ rc1[3];
 assign g[0][0][6:4]   = f[0][0][6:4];
 assign g[0][0][3]     = f[0][0][3] ^ rc1[2];
 assign g[0][0][2]     = f[0][0][2];
 assign g[0][0][1]     = f[0][0][1] ^ rc1[1];
 assign g[0][0][0]     = f[0][0][0] ^ rc1[0];

 assign g[1][0] = f[1][0];
 assign g[2][0] = f[2][0];
 assign g[3][0] = f[3][0];
 assign g[4][0] = f[4][0];
 assign g[0][1] = f[0][1];
 assign g[1][1] = f[1][1];
 assign g[2][1] = f[2][1];
 assign g[3][1] = f[3][1];
 assign g[4][1] = f[4][1];
 assign g[0][2] = f[0][2];
 assign g[1][2] = f[1][2];
 assign g[2][2] = f[2][2];
 assign g[3][2] = f[3][2];
 assign g[4][2] = f[4][2];
 assign g[0][3] = f[0][3];
 assign g[1][3] = f[1][3];
 assign g[2][3] = f[2][3];
 assign g[3][3] = f[3][3];
 assign g[4][3] = f[4][3];
 assign g[0][4] = f[0][4];
 assign g[1][4] = f[1][4];
 assign g[2][4] = f[2][4];
 assign g[3][4] = f[3][4];
 assign g[4][4] = f[4][4];

/*****************************************************************************
 *                                 Round 2                                   *
 *****************************************************************************/
  
 assign bb[0] = g[0][0] ^ g[0][1] ^ g[0][2] ^ g[0][3] ^ g[0][4];
 assign bb[1] = g[1][0] ^ g[1][1] ^ g[1][2] ^ g[1][3] ^ g[1][4];
 assign bb[2] = g[2][0] ^ g[2][1] ^ g[2][2] ^ g[2][3] ^ g[2][4];
 assign bb[3] = g[3][0] ^ g[3][1] ^ g[3][2] ^ g[3][3] ^ g[3][4];
 assign bb[4] = g[4][0] ^ g[4][1] ^ g[4][2] ^ g[4][3] ^ g[4][4];
 
 /* calc "cc == theta(g)" */
 assign cc[0][0] = g[0][0] ^ bb[4] ^ {bb[1][62:0], bb[1][63]};
 assign cc[1][0] = g[1][0] ^ bb[0] ^ {bb[2][62:0], bb[2][63]};
 assign cc[2][0] = g[2][0] ^ bb[1] ^ {bb[3][62:0], bb[3][63]};
 assign cc[3][0] = g[3][0] ^ bb[2] ^ {bb[4][62:0], bb[4][63]};
 assign cc[4][0] = g[4][0] ^ bb[3] ^ {bb[0][62:0], bb[0][63]};
 assign cc[0][1] = g[0][1] ^ bb[4] ^ {bb[1][62:0], bb[1][63]};
 assign cc[1][1] = g[1][1] ^ bb[0] ^ {bb[2][62:0], bb[2][63]};
 assign cc[2][1] = g[2][1] ^ bb[1] ^ {bb[3][62:0], bb[3][63]};
 assign cc[3][1] = g[3][1] ^ bb[2] ^ {bb[4][62:0], bb[4][63]};
 assign cc[4][1] = g[4][1] ^ bb[3] ^ {bb[0][62:0], bb[0][63]};
 assign cc[0][2] = g[0][2] ^ bb[4] ^ {bb[1][62:0], bb[1][63]};
 assign cc[1][2] = g[1][2] ^ bb[0] ^ {bb[2][62:0], bb[2][63]};
 assign cc[2][2] = g[2][2] ^ bb[1] ^ {bb[3][62:0], bb[3][63]};
 assign cc[3][2] = g[3][2] ^ bb[2] ^ {bb[4][62:0], bb[4][63]};
 assign cc[4][2] = g[4][2] ^ bb[3] ^ {bb[0][62:0], bb[0][63]};
 assign cc[0][3] = g[0][3] ^ bb[4] ^ {bb[1][62:0], bb[1][63]};
 assign cc[1][3] = g[1][3] ^ bb[0] ^ {bb[2][62:0], bb[2][63]};
 assign cc[2][3] = g[2][3] ^ bb[1] ^ {bb[3][62:0], bb[3][63]};
 assign cc[3][3] = g[3][3] ^ bb[2] ^ {bb[4][62:0], bb[4][63]};
 assign cc[4][3] = g[4][3] ^ bb[3] ^ {bb[0][62:0], bb[0][63]};
 assign cc[0][4] = g[0][4] ^ bb[4] ^ {bb[1][62:0], bb[1][63]};
 assign cc[1][4] = g[1][4] ^ bb[0] ^ {bb[2][62:0], bb[2][63]};
 assign cc[2][4] = g[2][4] ^ bb[1] ^ {bb[3][62:0], bb[3][63]};
 assign cc[3][4] = g[3][4] ^ bb[2] ^ {bb[4][62:0], bb[4][63]};
 assign cc[4][4] = g[4][4] ^ bb[3] ^ {bb[0][62:0], bb[0][63]};
 
 /* calc "dd == rho(cc)" */
 assign dd[0][0] = cc[0][0];
 assign dd[1][0] = {cc[1][0][62:0], cc[1][0][63]};
 assign dd[2][0] = {cc[2][0][1:0] , cc[2][0][63:2]};
 assign dd[3][0] = {cc[3][0][35:0], cc[3][0][63:36]};
 assign dd[4][0] = {cc[4][0][36:0], cc[4][0][63:37]};
 assign dd[0][1] = {cc[0][1][27:0], cc[0][1][63:28]};
 assign dd[1][1] = {cc[1][1][19:0], cc[1][1][63:20]};
 assign dd[2][1] = {cc[2][1][57:0], cc[2][1][63:58]};
 assign dd[3][1] = {cc[3][1][8:0] , cc[3][1][63:9]};
 assign dd[4][1] = {cc[4][1][43:0], cc[4][1][63:44]};
 assign dd[0][2] = {cc[0][2][60:0], cc[0][2][63:61]};
 assign dd[1][2] = {cc[1][2][53:0], cc[1][2][63:54]};
 assign dd[2][2] = {cc[2][2][20:0], cc[2][2][63:21]};
 assign dd[3][2] = {cc[3][2][38:0], cc[3][2][63:39]};
 assign dd[4][2] = {cc[4][2][24:0], cc[4][2][63:25]};
 assign dd[0][3] = {cc[0][3][22:0], cc[0][3][63:23]};
 assign dd[1][3] = {cc[1][3][18:0], cc[1][3][63:19]};
 assign dd[2][3] = {cc[2][3][48:0], cc[2][3][63:49]};
 assign dd[3][3] = {cc[3][3][42:0], cc[3][3][63:43]};
 assign dd[4][3] = {cc[4][3][55:0], cc[4][3][63:56]};
 assign dd[0][4] = {cc[0][4][45:0], cc[0][4][63:46]};
 assign dd[1][4] = {cc[1][4][61:0], cc[1][4][63:62]};
 assign dd[2][4] = {cc[2][4][2:0] , cc[2][4][63:3]};
 assign dd[3][4] = {cc[3][4][7:0] , cc[3][4][63:8]};
 assign dd[4][4] = {cc[4][4][49:0], cc[4][4][63:50]};

 /* calc "ee == pi(dd)" */
 assign ee[0][0] = dd[0][0];
 assign ee[0][2] = dd[1][0];
 assign ee[0][4] = dd[2][0];
 assign ee[0][1] = dd[3][0];
 assign ee[0][3] = dd[4][0];
 assign ee[1][3] = dd[0][1];
 assign ee[1][0] = dd[1][1];
 assign ee[1][2] = dd[2][1];
 assign ee[1][4] = dd[3][1];
 assign ee[1][1] = dd[4][1];
 assign ee[2][1] = dd[0][2];
 assign ee[2][3] = dd[1][2];
 assign ee[2][0] = dd[2][2];
 assign ee[2][2] = dd[3][2];
 assign ee[2][4] = dd[4][2];
 assign ee[3][4] = dd[0][3];
 assign ee[3][1] = dd[1][3];
 assign ee[3][3] = dd[2][3];
 assign ee[3][0] = dd[3][3];
 assign ee[3][2] = dd[4][3];
 assign ee[4][2] = dd[0][4];
 assign ee[4][4] = dd[1][4];
 assign ee[4][1] = dd[2][4];
 assign ee[4][3] = dd[3][4];
 assign ee[4][0] = dd[4][4];

 /* calc "ff = chi(ee)" */
 assign ff[0][0] = ee[0][0] ^ (~ee[1][0] & ee[2][0]);
 assign ff[1][0] = ee[1][0] ^ (~ee[2][0] & ee[3][0]);
 assign ff[2][0] = ee[2][0] ^ (~ee[3][0] & ee[4][0]);
 assign ff[3][0] = ee[3][0] ^ (~ee[4][0] & ee[0][0]);
 assign ff[4][0] = ee[4][0] ^ (~ee[0][0] & ee[1][0]);
 assign ff[0][1] = ee[0][1] ^ (~ee[1][1] & ee[2][1]);
 assign ff[1][1] = ee[1][1] ^ (~ee[2][1] & ee[3][1]);
 assign ff[2][1] = ee[2][1] ^ (~ee[3][1] & ee[4][1]);
 assign ff[3][1] = ee[3][1] ^ (~ee[4][1] & ee[0][1]);
 assign ff[4][1] = ee[4][1] ^ (~ee[0][1] & ee[1][1]);
 assign ff[0][2] = ee[0][2] ^ (~ee[1][2] & ee[2][2]);
 assign ff[1][2] = ee[1][2] ^ (~ee[2][2] & ee[3][2]);
 assign ff[2][2] = ee[2][2] ^ (~ee[3][2] & ee[4][2]);
 assign ff[3][2] = ee[3][2] ^ (~ee[4][2] & ee[0][2]);
 assign ff[4][2] = ee[4][2] ^ (~ee[0][2] & ee[1][2]);
 assign ff[0][3] = ee[0][3] ^ (~ee[1][3] & ee[2][3]);
 assign ff[1][3] = ee[1][3] ^ (~ee[2][3] & ee[3][3]);
 assign ff[2][3] = ee[2][3] ^ (~ee[3][3] & ee[4][3]);
 assign ff[3][3] = ee[3][3] ^ (~ee[4][3] & ee[0][3]);
 assign ff[4][3] = ee[4][3] ^ (~ee[0][3] & ee[1][3]);
 assign ff[0][4] = ee[0][4] ^ (~ee[1][4] & ee[2][4]);
 assign ff[1][4] = ee[1][4] ^ (~ee[2][4] & ee[3][4]);
 assign ff[2][4] = ee[2][4] ^ (~ee[3][4] & ee[4][4]);
 assign ff[3][4] = ee[3][4] ^ (~ee[4][4] & ee[0][4]);
 assign ff[4][4] = ee[4][4] ^ (~ee[0][4] & ee[1][4]);
 
 /* calc "gg = iota(ff)" */
 assign gg[0][0][63]    = ff[0][0][63] ^ rc2[6];
 assign gg[0][0][62:32] = ff[0][0][62:32];
 assign gg[0][0][31]    = ff[0][0][31] ^ rc2[5];
 assign gg[0][0][30:16] = ff[0][0][30:16];
 assign gg[0][0][15]    = ff[0][0][15] ^ rc2[4];
 assign gg[0][0][14:8]  = ff[0][0][14:8];
 assign gg[0][0][7]     = ff[0][0][7] ^ rc2[3];
 assign gg[0][0][6:4]   = ff[0][0][6:4];
 assign gg[0][0][3]     = ff[0][0][3] ^ rc2[2];
 assign gg[0][0][2]     = ff[0][0][2];
 assign gg[0][0][1]     = ff[0][0][1] ^ rc2[1];
 assign gg[0][0][0]     = ff[0][0][0] ^ rc2[0];

 assign gg[1][0] = ff[1][0];
 assign gg[2][0] = ff[2][0];
 assign gg[3][0] = ff[3][0];
 assign gg[4][0] = ff[4][0];
 assign gg[0][1] = ff[0][1];
 assign gg[1][1] = ff[1][1];
 assign gg[2][1] = ff[2][1];
 assign gg[3][1] = ff[3][1];
 assign gg[4][1] = ff[4][1];
 assign gg[0][2] = ff[0][2];
 assign gg[1][2] = ff[1][2];
 assign gg[2][2] = ff[2][2];
 assign gg[3][2] = ff[3][2];
 assign gg[4][2] = ff[4][2];
 assign gg[0][3] = ff[0][3];
 assign gg[1][3] = ff[1][3];
 assign gg[2][3] = ff[2][3];
 assign gg[3][3] = ff[3][3];
 assign gg[4][3] = ff[4][3];
 assign gg[0][4] = ff[0][4];
 assign gg[1][4] = ff[1][4];
 assign gg[2][4] = ff[2][4];
 assign gg[3][4] = ff[3][4];
 assign gg[4][4] = ff[4][4];

/*****************************************************************************
 *                                 Outputs                                   *
 *****************************************************************************/
 
 assign out[1599:1536] = gg[0][0];
 assign out[1535:1472] = gg[1][0];
 assign out[1471:1408] = gg[2][0];
 assign out[1407:1344] = gg[3][0];
 assign out[1343:1280] = gg[4][0];
 assign out[1279:1216] = gg[0][1];
 assign out[1215:1152] = gg[1][1];
 assign out[1151:1088] = gg[2][1];
 assign out[1087:1024] = gg[3][1];
 assign out[1023:960]  = gg[4][1];
 assign out[959:896]   = gg[0][2];
 assign out[895:832]   = gg[1][2];
 assign out[831:768]   = gg[2][2];
 assign out[767:704]   = gg[3][2];
 assign out[703:640]   = gg[4][2];
 assign out[639:576]   = gg[0][3];
 assign out[575:512]   = gg[1][3];
 assign out[511:448]   = gg[2][3];
 assign out[447:384]   = gg[3][3];
 assign out[383:320]   = gg[4][3];
 assign out[319:256]   = gg[0][4];
 assign out[255:192]   = gg[1][4];
 assign out[191:128]   = gg[2][4];
 assign out[127:64]    = gg[3][4];
 assign out[63:0]      = gg[4][4];

endmodule
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module padder1(
	input	[63:0]	in,
	input	[2:0]	byte_num,
	output	[63:0]	out
);
/*
 case (byte_num)
	0: out =             64'h0600000000000000;
	1: out = {in[63:56], 56'h06000000000000};
	2: out = {in[63:48], 48'h060000000000};
	3: out = {in[63:40], 40'h0600000000};
	4: out = {in[63:32], 32'h06000000};
	5: out = {in[63:24], 24'h060000};
	6: out = {in[63:16], 16'h0600};
	7: out = {in[63:8],   8'h06};
 endcase
*/
/*
 assign out[63:56] = (byte_num == 3'd0) ? 8'h06 : in[63:56];
 assign out[55:48] = (byte_num < 3'd1)  ? 8'h00 :
					 (byte_num == 3'd1) ? 8'h06 : in[55:48];
 assign out[47:40] = (byte_num < 3'd2)  ? 8'h00 :
					 (byte_num == 3'd2) ? 8'h06 : in[47:40];
 assign out[39:32] = (byte_num < 3'd3)  ? 8'h00 :
					 (byte_num == 3'd3) ? 8'h06 : in[39:32];
 assign out[31:24] = (byte_num < 3'd4)  ? 8'h00 :
					 (byte_num == 3'd4) ? 8'h06 : in[31:24];
 assign out[23:16] = (byte_num < 3'd5)  ? 8'h00 :
					 (byte_num == 3'd5) ? 8'h06 : in[23:16];
 assign out[15:8]  = (byte_num < 3'd6)  ? 8'h00 :
					 (byte_num == 3'd6) ? 8'h06 : in[15:8];
 assign out[7:0]   = (byte_num < 3'd7)  ? 8'h00 : 8'h06;
*/

 wire	byte0, byte1, byte2, byte3,
		byte4, byte5, byte6, byte7;

 wire	byte01, byte012, byte0123, byte567, byte67;

 assign byte0 = ~byte_num[2] & ~byte_num[1] & ~byte_num[0];
 assign byte1 = ~byte_num[2] & ~byte_num[1] &  byte_num[0];
 assign byte2 = ~byte_num[2] &  byte_num[1] & ~byte_num[0];
 assign byte3 = ~byte_num[2] &  byte_num[1] &  byte_num[0];
 assign byte4 =  byte_num[2] & ~byte_num[1] & ~byte_num[0];
 assign byte5 =  byte_num[2] & ~byte_num[1] &  byte_num[0];
 assign byte6 =  byte_num[2] &  byte_num[1] & ~byte_num[0];
 assign byte7 =  byte_num[2] &  byte_num[1] &  byte_num[0];
 
 assign byte01   = byte0   | byte1;
 assign byte012  = byte01  | byte2;
 assign byte0123 = byte012 | byte3;
 assign byte567  = byte5   | byte67;
 assign byte67   = byte6   | byte7;

 assign out[63:60] = {(4){~byte0}} & in[63:60];
 assign out[59]    = ~byte0 & in[59];
 assign out[58:57] = {(2){byte0}} | in[58:57];
 assign out[56]    = ~byte0 & in[56];
 assign out[55:52] = {(4){~byte01}} & in[55:52];
 assign out[51]    = ~byte01 & in[51];
 assign out[50:49] = {(2){~byte0}} & ({(2){byte1}} | in[50:49]);
 assign out[48]    = ~byte01 & in[48];
 assign out[47:44] = {(4){~byte012}} & in[47:44];
 assign out[43]    = ~byte012 & in[43];
 assign out[42:41] = {(2){~byte01}} & ({(2){byte2}} | in[42:41]);
 assign out[40]    = ~byte012 & in[40];
 assign out[39:36] = {(4){~byte0123}} & in[39:36];
 assign out[35]    = ~byte0123 & in[35];
 assign out[34:33] = {(2){~byte012}} & ({(2){byte3}} | in[34:33]);
 assign out[32]    = ~byte0123 & in[32];
 assign out[31:28] = {(4){byte567}} & in[31:28];
 assign out[27]    = byte567 & in[27];
 assign out[26:25] = {(2){byte4}} | ({(2){byte567}} & in[26:25]);
 assign out[24]    = byte567 & in[24];
 assign out[23:20] = {(4){byte67}} & in[23:20];
 assign out[19]    = byte67 & in[19];
 assign out[18:17] = {(2){byte5}} | ({(2){byte67}} & in[18:17]);
 assign out[16]    = byte67 & in[16];
 assign out[15:12] = {(4){byte7}} & in[15:12];
 assign out[11]    = byte7 & in[11];
 assign out[10:9]  = {(2){byte6}} | ({(2){byte7}} & in[10:9]);
 assign out[8]     = byte7 & in[8];
 assign out[7:3]   = 5'b00000;
 assign out[2:1]   = {(2){byte7}};
 assign out[0]     = 1'b0;

endmodule
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* "iLast" == 0 means byte number is 8, no matter what value "iByte_num" is. */
/* if "iReady" == 0, then "iLast" should be 0. */
/* the user switch to next "iData" only if "ack" == 1. */

module keccak(
	input				iClk,
	input				iRst,
	input		[63:0]	iData,
	input				iReady,
	input				iLast,
	input		[2:0]	iByte_num,
	output				oBuffer_full, /* to "user" module */
	output		[511:0]	oData,
	output	reg			oReady
);

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
 
 reg			state;	/* state == 0: user will send more input data
						 * state == 1: user will not send any data */
 reg	[10:0]	i; /* gen "oReady" */
 
 wire	[575:0]	padder_oData,
				padder_oData_pre; /* before reorder byte */
 wire			padder_oReady;
 
 wire			f_oAck;
 wire	[511:0]	f_oData;
 //wire			f_oReady;
 
 wire	[511:0]	Data_out_pre; /* before reorder byte */
 wire	[63:0]	Data_out_pre_7, Data_out_pre_6, Data_out_pre_5, Data_out_pre_4,
				Data_out_pre_3, Data_out_pre_2, Data_out_pre_1, Data_out_pre_0;
 wire	[63:0]	Data_out_7, Data_out_6, Data_out_5, Data_out_4,
				Data_out_3, Data_out_2, Data_out_1, Data_out_0;

 wire	[63:0]	padder_oData_pre_8, padder_oData_pre_7, padder_oData_pre_6,
				padder_oData_pre_5, padder_oData_pre_4, padder_oData_pre_3,
				padder_oData_pre_2, padder_oData_pre_1, padder_oData_pre_0;
 wire	[63:0]	padder_oData_8, padder_oData_7, padder_oData_6,
				padder_oData_5, padder_oData_4, padder_oData_3,
				padder_oData_2, padder_oData_1, padder_oData_0;
 
/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/
 
 /* reorder byte ~ ~ */
 assign Data_out_pre = f_oData;
 
 assign {Data_out_pre_7, Data_out_pre_6, Data_out_pre_5, Data_out_pre_4,
		 Data_out_pre_3, Data_out_pre_2, Data_out_pre_1, Data_out_pre_0} = Data_out_pre;

 assign Data_out_7 = {Data_out_pre_7[7:0]  , Data_out_pre_7[15:8] , Data_out_pre_7[23:16], Data_out_pre_7[31:24],
					  Data_out_pre_7[39:32], Data_out_pre_7[47:40], Data_out_pre_7[55:48], Data_out_pre_7[63:56]};
 assign Data_out_6 = {Data_out_pre_6[7:0]  , Data_out_pre_6[15:8] , Data_out_pre_6[23:16], Data_out_pre_6[31:24],
					  Data_out_pre_6[39:32], Data_out_pre_6[47:40], Data_out_pre_6[55:48], Data_out_pre_6[63:56]};
 assign Data_out_5 = {Data_out_pre_5[7:0]  , Data_out_pre_5[15:8] , Data_out_pre_5[23:16], Data_out_pre_5[31:24],
					  Data_out_pre_5[39:32], Data_out_pre_5[47:40], Data_out_pre_5[55:48], Data_out_pre_5[63:56]};
 assign Data_out_4 = {Data_out_pre_4[7:0]  , Data_out_pre_4[15:8] , Data_out_pre_4[23:16], Data_out_pre_4[31:24],
					  Data_out_pre_4[39:32], Data_out_pre_4[47:40], Data_out_pre_4[55:48], Data_out_pre_4[63:56]};
 assign Data_out_3 = {Data_out_pre_3[7:0]  , Data_out_pre_3[15:8] , Data_out_pre_3[23:16], Data_out_pre_3[31:24],
					  Data_out_pre_3[39:32], Data_out_pre_3[47:40], Data_out_pre_3[55:48], Data_out_pre_3[63:56]};
 assign Data_out_2 = {Data_out_pre_2[7:0]  , Data_out_pre_2[15:8] , Data_out_pre_2[23:16], Data_out_pre_2[31:24],
					  Data_out_pre_2[39:32], Data_out_pre_2[47:40], Data_out_pre_2[55:48], Data_out_pre_2[63:56]};
 assign Data_out_1 = {Data_out_pre_1[7:0]  , Data_out_pre_1[15:8] , Data_out_pre_1[23:16], Data_out_pre_1[31:24],
					  Data_out_pre_1[39:32], Data_out_pre_1[47:40], Data_out_pre_1[55:48], Data_out_pre_1[63:56]};
 assign Data_out_0 = {Data_out_pre_0[7:0]  , Data_out_pre_0[15:8] , Data_out_pre_0[23:16], Data_out_pre_0[31:24],
					  Data_out_pre_0[39:32], Data_out_pre_0[47:40], Data_out_pre_0[55:48], Data_out_pre_0[63:56]};

 assign oData = {Data_out_7, Data_out_6, Data_out_5, Data_out_4, Data_out_3, Data_out_2, Data_out_1, Data_out_0};

 assign {padder_oData_pre_8, padder_oData_pre_7, padder_oData_pre_6,
		 padder_oData_pre_5, padder_oData_pre_4, padder_oData_pre_3,
		 padder_oData_pre_2, padder_oData_pre_1, padder_oData_pre_0} = padder_oData_pre;
				 
 assign padder_oData_8 = {padder_oData_pre_8[7:0]  , padder_oData_pre_8[15:8] ,
						  padder_oData_pre_8[23:16], padder_oData_pre_8[31:24],
						  padder_oData_pre_8[39:32], padder_oData_pre_8[47:40],
						  padder_oData_pre_8[55:48], padder_oData_pre_8[63:56]};
 assign padder_oData_7 = {padder_oData_pre_7[7:0]  , padder_oData_pre_7[15:8] ,
						  padder_oData_pre_7[23:16], padder_oData_pre_7[31:24],
						  padder_oData_pre_7[39:32], padder_oData_pre_7[47:40],
						  padder_oData_pre_7[55:48], padder_oData_pre_7[63:56]};
 assign padder_oData_6 = {padder_oData_pre_6[7:0]  , padder_oData_pre_6[15:8] ,
						  padder_oData_pre_6[23:16], padder_oData_pre_6[31:24],
						  padder_oData_pre_6[39:32], padder_oData_pre_6[47:40],
						  padder_oData_pre_6[55:48], padder_oData_pre_6[63:56]};
 assign padder_oData_5 = {padder_oData_pre_5[7:0]  , padder_oData_pre_5[15:8] ,
						  padder_oData_pre_5[23:16], padder_oData_pre_5[31:24],
						  padder_oData_pre_5[39:32], padder_oData_pre_5[47:40],
						  padder_oData_pre_5[55:48], padder_oData_pre_5[63:56]};
 assign padder_oData_4 = {padder_oData_pre_4[7:0]  , padder_oData_pre_4[15:8] ,
						  padder_oData_pre_4[23:16], padder_oData_pre_4[31:24],
						  padder_oData_pre_4[39:32], padder_oData_pre_4[47:40],
						  padder_oData_pre_4[55:48], padder_oData_pre_4[63:56]};
 assign padder_oData_3 = {padder_oData_pre_3[7:0]  , padder_oData_pre_3[15:8] ,
						  padder_oData_pre_3[23:16], padder_oData_pre_3[31:24],
						  padder_oData_pre_3[39:32], padder_oData_pre_3[47:40],
						  padder_oData_pre_3[55:48], padder_oData_pre_3[63:56]};
 assign padder_oData_2 = {padder_oData_pre_2[7:0]  , padder_oData_pre_2[15:8] ,
						  padder_oData_pre_2[23:16], padder_oData_pre_2[31:24],
						  padder_oData_pre_2[39:32], padder_oData_pre_2[47:40],
						  padder_oData_pre_2[55:48], padder_oData_pre_2[63:56]};
 assign padder_oData_1 = {padder_oData_pre_1[7:0]  , padder_oData_pre_1[15:8] ,
						  padder_oData_pre_1[23:16], padder_oData_pre_1[31:24],
						  padder_oData_pre_1[39:32], padder_oData_pre_1[47:40],
						  padder_oData_pre_1[55:48], padder_oData_pre_1[63:56]};
 assign padder_oData_0 = {padder_oData_pre_0[7:0]  , padder_oData_pre_0[15:8] ,
						  padder_oData_pre_0[23:16], padder_oData_pre_0[31:24],
						  padder_oData_pre_0[39:32], padder_oData_pre_0[47:40],
						  padder_oData_pre_0[55:48], padder_oData_pre_0[63:56]};
	
 assign padder_oData = {padder_oData_8, padder_oData_7, padder_oData_6,
						padder_oData_5, padder_oData_4, padder_oData_3,
						padder_oData_2, padder_oData_1, padder_oData_0};

/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/
 
 always@(posedge iClk) begin
	if(iRst)	i <= 11'b0;
	else		i <= {i[9:0], state & f_oAck};
 end

 always@(posedge iClk) begin
	if(iRst)		state <= 1'b0;
	else if(iLast)	state <= 1'b1;
	else			state <= state;
 end

 always@(posedge iClk) begin
	if(iRst)		oReady <= 1'b0;
	else if(i[10])	oReady <= 1'b1;
	else			oReady <= oReady;
 end
 
/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
 
 padder padder_ (
	.iClk			(iClk),
	.iRst			(iRst),
	.iData			(iData),
	.iReady			(iReady),
	.iLast			(iLast),
	.iByte_num		(iByte_num),
	.oBuffer_full	(oBuffer_full),
	.oData			(padder_oData_pre),
	.oReady			(padder_oReady),
	.iF_ack			(f_oAck)
 );

 f_permutation f_permutation_ (
	.iClk		(iClk),
	.iRst		(iRst),
	.iData		(padder_oData),
	.iReady		(padder_oReady),
	.oAck		(f_oAck),
	.oData		(f_oData)
	//.oReady	(f_oReady)
 );

endmodule
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* "iLast" == 0 means byte number is 8, no matter what value "iByte_num" is. */
/* if "iReady" == 0, then "iLast" should be 0. */
/* the user switch to next "iData" only if "ack" == 1. */

module padder(
    input				iClk,
	input				iRst,
    input		[63:0]	iData,
    input				iReady,
	input				iLast,
    input		[2:0]   iByte_num,
    output				oBuffer_full,	/* to "user" module */
    output	reg	[575:0]	oData,			/* to "f_permutation" module */
    output				oReady,		/* to "f_permutation" module */
    input				iF_ack			/* from "f_permutation" module */
);

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
 
 reg			state;		/* state == 0: user will send more input data
							 * state == 1: user will not send any data */
 reg			done;		/* == 1: oReady should be 0 */
 reg	[8:0]	i;			/* length of "oData" buffer */
 wire	[63:0]	v0;			/* output of module "padder1" */
 wire	[63:0]	v1;			/* to be shifted into register "oData" */
 //wire			accept;		/* accept user input? */
 wire			update;

/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/
 
 assign oBuffer_full = i[8];
 assign oReady = oBuffer_full;
 
 // if state == 1, do not eat input
 //assign accept = ~state & iReady & ~oBuffer_full;
 // don't fill buffer if done
 assign update = (iReady|state) & ~(oBuffer_full|done);
 
// assign v1 = (state) ? {56'b0, i[7], 7'b0} :
//			 (~iLast) ? iData : {v0[63:8], v0[7]|i[7], v0[6:0]};
 assign v1[63:8] = {(56){~state}} & ((~iLast) ? iData[63:8] : v0[63:8]);
 assign v1[7] = (state) ? i[7] : ((~iLast) ? iData[7] : (v0[7]|i[7]));
 assign v1[6:0] = {(7){~state}} & ((~iLast) ? iData[6:0] : v0[6:0]);
			 
/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/
 
 always@(posedge iClk) begin
	if(update)	oData <= {oData[511:0], v1};
	else		oData <= oData;
 end
 
 // if (iF_ack)  i <= 0;
 // if (update) i <= {i[7:0], 1'b1};	/* increase length */
 always@(posedge iClk) begin
	if(iRst)				i <= 9'b0;
	else if(iF_ack|update)	i <= {i[7:0], 1'b1} & {9{~iF_ack}};
	else					i <= i;
 end
 
 always@(posedge iClk) begin
	if(iRst)		state <= 1'b0;
	else if(iLast)	state <= 1'b1;
	else			state <= state;
 end
 
 always@(posedge iClk) begin
	if(iRst)				done <= 1'b0;
	else if(state&oReady)	done <= 1'b1;
	else					done <= done;
 end
 
/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
 
 padder1 p0 (
	.in			(iData),
	.byte_num	(iByte_num),
	.out		(v0)
 );
 
endmodule
/*
 * Copyright 2013, Homer Hsing <homer.hsing@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* round constant (2 in 1 ~ ~) */
module rconst2in1(
	input	[11:0]	i,
	output	[6:0]	rc1,
	output	[6:0]	rc2
);
/*
 always@(i) begin
	rc1 = 0;
	rc1[0] = i[0] | i[2] | i[3] | i[5] | i[6] | i[7] | i[10] | i[11];
	rc1[1] = i[1] | i[2] | i[4] | i[6] | i[8] | i[9];
	rc1[2] = i[1] | i[2] | i[4] | i[5] | i[6] | i[7] | i[9];
	rc1[3] = i[1] | i[2] | i[3] | i[4] | i[6] | i[7] | i[10];
	rc1[4] = i[1] | i[2] | i[3] | i[5] | i[6] | i[7] | i[8] | i[9] | i[10];
	rc1[5] = i[3] | i[5] | i[6] | i[10] | i[11];
	rc1[6] = i[1] | i[3] | i[7] | i[8] | i[10];
 end

 always@(i) begin
	rc2 = 0;
	rc2[0] = i[2] | i[3] | i[6] | i[7];
	rc2[1] = i[0] | i[5] | i[6] | i[7] | i[9];
	rc2[2] = i[3] | i[4] | i[5] | i[6] | i[9] | i[11];
	rc2[3] = i[0] | i[4] | i[6] | i[8] | i[10];
	rc2[4] = i[0] | i[1] | i[3] | i[7] | i[10] | i[11];
	rc2[5] = i[1] | i[2] | i[5] | i[9] | i[11];
	rc2[6] = i[1] | i[3] | i[6] | i[7] | i[8] | i[9] | i[10] | i[11];
 end
*/

 assign rc1[6] = i[1] | i[3] | i[7] | i[8] | i[10];
 assign rc1[5] = i[3] | i[5] | i[6] | i[10] | i[11];
 assign rc1[4] = i[1] | i[2] | i[3] | i[5] | i[6] | i[7] | i[8] | i[9] | i[10];
 assign rc1[3] = i[1] | i[2] | i[3] | i[4] | i[6] | i[7] | i[10];
 assign rc1[2] = i[1] | i[2] | i[4] | i[5] | i[6] | i[7] | i[9];
 assign rc1[1] = i[1] | i[2] | i[4] | i[6] | i[8] | i[9];
 assign rc1[0] = i[0] | i[2] | i[3] | i[5] | i[6] | i[7] | i[10] | i[11];
 
 assign rc2[6] = i[1] | i[3] | i[6] | i[7] | i[8] | i[9] | i[10] | i[11];
 assign rc2[5] = i[1] | i[2] | i[5] | i[9] | i[11];
 assign rc2[4] = i[0] | i[1] | i[3] | i[7] | i[10] | i[11];
 assign rc2[3] = i[0] | i[4] | i[6] | i[8] | i[10];
 assign rc2[2] = i[3] | i[4] | i[5] | i[6] | i[9] | i[11];
 assign rc2[1] = i[0] | i[5] | i[6] | i[7] | i[9];
 assign rc2[0] = i[2] | i[3] | i[6] | i[7];
 
endmodule
module SHA3_TOP (
	input			ICLK,
	input			IRST,
	input	[63:0]	IDATA,
	input			IREADY,
	input			ILAST,
	input	[2:0]	IBYTE_NUM,
	output			OBUFFER_FULL,
	output	[511:0]	ODATA,
	output			OREADY
);

keccak uut (
	.iClk			(ICLK),
	.iRst			(IRST),
	.iData			(IDATA),
	.iReady			(IREADY),
	.iLast			(ILAST),
	.iByte_num		(IBYTE_NUM),
	.oBuffer_full	(OBUFFER_FULL),
	.oData			(ODATA),
	.oReady			(OREADY)
);

endmodule
module SHA3_TOP_wrapper (
	input			clk,
	input			reset,
	input	[63:0]	in,
	input			in_ready,
	input			is_last,
	input	[2:0]	byte_num,
	output			buffer_full,
	output	[511:0]	out,
	output			out_ready
);

SHA3_TOP U1_TOP (
	.ICLK			(clk),
	.IRST			(reset),
	.IDATA			(in),
	.IREADY			(in_ready),
	.ILAST			(is_last),
	.IBYTE_NUM		(byte_num),
	.OBUFFER_FULL	(buffer_full),
	.ODATA			(out),
	.OREADY			(out_ready)
);

endmodule
`undef WT_DCACHE
`undef DISABLE_TRACER
`undef SRAM_NO_INIT
`undef VERILATOR

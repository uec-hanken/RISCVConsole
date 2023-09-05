/* See the file LICENSE for further information */

#include "encoding.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include "src/main.h"
#include <uart/uart.h>
#include <stdio.h>
#include <platform.h>
#include <barrier.h>
#include <stdatomic.h>
#include <devices/gpio.h>
//#include <spi/spi.h>
//#include <boot/boot.h>
//#include <gpt/gpt.h>
#include <plic/plic_driver.h>
//#include "usb/usbtest.h"
#include "clkutils.h"
#include "common.h"

//#define DEBUG_RSA 1

void hwRSA_init(void* rsactrl){
  _REG32((char*)rsactrl, RSA_REG_I_START) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_RST_CORE_N) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_I_WRM) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_I_WRE) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_I_WRN) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_READY) =  0x0;
  _REG32((char*)rsactrl, RSA_REG_RST_CORE_N) =  0x1;
}

void hwRSA_results(void* rsactrl){
  uart_put_hex((void*)uart_reg, _REG32((char*)rsactrl, RSA_REG_DATA_0));
  uart_put_hex((void*)uart_reg, _REG32((char*)rsactrl, RSA_REG_DATA_1));
}


void hwRSA_M_write(void* rsactrl, uint32_t M0, uint32_t M1 ){
  _REG32((char*)rsactrl, RSA_REG_I_M0)  =  M1;
  _REG32((char*)rsactrl, RSA_REG_I_M1)  =  M0;
  _REG32((char*)rsactrl, RSA_REG_I_WRM) =  0x1;
  _REG32((char*)rsactrl, RSA_REG_I_WRM) =  0x0;
}



void hwRSA_E_write(void* rsactrl, uint32_t E0, uint32_t E1 ){
  _REG32((char*)rsactrl, RSA_REG_I_E0)  =  E1;
  _REG32((char*)rsactrl, RSA_REG_I_E1)  =  E0;
  _REG32((char*)rsactrl, RSA_REG_I_WRE) =  0x1;
  _REG32((char*)rsactrl, RSA_REG_I_WRE) =  0x0;
}

void hwRSA_N_write(void* rsactrl, uint32_t N0, uint32_t N1 ){
  _REG32((char*)rsactrl, RSA_REG_I_N0)  =  N1;
  _REG32((char*)rsactrl, RSA_REG_I_N1)  =  N0;
  _REG32((char*)rsactrl, RSA_REG_I_WRN) =  0x1;
  _REG32((char*)rsactrl, RSA_REG_I_WRN) =  0x0;
}





uint64_t hw_rsa_selftest(void* rsactrl, uint64_t wait){
  uint64_t start_mcycle;
  uint64_t delta_mcycle;
  start_mcycle = clkutils_read_mtime();
 
 
   uint32_t n [32]= {0xd0b750c8,0x554b64c7,
                     0xa9d34d06,0x8e020fb5,
                     0x2fea1b39,0xc47971a3,
                     0x59f0eec5,0xda0437ea,
                     0x3fc94597,0xd8dbff54,
                     0x44f6ce5a,0x3293ac89,
                     0xb1eebb3f,0x712b3ad6,
                     0xa06386e6,0x401985e1,
                     0x9898715b,0x1ea32ac0,
                     0x3456fe17,0x96d31ed4,
                     0xaf389f4f,0x675c23c4,
                     0x21a12549,0x1e740fda,
                     0xc4322ec2,0xd46ec945,
                     0xddc34922,0x7b492191,
                     0xc9049145,0xfb2f8c29,
                     0x98c486a8,0x40eac4d3};
   
   uint32_t m [32]= {0x6cf87c6a,0x65925df6,
                     0x719eef5f,0x1262edc6,
                     0xf8a0a0a0,0xd21c535c,
                     0x64580745,0xd9a268a9,
                     0x5b50ff3b,0xe24ba8b6,
                     0x49ca47c3,0xa760b71d,
                     0xdc3903f3,0x6aa1d98e,
                     0x87c53b33,0x70be784b,
                     0xffcb5bc1,0x80dea2ac,
                     0xc15bb12e,0x681c889b,
                     0x89b8f3de,0x78050019,
                     0xdcdbb68c,0x051b04b8,
                     0x80f0f8c4,0xe855321f,
                     0xfed89767,0xfc9d4a8a,
                     0x27a5d82b,0xa450b247,
                     0x8c21e118,0x43c2f539};
 
   uint32_t e [32]= {0x27b7119a,0x09edb827,
                     0xc13418c8,0x20b522a1,
                     0xee08de0e,0x4bb28106,
                     0xdb6bb914,0x98a3b361,
                     0xab293af8,0x3fefcdd8,
                     0xa6bd2134,0xca4afacf,
                     0x64a0e33c,0x014f48f4,
                     0x7530f884,0x7cc9185c,
                     0xbedec0d9,0x238c8f1d,
                     0x5498f71c,0x7c0cff48,
                     0xdc213421,0x742e3435,
                     0x0ca94007,0x753cc0e5,
                     0xa783264c,0xf49ff644,
                     0xffea9425,0x3cfe8685,
                     0x9acd2a22,0x76ca4e72,
                     0x15f8ebaa,0x2f188f51};
 
 
 
 // Test nist
 /*
 
 
  uint32_t n [32]= {0x98c486a8,0x40eac4d3,
                    0xc9049145,0xfb2f8c29,
                    0xddc34922,0x7b492191,
                    0xc4322ec2,0xd46ec945,
		                0x21a12549,0x1e740fda,
		                0xaf389f4f,0x675c23c4,
		                0x3456fe17,0x96d31ed4,
		                0x9898715b,0x1ea32ac0,
		                0xa06386e6,0x401985e1,
		                0xb1eebb3f,0x712b3ad6,
		                0x44f6ce5a,0x3293ac89,
		                0x3fc94597,0xd8dbff54,
		                0x59f0eec5,0xda0437ea,
		                0x2fea1b39,0xc47971a3,
		                0xa9d34d06,0x8e020fb5,
		                0xd0b750c8,0x554b64c7}; 
		                
		                
  uint32_t m [32]= {0x8c21e118,0x43c2f539,
                    0x27a5d82b,0xa450b247,
                    0xfed89767,0xfc9d4a8a,
                    0x80f0f8c4,0xe855321f,
		                0xdcdbb68c,0x051b04b8,
		                0x89b8f3de,0x78050019,
		                0xc15bb12e,0x681c889b,
		                0xffcb5bc1,0x80dea2ac,
		                0x87c53b33,0x70be784b,
		                0xdc3903f3,0x6aa1d98e,
		                0x49ca47c3,0xa760b71d,
		                0x5b50ff3b,0xe24ba8b6,
		                0x64580745,0xd9a268a9,
		                0xf8a0a0a0,0xd21c535c,
		                0x719eef5f,0x1262edc6,
		                0x6cf87c6a,0x65925df6};
		
		
  uint32_t e [32]= {0x15f8ebaa,0x2f188f51,
                    0x9acd2a22,0x76ca4e72,
                    0xffea9425,0x3cfe8685,
                    0xa783264c,0xf49ff644,
		                0x0ca94007,0x753cc0e5,
		                0xdc213421,0x742e3435,
		                0x5498f71c,0x7c0cff48,
		                0xbedec0d9,0x238c8f1d,
		                0x7530f884,0x7cc9185c,
		                0x64a0e33c,0x014f48f4,
		                0xa6bd2134,0xca4afacf,
		                0xab293af8,0x3fefcdd8,
	        	        0xdb6bb914,0x98a3b361,
	        	        0xee08de0e,0x4bb28106,
	        	        0xc13418c8,0x20b522a1,
	        	        0x27b7119a,0x09edb827};
	
	*/
	
	
	 /* test_thuc
	 
	  uint32_t m [32]= { 0x0008df66,0x8ac99f93,
                    0xab900fd3,0xba636a00,
                    0xcc747142,0xe129d188,
                    0x480440ed,0xa318bc06,
		                0x97b0b689,0x745d228b,
		                0xe9ddf1cf,0x1292ad6d,
		                0xa790c118,0x8845a8f2,
		                0x0d54b11b,0xa993e3fa,
		                0xb7bb70c1,0x36e28d98,
		                0x0e5548f1,0x4b445598,
		                0x1307cf6a,0xa392cd25,
		                0x9d238678,0x8aa63621,
		                0x6c4b39f9,0x1d715ba7,
		                0xebdb674c,0x2e116652,
		                0x2727ea03,0x39834b5b,
		                0xadc75262,0x7a7e74d2};
	 
	 		    uint32_t n [32]= { 0x00154424,0xe24caec8,
                    0x52757174,0x5f1da82e,
                    0x25b3aa4d,0xc32ded41,
                    0xef068a9b,0x5c66b5f4,
		                0xe7ae797b,0x6417505e,
		                0x60f312c4,0x20f98972,
		                0x6cae1ab5,0xa20d5d41,
		                0x3d4fcdf2,0xb3df3fa0,
		                0x60722812,0xd635ad3a,
		                0x72aa003b,0x957c85f6,
		                0x3b39ae11,0xdbee6116,
		                0xb36748f6,0x866d0932,
		                0x017c218e,0x7665b4ca,
		                0xc76c5914,0xca477aca,
		                0x167c890e,0x2cb4d4d9,
		                0xa8e17992,0x7d44ea71}; 
	 
	 
	 
	 
	 uint32_t e [32]= { 0x000016ad,0x1c9b2a8f,
                    0x40a22351,0x52d54b16,
                    0x62e578f2,0x54223574,
                    0x0325649a,0x504f3a20,
		                0x6d8a2375,0x00c716b1,
		                0x16316860,0x4c117a09,
		                0x67cb51b0,0x6e8a06c5,
		                0x3d727b41,0x44651fe2,
		                0x43cd18c1,0x10e20bb3,
		                0x3d66443d,0x5ecd3901,
		                0x66496ceb,0x56393283,
		                0x72e01238,0x237c0c7f,
		                0x660c3713,0x4b6b58c0,
		                0x3a87397b,0x08d96cba,
		                0x1b787a45,0x0f4c05fa,
		                0x28550131,0x4f0118d3};*/
		                
		              
		              
		                
  uint32_t result [32];
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nRSA init");
  #endif
  hwRSA_init(rsactrl);
  
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nwrite m");
  #endif
  for (int i = 0; i < 32; i=i+2) {
    hwRSA_M_write(rsactrl, m[31-i],m[31-i-1]);
  }
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nwrite e");
  #endif
  for (int i = 0; i < 32; i=i+2) {
    hwRSA_E_write(rsactrl, e[31-i],e[31-i-1]);  
  }

  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nwrite n");
  #endif
  for (int i = 0; i < 32; i=i+2) {
    hwRSA_N_write(rsactrl, n[31-i],n[31-i-1]);
  }
  
  //Enable process
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nenable process");
  #endif
  _REG32((char*)rsactrl, RSA_REG_I_START) =  0x1;
  _REG32((char*)rsactrl, RSA_REG_I_START) =  0x0;
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nstart ready");
  #endif
  //uint32_t counter = 0;
  while(1){
    if(_REG32((char*)rsactrl, RSA_REG_READY) == 1){
      #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nwaiting rsa response");
      #endif
      break;
    }
    if((clkutils_read_mtime() - start_mcycle) > wait) {
      uart_puts((void*)uart_reg, "\r\nbreak at wait time");
      return;
    }
    
    //else{counter++;}
    /*if(counter > 100000){
      uart_puts((void*)uart_reg, "\r\nbreak at 10000");
      counter = 0;
      for (int ii = 0; ii < 32; ii=ii+2) {
        _REG32((char*)rsactrl, RSA_REG_I_RDR) =  0x1;  
        result[31-ii] = _REG32((char*)rsactrl, RSA_REG_DATA_0);
        result[31-ii-1] = _REG32((char*)rsactrl, RSA_REG_DATA_1);
      }
      _REG32((char*)rsactrl, RSA_REG_I_RDR) =  0x1;

      for(int i = 0; i < 32; i++){
    if (counter ==4){
      uart_puts((void*)uart_reg,"\n");
      counter = 1;    
    }
    else { 
    counter=counter+1;}
    uart_put_hex((void*)uart_reg, result[i]);
    } 
    counter=0;
    }*/
  }
  #ifdef DEBUG_RSA
      uart_puts((void*)uart_reg, "\r\nprinting result");
  #endif

  // Read result
  for (int ii = 0; ii < 32; ii=ii+2) {
    _REG32((char*)rsactrl, RSA_REG_I_RDR) =  0x1;  
    result[31-ii] = _REG32((char*)rsactrl, RSA_REG_DATA_0);
    result[31-ii-1] = _REG32((char*)rsactrl, RSA_REG_DATA_1);
  }
    _REG32((char*)rsactrl, RSA_REG_I_RDR) =  0x1; 

  
  delta_mcycle = clkutils_read_mtime() - start_mcycle;

  int count=0;
  for(int i = 0; i < 32; i++){
    if (count ==4){
      uart_puts((void*)uart_reg,"\r\n");
      count = 1;    
    }
    else { 
    count=count+1;}
    uart_put_hex((void*)uart_reg, result[i]);
    }     

  uart_puts((void*)uart_reg,"\r\n");
  uart_puts((void*)uart_reg, "\r\nTime: ");
  print_meas(delta_mcycle);
  uart_puts((void*)uart_reg, "\n");
  
  return delta_mcycle;
}



uint64_t sw_rsa_selftest(void* rsactrl){
  uint64_t start_mcycle;
  uint64_t delta_mcycle;
  start_mcycle = clkutils_read_mtime();
  
  uint64_t n [16]= {0x98c486a840eac4d3,0xc9049145fb2f8c29,0xddc349227b492191,0xc4322ec2d46ec945,
		                0x21a125491e740fda,0xaf389f4f675c23c4,0x3456fe1796d31ed4,0x9898715b1ea32ac0,
		                0xa06386e6401985e1,0xb1eebb3f712b3ad6,0x44f6ce5a3293ac89,0x3fc94597d8dbff54,
		                0x59f0eec5da0437ea,0x2fea1b39c47971a3,0xa9d34d068e020fb5,0xd0b750c8554b64c7};

  uint64_t c [16]= {0x8c21e11843c2f539,0x27a5d82ba450b247,0xfed89767fc9d4a8a,0x80f0f8c4e855321f,
		                0xdcdbb68c051b04b8,0x89b8f3de78050019,0xc15bb12e681c889b,0xffcb5bc180dea2ac,
		                0x87c53b3370be784b,0xdc3903f36aa1d98e,0x49ca47c3a760b71d,0x5b50ff3be24ba8b6,
		                0x64580745d9a268a9,0xf8a0a0a0d21c535c,0x719eef5f1262edc6,0x6cf87c6a65925df6};
		

  uint64_t d [16]= {0x15f8ebaa2f188f51,0x9acd2a2276ca4e72,0xffea94253cfe8685,0xa783264cf49ff644,
		                0x0ca94007753cc0e5,0xdc213421742e3435,0x5498f71c7c0cff48,0xbedec0d9238c8f1d,
		                0x7530f8847cc9185c,0x64a0e33c014f48f4,0xa6bd2134ca4afacf,0xab293af83fefcdd8,
	        	        0xdb6bb91498a3b361,0xee08de0e4bb28106,0xc13418c820b522a1,0x27b7119a09edb827};
	        	           	        
  uint64_t R[16];
  
  rsa1024(R,c,d,n);	
  
  delta_mcycle = clkutils_read_mtime() - start_mcycle;
   
  int count=0;
  for(int i = 0; i < 16; i++){
    if (count ==2){
      uart_puts((void*)uart_reg,"\r\n");
      count = 1;    
    }
    else { 
    count=count+1;}
    uart_put_hex64((void*)uart_reg, R[15-i]);
    }        	        
  
  uart_puts((void*)uart_reg,"\r\n");
  uart_puts((void*)uart_reg, "\r\nTime: ");
  print_meas(delta_mcycle);
  uart_puts((void*)uart_reg, "\n");
  
  return delta_mcycle;
}
























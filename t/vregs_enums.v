// $Revision: 1.5 $$Date: 2005/01/12 21:35:09 $$Author: wsnyder $ -*- Verilog -*-
//====================================================================
// DESCRIPTION: Manual test case showing use of AUTOASCII
//
// Copyright 2001-2005 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.
//====================================================================

`include "vregs_spec_defs.v"

module vregs_enums (/*AUTOARG*/);

`include "vregs_spec_param.v"
   
   reg [3:0] 	  	// synopsys enum En_ExEnum
     m_exenum_r;

   /*AUTOASCIIENUM("m_exenum_r", "m_exenum_r_ascii", "EP_ExEnum_")*/
   // Beginning of automatic ASCII enum decoding
   reg [63:0]		m_exenum_r_ascii;	// Decode of m_exenum_r
   always @(m_exenum_r) begin
      case ({m_exenum_r})
	EP_ExEnum_ONE:      m_exenum_r_ascii = "one     ";
	EP_ExEnum_TWO:      m_exenum_r_ascii = "two     ";
	EP_ExEnum_FIVE:     m_exenum_r_ascii = "five    ";
	EP_ExEnum_FOURTEEN: m_exenum_r_ascii = "fourteen";
	default:            m_exenum_r_ascii = "%Error  ";
      endcase
   end
   // End of automatics

   // ****************************************************************

   // surefire lint_off STMINI

   initial begin
      m_exenum_r = EP_ExEnum_FIVE;
      $write("State = %x = %s\n", m_exenum_r, m_exenum_r_ascii);
   end

endmodule

// Local Variables:
// verilog-auto-sense-defines-constant: t
// verilog-library-directories:("." "../test_dir")
// eval:(verilog-read-defines)
// eval:(verilog-read-includes)
// compile-command: "vlint --brief +incdir+../test_dir vregs_enums.v"
// End:

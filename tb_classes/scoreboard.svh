/******************************************************/
// Title 		: stimulus_values.svh
// Project Name : SDRAM Controller with wishbone Validation
// Author		: Karthik Rudraraju
//				  Manasa Gurrala
//				  Naveen Yalla
// Description	: It contains the checker which checkes the obtained output with the expected
//				  output. It uses queues for its fuctionality. 
/******************************************************/
class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)

  uvm_analysis_export #(sdr_seq_item) analysis_export;
  logic [31:0] data_assoc[int];

  function new (string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction : new

  function bit is_valid_addr(logic [31:0] addr);
    return !$isunknown(addr);
  endfunction

  function void write(sdr_seq_item tr);
    if (!is_valid_addr(tr.addr)) begin
      `uvm_warning("SB_ADDR", $sformatf("Address is X/Z, skip at time %0t", $time))
      return;
    end
    case (tr.cmd)
      sdr_seq_item::SDR_WRITE: begin
        if (tr.data_q.size() > 0) begin
          data_assoc[tr.addr] = tr.data_q[0];
        end else begin
          data_assoc[tr.addr] = '0;
        end
      end
      sdr_seq_item::SDR_READ: begin
        if (data_assoc.exists(tr.addr)) begin
          logic [31:0] exp = data_assoc[tr.addr];
          if (tr.data_q.size() > 0 && tr.data_q[0] !== exp) begin
            `uvm_error("SB_MISMATCH", $sformatf("Read mismatch addr=%h exp=%h got=%h time=%0t",
                                               tr.addr, exp, tr.data_q[0], $time))
          end
        end else begin
          `uvm_warning("SB_UNINIT", $sformatf("Read before write at addr=%h time=%0t", tr.addr, $time))
        end
      end
    endcase
  endfunction
endclass : scoreboard

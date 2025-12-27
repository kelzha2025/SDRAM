// UVM sequence item for SDRAM transactions
class sdr_seq_item extends uvm_sequence_item;
  `uvm_object_utils(sdr_seq_item)

  typedef enum {SDR_WRITE, SDR_READ} sdr_cmd_e;

  rand logic [31:0] addr;
  rand logic [7:0]  burst_len;
  rand sdr_cmd_e    cmd;
  rand logic [31:0] data_q[$]; // write data payloads, empty for reads

  constraint c_burst_len { burst_len inside {[1:255]}; }

  function new(string name = "sdr_seq_item");
    super.new(name);
  endfunction

  function void post_randomize();
    if (cmd == SDR_WRITE) begin
      data_q.delete();
      foreach (data_q[i]) begin end // keep linter quiet
      for (int i = 0; i < burst_len; i++) begin
        data_q.push_back($urandom());
      end
    end else begin
      data_q.delete();
    end
  endfunction
endclass

// UVM sequence generating random SDRAM transactions
class sdr_sequence extends uvm_sequence #(sdr_seq_item);
  `uvm_object_utils(sdr_sequence)

  rand int unsigned num_transactions = 50;

  function new(string name = "sdr_sequence");
    super.new(name);
  endfunction

  task body();
    sdr_seq_item req;
    for (int i = 0; i < num_transactions; i++) begin
      req = sdr_seq_item::type_id::create($sformatf("req_%0d", i));
      assert(req.randomize() with {
        cmd dist { SDR_WRITE := 50, SDR_READ := 50 };
        addr == $urandom_range(0, 32'hFFFF_FFFF);
        burst_len == $urandom_range(1, 8'hFF);
      });
      start_item(req);
      finish_item(req);
    end
  endtask
endclass

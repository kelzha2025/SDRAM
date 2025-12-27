// UVM monitor: samples transactions from the BFM interface
class sdr_monitor extends uvm_component;
  `uvm_component_utils(sdr_monitor)

  virtual sdrctrlinterface_bfm bfm;
  uvm_analysis_port #(sdr_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual sdrctrlinterface_bfm)::get(this, "", "bfm", bfm)) begin
      `uvm_fatal("NOVIF", "BFM interface not set for sdr_monitor")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge bfm.sys_clk);
      if (bfm.wb_stb_i && bfm.wb_cyc_i) begin
        sdr_seq_item tr = sdr_seq_item::type_id::create("mon_tr");
        tr.addr = bfm.wb_addr_i;
        if (bfm.wb_we_i === 1'b1) begin
          tr.cmd  = sdr_seq_item::SDR_WRITE;
          tr.burst_len = 1;
          tr.data_q.delete();
          tr.data_q.push_back(bfm.wb_dat_i);
        end else if (bfm.wb_we_i === 1'b0) begin
          tr.cmd  = sdr_seq_item::SDR_READ;
          tr.burst_len = 1;
          tr.data_q.delete();
          tr.data_q.push_back(bfm.wb_dat_o);
        end
        ap.write(tr);
      end
    end
  endtask
endclass

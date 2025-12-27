// UVM agent bundling sequencer/driver/monitor
class sdr_agent extends uvm_agent;
  `uvm_component_utils(sdr_agent)

  sdr_sequencer seqr_h;
  sdr_driver    drv_h;
  sdr_monitor   mon_h;

  uvm_analysis_port #(sdr_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    seqr_h = sdr_sequencer::type_id::create("seqr_h", this);
    drv_h  = sdr_driver   ::type_id::create("drv_h" , this);
    mon_h  = sdr_monitor  ::type_id::create("mon_h" , this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv_h.seq_item_port.connect(seqr_h.seq_item_export);
    mon_h.ap.connect(ap);
  endfunction
endclass

// Adapter to feed existing coverage class from monitor transactions
class cov_adapter extends uvm_component;
  `uvm_component_utils(cov_adapter)

  coverage cov_h;
  uvm_analysis_export #(sdr_seq_item) analysis_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    cov_h = coverage::type_id::create("cov_h", this);
  endfunction

  function void write(sdr_seq_item tr);
    // For now, no direct sampling; existing coverage samples via interface
    // Placeholder to keep connectivity; extend if transactional coverage is needed
  endfunction
endclass

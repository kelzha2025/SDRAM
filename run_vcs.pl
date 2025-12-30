#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Cwd qw(getcwd);

$ENV{SYNOPSYS_SIM_SETUP} = getcwd() . "/synopsys_sim.setup";
print "SYNOPSYS_SIM_SETUP=$ENV{SYNOPSYS_SIM_SETUP}\n";

# VCS + Verdi runner for the UVM version of SDRAM verification
# Usage examples:
#   perl run_vcs.pl                # compile + run, UVM 1.2, no FSDB
#   perl run_vcs.pl --fsdb         # compile + run, generate FSDB
#   perl run_vcs.pl --gui          # compile + run, enable UVM debug (kdb/trace: hier+seq) and launch Verdi GUI
#   perl run_vcs.pl --clean        # remove previous build artifacts
# Options can be combined; --dry-run prints commands without executing.
# Manual Verdi launch example (if GUI did not auto-open):
#   verdi -kdb -dbdir simv.daidir -ssf sdram_uvm.fsdb -ssv my_top.sv package.sv -f dut.f -f tb.f &

my $fsdb       = 0;
my $clean      = 0;
my $dry_run    = 0;
my $uvm_test   = 'test';
my $gui_flag   = 0;
my $vcs_home   = $ENV{VCS_HOME}   || '/home/synopsys/vcs/O-2018.09-SP2';
my $verdi_home = $ENV{VERDI_HOME} || '/home/synopsys/verdi/Verdi_O-2018.09-SP2';

GetOptions(
    'fsdb!'      => \$fsdb,
    'clean!'     => \$clean,
    'dry-run!'   => \$dry_run,
    'uvm-test=s' => \$uvm_test,
    'gui!'       => \$gui_flag,
) or die "Error in command line arguments\n";

my $vlogan_bin   = "$vcs_home/bin/vlogan";
my $vcs_bin   = "$vcs_home/bin/vcs";
my $verdi_bin = "$verdi_home/bin/verdi";
my $simv      = './simv';
my $comp_ana1_log  = 'comp_ana1.log';
my $comp_ana2_log  = 'comp_ana2.log';
my $comp_log  = 'comp.log';
my $comp_elab_log  = 'comp_elab.log';
my $sim_log   = 'sim.log';
my $fsdb_def  = $fsdb ? '+define+FSDB' : '';
my $fsdb_file = 'test.fsdb';
my @uvm_verdi_trace = (
    '+UVM_VERDI_ENABLE=1',
    '+UVM_VERDI_TRACE=ALL',
    '+UVM_VERDI_TRACE=HIER',  # hierarchy/TLM info
    '+UVM_TR_RECORD'          # sequence history
);

my @clean_list = (
    'csrc', 'simv', 'simv.daidir', 'ucli.key', 'vcs.key', 'vc_hdrs.h', 'novas.conf','verdiLog', 
    'sim.log', 'comp.log','*.fsdb', 'DVEfiles', 'novas.rc', 'urgReport','novas_dump.log', 'simv.vdb',
);

if ($clean) {
    for my $path (@clean_list) {
        run_cmd("rm -rf $path");
    }
    exit 0;
}
my @vlogan1_cmd = (
    $vlogan_bin,
    '-full64',
    '-sverilog',
    '-ntb_opts', 'uvm-1.2',
    '-work', 'work',
    '-l', $comp_ana1_log,
);
my @vlogan2_cmd = (
    $vlogan_bin,
    '-full64',
    '-sverilog',
    '-ntb_opts', 'uvm-1.2',
    '-f', 'dut.f',
    '-f', 'tb.f',
    ($gui_flag ? '-kdb' : ()),
    ($fsdb_def ? $fsdb_def : ()),
    '-l', $comp_ana2_log,
    '-work', 'work',
);
my @vcs_cmd = (
    $vcs_bin,
    '-full64',
    '-sverilog',
    '-timescale=1ns/1ps',
    '-ntb_opts', 'uvm-1.2',
    '-top', 'my_top',
    '-debug_access+all',
    ($gui_flag ? '-kdb' : ()),
    '-P', "$verdi_home/share/PLI/VCS/LINUX64/novas.tab",
          "$verdi_home/share/PLI/VCS/LINUX64/pli.a",
    '-l', $comp_elab_log,
    'work.my_top',
);


# 2 stage compile
#my @vcs_cmd = (
#    $vcs_bin,
#    '-full64',
#    '-sverilog',
#    '-timescale=1ns/1ps',
#    '-ntb_opts', 'uvm-1.2',
#    '-f', 'dut.f',
#    '-f', 'tb.f',
#    '-top', 'my_top',
#    '-debug_access+all',
#    ($gui_flag ? '-kdb' : ()),
#    '-P', "$verdi_home/share/PLI/VCS/LINUX64/novas.tab",
#          "$verdi_home/share/PLI/VCS/LINUX64/pli.a",
#    ($fsdb_def ? $fsdb_def : ()),
#    '-l', $comp_log,
#);

my @sim_cmd = (
    $simv,
    '+UVM_TESTNAME=' . $uvm_test,
    ($gui_flag ? @uvm_verdi_trace : ()),
    '-l', $sim_log,
    #'+fsdbfile+test.fsdb',
);

run_cmd(join(' ', @vlogan1_cmd));
run_cmd(join(' ', @vlogan2_cmd));
run_cmd(join(' ', @vcs_cmd));
run_cmd(join(' ', @sim_cmd));

if ($gui_flag) {
    # Verdi UVM debug: use KDB (simv.daidir) and optionally FSDB
    if (!-e $fsdb_file) {
        print "Warning: FSDB file $fsdb_file not found. Verdi will start without waveform.\n";
    }
    my @verdi_cmd = (
        $verdi_bin,
        '-uvmDebug',
        '-kdb',
        '-ntb_opts', 'uvm-1.2',
        '-dbdir', 'simv.daidir',
        ($fsdb_file && -e $fsdb_file ? ('-ssf', $fsdb_file) : ()),
        '-ssv', 'my_top.sv', 'package.sv',
        '-f', 'dut.f', '-f', 'tb.f',
    );
    run_cmd(join(' ', @verdi_cmd) . ' &');
}

exit 0;

sub run_cmd {
    my ($cmd) = @_;
    if ($dry_run) {
        print "[DRY-RUN] $cmd\n";
        return;
    }
    print "$cmd\n";
    system($cmd) == 0 or die "Command failed: $cmd\n";
}

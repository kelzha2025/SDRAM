#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;

# VCS + Verdi runner for the UVM version of SDRAM verification
#
# Usage examples:
#   perl run_vcs.pl
#       - compile + run, UVM 1.2, no FSDB
#
#   perl run_vcs.pl --fsdb
#       - compile + run, generate FSDB (FSDB enabling is assumed to be controlled by +define+FSDB in TB)
#
#   perl run_vcs.pl --gui
#       - compile + run, then launch Verdi GUI (interactive UVM debug mode)
#
#   perl run_vcs.pl --uvm-debug=hier,seq --fsdb
#       - compile with -kdb, run simv with UVM debug recording options (hierarchy tree + sequence history)
#       - does NOT auto-launch Verdi unless you also pass --gui
#
#   perl run_vcs.pl --gui --uvm-debug=ralwave --fsdb
#       - record register history + related object dump into FSDB, then launch Verdi with -uvmDebug
#
#   perl run_vcs.pl --clean
#       - remove previous build artifacts
#
# Options can be combined; --dry-run prints commands without executing.
#
# Manual Verdi launch example (if GUI did not auto-open):
#   verdi -kdb -dbdir simv.daidir -ssf sdram_uvm.fsdb -ssv my_top.sv package.sv -f dut.f -f tb.f &
#
# ------------------------------------------------------------------------------
# UVM / Verdi debug option mapping table (for --uvm-debug=...)
#
# Terminology:
#   - Compile-time: options that MUST be added to VCS compilation (vcs command)
#   - Runtime:      plusargs that MUST be added when running simv
#   - Verdi:        options for launching verdi GUI
#
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | Token          | Purpose                     | Compile-time (vcs)            | Runtime (simv)   | Dependency / Notes        | Conflict / Override       |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | hier           | UVM Hierarchy Tree          | -kdb (recommended)            | +UVM_VERDI_TRACE=HIER
# |                |                             |                               |                  | Enables hierarchy tree +  | none                      |
# |                |                             |                               |                  | TLM connectivity dump     |                           |
# |                |                             |                               |                  | (needs runtime option)    |                           |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | seq            | Sequence history             | -kdb (recommended)            | +UVM_TR_RECORD   | Enables transaction record| none                      |
# |                | (Sequence View)              |                               |                  | for sequence history      |                           |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | ral            | Register access history      | -kdb (recommended)            | +UVM_VERDI_TRACE=RAL
# |                | (Register View)              |                               |                  | Dumps register hierarchy &| overridden by ralwave     |
# |                |                             |                               |                  | R/W access history        | (ralwave includes it)     |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | ralwave        | Register history + related   | +define+UVM_VERDI_RALWAVE      | +UVM_VERDI_TRACE=RALW
# |                | object dump to FSDB          | -kdb (recommended)            | ALWAVE           | VCS-only; includes RAL so | overrides ral             |
# |                |                             |                               |                  | no need to also set ral   |                           |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
# | compwave       | Dump UVM component objects   | +define+UVM_VERDI_COMPWAVE     | +UVM_VERDI_TRACE=COMPWAVE
# |                | into nWave (object wave)     | -kdb + -debug_access+all       |                  | COMPWAVE implies HIER     | none (implies hier)       |
# +----------------+-----------------------------+-------------------------------+------------------+---------------------------+---------------------------+
#
# Baseline recommendation:
#   If any --uvm-debug token is used, also add:
#     +UVM_VERDI_TRACE=UVM_AWARE
#   (Verdi adds this automatically when UVM Debug is enabled in preferences,
#    but adding it explicitly keeps behavior consistent across flows.)
# ------------------------------------------------------------------------------
#
# NOTE on interactive Verdi flow:
#   This script launches Verdi with:
#     verdi -uvmDebug -kdb -dbdir simv.daidir ...
#   which corresponds to importing the design into Verdi and enabling UVM debug.
# ------------------------------------------------------------------------------

my $fsdb       = 0;
my $clean      = 0;
my $dry_run    = 0;
my $uvm_test   = 'test';
my $gui_flag   = 0;

# New: enumerated UVM debug tokens
# Examples:
#   --uvm-debug            => default "hier,seq"
#   --uvm-debug=hier,seq
#   --uvm-debug=ral
#   --uvm-debug=ralwave
#   --uvm-debug=compwave
#   --uvm-debug=all        => enables a reasonable "all"; conflicts handled (ralwave overrides ral)
my $uvm_debug  = undef;

my $vcs_home   = $ENV{VCS_HOME}   || '/home/synopsys/vcs/O-2018.09-SP2';
my $verdi_home = $ENV{VERDI_HOME} || '/home/synopsys/verdi/Verdi_O-2018.09-SP2';

GetOptions(
    'fsdb!'       => \$fsdb,
    'clean!'      => \$clean,
    'dry-run!'    => \$dry_run,
    'uvm-test=s'  => \$uvm_test,
    'gui!'        => \$gui_flag,
    'uvm-debug:s' => \$uvm_debug,   # <-- NEW
) or die "Error in command line arguments\n";

my $vcs_bin   = "$vcs_home/bin/vcs";
my $verdi_bin = "$verdi_home/bin/verdi";
my $simv      = './simv';
my $comp_log  = 'comp.log';
my $sim_log   = 'sim.log';
my $fsdb_def  = $fsdb ? '+define+FSDB' : '';
my $fsdb_file = 'sdram_uvm.fsdb';

# Build uvm-debug expanded options
my ($need_kdb, $uvm_dbg_vcs_defines_ref, $uvm_dbg_sim_plusargs_ref) = build_uvm_debug_opts($uvm_debug);

my @clean_list = (
    'csrc', 'simv', 'simv.daidir', 'ucli.key', 'vcs.key', 'vc_hdrs.h',
    'sim.log', 'comp.log', 'DVEfiles', 'urgReport', 'vdb',
);

if ($clean) {
    for my $path (@clean_list) {
        run_cmd("rm -rf $path");
    }
    exit 0;
}

my @vcs_cmd = (
    $vcs_bin,
    '-full64',
    '-sverilog',
    '-timescale=1ns/1ps',
    '-ntb_opts', 'uvm-1.2',
    '-f', 'dut.f',
    '-f', 'tb.f',
    '-top', 'my_top',
    '-debug_access+all',

    # -kdb for Verdi/UFE flow: enable if GUI is requested OR any uvm-debug token is requested
    (($gui_flag || $need_kdb) ? '-kdb' : ()),

    # FSDB dumper PLI
    '-P', "$verdi_home/share/PLI/VCS/LINUX64/novas.tab",
          "$verdi_home/share/PLI/VCS/LINUX64/pli.a",

    # uvm-debug compile-time defines (e.g., UVM_VERDI_RALWAVE / UVM_VERDI_COMPWAVE)
    (@{$uvm_dbg_vcs_defines_ref}),

    ($fsdb_def ? $fsdb_def : ()),
    '-l', $comp_log,
);

my @sim_cmd = (
    $simv,
    '+UVM_TESTNAME=' . $uvm_test,
    ($fsdb_def ? $fsdb_def : ()),

    # uvm-debug runtime plusargs (e.g., HIER/SEQ/RAL/RALWAVE/COMPWAVE)
    (@{$uvm_dbg_sim_plusargs_ref}),

    '-l', $sim_log,
);

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

sub _split_csv_opts {
    my ($s) = @_;
    $s //= '';
    $s =~ s/\s+//g;
    my @t = grep { $_ ne '' } split(/[,:;]/, $s);
    my %seen;
    return grep { !$seen{$_}++ } @t;
}

sub build_uvm_debug_opts {
    my ($arg) = @_;

    # If --uvm-debug is not used at all
    return (0, [], []) if !defined $arg;

    # If user uses: --uvm-debug   (no "=...")
    # Default to the most common: hier + seq
    $arg = 'hier,seq' if $arg eq '';

    my @tok = _split_csv_opts(lc($arg));

    # Convenience: "all"
    if (grep { $_ eq 'all' } @tok) {
        @tok = qw(hier seq ral ralwave compwave);
    }

    # Normalize / aliases
    my %alias = (
        'tree'     => 'hier',
        'tlm'      => 'hier',
        'seqrec'   => 'seq',
        'reg'      => 'ral',
        'regwave'  => 'ralwave',
        'comp'     => 'compwave',
    );

    my %want;
    for my $t (@tok) {
        $t = $alias{$t} // $t;
        $want{$t} = 1;
    }

    # Validate tokens (keep strict so mistakes are caught early)
    my %known = map { $_ => 1 } qw(hier seq ral ralwave compwave);
    for my $k (keys %want) {
        next if $known{$k};
        die "Unknown --uvm-debug token: '$k'. Supported: hier, seq, ral, ralwave, compwave, all\n";
    }

    # Dependency: compwave implies hier
    if ($want{compwave}) {
        $want{hier} = 1;
    }

    # Conflict/override: ralwave includes ral, so drop ral if both set
    if ($want{ralwave}) {
        delete $want{ral};
    }

    my @vcs_defines;
    my @sim_plusargs;

    # Baseline (keep behavior consistent even without GUI preferences)
    push @sim_plusargs, '+UVM_VERDI_TRACE=UVM_AWARE';

    # HIER
    push @sim_plusargs, '+UVM_VERDI_TRACE=HIER' if $want{hier};

    # SEQ (sequence history)
    push @sim_plusargs, '+UVM_TR_RECORD' if $want{seq};

    # RAL
    push @sim_plusargs, '+UVM_VERDI_TRACE=RAL' if $want{ral};

    # RALWAVE (needs compile define)
    if ($want{ralwave}) {
        push @vcs_defines, '+define+UVM_VERDI_RALWAVE';
        push @sim_plusargs, '+UVM_VERDI_TRACE=RALWAVE';
    }

    # COMPWAVE (needs compile define)
    if ($want{compwave}) {
        push @vcs_defines, '+define+UVM_VERDI_COMPWAVE';
        push @sim_plusargs, '+UVM_VERDI_TRACE=COMPWAVE';
    }

    # (Kept from original script style; harmless if not recognized by your UVM/recorder setup)
    # Only add this when uvm-debug is explicitly requested.
    push @sim_plusargs, '+UVM_VERDI_ENABLE=1';

    # Dedup while preserving order
    my (%d1, %d2);
    @vcs_defines  = grep { !$d1{$_}++ } @vcs_defines;
    @sim_plusargs = grep { !$d2{$_}++ } @sim_plusargs;

    my $need_kdb = 1; # uvm-debug requests imply compile -kdb
    return ($need_kdb, \@vcs_defines, \@sim_plusargs);
}

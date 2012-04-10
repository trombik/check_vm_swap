#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw{ :DEFAULT :flock :seek };
use File::Spec;
use File::Basename;
use English '-no_match_vars';
use IPC::Cmd qw{ run };
use Nagios::Plugin;

# TODO
# - per min/sec
our $VERSION = 0.1;

my $default_statedir = "/var/spool/nagios/plugins";

#my $state_dir = "/home/tomoyukis/tmp";
my $myname      = basename $PROGRAM_NAME;
my %command_for = (

    # the order matters
    freebsd => {
        swap => "sysctl -n vm.stats.vm.v_swapin vm.stats.vm.v_swapout",
        page => "sysctl -n vm.stats.vm.v_swappgsin vm.stats.vm.v_swappgsout",
    }
);

my $p = Nagios::Plugin->new(
    shortname => uc($myname),
    usage     => "Usage: %s [ --warning w ] [ --critical c ] ] [ -v ]",
    version   => $VERSION,
    plugin    => $myname,
    timeout   => 10,
);

$p->add_arg(
    spec => "warning=i",
    help =>
      ["Exit with WARNING status if more than swap in/out operations/min"],
    label    => qw[ NUMBER ],
    required => 1,
);

$p->add_arg(
    spec => "critical=i",
    help =>
      ["Exit with CRITICAL status if more than swap in/out operations/min"],
    label    => qw[ NUMBER ],
    required => 1,
);

$p->add_arg(
    spec => "type=s",
    help =>
      ["What to monitor, either \"swap\" or \"page\". default is \"swap\""],
    default => "swap",
);

$p->add_arg(
    spec => "statedir=s",
    help => [ "path to plugins state directory" ],
    default => $default_statedir,
);

$p->getopts;

sub update_data {
    my $total = shift;
    my $file = File::Spec->catfile( $p->opts->statedir, $myname );
    my $state_fh;
    if (-f $file) {
        open $state_fh, "+<", $file
          or $p->nagios_exit( UNKNOWN, "cannot open() for +< $file: $!" );
    } else {
        open $state_fh, "+>", $file
          or $p->nagios_exit( UNKNOWN, "cannot open() for > $file: $!" );
    }
    flock $state_fh, LOCK_EX or $p->nagios_exit( UNKNOWN, $! );
    my $last_total = do { local $/; <$state_fh> };    # slurp mode
    $last_total = 0 unless $last_total;
    printf "total: %d last_total: %d\n", $total, $last_total
      if $p->opts->verbose;
    seek $state_fh, 0, 0
      or $p->nagios_exit( UNKNOWN, "cannot seek() $file: $!" );
    print $state_fh $total;
    truncate $state_fh, tell($state_fh)
      or $p->nagios_exit( UNKNOWN, "cannot truncate() $file: $!" );
    return $last_total == 0 ? 0 : $total - $last_total;
}

sub get_diff {
    my $command = $command_for{$OSNAME}{ $p->opts->type };
    my ( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) =
      run( command => $command, verbose => $p->opts->verbose );
    if ( !$success ) {
        $p->nagios_exit( UNKNOWN, sprintf "failed to run command \"%s\": %s",
            $command, join( q{}, @{$full_buf} ) );
    }
    my ( $in, $out ) =
      split( "\n", join q{}, @{$stdout_buf} );
    my $diff = update_data( $in + $out );
    return $diff;
}

if ( !$command_for{$OSNAME} ) {
    $p->nagios_exit( UNKNOWN, sprintf "platform %s is not supported", $OSNAME );
}

my $diff   = get_diff();
my $permin = $diff / 5;
my $status = $p->check_threshold(
    check    => $permin,
    warning  => $p->opts->warning,
    critical => $p->opts->critical,
);
my $message = sprintf "%s in/out %d/min", $p->opts->type, $permin;
$p->nagios_exit( $status, $message );

=head1 NAME

check_vm_swap - A Nagios plugin to check swap in/out operations

activities

=head1 SYNOPSIS

check_vm_swap --warning w --critical c [-v]

=head1 DESCRIPTION

check_vm_swap checks swap activities. it does B<NOT> check total amount
of available swap storage. As long as kernel has enough swap space, swapping
is not a problem. Mordern kernel rarely swap process. Even if it does, it's OK
if the swapped process is idling. However, many swapping activity is almost
always a problem. check_swap from Nagios plugins just checks how much swap
space is available and screams when swap is used. If swapped process has been
idle for a while and other processes need memory, it's okay. That's what kernel
is supposed to do. I needed a plugin to check how often kernel swap-in/out
process.

by default, it monitors how often kernel swaps in/out. paging in/out is also
supported.

=head2 OPTIONS

=over

=item --warning, --critical

per-five-minutes thresholds for swap operation.

=item --type TYPE

What VM activity to monitor, "swap" or "page", default is swap.

=item --statedir /path/to/directoy

Where state file is written (/var/spool/nagios/plugins). The user needs write
perimission.

=back

=head1 SEE ALSO

check_swap, if you B<really> want to monitor how much swap space left.

=head1 AUTHOR

Tomoyuki Sakurai <tomoyukis@reallyenglish.com>

=head1 LICENSE

Copyright (c) 2012 Tomoyuki Sakurai <tomoyukis@reallyenglish.com>

Permission to use, copy, modify, and distribute this software for any 
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR 
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

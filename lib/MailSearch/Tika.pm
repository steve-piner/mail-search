package MailSearch::Tika;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use Moose;
use Carp 'croak';
use IO::Socket;
use Socket qw[SHUT_WR];
use JSON 'decode_json';
use MailSearch::Util 'slow_connect';

sub BUILD {
    my ($self, $args) = @_;
    croak "Parameter 'config' is required" unless exists $args->{config};
    $args->{config}->must_have(__PACKAGE__, 'jar', 'text port', 'metadata port');
    $self->_config($args->{config}->section(__PACKAGE__));
}

sub DEMOLISH {
    my $self = shift;
    $self->finish;
}

has _config => (
    is => 'rw',
);

has _pids => (
    is => 'rw',
    default => sub { {} },
);

sub start {
    my $self = shift;
    $self->_start_text_server;
    $self->_start_metadata_server;
    return;
}

sub _start_text_server {
    my $self = shift;
    $self->_start_tika('text', '--text', $self->_config->{'text port'});
    return;
}

sub _start_metadata_server {
    my $self = shift;
    $self->_start_tika('metadata', '--metadata', '--json', $self->_config->{'metadata port'});
    return;
}

sub _start_tika {
    my $self = shift;
    my $label = shift;
    my @args = @_;

    # Already running?
    return if ($self->_pids->{$label});

    my $pid = fork();
    if (not $pid) {
        exec {'java'} 'java', '-server',
            '-jar', glob($self->_config->{jar}),
            '--server', @args;
    }
    $self->_pids->{$label} = $pid;
    return $pid;
}

sub finish {
    my $self = shift;

    if (%{$self->_pids}) {
        kill 'TERM', values %{$self->_pids};
        while (%{$self->_pids}) {
            my $pid = wait;
            last if $pid < 0;
            for (keys %{$self->_pids}) {
                if ($self->_pids->{$_} == $pid) {
                    delete $self->_pids->{$_};
                }
            }
        }
    }
    return;
}

sub _send_receive {
    my $self = shift;
    my $port = shift;
    my $data = shift;

    my $socket = slow_connect('127.0.0.1:' . $port, 10, 1);
    print {$socket} $data;
    $socket->shutdown(SHUT_WR);
    local $/;
    my $response = <$socket>;
    close $socket;
    return $response;
}

sub extract {
    my $self = shift;
    my $data = shift;

    my $response = {
        text => $self->_send_receive($self->_config->{'text port'}, $data->{message}),
        metadata => decode_json($self->_send_receive($self->_config->{'metadata port'}, $data->{message})),
    };
    return $response;
}

__PACKAGE__->meta->make_immutable;

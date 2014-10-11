package MailSearch::Ssh;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use IPC::Open2;
use Storable 'fd_retrieve';
use Moose;

with 'MailSearch::Roles::Fetch';

has _config => (
    is => 'rw',
);

has _pid => (
    is => 'rw',
);

has _read => (
    is => 'rw',
);

has _write => (
    is => 'rw',
);

sub BUILD {
    my ($self, $args) = @_;
    $args->{config}->must_have(__PACKAGE__, 'host', 'script path');
    $self->_config($args->{config}->section(__PACKAGE__));
}

sub start {
    my $self = shift;
    my ($config, $read, $write, $pid);
    $config = $self->_config;

    $pid = open2($read, $write, 'ssh',
        ($config->{'private key'} ? ('-i', glob $config->{'private key'}) : ()),
        $self->_config->{host},
        $self->_config->{'perl path'} // 'perl',
        $self->_config->{'script path'},
    );
    $self->_pid($pid);
    $self->_read($read);
    $self->_write($write);

    print {$self->_write} "start\n";
    $self->_retrieve;
}

sub finish {
    my $self = shift;
    print {$self->_write} "finish\n";
    $self->_retrieve;
    close $self->_read;
    close $self->_write;
    return;
}

sub fetch {
    my $self = shift;
    print {$self->_write} "fetch\n";
    return $self->_retrieve->{fetch};
}

sub _retrieve {
    my $self = shift;
    my $response = fd_retrieve($self->_read);
    if (exists $response->{error}) {
        say STDERR $response->{error};
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;
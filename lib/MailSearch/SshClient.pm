package MailSearch::SshClient;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use namespace::autoclean;
use IPC::Open2;
use Storable 'store_fd';
use Moose;
use Try::Tiny;

use MailSearch::Util 'require_object';

has _fetch => (
    is => 'rw',
);

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $config = $args->{config}->section(__PACKAGE__);
    $self->_fetch(require_object($config->{fetch}, config => $args->{config}));
}

sub run {
    my $self = shift;

    STDOUT->autoflush(1);

    while (my $command = <>) {
        chomp $command;

        my %response;
        try {
            %response = ();
            if ($command eq 'fetch') {
                $response{fetch} = $self->_fetch->fetch;
            }
            elsif ($command =~ /^(?:start|finish)$/) {
                $self->_fetch->$command();
            }
        }
        catch {
            $response{error} = $_;
        };
        store_fd \%response, \*STDOUT;
        last if $command eq 'finish';
    }
    return;
}

__PACKAGE__->meta->make_immutable;

package lib::MailSearch::Maildir;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use File::Temp;
use namespace::autoclean;
use Moose;

use constant MTIME => 9;

with 'MailSearch::Roles::Fetch';

has _config => (
    is => 'rw',
);

has _old_state_file => (
    is => 'rw',
);

has _new_state_file => (
    is => 'rw',
);

has _dirs => (
    is => 'rw',
);

has _file => (
    is => 'rw',
);

has _files => (
    is => 'rw',
    default => sub { [] },
);

has _state => (
    is => 'rw',
);

has _maildir => (
    is => 'rw',
);

sub BUILD {
    my ($self, $args) = @_;
    $self->_config($args->{config}->section(__PACKAGE__));
}

sub start {
    my $self = shift;
    my ($old_state_file, $new_state_file);

    my $file_name = glob($self->_config->{'state file'});
    open $old_state_file, '<', $file_name;
    $self->_old_state_file($old_state_file);

    my $fh = File::Temp->new(UNLINK => 0);
    $self->_new_state_file($new_state_file);

    my $maildir = glob($self->_config->{'maildir path'});
    $self->_maildir($maildir);

    opendir my ($dir), $maildir;
    my @dirs;
    for (readdir $dir) {
        next if m{^\.\.?$};
        next unless -d $_;

        if ($_ eq 'cur') {
            push @dirs, $_;
        }
        elsif (-d "$_/cur") {
            push @dirs, "$_/cur";
        }
    }
    closedir $dir;

    $self->_dirs([sort @dirs]);

    return;
}

sub fetch {
    my $self = shift;
    my $files = $self->_files;
    my $file = $self->_file;

FETCH: {
        # Get the next file.
        while (not defined $file) {
            if (@{$self->_files}) {
                $file = shift @{$self->_files};
            }
            else {
                return if not @{$self->_dirs};

                my $dir_name = shift @{$self->_dirs};
                opendir my $dir, $self->_maildir . '/' . $dir_name;
                $files = $self->_files([
                    sort grep { -f $_ } map {"$dir_name/$_"} readdir $dir
                ]);
            }
        }

        # Get the state from the previous run.
        my $state = $self->_state;
        if (not defined $state) {
            my $old_state_file = $self->_old_state_file;
            @{$state}{'mtime', 'id'} = {split /~/, scalar <$old_state_file>, 2};
            $self->_state($state);
        }

        # check against old state.
        if ($file gt $state->{id}) {
            # Deleted file
            $self->_state(undef);
            return {
                id => $state->{id},
                status => 'deleted',
            };
        }
        elsif ($file eq $state->{id}) {
            # Same file name - but is it the same file? 
            my $mtime = (stat $self->_maildir . '/' . $file)[MTIME];
            say {$self->_new_state_file} $mtime . '~' . $file;
            $self->_state(undef);

            # If no change, no update required.
            redo FETCH if $mtime == $state->{mtime};
        }
    }

    open my $fh, '<', $self->_maildir . '/' . $file;
    local $/;
    my $message = <$fh>;
    close $fh;
    return {
        message => $message,
        id => $file,
    };
}

sub finish {
    my $self = shift;

    my $old_state_file = $self->_old_state_file;
    # If finish is called before everything has been fetched, assume that the
    # state we didn't see hasn't changed.
    while (not eof($old_state_file)) {
        my $state = <$old_state_file>;
        print {$self->_new_state_file} $state;
    }
    close $self->_old_state_file;
    my $temp_name = $self->_new_state_file->filename;
    close $self->_new_state_file;
    rename $temp_name, $self->_old_state_file;
    return;
}

sub fetch {
    return;
}


__PACKAGE__->meta->make_immutable;
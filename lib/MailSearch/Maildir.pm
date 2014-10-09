package MailSearch::Maildir;
use 5.014;
use strict;
use warnings;
use autodie;

use version; our $VERSION = qv('0.0.1');

use File::Temp;
use File::Basename 'dirname';
use namespace::autoclean;
use Moose;

use constant MTIME => 9;

use constant MODE_FINISHED => 0;
use constant MODE_FILES_ONLY => 1;
use constant MODE_STATE_ONLY => 2;
use constant MODE_MIX => MODE_FILES_ONLY | MODE_STATE_ONLY;

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

has _mode => (
    is => 'rw',
    default => MODE_MIX,
);

sub BUILD {
    my ($self, $args) = @_;
    $self->_config($args->{config}->section(__PACKAGE__));
}

sub start {
    my $self = shift;
    my ($old_state_file, $new_state_file);

    my $file_name = glob($self->_config->{'state file'});
    eval { open $old_state_file, '<', $file_name };
    $self->_old_state_file($@ ? undef : $old_state_file); #?; # Editor glitch.

    $new_state_file = File::Temp->new(UNLINK => 0, DIR => dirname $file_name);
    $self->_new_state_file($new_state_file);

    my $maildir = glob($self->_config->{'maildir path'});
    $self->_maildir($maildir);

    opendir my ($dir), $maildir;
    my @dirs;
    for (readdir $dir) {
        next if m{^\.\.?$};
        next unless -d "$maildir/$_";

        if ($_ eq 'cur') {
            push @dirs, $_;
        }
        elsif (-d "$maildir/$_/cur") {
            push @dirs, "$_/cur";
        }
    }
    closedir $dir;

    $self->_dirs([sort @dirs]);

    return;
}

sub fetch {
    my $self = shift;

    my $mode = $self->_mode;
    my $file;
    my $state;

FETCH: {
        if ($mode & MODE_FILES_ONLY) {
            $file = $self->_file;
            if (not defined $file) {
                if ($self->_fetch_file) {
                    $file = $self->_file;
                }
                else {
                    $self->_mode($mode ^= MODE_FILES_ONLY);
                }
            }
        }

        if ($mode & MODE_STATE_ONLY) {
            $state = $self->_state;
            if (not defined $state) {
                if ($self->_fetch_state) {
                    $state = $self->_state;
                }
                else {
                    $self->_mode($mode ^= MODE_STATE_ONLY);
                }
            }
        }

        if ($mode == MODE_MIX) {
            if ($state->{id} lt $file) {
                # File mentioned in state has been deleted.
                $self->_fetch_state or $self->_mode(MODE_FILES_ONLY);
                return $self->_return_deleted($state);
            }
            elsif ($file eq $state->{id}) {
                # Same file name - but is it the same file?
                $self->_write_state($file);
                $self->_fetch_file or $self->_mode(MODE_STATE_ONLY);
                $self->_fetch_state or $self->_mode(MODE_FILES_ONLY);
                # If no change, no update required.
                my $mtime = (stat $self->_maildir . '/' . $file)[MTIME];
                redo FETCH if $mtime == $state->{mtime};
            }
            else {
                # $file lt $state->{id}
                $self->_write_state($file);
                $self->_fetch_file or $self->_mode(MODE_STATE_ONLY);
            }
            return $self->_return_message($file);
        }
        elsif ($mode == MODE_STATE_ONLY) {
            if (not $self->_fetch_state) {
                $self->_mode(MODE_FINISHED);
            }
            return $self->_return_deleted($state->{id});
        }
        elsif ($mode == MODE_FILES_ONLY) {
            if (not $self->_fetch_file) {
                $self->_mode(MODE_FINISHED);
            }
            $self->_write_state($file);
            return $self->_return_message($file);
        }
    }

    # MODE_FINISHED.
    return;
}

sub _fetch_file {
    my $self = shift;
    my $files = $self->_files;
    my $file;

    while (not defined $file) {
        if (@{$self->_files}) {
            $file = shift @{$self->_files};
        }
        else {
            if (not @{$self->_dirs}) {
                $self->_file(undef);
                return;
            }

            my $maildir = $self->_maildir;
            my $dir_name = shift @{$self->_dirs};
            opendir my $dir, "$maildir/$dir_name";
            $files = $self->_files([
                sort grep { -f "$maildir/$_" } map {"$dir_name/$_"} readdir $dir
            ]);
        }
    }
    $self->_file($file);
    return 1;
}

sub _fetch_state {
    my $self = shift;
    my $old_state_file = $self->_old_state_file;
    if (not $old_state_file) {
        $self->_state(undef);
        return;
    }

    my $state = <$old_state_file>;
    if (defined $state) {
        chomp $state;
        my $next;
        @{$next}{'mtime', 'id'} = split /~/, $state, 2;
        $self->_state($next);
        return 1;
    }
    $self->_state(undef);
    return;
}

sub _write_state {
    my $self = shift;
    my $file = shift;

    my $mtime = (stat $self->_maildir . '/' . $file)[MTIME];
    say {$self->_new_state_file} $mtime . '~' . $file;

    return;
}

sub _return_deleted {
    my $self = shift;
    my $id = shift;

    return {
        id => $id,
        status => 'deleted',
    };
}

sub _return_message {
    my $self = shift;
    my $file = shift;

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
    if ($old_state_file) {
        # If finish is called before everything has been fetched, assume that
        # the state we didn't see hasn't changed.
        while (not eof($old_state_file)) {
            my $state = <$old_state_file>;
            print {$self->_new_state_file} $state;
        }
        close $self->_old_state_file;
    }
    my $temp_name = $self->_new_state_file->filename;
    close $self->_new_state_file;
    rename $temp_name, scalar glob($self->_config->{'state file'});
    return;
}



__PACKAGE__->meta->make_immutable;
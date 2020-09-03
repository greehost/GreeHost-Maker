package GreeHost::Maker::Pull::Git;
use Moo;
use IPC::Run3;
use Cwd;
use File::Temp;

has repo => (
    is       => 'ro',
    required => 1,
);

has dest => (
    is      => 'ro',
    default => '/maker',
);

# TODO validate this with the ssh tools
has ssh_priv_key_contents => (
    is => 'ro',
);

sub run {
    my ( $self ) = @_;

    die "REFUSING TO RUN WITH A ROOT SSH KEY EXISTING: This module should be run inside Docker."
        if -e '/root/.ssh/id_rsa';

    $self->write_ssh_configs;
    run3([ 'git', 'clone', $self->repo, $self->dest ]);
}

sub write_ssh_configs {
    my ( $self ) = @_;
    
    mkdir '/root/.ssh';

    $self->write_file( '/root/.ssh/config', "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n" );
    $self->write_file( '/root/.ssh/id_rsa', $self->ssh_priv_key_contents );
    
    chmod 0700, '/root/.ssh';
    chmod 0600, '/root/.ssh/id_rsa';
    chmod 0600, '/root/.ssh/config';
}

sub write_file {
    my ( $self, $file, $content ) = @_;

    open my $sf, ">", $file
        or die "Failed to open $file for writing: $!";
    print $sf $content;
    close $sf;
}

1;

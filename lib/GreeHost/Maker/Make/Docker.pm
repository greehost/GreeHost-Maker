package GreeHost::Maker::Make::Docker;
use Moo;
use IPC::Run3;
use File::Temp;
use Cwd qw( getcwd );
use File::Basename;

has image => (
    is => 'ro',
);

has script => (
    is => 'ro',
);

# Remember: Files for docker mounting are based on the host machine
# root, NOT the docker container's root we're running inside of.
has docker0_root => (
    is      => 'ro',
    lazy    => 1,
    builder => sub { $ENV{GREEHOST_DOCKER0_ROOT} },
);

sub _build {
    my ( $self ) = @_;

    # Install our script
    my $script = File::Temp->new( DIR => '/app' );
    print $script join( "\n", @{$self->script} );
    $script->sync;

    # Declare volumns for Docker
    my @vols = (
        '-v', sprintf( '%s:/app:rw', $self->docker0_root ),
        '-v', sprintf( '%s:/greehost-script:ro', $self->docker0_root . basename($script->filename) ),
    );

    # Invoke the user script inside of a Docker image
    run3([qw( docker run -w /app ), @vols, $self->image, '/bin/bash', '/greehost-script'  ]);
}

sub build {
    my ( $class, $args ) = @_;

    return $class->new($args)->_build;
}

sub run {
    return shift->_build;
}

1;

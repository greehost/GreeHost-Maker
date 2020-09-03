# ABSTRACT: Pull, Build, and Deploy GreeHost Project Directories
package GreeHost::Maker;
use File::Temp;
use IPC::Run3;
use JSON::MaybeXS qw( encode_json decode_json );
use POSIX qw( strftime );

sub verbose {
    my ( $message ) = @_;
    my $ts = strftime( "%H:%M:%S", localtime() );
    print "[*] [$ts]: $message\n";
}

# $project = {
#     pull => {
#         class                 => 'Git',
#         repo                  => 'git@....git',
#         ssh_priv_key_contents => ,
#     }
# };
sub make_project {
    my ( $self, $project ) = @_;


    # Create Build directory and work from there.
    my $build_dir = File::Temp->newdir( CLEANUP => 0 );
    chdir $build_dir->dirname
        or die "Failed to chdir(" . $build_dir->dirname . "): $!";

    verbose "Created build dir" . $build_dir->dirname;

    # Create initial maker configuration
    my $project_config_file = File::Temp->new;
    my $encoded = encode_json( $project );
    print $project_config_file $encoded;
    $project_config_file->sync;

    # Run docker and pull down the repo into our current working directory.;
    my @vols = (
        '-v', sprintf( '%s:/maker:rw', $build_dir->dirname ),
        '-v', sprintf( '%s:/.maker.json:ro', $project_config_file->filename  ),
    );
    run3([qw( docker run -w /maker ), @vols, 'greehost/maker:latest', 'greehost-maker-pull' ]);

    verbose "Pulled down repo";

    # Run docker to generate the configuration file
    @vols = (
        '-v', sprintf( '%s:/app:rw', $build_dir->dirname ),
    );
    run3([qw( docker run -w /app ), @vols, 'greehost/maker:latest', 'greehost-maker-make-config' ]);
    
    verbose "Created config";

    # Run docker to invoke all make commands, this needs permission for docker to run docker inside
    # of docker.
    @vols = (
        '-v', sprintf( '%s:/app:rw', $build_dir->dirname ),
        '-v', '/var/run/docker.sock:/var/run/docker.sock',
        '-e', sprintf( 'GREEHOST_DOCKER0_ROOT=%s/', $build_dir->dirname),
    );
    run3([qw( docker run -w /app ), @vols, 'greehost/maker:latest', 'greehost-maker-make' ]);

    # Run all deployment steps, for this we need deployment keys that can access staticXX.mn.greehost.com
    # machines currently.
    # TODO: Solve the ssh key location/hosts file more generally for these machines
    @vols = (
        '-v', sprintf( '%s:/app:rw', $build_dir->dirname ),
        '-v', '/root/.ssh/id_rsa:/root/.ssh/id_rsa:ro',
        '-v', '/etc/hosts:/etc/hosts',
    );
    run3([qw( docker run -w /app ), @vols, 'greehost/maker:latest', 'greehost-maker-deploy' ]);

    verbose "Ran deployment scripts.";
}

1;

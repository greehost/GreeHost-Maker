package GreeHost::Maker::Deploy::StaticServ;
use Moo;
use Text::Xslate;
use File::Temp;
use IPC::Run3;
use Object::Remote;
use GreeHost::Config;
use GreeHost::StaticServ;

has domain => (
    is => 'ro',
);

has root => (
    is => 'ro',
);

has sslstore => (
    is => 'ro',
);

has redirect => (
    is => 'ro',
);

my $nginx_template =<<"EOF";
server {
    server_name [% \$domain %];
    listen 80;

%% if \$sslstore {
    listen 443 ssl;
    ssl_certificate      /opt/greehost/sslstore/domains/[% \$sslstore %]/live/[% \$sslstore %]/fullchain.pem;
    ssl_certificate_key  /opt/greehost/sslstore/domains/[% \$sslstore %]/live/[% \$sslstore %]/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!MD5;
%% }

    root /var/www/[% \$domain %];
    index index.html index.htm index.md index.txt;
}
EOF

sub generate_nginx_domain_config {
    my ( $self ) = @_;

    return Text::Xslate->new(
        syntax => 'Metakolon'
    )->render_string($nginx_template, {
        domain => $self->domain,
        ( $self->sslstore ? ( sslstore => $self->sslstore ) : () ),
    });
}

sub _build {
    my ( $self ) = @_;

    # Create a temp directory that we'll use for the StaticServ payload.
    my $dir = File::Temp->newdir( CLEANUP => 1 );

    # Stick a webroot.tgz file into this directory, containing the user's webroot.
    run3( [ 'tar', '-C', $self->root, '-czf', "$dir/webroot.tgz", '.' ] );

    # Generate the config file and stick it the directory.
    my $config_contents = $self->generate_nginx_domain_config;
    open my $sf, ">", "$dir/" . $self->domain . ".conf"
        or die "Failed to open $dir/" . $self->domain . " for writing: $!";
    print $sf $config_contents;
    close $sf;

    return $self->deploy($dir);
}

sub deploy {
    my ( $self, $directory ) = @_;

    $self->write_ssh_configs;

    my $hosts = $GreeHost::Config::STATICSERV_TARGETS;
    foreach my $host ( @{ $hosts } ) {
        my $conn = Object::Remote->connect( $host );

        # Create Remote Directory
        my $rdir = File::Temp->can::on( $conn, 'tempdir' )->();

        # Push our directory over into that temporary one.
        run3([ qw( rsync -a ), "$directory/", "$host:$rdir" ]);

        # Trigger the remote-side to ingest the folder
        GreeHost::StaticServ->can::on( $conn, 'install_domain' )->( $rdir );
    }
}

sub build {
    my ( $class, $args ) = @_;

    return $class->new($args)->_build;
}

sub run {
    return shift->_build;
}

sub write_ssh_configs {
    my ( $self ) = @_;
    
    mkdir '/root/.ssh';

    $self->write_file( '/root/.ssh/config', "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n" );
    
    chmod 0700, '/root/.ssh';
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

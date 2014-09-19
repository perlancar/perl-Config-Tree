package Config::Tree;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Path::Naive qw(abs_path);

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    $self->{_dirstack} = [];
    $self->{_mounts}   = {}; # key=path, val=[$obj, $write]
    $self->{_cwd}      = '/';
    $self;
}

sub mount {
    my ($self, $path, $obj, $write) = @_;
    die "mount(): Please specify mountpoint" unless length $path;
    $self->{_mounts}{abs_path($path, '/')} = [$obj, $write];
}

sub cd {
    my ($self, $dir) = @_;
    die "cd(): Please specify dir" unless length $dir;
    $self->{_cwd} = abs_path($dir, $self->{_cwd});
}

sub pushd {
    my ($self, $dir) = @_;
    my $old_dir = $self->{_cwd};
    $self->cd($dir);
    push @{ $self->{_dirstack} }, $dir;
    $old_dir;
}

sub popd {
    my ($self, $dir) = @_;
    die "popd(): Dirstack is empty" unless @{ $self->{_dirstack} };
    my $old_dir = $self->{_cwd};
    $self->cd( pop @{ $self->{_dirstack} } );
    $old_dir;
}

sub get {
    my ($self, $path) = @_;
    die "get(): Please specify path" unless length $path;
    die "get(): Can't get directory '$path'" if $path =~ m!/\z!;
    my $apath = abs_path($path, $self->{_cwd});
    die "get(): Can't get root directory '/'" if $apath eq '/';

    my $mnts = $self->{_mounts};
    die "get(): Can't get directory (root of mountpoint) '$apath'"
        if $mnts->{$apath};
    my $lpath = '';
    #say "D:apath=$apath";
    while ($apath =~ s!/([^/]+)\z!!) {
        $apath = "/" if $apath eq '';
        $lpath = "$lpath/$1";
        #say "D:apath=$apath, lpath=$lpath";
        my $v = $mnts->{$apath};
        return $v->[0]->get($lpath) if $v;
    }
    die "get(): Path does not fall under any mounted config: '$path'";
}

sub list {
}

sub set {
}

sub save {
}

sub delete {
}

1;
#ABSTRACT: Access configuration data using a filesystem-like tree interface

=head1 SYNOPSIS

 use Config::Tree;
 use Config::Tree::IOD;
 use Config::Tree::Hash;


=head1 ATTRIBUTES


=head1 METHODS


=head1 FAQ


=head1 SEE ALSO

=cut

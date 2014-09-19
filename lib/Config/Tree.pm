package Config::Tree;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';

use Path::Naive qw(abs_path);

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    $self->{_dirstack} = [];
    $self->{_mounts}   = {};
    $self->{_cwd}      = '/';
    $self;
}

sub mount {
    my ($self, $path, $obj, $write) = @_;
    die "mount(): Please specify mountpoint" unless length $path;
    $self->{_mounts}{ abs_path($path, $self->{_cwd}) } = [$obj, $write];
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

sub _file {
    my $self = shift;
    my $which = shift;
    my $path = shift;

    die "$which(): Please specify path" unless length $path;
    die "$which(): Can't $which directory '$path'" if $path =~ m!/\z!;
    my $apath = abs_path($path, $self->{_cwd});
    die "$which(): Can't $which root directory '/'" if $apath eq '/';

    my $mnts = $self->{_mounts};
    die "$which(): Can't $which directory (root of mountpoint) '$apath'"
        if $mnts->{$apath};
    my $lpath = '';
    #say "D:apath=$apath";
    while ($apath =~ s!/([^/]+)\z!!) {
        $apath = "/" if $apath eq '';
        $lpath = "/$1$lpath";
        #say "D:apath=$apath, lpath=$lpath";
        my $v = $mnts->{$apath};
        if ($v) {
            if ($which eq 'set' && !$v->[1]) {
                die "$which(): Can't set because $apath is mounted read-only";
            }
            return $v->[0]->$which($lpath, @_);
        }
    }
    die "$which(): Path does not fall under any mounted config: '$path'";
}

sub get {
    my $self = shift;
    $self->_file('get', @_);
}

sub set {
    my $self = shift;
    $self->_file('set', @_);
}

sub delete {
    my $self = shift;
    $self->_file('delete', @_);
}

sub _dir {
    my $self = shift;
    my $which = shift;
    my $path = shift;

    die "$which(): Please specify path" unless length $path;
    my $apath = abs_path($path, $self->{_cwd});
    my $mnts = $self->{_mounts};
    my $lpath = '';
    while (1) {
        my $v = $mnts->{$apath};
        if ($v) {
            return $v->[0]->$which($lpath, @_);
        }
        $apath =~ s!/([^/]+)\z!! or last;
        $apath = "/" if $apath eq '';
        $lpath = "/$1$lpath";
        #say "D:apath=$apath, lpath=$lpath";
    }

    # special handling for 'list'
    if ($which eq 'list') {
        my @res;
        for (sort keys %$mnts) {
            if ($apath eq '/') {
                if (m!\A/([^/]+)!) {
                    push @res, $1 unless $1 ~~ @res;
                }
            } else {
                if (m!\A\Q$apath\E/([^/]+)!) {
                    push @res, $1;
                }
            }
        }
        return sort @res;
    }

    die "$which(): Path does not fall under any mounted config: '$path'";
}

sub list {
    my $self = shift;
    $self->_dir('list', @_);
}

sub save {
    my $self = shift;
    for (@{ $self->{_mounts} }) {
        $_->[0]->save;
    }
}

1;
#ABSTRACT: Unified access to configuration using filesystem-like tree interface

=head1 SYNOPSIS

In C<file.ini>:

 [sect1]
 foo=11
 bar=21

 [sect2]
 foo=12

In your script:

 use Config::Tree;
 use Config::Tree::IOD;
 use Config::Tree::Hash;

 my $hash = { foo => 1, bar => 2 };

 # prepare the config
 my $conf = Config::Tree->new;
 $conf->mount("/a", Config::Tree::IOD->new(path=>"file.ini", section=>"sect1"));
 $conf->mount("/b", Config::Tree::Hash->new(hash => $hash);

 # access your config
 say $conf->get('/a/foo');    # -> 11 (from config file file.ini)
 say $conf->get('/a/qux');    # -> undef (not found in config file)
 say $conf->get('/b/foo');    # -> 1 (from hash)
 say $conf->list('/a');       # -> ("foo", "bar")
 say $conf->list('/b');       # -> (1, 2)
 say $conf->list('/);         # -> ('a', 'b')

 $conf->set('/b/qux', 3);
 $conf->delete('/b/foo');
 say $conf->list('/b');       # -> ("foo", "qux")
 say $conf->get('/c/d/e');    # dies, outside of any mounted paths

 # more unix filesystem semantic: cd & relative paths
 $conf->cd('/b');
 $conf->list;                 # -> ("foo", "qux")
 $conf->get('../a/bar');      # -> 21
 $conf->pushd('../a');        # we are now in /a
 $conf->popd;                 # we are back in /b


=head1 DESCRIPTION

B<This is an early release. API might still change. Implementation will be
improved over time.>

This class provides a unified interface to various configuration data. The
interface mimics a Unix filesystem: a single-root tree with C</> as path
separator (as well as C<.> and C<..> notation for relative path).

The idea is to make your application storage-agnostic with regard to how and
where configuration is stored. All you need to be concerned with is the layout
of the configuration namespace (the structure and naming).

Interesting things can be done, e.g. dynamic config:

 $conf->get('/user/mince/max_disk_space');

 # disable all users
 for my $user ($conf->list('/user')) {
     $conf->set("/user/$user/is_disabled" => 1);
 }

where the configuration object mounted at C</user> will retrieve the list of
users dynamically as well as making sure user is really disabled if the
configuration C<is_disabled> is set to true.


=head1 ATTRIBUTES


=head1 METHODS

=head2 new(%attrs) => obj

Constructor. Initial working directory is C</>.

=head2 $conf->mount($path, $obj) => obj

Mount a configuration tree at C<$path>. Path must be an absolute path. C<$obj>
is another C<Config::Tree> object, a storage-specific C<Config::Tree::*> object,
or any other object that responds to the methods below (C<get()>, C<set()>,
etc).

All request (get, set, list, delete) under C<$path> will be delegated to
C<$obj>.

=head2 $conf->get($path) => $value

Get a configuration variable. Will return undef if variable does not exist.

C<$path> must point to a "file" or leaf, not a "directory" or subtree; the
method will die if it does.

=head2 $conf->set($path, $value) => $old_value

Set the value of a configuration variable.

C<$path> must point to a "file" or leaf, not a "directory" or subtree; the
method will die if it does.

=head2 $conf->delete($path, $value) => $old_value

Delete a configuration variable. Will do nothing if configuration variable
already does not exist.

C<$path> must point to a "file" or leaf, not a "directory" or subtree; the
method will die if it does.

=head2 $conf->list($path) => list

List the variable names at C<$path>.

C<$path> must point to a "directory" or leaf, not a "directory" or subtree; the
method will die if it does.

=head2 $conf->save($path)

Save modification to storage. This is relevant only for some drivers, like
L<Config::Tree::IOD>. With these kinds of drivers, every C<set()> won't
immediately save to storage because it would be inefficient. You will have to
call C<save()> to save to the file. But normally, you don't have to do this
manually as it will be called during C<DESTROY()>.


=head1 FAQ


=head1 SEE ALSO

=cut

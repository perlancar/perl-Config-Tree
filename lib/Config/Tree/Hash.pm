package Config::Tree::Hash;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Path::Naive qw(abs_path);

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    die "Please specify hash" unless $self->{hash};
    die "hash argument must be a hash" unless ref($self->{hash}) eq 'HASH';
    $self;
}

sub _doit {
    my $self  = shift;
    my $which = shift;
    my $path  = shift;

    my @path = split m!/!, $path; shift @path;
    my $h = $self->{hash};
    my $h2;
    for (0..@path-1) {
        $h2 = $h->{$path[$_]};
        if (ref($h2) eq 'HASH') {
            $h = $h2 unless $_ == @path-1;
        } else {
            if ($which eq 'set') {
                if ($_ < @path-1) {
                    die "set(): Can't set: '".join("/", @path[0..$_]).
                        "' is not a hash";
                }
            } else {
                if ($_ == @path-1) {
                    return $h2;
                } else {
                    return undef;
                }
            }
        }
    }
    if ($which eq 'get') {
        return $h;
    } elsif ($which eq 'set') {
        my $old = $h->{$path[-1]};
        $h->{$path[-1]} = $_[0];
        return $old;
    }
}

sub get {
    my $self = shift;
    $self->_doit('get', @_);
}

sub set {
    my $self = shift;
    $self->_doit('set', @_);
}

sub delete {
}

sub list {
}

sub save {}

1;
#ABSTRACT: Configuration tree from Perl hash

=ofr Pod::Coverage ^()$

=head1 SYNOPSIS

 use Config::Tree::Hash;

 my $hash = { foo => 1, bar => 2 };
 my $ct = Config::Tree::Hash->new(hash => $hash);


=head1 DESCRIPTION

This is a configuration tree which gets its values from a Perl hash.

Should not be used directly, but through L<Config::Tree>.


=head1 ATTRIBUTES

=head2 hash => hash


=head1 METHODS


=head1 FAQ


=head1 SEE ALSO

L<Config::Tree>

=cut

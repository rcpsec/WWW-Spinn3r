package WWW::Spinn3r;

use base Class::Accessor;
use LWP::UserAgent; 
use XML::RSS;
use Data::Dumper;
use Carp;

__PACKAGE__->mk_accessors(qw( api api_url next_url retries retry_sleep last_url this_cursor this_feed version ));

$WWW::Spinn3r::VERSION = '2.00100302';

our $DEFAULTS = { 
    api_url => 'http://api.spinn3r.com/rss',
    debug   => 0,
    retries => 5,
    retry_sleep => 30,
    version => '2.1.3',
};

    
sub new { 

    my ($class, %args) = @_;

    croak "Need vendor key" unless $args{params}->{vendor};
    croak "Need api name" unless $args{api};

    my $self = bless { %$DEFAULTS, %args }, $class;

    $self->{ua} = new LWP::UserAgent (timeout => 30);

    return $self;

}


sub first_url { 

    my ($self) = @_;

    # use default version if one is not provided. 
    if (defined $self->{params}->{version}) { 
        $self->version($self->{params}->{version});
        delete $self->{params}->{version}; 
    }

    my $url = $self->api_url . '/' . $self->api . '?version=' . $self->version;
    for my $param (keys %{ $self->{params} }) {
        $url .= '&' . $param . '=' . $self->{params}->{$param};
    }
    return $url;

}


sub http_get { 

    my ($self, $url) = @_;
    # fetch from Spinn3r

    my $tries = 0;
    my $done = 0;
    my $content = '';

    while ($tries < $self->retries and not $content) { 
    
        $tries++;

        $self->debug("fetching: $url");
        my $response = $self->{ua}->get($url);

        unless ($response->is_success) { 
            $self->debug($response->status_line);
            if ($response->status_line =~ /^4\d\d/) { 
                last;
            } 
            $self->debug("sleeping for " . $self->retry_sleep . " seconds...");
            sleep($self->retry_sleep);
        } else { 
            $content = $response->content;
            $self->debug("fetched on try $tries - length " . length($content));
        }
        
    }

    unless ($content) { 
        croak "Unable to fetch from spinn3r: $url";
    }

    return $content;

}

sub next_feed {

    my ($self) = @_;
    my $url = $self->next_url || $self->first_url;

    my $xml = $self->http_get($url);
    $self->last_url($url);
    return $xml;

}
 
 
sub next { 

    my ($self) = @_;
  
    unless ($self->this_feed) { 

        my $xml = $self->next_feed();

        # parse the response
        $self->debug("parsing: " . $self->last_url);
        my $parser = new XML::RSS;
        $parser->parse($xml);
        $self->debug("done parsing: " . $self->last_url);

        # set the object with the current feed, cursor, next_url
        $self->this_feed($parser);
        $self->this_cursor(0);
        $self->next_url($self->this_feed->{channel}->{'http://tailrank.com/ns/#api'}->{next_request_url});

        return $self->next();

    }

    my $item = $self->this_feed->{items}->[$self->this_cursor];

    unless ($item) { 
        $self->this_feed(undef);
        return $self->next();
    }

    $self->this_cursor($self->this_cursor+1);
    return $item;

}


sub debug { 

    my ($self, $msg) = @_;
    print "debug: (WWW::Spinn3r) $msg\n" if $self->{debug};

}


1;


=head1 NAME
    
WWW::Spinn3r - An interface to the Spinn3r API (http://www.spinn3r.com)

=head1 SYNOPSIS

 use WWW::Spinn3r;
 use DateTime;

 my $API = { 
    vendor          => 'acme',   # required
    limit           => 5, 
    lang            => 'en',
    tier            => '0:5', 
    after           => DateTime->now()->subtract(hours => 48),
 };

 my $spnr = new WWW::Spinn3r ( 
    api => 'permalink.getDelta', params => $API, debug => 1);
 );

 while(1) { 
     my $item = $spnr->next;
     print $item->{title};
     print $item->{link};
     print $item->{dc}->{source};
     print $item->{description};
 }

=head1 DESCRIPTION 

WWW::Spinn3r is an iterative interface to the Spinn3r API. The Spinn3r API 
is implemented over REST and XML and documented at 
C<http://spinn3r.com/documentation>.

=head1 OBTAINING A VENDOR KEY 

Spinn3r service is available through a B<vendor> key, which you can 
get from the good folks at Tailrank, C<http://spinn3r.com/contact>.

=head1 HOW TO USE

Most commonly, you'll need just two functions from this module: C<new()>
and C<next()>. C<new()> creates a new instance of the API and C<next()>
returns the next item from the Spinn3r feed, as a reference to a hash.
Details are below.

=head1 B<new()>

The contructor. This function takes

supports the following parameters:

=over 4

=item B<api>

C<permalink.getDelta> or C<feed.getDelta> or another API supported 
by Spinn3r.

=item B<params>

These are parameters that are passed to the API call. See
C<http://spinn3r.com/documentation> for a list of available parameters
and their values.

The B<version> parameter to the API is a function of version of this
module. For instance Spinn3r API version 2.1.3 corresponds to version
2.001003xx. The B<version> accessor method returns the version of the 
API.

If the version of the spinn3r API has changed, you can specify it 
as a parameter.  While the module is not guranteed to work with 
higher versions of the Spinn3r API it is designed for, it might if the
underlying formats and encodings have not changed.

=item B<debug>

Emits debug noise on STDOUT if set to 1. 

=item B<retries>

The number of HTTP retries in case of a 5xx failure from the API. 
The default is 5.

=back

=head1 B<next()>

This method returns the next item from the Spinn3r feed. The item is a
reference to a hash, which contains an RSS item as decoded by
XML::RSS.

The module transparently fetches a new set of results from
Spinn3r, using the C<api:next_request_url> returned by Spinn3r
with every request, and caches the result to implement C<next()>.

You can control the number of results that are fetched with 
every call by changing the C<limit> parameter at C<new()>.

=head1 B<next_feed()>

This method returns the raw XML returned by the next API call. This
SHOULD NOT be mixed with next() - either use next() and have
WWW::Spinn3r manage the iteration, or use next_feed() and manage the
iteration yourself. Note that next_feed() does not set the next_url(),
which has to be set explicitely, by you, after the first call.

=head1 B<next_url()>

The next API URL that WWW::Spinn3r will fetch. This is set to the
C<api:next_request_url> value returned by Spinn3r in the next() method.
This is a read/write accessor method, so you can manually set the
next_url() should you want to, for instance if you are using the 
next_feed() interface.

=head1 B<last_url()>

The last API URL that was fetched.

=head1 DATE STRING FORMAT

Spinn3r support ISO 8601 timestamps in the C<after> parameter. To 
create ISO 8601 timestamps, use the DateTime module that returns 
ISO 8601 date strings by default. eg:

 after => DateTime->now()->subtract(hours => 48),
 after => DateTime->now()->subtract(days => 31),

=head1 REPORTING BUGS

Bugs should be reported at C<http://rt.cpan.org>

=head1 TODO 

=over 4

=item Implement deflate compression. 

=item Implement saving to a file and expose next_feed()

=head1 AUTHOR

Vipul Ved Prakash <vipul@slaant.com>

=head1 LICENSE 

This software is distributed under the same terms as perl itself.

=cut

package MetaQuery;
use Dancer ':syntax';
use RDF::Query::Client;
use Modern::Perl;
use Data::Dumper;

our $VERSION = '0.1';
our $endpoint = 'http://data.libriotech.no/metaquery/';

get '/' => sub {
    template 'index';
};

get '/**' => sub {
    my $uri = request->uri_base . request->uri;
    $uri =~ s/localhost:3000/metaquery.libriotech.no/;
    
    # For some reason DISTINCT does not do what I expected here
    my $typesparql = _get_typesparql( $uri );
    debug $typesparql;
    my %datapoints;
    my $typequery = RDF::Query::Client->new( $typesparql );
    my $iterator = $typequery->execute( $endpoint );
    # Pick out the unique rows
    while (my $row = $iterator->next) {
        my $slug = $row->{slug}->literal_value;
        $datapoints{ $slug } = {
            sparql   => $row->{sparql}->literal_value,
            template => $row->{template}->literal_value,
        };
    }

    my $templatesparql = _get_templatesparql( $uri );
    my $templatequery = RDF::Query::Client->new( $templatesparql );
    my $templateiterator = $templatequery->execute( $endpoint );
    my $t = $templateiterator->next;
    my $template = $t->{template}->literal_value;
    debug '*** Template: ' . $template;
    
    foreach my $key ( keys %datapoints ) {
        my $sparql = $datapoints{ $key }{ 'sparql' };
        $sparql =~ s/__URI__/$uri/;
        debug '*** SPARQL: ' . $sparql;
        my $q = RDF::Query::Client->new( $sparql );
        my @querydata = $q->execute( $endpoint );
        # if ( @querydata ) {
        debug '*** Data: ' . Dumper @querydata;
        $datapoints{ $key }{ 'data' } = \@querydata;
        # } else {
        #     debug "http_response: " . Dumper $q->http_response;
        #     debug "error: " .         $q->error;
        # }
        
    }
    
    template 'index', { t => $template, d => \%datapoints };
};

sub _get_typesparql {

    my $uri = shift;

return "SELECT DISTINCT ?slug ?sparql ?template WHERE {
  <$uri> a ?type .
  ?type <http://example.org/hasQuery> ?typequery .
  ?typequery <http://example.org/hasSlug>     ?slug .
  ?typequery <http://example.org/hasQuery>    ?sparql .
  ?typequery <http://example.org/hasTemplate> ?template .
}";

}

sub _get_templatesparql {

    my $uri = shift;

return "SELECT DISTINCT ?template  WHERE {
  <$uri> a ?type .
  ?type <http://example.org/hasTemplate> ?template .
}";

}

true;

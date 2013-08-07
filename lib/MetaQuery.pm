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
    my $data = get_data_from_uri( $uri );
    template 'index', $data;
};

sub get_data_from_uri {

    my ( $uri ) = @_;
    my %data;
    my %datapoints;
    
    ##  First, get all the queries and templates based on the type of the given URI
    
    # Get the type query
    # $queries will be an iterator that holds a list of queries, each of which
    # is made up of a slug, a query and a template
    my $typesparql = "SELECT DISTINCT ?slug ?sparql ?template WHERE {
  <$uri> a ?type .
  ?type <http://example.org/hasQuery> ?typequery .
  ?typequery <http://example.org/hasSlug>     ?slug .
  ?typequery <http://example.org/hasQuery>    ?sparql .
  ?typequery <http://example.org/hasTemplate> ?template .
}";
    debug $typesparql;
    my $typequery = RDF::Query::Client->new( $typesparql );
    my $queries = $typequery->execute( config->{sparql_endpoint} );
    
    # Simplify the datastructure in $queries a bit
    # This will give us a hash of hashes, with the slugs as keys, 
    # and two keys in the inner hash: sparql and template
    # (It looked like the DISTINCT part of the type query did not
    # work at some point, this operation will have the side effect 
    # of ensuring we are working on unique slugs.)
    while (my $row = $queries->next) {
        my $slug = $row->{slug}->literal_value;
        $datapoints{ $slug } = {
            sparql   => $row->{sparql}->literal_value,
            template => $row->{template}->literal_value,
        };
    }

    ## Get the main template, based on the type of the given URI
    
    my $templatesparql = "SELECT DISTINCT ?template  WHERE {
  <$uri> a ?type .
  ?type <http://example.org/hasTemplate> ?template .
}";
    my $templatequery = RDF::Query::Client->new( $templatesparql );
    my $templateiterator = $templatequery->execute( $endpoint );
    # Grab the first template (there should not be more than one)
    my $t = $templateiterator->next;
    $data{'t'} = $t->{template}->literal_value;
    
    ## Iterate over the queries, and collect their data in %datapoints
    
    foreach my $key ( keys %datapoints ) {
        
        # Get the SPARQL query
        my $sparql = $datapoints{ $key }{ 'sparql' };
        
        # Insert the given URI into the query
        $sparql =~ s/__URI__/$uri/;
        debug '*** SPARQL: ' . $sparql;
        
        # Run the query
        my $q = RDF::Query::Client->new( $sparql );
        my @querydata = $q->execute( $endpoint );
        debug '*** Data: ' . Dumper @querydata;
        # Add the data to %datapoints with a new key called "data"
        $datapoints{ $key }{ 'data' } = \@querydata;
        
    }
    $data{'d'} = \%datapoints;

    return \%data;

}

true;

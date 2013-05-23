package MetaQuery;
use Dancer ':syntax';
use Dancer::Exception qw(:all);
use RDF::Query::Client;
use JSON;
use Modern::Perl;
use Data::Dumper;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/admin' => sub {
    my $query = 'SELECT DISTINCT ?query WHERE { <http://purl.org/ontology/bibo/Document> <http://example.org/hasQuery> ?query . }';
    my $client = RDF::Query::Client->new( $query );
    my @queries = $client->execute( config->{sparql_endpoint} );
    template 'admin', { queries => \@queries };
};

get '/query/add' => sub {
    template 'query_add';
};

post '/query/add' => sub {
    
    my $slug     = param 'slug';
    my $query    = param 'query';
    my $template = param 'template';
    
    my $insertquery = "INSERT INTO <http://metaquery.libriotech.no/queries/> { 
        <http://purl.org/ontology/bibo/Document> <http://example.org/hasQuery> <http://example.org/query/$slug> .
        <http://example.org/query/$slug> <http://example.org/hasSlug> '$slug' .
        <http://example.org/query/$slug> <http://example.org/hasQuery> '$query' .
        <http://example.org/query/$slug> <http://example.org/hasTemplate> '$template' .
    }";
    debug '*** Insert query: ' . $insertquery;
    _sparql_insert( $insertquery );
    
    # This succeeds but then gives some weird and fatal error:
    # my $client = RDF::Query::Client->new( $insertquery );
    # my %opts = ( 
    #     'QueryMethod' => 'POST'
    # );
    # try {
        # my $result = 
        # $client->execute( config->{sparql_endpoint}, \%opts );
        # if ( $result ) {
        #     debug '*** result ok: ' . Dumper $result;
        # } 
        # else {
        #     debug '*** result !ok: ' .        Dumper $result;
        #     debug '*** http_response: ' . Dumper $client->http_response;
        #     debug '*** error: ' .         $client->error;
        # }
    # }
    
    redirect '/admin';
};

## Front end

get '/**' => sub {
    my $uri = request->uri_base . request->uri;
    $uri =~ s/localhost:3000/metaquery.libriotech.no/;
    
    # For some reason DISTINCT does not do what I expected here
    my $typesparql = _get_typesparql( $uri );
    debug $typesparql;
    my %datapoints;
    my $typequery = RDF::Query::Client->new( $typesparql );
    my $iterator = $typequery->execute( config->{sparql_endpoint} );
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
    my $templateiterator = $templatequery->execute( config->{sparql_endpoint} );
    my $t = $templateiterator->next;
    my $template = $t->{template}->literal_value;
    debug '*** Template: ' . $template;
    
    foreach my $key ( keys %datapoints ) {
        my $sparql = $datapoints{ $key }{ 'sparql' };
        $sparql =~ s/__URI__/$uri/;
        debug '*** SPARQL: ' . $sparql;
        my $q = RDF::Query::Client->new( $sparql );
        my @querydata = $q->execute( config->{sparql_endpoint} );
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

sub _sparql_insert {

    my $sparql = shift;

    return _sparql_query( $sparql, 'POST', config->{sparql_endpoint}, config->{sparql_endpoint_key} );

}

sub _sparql_query {
  
  my ($sparql, $method, $baseURL, $baseURLkey, $debug) = @_;
  
  # if ( !$baseURL ) {
  #   # Use the default baseURL
  #   $baseURL = config->{'base_url'};
  #   if ( !$baseURLkey ) {
  #     # Only set baseURLkey to the default if we are going to talk
  #     # to our own baseURL, otherwise we will be sending our password
  #     # to remote baseURls!
  #     $baseURLkey = config->{'base_url_key'};
  #   }
  # }
  
  my %params=(
    'query' => $sparql,
    'output' => 'json',
    'key' => $baseURLkey,
  );

  my $ua = LWP::UserAgent->new;
  $ua->agent("literawards");
  my $res = '';
  if ( lc $method eq 'get' ) {
    my $url = URI->new($baseURL);
    $url->query_form(%params);
    $res = $ua->get($url);
  } elsif ( lc $method eq 'post' ) {
    $res = $ua->post($baseURL, Content => \%params);
  }
  
  if ($res->is_success) {
    print $res->decoded_content if $debug;
  } else {
    print $res->status_line, "\n";
  }
  
  my $str = $res->content;

  print Dumper $str if $debug;
  
  my $data = decode_json($str);

  if ( $sparql =~ m/^load/i || $sparql =~ m/^insert/i ) {
    return $data->{'inserted'};
  }
  
  return $data->{'results'}->{'bindings'};
}

true;

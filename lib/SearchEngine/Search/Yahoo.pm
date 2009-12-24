# Copyright (c) 2009 ToI-Planning, All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# $Id$

package SearchEngine::Search::Yahoo::Handler;
use XML::SAX::Base;
use base qw(XML::SAX::Base);

sub new {
    my $class = shift;
    my (%param) = @_;
    my $self = bless \%param, $class;

	$self->{'d'} = {};
	$self->{'d'}{'total'} = 0;
	$self->{'d'}{'estimated'} = 0;
	$self->{'d'}{'results'} = [];
	$self->{'d'}{'cache'} = 0;

    return $self;
}

sub start_element {
	my $self = shift;
	my $data = shift;

	if ($data->{'Name'} eq 'ResultSet') {
		$self->{'d'}{'estimated'} = $self->{'d'}{'total'} =
			$data->{'Attributes'}{'{}totalResultsAvailable'}->{'Value'};
	}
	elsif ($data->{'Name'} eq 'Result') {
		$self->{'d'}{'current'} = bless({}, 'SearchEngine::Result');
	}
	elsif ($data->{'Name'} eq 'Cache') {
		$self->{'d'}{'cache'} = 1;
	}
	elsif (grep($_ eq lc($data->{'Name'}), 'title', 'summary', 'url'))  {
		$self->{'d'}{'currentkey'} = lc($data->{'Name'});
	}
}

sub characters {
	my $self = shift;
	my $data = shift;

	return if $self->{'d'}{'cache'};

	my %map = qw(
		title title
		url url
		summary content
	);

	if ($self->{'d'}{'current'} && $self->{'d'}{'currentkey'}) {
		$self->{'d'}{'current'}{$map{$self->{'d'}{'currentkey'}}} ||= '';
		$self->{'d'}{'current'}{$map{$self->{'d'}{'currentkey'}}} .=
			$data->{'Data'};
	}
}

sub end_element {
	my $self = shift;
	my $data = shift;

	if ($data->{'Name'} eq 'Result') {
		push(@{ $self->{'d'}{'results'} }, $self->{'d'}{'current'});
		$self->{'d'}{'current'} = undef;
	}
	elsif ($data->{'Name'} eq 'Cache') {
		$self->{'d'}{'cache'} = 0;
	}
	else {
		delete($self->{'d'}{'currentkey'});
	}
}

package SearchEngine::Search::Yahoo;

use strict;
use warnings;

use SearchEngine::Search;
use base qw/ SearchEngine::Search /;

sub process { __PACKAGE__->SUPER::process(@_); }

sub _search {
    my $app = shift;
    my $q   = $app->param;
	my ($url) = @_;

	my $plugin = MT->component('SearchEngine');

	my $ua = $app->_user_agent;
	my $site = $app->_site;

	my $appid = $plugin->get_config_value('yahoo_appid') || '';

	my $limit = $app->param('limit') || 20;
	$app->param('limit', $limit);
	my $start = $app->param('offset') || 0;
	$start++;
	my $search = $app->{'search_string'};
	my $format = $app->_format;
	$format = '&format=' . $format if $format;

	my $req = HTTP::Request->new(
		GET => "$url?v=1.0&q=site:$site $search$format&rsz=large&start=$start",
		new HTTP::Headers(Referer => $site)
	);

	my $response = $ua->get("$url?appid=$appid&site=$site&query=$search&results=$limit&start=$start");
	if ($response->is_success) {
		my $content = $response->content;
		if (MT->version_number < 5) {
			require Encode;
			$content = Encode::encode('utf-8', $content);
		}

		my $objs;

		require XML::SAX;
		my $handler = SearchEngine::Search::Yahoo::Handler->new;

		require MT::Util;
		my $parser = MT::Util::sax_parser();
		$parser->{Handler} = $handler;
		eval { $parser->parse_string($content); };

		return $handler->{'d'};
	}
	else {
		die $response->status_line;
	}
}

sub web {
    my $app = shift;
	$app->_search('http://search.yahooapis.jp/WebSearchService/V1/webSearch', @_);
}

sub images {
    my $app = shift;
	$app->_search('http://search.yahooapis.jp/ImageSearchService/V1/imageSearch', @_);
}

sub formats {
	qw/
		doc msword
		docx msword
	/;
}

sub powered_by {
	my $app = shift;
	my ($type) = @_;
	if ($type eq 'text') {
		'Web services by Yahoo! JAPAN';
	}
	else {
		'<img height="17" width="125" alt="Web services by Yahoo! JAPAN" src="http://i.yimg.jp/images/yjdn/common/yjdn_attbtn1_125_17.gif"/>';
	}
}

1;

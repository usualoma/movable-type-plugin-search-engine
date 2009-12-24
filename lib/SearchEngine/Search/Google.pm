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

package SearchEngine::Search::Google;

use strict;
use warnings;

use SearchEngine::Search;
use base qw/ SearchEngine::Search /;

sub process { __PACKAGE__->SUPER::process(@_); }

sub _search {
    my $app = shift;
    my $q   = $app->param;
	my ($url) = @_;

	use HTTP::Request;
	use HTTP::Headers;
	use JSON;

	my $ua = $app->_user_agent;
	my $site = $app->_site;

	$app->param('limit', 8);
	my $start = $app->param('offset') || 0;
	my $search = $app->{'search_string'};
	my $format = $app->_format;
	$format = ' filetype:' . $format if $format;

	my $req = HTTP::Request->new(
		GET => "$url?v=1.0&q=site:$site $format $search&rsz=large&start=$start",
		new HTTP::Headers(Referer => $site)
	);

	my $response = $ua->simple_request($req);
	if ($response->is_success) {
		my %res = ();
		#my $objs = JSON::from_json($response->content);
		my $objs = JSON::jsonToObj($response->content);

		$res{'estimated'} = $res{'total'} =
			$objs->{'responseData'}{'cursor'}{'estimatedResultCount'};
		if ($res{'total'} > 64) {
			$res{'total'} = 64;
		}

		$res{'results'} = [];
		foreach my $r (@{ $objs->{'responseData'}{'results'} }) {
			push(@{ $res{'results'} }, bless($r, 'SearchEngine::Result'));
		}

		return \%res;
	}
	else {
		die $response->status_line;
	}
}

sub web {
    my $app = shift;
	$app->_search('http://ajax.googleapis.com/ajax/services/search/web', @_);
}

sub images {
    my $app = shift;
	$app->_search('http://ajax.googleapis.com/ajax/services/search/images', @_);
}

sub formats {
	qw/
		msword doc
	/;
}

sub powered_by {
	my $app = shift;
	my ($type) = @_;
	if ($type eq 'text') {
		'powered by Google';
	}
	else {
		'<img border="0" alt="powered by Google" src="http://www.google.com/logos/powered_by_google_135x35.gif"/>';
	}
}

1;

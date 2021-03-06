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

package SearchEngineTest;

use strict;
use warnings;

use SearchEngine::Search;
use base qw/ SearchEngine::Search /;

sub process { __PACKAGE__->SUPER::process(@_); }

sub _search {
    my $app = shift;
    my $q   = $app->param;

	my $site = $app->_site;

	my $limit = $app->param('limit') || 20;
	my $start = $app->param('offset') || 0;
	my $search = $app->{'search_string'};
	# file format
	my $format = $app->_format;

	my %res = ();
	$res{'total'} = 2;

	$res{'results'} = [];

	if (my $obj = MT->model('entry')->load({
		'blog_id' => [ $app->blog_ids ],
	})) {
		push(@{ $res{'results'} }, bless({
			'title' => $obj->title,
			'url' => $obj->permalink,
			'content' => $obj->get_excerpt,
		}, 'SearchEngine::Result'));
	}

	if (my $obj = MT->model('entry')->load({
		'class' => 'page', 'blog_id' => [ $app->blog_ids ],
	})) {
		push(@{ $res{'results'} }, bless({
			'title' => $obj->title,
			'url' => $obj->permalink,
			'content' => $obj->get_excerpt,
		}, 'SearchEngine::Result'));
	}

	if (my $obj = MT->model('asset')->load({
		'class' => '*', 'blog_id' => [ $app->blog_ids ],
	})) {
		push(@{ $res{'results'} }, bless({
			'title' => $obj->file_name,
			'url' => $obj->url,
			'content' => $obj->description,
		}, 'SearchEngine::Result'));
	}

	$res{'total'} = scalar(@{ $res{'results'} });

	return \%res;
}

sub web {
    my $app = shift;
	$app->_search(@_);
}

sub images {
    my $app = shift;
	$app->_search(@_);
}

1;

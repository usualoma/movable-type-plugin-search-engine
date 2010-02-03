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

package SearchEngine::Result;

use strict;
use warnings;

use MT::Object;
use base qw/ MT::Object /;

sub properties {
	{};
}

sub AUTOLOAD {
	my $self = shift;
	my $method = our $AUTOLOAD;
	$method =~ s/.*:://o;

	$self->{$method} || '';
}

package SearchEngine::Search;

use strict;
use warnings;

use MT::App::Search;
use base qw/ MT::App::Search /;

sub process {
	my $pkg = shift;

	my $app = shift;
	$app = bless({ %$app }, $pkg);
	MT->set_instance($app);

	$app->_register_core_callbacks({
		"${pkg}::search_post_execute" => \&MT::App::Search::_log_search,
		"${pkg}::search_post_render"  => \&MT::App::Search::_cache_out,
		"${pkg}::prepare_throttle"    => \&MT::App::Search::_default_throttle,
		"${pkg}::take_down"           => \&MT::App::Search::_default_takedown,
	});

	no warnings 'redefine';
	require MT::Template::Context::Search;
	my $context_script = \&MT::Template::Context::Search::context_script;
	*MT::Template::Context::Search::context_script = \&context_script;

	$app->SUPER::process(@_);
}

sub context_script {
	my ($ctx, $args, $cond) = @_;

	require MT;
	my $app = MT->instance;

	my $cgipath = ($ctx->handler_for('CGIPath'))[0]->($ctx, $args);
	my $script = $ctx->{config}->SearchScript;

	my @ignores = ('startIndex', 'limit', 'offset', 'format', 'page');
	my $q = new CGI('');
	if ($app->isa('MT::App::Search')) {
		foreach my $p ($app->param) {
			if (! grep({ $_ eq $p } @ignores)) {
				$q->param($p, $app->param($p));
			}
		}
	}

	local $CGI::USE_PARAM_SEMICOLONS;
	$CGI::USE_PARAM_SEMICOLONS = 0;
	$cgipath . $script . '?' . $q->query_string;
}

sub default_type {
    my $app = shift;
	($app->supported_types)[0];
}

sub supported_types {
	('web', 'images');
}

sub web {
	();
}

sub images {
	();
}

sub make_iter {
    my $app = shift;
	my ($list) = @_;

	sub {
		shift(@$list);
	};
}

sub search_terms {
	return({}, {});
}

sub blog_ids {
	my $app = shift;
	my $q = $app->param;

	if ($q->param('IncludeBlogs')) {
		split ',', $q->param('IncludeBlogs');
	}
	elsif (
		exists($app->{searchparam}{IncludeBlogs})
		&& keys(%{ $app->{searchparam}{IncludeBlogs} } )
	) {
		keys %{ $app->{searchparam}{IncludeBlogs} };
	}
}

sub execute {
    my $app = shift;
    my $q   = $app->param;

	my $type = $app->{searchparam}{Type};
	$app->{searchparam}{Type} = 'entry';
	$app->{'search_string'} = $q->param('searchTerms') || $q->param('search');

	my $res = {
		'total' => 0,
		'results' => [],
	};

	my ($search_type) = grep($type eq $_, $app->supported_types);
	$search_type ||= $app->default_type;

	$res = $app->$search_type(@_);
	foreach my $r (@{ $res->{'results'} }) {
		next if $r->{'entry'} || $r->{'asset'};

		my $url = $r->{'url'} if $r->{'url'};

		{
			my ($rel_url) = ( $url =~ m|^(?:[^:]*\:\/\/)?[^/]*(.*)| );
			$rel_url =~ s|//+|/|g;

			my $terms = {
				'url' => $rel_url,
			};
			if ($rel_url =~ m{/$}) {
				$terms->{'url'} = {'like' => $rel_url . 'index%'};
			}
			$r->{'fileinfo'} = MT->model('fileinfo')->load($terms);
			if ($r->{'fileinfo'}) {
				$r->{'entry'} = MT->model('entry')->load({
					'id' => $r->{'fileinfo'}->entry_id,
				});
			}
		}

		if (! $r->{'entry'}) {
			my $static_path = MT->instance->static_path;
			foreach my $id ($app->blog_ids) {
				my $blog = MT->model('blog')->load($id);

				my $site_url = $blog->site_url;
				my $archive_url = $blog->archive_url;

				my @urls = ($url) x 4;
				$urls[1] =~ s{^$static_path}{/%s};
				$urls[2] =~ s{^$site_url}{%r/};
				$urls[3] =~ s{^$archive_url}{%a/};

				$r->{'asset'} = MT->model('asset')->load({
					'class' => '*',
					'url' => \@urls,
					'blog_id' => $blog->id,
				});

				if ($r->{'asset'}) {
					last;
				}
			}
		}
	}

	$app->{'estimated_total'} = $res->{'estimated'};
	return ($res->{'total'}, $app->make_iter($res->{'results'}));
}

sub _user_agent {
	my $app = shift;

	use LWP::UserAgent;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	if (my $proxy = MT->config('HTTPProxy')) {
		$ua->proxy('http', $proxy);
	}
	$ua->timeout(10);

	$ua;
}

sub _site {
	my $app = shift;

	my $site = $app->param('site');
	if (! $site) {
		foreach my $id ($app->blog_ids) {
			my $blog = $app->model('blog')->load($id);
			my $site_url = $blog->site_url;
			if (! $site || (length($site) > length($site_url))) {
				$site = $site_url;
			}
		}
	}

	$site;
}

sub formats {
	();
}

sub _format {
	my $app = shift;
	my %map = $app->formats;
	my $format = $app->param('format') || '';
	$format = $map{$format} if $map{$format};

	$format;
}

sub powered_by {
	'';
}

1;

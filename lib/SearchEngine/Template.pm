# Copyright (c) 2009 Movable Type ACME Plugin Project, All rights reserved.
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

package SearchEngine::Template;

use strict;
use warnings;

sub __hdlr_is_entry {
	my ($class, $ctx, $args, $cond) = @_;

	my $result = $ctx->stash('entry')
		or '';
	if ($result->{'entry'} && ($result->{'entry'}->class eq $class)) {
		local $ctx->{__stash}{'entry'} = $result->{'entry'};
		return $ctx->slurp($args, $cond);
	}
	else {
		return '';
	}
}

sub _hdlr_is_entry {
	&__hdlr_is_entry('entry', @_);
}

sub _hdlr_is_page {
	&__hdlr_is_entry('page', @_);
}

sub _hdlr_is_asset {
	my ($ctx, $args, $cond) = @_;
	my $result = $ctx->stash('entry')
		or '';
	if ($result->{'asset'}) {
		local $ctx->{__stash}{'asset'} = $result->{'asset'};
		return $ctx->slurp($args, $cond);
	}
	else {
		return '';
	}
}

sub _hdlr_is_unkown {
	my ($ctx, $args, $cond) = @_;
	my $result = $ctx->stash('entry');
	$result
		&& $result->isa('SearchEngine::Result')
		&& (! $result->{'entry'})
		&& (! $result->{'asset'});
}

sub _hdlr_result_title {
	my ($ctx, $args) = @_;
	my $result = $ctx->stash('entry');
	$result->title;
}

sub _hdlr_result_url {
	my ($ctx, $args) = @_;
	my $result = $ctx->stash('entry');
	$result->url;
}

sub _hdlr_result_content {
	my ($ctx, $args) = @_;
	my $result = $ctx->stash('entry');
	$result->content;
}

sub _hdlr_search_type {
	MT->instance->param('type');
}

sub _hdlr_search_engine {
	MT->instance->param('__mode');
}

sub _hdlr_search_format {
	MT->instance->param('format');
}

sub _hdlr_powered_by {
	my ($ctx, $args) = @_;
	MT->instance->powered_by($args->{'type'} || 'html');
}

sub _hdlr_estimated_total {
	my ($ctx, $args) = @_;
	MT->instance->{'estimated'};
}

1;

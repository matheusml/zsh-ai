#!/usr/bin/env perl

use strict;
use warnings;
use JSON::PP qw(decode_json);

my $raw = do { local $/; <STDIN> };

# Normalize model output to a single command line before inserting it into zsh.
sub clean {
    my ($text) = @_;
    $text =~ s/\n//g;
    $text =~ s/[[:space:]]+\z//;
    return $text;
}

# Emit backend failures in the provider's standard error format.
sub api_error {
    my ($message) = @_;
    $message ||= "Unknown API error";
    print "API Error: $message";
    exit 1;
}

# Extract command text from non-streamed Responses API JSON or completed
# response objects that arrive inside SSE events.
sub extract_response_text {
    my ($data) = @_;
    return undef unless $data && ref($data) eq "HASH";

    if (ref($data->{error}) eq "HASH") {
        api_error($data->{error}->{message});
    }
    if (defined($data->{error}) && !ref($data->{error})) {
        api_error($data->{error});
    }
    if (defined($data->{message}) && !ref($data->{message})) {
        api_error($data->{message});
    }
    if (defined($data->{detail}) && !ref($data->{detail})) {
        api_error($data->{detail});
    }

    my $status = $data->{status} || "";
    if ($status eq "failed" || $status eq "incomplete") {
        my $message = "Response $status";
        if (ref($data->{error}) eq "HASH" && $data->{error}->{message}) {
            $message = $data->{error}->{message};
        } elsif (ref($data->{incomplete_details}) eq "HASH" && $data->{incomplete_details}->{reason}) {
            $message = $data->{incomplete_details}->{reason};
        }
        api_error($message);
    }

    my $text = $data->{output_text};
    if ((!defined($text) || $text eq "") && ref($data->{output}) eq "ARRAY") {
        my @parts;
        for my $item (@{$data->{output}}) {
            next unless ref($item) eq "HASH" && ref($item->{content}) eq "ARRAY";
            for my $content (@{$item->{content}}) {
                next unless ref($content) eq "HASH";
                push @parts, $content->{text} if defined $content->{text} && !ref($content->{text});
            }
        }
        $text = join "", @parts;
    }

    return $text if defined($text) && $text ne "";
    return undef;
}

# Walk server-sent-event blocks, collect output deltas, prefer final done text
# when supplied, and surface streamed error events as API failures.
sub parse_sse {
    my ($stream) = @_;
    my @deltas;
    my $done_text;
    my $completed_text;

    for my $block (split /\r?\n\r?\n/, $stream) {
        my $event_name = "";
        my @data_lines;

        for my $line (split /\r?\n/, $block) {
            if ($line =~ /^event:\s*(.*)$/) {
                $event_name = $1;
            } elsif ($line =~ /^data:\s?(.*)$/) {
                push @data_lines, $1;
            }
        }

        next unless @data_lines;
        my $payload = join "\n", @data_lines;
        $payload =~ s/^\s+//;
        $payload =~ s/\s+\z//;
        next if $payload eq "" || $payload eq "[DONE]";

        my $event = eval { decode_json($payload) };
        next unless $event && ref($event) eq "HASH";

        my $type = $event->{type} || $event_name;
        if ($type eq "error" || $event_name eq "error") {
            if (ref($event->{error}) eq "HASH" && $event->{error}->{message}) {
                api_error($event->{error}->{message});
            }
            api_error($event->{message} || $event->{error});
        }

        if ($type eq "response.failed" || $type eq "response.incomplete") {
            if (ref($event->{response}) eq "HASH") {
                extract_response_text($event->{response});
            }
            api_error($event->{message});
        }

        if ($type eq "response.output_text.delta" && defined($event->{delta}) && !ref($event->{delta})) {
            push @deltas, $event->{delta};
        } elsif ($type eq "response.output_text.done" && defined($event->{text}) && !ref($event->{text})) {
            $done_text = $event->{text};
        } elsif ($type eq "response.completed" && ref($event->{response}) eq "HASH") {
            my $text = extract_response_text($event->{response});
            $completed_text = $text if defined($text) && $text ne "";
        }
    }

    return $done_text if defined($done_text) && $done_text ne "";
    return join "", @deltas if @deltas;
    return $completed_text if defined($completed_text) && $completed_text ne "";
    return undef;
}

my $data = eval { decode_json($raw) };
if ($data && ref($data) eq "HASH") {
    my $text = extract_response_text($data);
    if (defined($text) && $text ne "") {
        print clean($text);
        exit 0;
    }

    print "Error: Unable to parse response";
    exit 1;
}

my $text = parse_sse($raw);
if (defined($text) && $text ne "") {
    print clean($text);
    exit 0;
}

print "Error: Unable to parse response";
exit 1;
